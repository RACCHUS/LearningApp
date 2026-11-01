-- pgTAP test for study_progress security_invoker view, Data API grants, lesson_texts visibility, and skill assessment RLS
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(38);

-- 1. Create synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid'),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name, show_on_leaderboards) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid', 'Learner One', true),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid', 'Learner Two', true)
on conflict (id) do nothing;

-- 2. Insert test course, lessons (public & private), lesson_texts, skill, and progress via service_role
set local role service_role;
insert into public.courses (id, title, description, user_id) values
 ('c0000000-0000-0000-0000-000000000001', 'Test Course', 'Course Description', 'cc111111-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.lessons (id, title, user_id, visibility) values
 ('b0000000-0000-0000-0000-000000000001', 'Test Public Lesson', 'cc111111-0000-4000-8000-000000000001', 'public'),
 ('b0000000-0000-0000-0000-000000000002', 'Test Private Lesson', 'cc111111-0000-4000-8000-000000000001', 'private')
on conflict (id) do nothing;

insert into public.lesson_texts (id, lesson_id, text) values
 ('ee000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'Public Supplementary Text'),
 ('ee000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'Private Confidential Text')
on conflict (id) do nothing;

insert into public.user_progress (id, user_id, lesson_id, date, questions_answered, correct_count, lesson_completed) values
 ('d0000000-0000-0000-0000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'b0000000-0000-0000-0000-000000000001', current_date, 5, 5, true),
 ('d0000000-0000-0000-0000-000000000002', 'cc111111-0000-4000-8000-000000000002', 'b0000000-0000-0000-0000-000000000001', current_date, 10, 8, true)
on conflict (id) do nothing;

insert into public.skills (id, name, slug, category, description) values
 ('e0000000-0000-0000-0000-000000000001', 'Test Skill 1', 'test-skill-1', 'Technical', 'Skill 1 description'),
 ('e0000000-0000-0000-0000-000000000002', 'Test Skill 2', 'test-skill-2', 'Technical', 'Skill 2 description')
on conflict (id) do nothing;

insert into public.skill_assessments (id, skill_id, title, is_active) values
 ('a0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'Skill Assessment 1', true),
 ('a0000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'Skill Assessment 2', true)
on conflict (id) do nothing;

insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer) values
 ('f0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'What is 1+1?', '["1", "2"]'::jsonb, 1)
on conflict (id) do nothing;

-- 3. Explicit Table-Level Privilege Assertions (has_table_privilege)
select ok(
  has_table_privilege('authenticated', 'public.user_skill_stats', 'SELECT'),
  'authenticated role has SELECT privilege on user_skill_stats'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_skill_stats', 'INSERT'),
  'authenticated role has no INSERT privilege on user_skill_stats'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_skill_stats', 'UPDATE'),
  'authenticated role has no UPDATE privilege on user_skill_stats'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_skill_stats', 'DELETE'),
  'authenticated role has no DELETE privilege on user_skill_stats'
);
select ok(
  not has_table_privilege('anon', 'public.user_skill_stats', 'SELECT'),
  'anon role has no SELECT privilege on user_skill_stats'
);
select ok(
  not has_table_privilege('anon', 'public.study_progress', 'SELECT'),
  'anon role has no SELECT privilege on study_progress'
);
select ok(
  has_table_privilege('authenticated', 'public.study_progress', 'SELECT'),
  'authenticated role has SELECT privilege on study_progress'
);

-- 4. Test anon role permissions & lesson_texts visibility
set local role anon;

-- Anon CAN read public catalog tables
select lives_ok(
  $$ select count(*) from public.skills $$,
  'Anon can SELECT from public.skills'
);

select lives_ok(
  $$ select count(*) from public.skill_assessments $$,
  'Anon can SELECT from public.skill_assessments'
);

select lives_ok(
  $$ select count(*) from public.assessment_questions $$,
  'Anon can SELECT from public.assessment_questions'
);

-- Anon CANNOT read private progress view or private user tables (42501 permission denied)
select throws_ok(
  $$ select * from public.study_progress $$,
  '42501',
  null,
  'Anon cannot SELECT from public.study_progress view'
);

select throws_ok(
  $$ select * from public.assessment_attempts $$,
  '42501',
  null,
  'Anon cannot SELECT from public.assessment_attempts'
);

select throws_ok(
  $$ select * from public.user_skill_stats $$,
  '42501',
  null,
  'Anon cannot SELECT from public.user_skill_stats'
);

-- Anon CAN read text of public lesson
select is(
  (select count(*)::integer from public.lesson_texts where id = 'ee000000-0000-0000-0000-000000000001'),
  1,
  'Anon can SELECT lesson_texts of public lesson'
);

-- P1 SECURITY VERIFICATION: Anon CANNOT read text of private lesson
select is(
  (select count(*)::integer from public.lesson_texts where id = 'ee000000-0000-0000-0000-000000000002'),
  0,
  'Anon CANNOT read lesson_texts belonging to private lesson'
);

-- 5. Test unrelated authenticated user (User 2)
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000002', true);
end $$;

-- User 2 CAN read text of public lesson
select is(
  (select count(*)::integer from public.lesson_texts where id = 'ee000000-0000-0000-0000-000000000001'),
  1,
  'Unrelated authenticated user can SELECT lesson_texts of public lesson'
);

-- P1 SECURITY VERIFICATION: User 2 CANNOT read text of User 1 private lesson
select is(
  (select count(*)::integer from public.lesson_texts where id = 'ee000000-0000-0000-0000-000000000002'),
  0,
  'Unrelated authenticated user CANNOT read lesson_texts belonging to private lesson'
);

-- 6. Switch to authenticated User 1 (owner)
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- User 1 CAN read public catalog
select lives_ok(
  $$ select count(*) from public.skills $$,
  'Authenticated can SELECT from public.skills'
);

-- User 1 CAN read own study_progress
select is(
  (select count(*)::integer from public.study_progress where user_id = 'cc111111-0000-4000-8000-000000000001'),
  1,
  'User 1 can see own record in study_progress'
);

-- P1 SECURITY VERIFICATION: User 1 CANNOT see User 2 progress through study_progress view (security_invoker = true)
select is(
  (select count(*)::integer from public.study_progress where user_id = 'cc111111-0000-4000-8000-000000000002'),
  0,
  'User 1 cannot see User 2 records in study_progress view (security_invoker enforced)'
);

-- User 1 cannot directly INSERT into user_skill_stats (privilege revoked, strictly server-side trigger)
select throws_ok(
  $$ insert into public.user_skill_stats (user_id, skill_id, level) values ('cc111111-0000-4000-8000-000000000001', 'e0000000-0000-0000-0000-000000000001', 99) $$,
  '42501',
  null,
  'Authenticated user cannot directly INSERT into user_skill_stats'
);

-- User 1 cannot execute calculate_skill_level RPC directly (service_role only)
select throws_ok(
  $$ select calculate_skill_level('cc111111-0000-4000-8000-000000000001'::uuid, 'e0000000-0000-0000-0000-000000000001'::uuid) $$,
  '42501',
  null,
  'Authenticated user cannot execute calculate_skill_level directly'
);

-- User 1 CAN start an attempt with is_verified = FALSE
select lives_ok(
  $$ insert into public.assessment_attempts (id, assessment_id, user_id, is_verified, started_at)
     values ('aa000000-0000-0000-0000-000000000001'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'cc111111-0000-4000-8000-000000000001', false, now()) $$,
  'User 1 can create unverified assessment attempt'
);

-- User 1 CANNOT self-certify an attempt with is_verified = TRUE (RLS WITH CHECK rejects)
select throws_ok(
  $$ insert into public.assessment_attempts (id, assessment_id, user_id, is_verified, started_at)
     values ('aa000000-0000-0000-0000-000000000002'::uuid, 'a0000000-0000-0000-0000-000000000001'::uuid, 'cc111111-0000-4000-8000-000000000001', true, now()) $$,
  '42501',
  null,
  'User 1 cannot create verified assessment attempt (RLS rejects is_verified = true)'
);

-- Completing unverified attempt updates user_skill_stats as is_verified = FALSE
select lives_ok(
  $$ update public.assessment_attempts
     set completed_at = now(), score = 80, correct_count = 1, total_questions = 1
     where id = 'aa000000-0000-0000-0000-000000000001' $$,
  'User 1 completes unverified assessment attempt'
);

-- Leaderboard isolation: unverified stats do NOT appear on skill_leaderboard view
select is(
  (select count(*)::integer from public.skill_leaderboard where user_id = 'cc111111-0000-4000-8000-000000000001'),
  0,
  'Unverified skill stats do not appear on public skill_leaderboard'
);

-- User 1 (owner) CAN read own private lesson text
select is(
  (select count(*)::integer from public.lesson_texts where id = 'ee000000-0000-0000-0000-000000000002'),
  1,
  'Lesson owner can SELECT lesson_texts belonging to own private lesson'
);

-- 7. P2 VERIFICATION: Verified attempt populates stats; soft-deletion recalculates and clears leaderboard
set local role service_role;
insert into public.assessment_attempts (id, assessment_id, user_id, score, is_verified, is_deleted, started_at, completed_at)
values ('aa000000-0000-0000-0000-000000000099', 'a0000000-0000-0000-0000-000000000001', 'cc111111-0000-4000-8000-000000000001', 95, true, false, now(), now());

-- Stat has become verified
select is(
  (select is_verified from public.user_skill_stats where user_id = 'cc111111-0000-4000-8000-000000000001' and skill_id = 'e0000000-0000-0000-0000-000000000001'),
  true,
  'Verified completed attempt updates user_skill_stats with is_verified = TRUE'
);

-- User appears on skill_leaderboard
select is(
  (select count(*)::integer from public.skill_leaderboard where user_id = 'cc111111-0000-4000-8000-000000000001'),
  1,
  'User 1 appears on skill_leaderboard with verified skill stats'
);

-- Advisory transaction lock was acquired during recalculation to serialize concurrent submissions
select ok(
  exists (
    select 1 from pg_locks 
    where locktype = 'advisory' 
      and classid = hashtext('cc111111-0000-4000-8000-000000000001')::oid
      and objid = hashtext('e0000000-0000-0000-0000-000000000001')::oid
  ),
  'recompute_user_skill_stat acquires advisory transaction lock for (user_id, skill_id)'
);

-- 8. P2 VERIFICATION: Assessment and User immutability on attempts (prevent reassignment bypass)
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- Attempting to reassign assessment_id to Skill Assessment 2 is strictly blocked by trigger
select throws_ok(
  $$ update public.assessment_attempts
     set assessment_id = 'a0000000-0000-0000-0000-000000000002',
         is_verified = false
     where id = 'aa000000-0000-0000-0000-000000000099' $$,
  'assessment_id is immutable once an attempt is created',
  'Attempting to reassign assessment_id on an existing attempt is strictly rejected'
);

-- Attempting to reassign user_id to User 2 is strictly blocked by trigger
select throws_ok(
  $$ update public.assessment_attempts
     set user_id = 'cc111111-0000-4000-8000-000000000002',
         is_verified = false
     where id = 'aa000000-0000-0000-0000-000000000099' $$,
  'user_id is immutable once an attempt is created',
  'Attempting to reassign user_id on an existing attempt is strictly rejected'
);

-- Assessment attempt retains original assessment_id
select is(
  (select assessment_id from public.assessment_attempts where id = 'aa000000-0000-0000-0000-000000000099'),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'Attempt assessment_id remains unchanged after rejected reassignment'
);

-- Original Skill 1 stats remain valid and verified
select is(
  (select is_verified from public.user_skill_stats where user_id = 'cc111111-0000-4000-8000-000000000001' and skill_id = 'e0000000-0000-0000-0000-000000000001'),
  true,
  'Original Skill 1 stats remain valid and verified'
);

-- Skill 2 has no stats created for User 1
select is(
  (select count(*)::integer from public.user_skill_stats where user_id = 'cc111111-0000-4000-8000-000000000001' and skill_id = 'e0000000-0000-0000-0000-000000000002'),
  0,
  'Skill 2 has no stats created for User 1'
);

-- User 1 soft deletes all attempts for this skill
select lives_ok(
  $$ select soft_delete_skill_attempts('cc111111-0000-4000-8000-000000000001'::uuid, 'e0000000-0000-0000-0000-000000000001'::uuid) $$,
  'User 1 can execute soft_delete_skill_attempts'
);

-- Trigger recalculates on soft deletion: no eligible attempts remain, so user_skill_stats is cleaned up
select is(
  (select count(*)::integer from public.user_skill_stats where user_id = 'cc111111-0000-4000-8000-000000000001' and skill_id = 'e0000000-0000-0000-0000-000000000001'),
  0,
  'user_skill_stats aggregate record deleted after all skill attempts are soft-deleted'
);

-- User 1 is immediately cleared from skill_leaderboard
select is(
  (select count(*)::integer from public.skill_leaderboard where user_id = 'cc111111-0000-4000-8000-000000000001'),
  0,
  'User 1 immediately removed from skill_leaderboard after soft deletion of verified attempts'
);

select * from finish();
rollback;
