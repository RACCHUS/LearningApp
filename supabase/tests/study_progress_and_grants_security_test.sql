-- pgTAP test for study_progress security_invoker view, Data API grants, and skill assessment RLS
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

-- 1. Create synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid'),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name, show_on_leaderboards) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid', 'Learner One', true),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid', 'Learner Two', true)
on conflict (id) do nothing;

-- 2. Insert test course, lesson, skill, and progress for User 2 via service_role
set local role service_role;
insert into public.courses (id, title, description, category, user_id) values
 ('c0000000-0000-0000-0000-000000000001', 'Test Course', 'Course Description', 'Test', 'cc111111-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.lessons (id, course_id, title, order_index, user_id) values
 ('l0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Test Lesson', 1, 'cc111111-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.user_progress (id, user_id, lesson_id, date, questions_answered, correct_count, lesson_completed) values
 ('p0000000-0000-0000-0000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'l0000000-0000-0000-0000-000000000001', current_date, 5, 5, true),
 ('p0000000-0000-0000-0000-000000000002', 'cc111111-0000-4000-8000-000000000002', 'l0000000-0000-0000-0000-000000000001', current_date, 10, 8, true)
on conflict (id) do nothing;

insert into public.skills (id, name, slug, category, description) values
 ('s0000000-0000-0000-0000-000000000001', 'Test Skill', 'test-skill', 'Technical', 'Skill description')
on conflict (id) do nothing;

insert into public.skill_assessments (id, skill_id, title, is_active) values
 ('a0000000-0000-0000-0000-000000000001', 's0000000-0000-0000-0000-000000000001', 'Skill Assessment 1', true)
on conflict (id) do nothing;

insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer) values
 ('q0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'What is 1+1?', '["1", "2"]'::jsonb, 1)
on conflict (id) do nothing;

-- 3. Test anon role permissions
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

-- 4. Switch to authenticated User 1
set local role authenticated;
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
  $$ insert into public.user_skill_stats (user_id, skill_id, level) values ('cc111111-0000-4000-8000-000000000001', 's0000000-0000-0000-0000-000000000001', 99) $$,
  '42501',
  null,
  'Authenticated user cannot directly INSERT into user_skill_stats'
);

-- User 1 cannot execute calculate_skill_level RPC directly (service_role only)
select throws_ok(
  $$ select calculate_skill_level('cc111111-0000-4000-8000-000000000001'::uuid, 's0000000-0000-0000-0000-000000000001'::uuid) $$,
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

select * from finish();
rollback;

