-- pgTAP Trust, Safety & Moderation Security Test Suite (ECO-00B)
-- Validates zero-argument authorization, RLS isolation, privilege separation,
-- audit preservation on user deletion, target existence, and atomic workflow transactions.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(37);

-- 1. Setup synthetic test users in auth.users
insert into auth.users (id, email) values
  ('8f7c1a10-0000-4000-8000-000000000010', 'admin@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000020', 'moderator@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000030', 'reporter@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000040', 'learner@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000099', 'deletable-mod@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('8f7c1a10-0000-4000-8000-000000000010', 'admin@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000020', 'moderator@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000030', 'reporter@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000040', 'learner@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000099', 'deletable-mod@example.invalid')
on conflict (id) do nothing;

-- 2. Setup real target entities for report testing
insert into public.lessons (id, title, user_id, visibility) values
  ('8f7c1a10-0000-4000-8000-000000000501', 'Public Safety Compliance Lesson', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000502', 'Private Learner Notes', '8f7c1a10-0000-4000-8000-000000000040', 'private'),
  ('8f7c1a10-0000-4000-8000-000000000511', 'Public Lesson 11', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000512', 'Public Lesson 12', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000513', 'Public Lesson 13', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000514', 'Public Lesson 14', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000515', 'Public Lesson 15', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000516', 'Public Lesson 16', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000517', 'Public Lesson 17', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000518', 'Public Lesson 18', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000519', 'Public Lesson 19', '8f7c1a10-0000-4000-8000-000000000040', 'public'),
  ('8f7c1a10-0000-4000-8000-000000000520', 'Public Lesson 20', '8f7c1a10-0000-4000-8000-000000000040', 'public')
on conflict (id) do nothing;

insert into public.study_sets (id, title, user_id) values
  ('8f7c1a10-0000-4000-8000-000000000503', 'Learner Private Study Set', '8f7c1a10-0000-4000-8000-000000000040')
on conflict (id) do nothing;

insert into public.word_lists (id, title, user_id) values
  ('8f7c1a10-0000-4000-8000-000000000504', 'Learner Private Word List', '8f7c1a10-0000-4000-8000-000000000040')
on conflict (id) do nothing;

-- Target & Version for unpublished target-version lesson isolation testing
insert into public.learning_targets
  (id, target_type, title, slug, status, is_public, is_official, created_by)
values
  ('8f7c1a10-0000-4000-8000-000000000601', 'certification',
   'Private Draft Target', 'private-draft-target', 'draft', false, false,
   '8f7c1a10-0000-4000-8000-000000000040')
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_code, status)
values
  ('8f7c1a10-0000-4000-8000-000000000602',
   '8f7c1a10-0000-4000-8000-000000000601', 'draft-v1', 'draft')
on conflict (id) do nothing;

insert into public.lessons (id, title, user_id, visibility, origin_target_version_id)
values
  ('8f7c1a10-0000-4000-8000-000000000603', 'Public Flag But Draft Target Lesson',
   '8f7c1a10-0000-4000-8000-000000000040', 'public',
   '8f7c1a10-0000-4000-8000-000000000602')
on conflict (id) do nothing;

insert into public.questions (id, lesson_id, question_text, options, correct_answer, user_id)
values
  ('8f7c1a10-0000-4000-8000-000000000604',
   '8f7c1a10-0000-4000-8000-000000000603',
   'Draft Lesson Test Question',
   '["Option A", "Option B"]'::jsonb,
   0,
   '8f7c1a10-0000-4000-8000-000000000040'),
  ('8f7c1a10-0000-4000-8000-000000000505',
   '8f7c1a10-0000-4000-8000-000000000501',
   'Public Safety Lesson Test Question',
   '["Option A", "Option B"]'::jsonb,
   0,
   '8f7c1a10-0000-4000-8000-000000000040')
on conflict (id) do nothing;

-- 3. Bootstrap moderation roles directly (as superuser/service_role)
insert into public.moderation_roles (id, user_id, role) values
  ('8f7c1a10-0000-4000-8000-000000000110', '8f7c1a10-0000-4000-8000-000000000010', 'admin'),
  ('8f7c1a10-0000-4000-8000-000000000120', '8f7c1a10-0000-4000-8000-000000000020', 'moderator'),
  ('8f7c1a10-0000-4000-8000-000000000199', '8f7c1a10-0000-4000-8000-000000000099', 'moderator')
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Test A: Zero-argument authorization helper evaluations
-- -----------------------------------------------------------------------------

set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000010', true);
end $$;

select is(private.is_admin(), true, 'Admin caller returns true for private.is_admin()');
select is(private.is_moderator(), true, 'Admin caller returns true for private.is_moderator()');
select is(public.is_admin(), true, 'Admin caller returns true for public.is_admin() RPC');
select is(public.is_moderator(), true, 'Admin caller returns true for public.is_moderator() RPC');

do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000020', true);
end $$;

select is(private.is_admin(), false, 'Moderator caller returns false for private.is_admin()');
select is(private.is_moderator(), true, 'Moderator caller returns true for private.is_moderator()');
select is(public.is_admin(), false, 'Moderator caller returns false for public.is_admin() RPC');
select is(public.is_moderator(), true, 'Moderator caller returns true for public.is_moderator() RPC');

do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000030', true);
end $$;

select is(private.is_admin(), false, 'Normal learner returns false for private.is_admin()');
select is(private.is_moderator(), false, 'Normal learner returns false for private.is_moderator()');
select is(public.is_admin(), false, 'Normal learner returns false for public.is_admin() RPC');
select is(public.is_moderator(), false, 'Normal learner returns false for public.is_moderator() RPC');

-- -----------------------------------------------------------------------------
-- Test B: RLS on moderation_roles
-- -----------------------------------------------------------------------------

-- Normal learner cannot read moderation_roles
select is(
  (select count(*)::integer from public.moderation_roles),
  0,
  'Non-moderator learner cannot query moderation_roles'
);

-- Moderator cannot insert into moderation_roles (only admin can)
do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000020', true);
end $$;

select throws_ok(
  $$ insert into public.moderation_roles (user_id, role) values ('8f7c1a10-0000-4000-8000-000000000040', 'moderator') $$,
  '42501',
  null,
  'Moderator cannot grant moderation roles (requires admin)'
);

-- -----------------------------------------------------------------------------
-- Test C: Direct Write Bypass Denial (RLS Negative Tests)
-- -----------------------------------------------------------------------------

do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000030', true);
end $$;

-- Direct insert into moderation_reports denied (must use submit_moderation_report RPC)
select throws_ok(
  $$ insert into public.moderation_reports (reporter_id, target_type, target_id, reason)
     values ('8f7c1a10-0000-4000-8000-000000000030', 'lesson', '8f7c1a10-0000-4000-8000-000000000501', 'spam') $$,
  '42501',
  null,
  'Direct INSERT into moderation_reports is denied by RLS'
);

-- Direct update on moderation_reports denied
select throws_ok(
  $$ update public.moderation_reports set status = 'actioned' where target_id = '8f7c1a10-0000-4000-8000-000000000501' $$,
  '42501',
  null,
  'Direct UPDATE on moderation_reports is denied by RLS'
);

-- Direct insert into moderation_actions denied (must use apply_moderation_action RPC)
select throws_ok(
  $$ insert into public.moderation_actions (target_type, target_id, action, reason)
     values ('lesson', '8f7c1a10-0000-4000-8000-000000000501', 'hide', 'Bypass test') $$,
  '42501',
  null,
  'Direct INSERT into moderation_actions is denied by RLS'
);

-- -----------------------------------------------------------------------------
-- Test D: Report Submission, Target Visibility & Deduplication
-- -----------------------------------------------------------------------------

-- Non-existent target UUID is rejected
select throws_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000999'::uuid,
       'spam',
       'Target does not exist'
     ) $$,
  'P0002',
  null,
  'Submitting report on non-existent target raises P0002'
);

-- Reporter attempting to report another user's private lesson is rejected with P0002
select throws_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000502'::uuid,
       'spam',
       'Attempting to report private lesson without authorization'
     ) $$,
  'P0002',
  null,
  'Reporting private lesson of another user is denied with P0002'
);

-- Reporter attempting to report lesson on unpublished target version is rejected with P0002
select throws_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000603'::uuid,
       'spam',
       'Attempting to report lesson on unpublished target version'
     ) $$,
  'P0002',
  null,
  'Reporting lesson on unpublished draft target version is denied with P0002'
);

-- Reporter attempting to report question on unpublished target version is rejected with P0002
select throws_ok(
  $$ select public.submit_moderation_report(
       'question',
       '8f7c1a10-0000-4000-8000-000000000604'::uuid,
       'spam',
       'Attempting to report question on unpublished target version'
     ) $$,
  'P0002',
  null,
  'Reporting question on unpublished draft target version is denied with P0002'
);

-- Reporter attempting to report another user's private study set is rejected with P0002
select throws_ok(
  $$ select public.submit_moderation_report(
       'study_set',
       '8f7c1a10-0000-4000-8000-000000000503'::uuid,
       'spam',
       'Attempting to report private study set without authorization'
     ) $$,
  'P0002',
  null,
  'Reporting private study set of another user is denied with P0002'
);

-- Reporter attempting to report another user's private word list is rejected with P0002
select throws_ok(
  $$ select public.submit_moderation_report(
       'word_list',
       '8f7c1a10-0000-4000-8000-000000000504'::uuid,
       'spam',
       'Attempting to report private word list without authorization'
     ) $$,
  'P0002',
  null,
  'Reporting private word list of another user is denied with P0002'
);

-- Reporter attempting to report a profile is rejected with 0A000 (profile reporting disabled)
select throws_ok(
  $$ select public.submit_moderation_report(
       'profile',
       '8f7c1a10-0000-4000-8000-000000000040'::uuid,
       'harassment',
       'Profile report attempt'
     ) $$,
  '0A000',
  null,
  'Submitting moderation report against profile is rejected with 0A000 (feature disabled)'
);

-- Reporter submits a valid report on existing public lesson
select lives_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000501'::uuid,
       'spam',
       'Automated promotional link'
     ) $$,
  'Authenticated learner can submit a moderation report on existing public content'
);

-- Reporter submits a valid report on existing public question
select lives_ok(
  $$ select public.submit_moderation_report(
       'question',
       '8f7c1a10-0000-4000-8000-000000000505'::uuid,
       'inappropriate',
       'Inappropriate quiz content'
     ) $$,
  'Authenticated learner can submit a moderation report on existing public question'
);

-- Duplicate pending report on the same target is blocked
select throws_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000501'::uuid,
       'harassment',
       'Second report attempt while pending'
     ) $$,
  '23505',
  null,
  'Duplicate active report on the same target is blocked'
);

-- Reporter can see their own report
select is(
  (select count(*)::integer from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501'),
  1,
  'Reporter can see their own filed report'
);

-- Other learner cannot see the reporter's report
do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000040', true);
end $$;

select is(
  (select count(*)::integer from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501'),
  0,
  'Other learner cannot see reports filed by someone else'
);

-- -----------------------------------------------------------------------------
-- Test E: Atomic Moderation Action & Status Transition Safety
-- -----------------------------------------------------------------------------

-- Normal learner cannot apply moderation actions
select throws_ok(
  $$ select public.apply_moderation_action(
       (select id from public.moderation_reports limit 1),
       'dismiss',
       'Dismissing false flag'
     ) $$,
  '42501',
  null,
  'Non-moderator cannot execute apply_moderation_action'
);

-- Moderator executes apply_moderation_action
do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000099', true);
end $$;

select lives_ok(
  $$ select public.apply_moderation_action(
       (select id from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501'),
       'hide',
       'Spam link confirmed',
       'Target content flagged for hiding'
     ) $$,
  'Moderator can execute apply_moderation_action'
);

-- Verify report status transitioned to 'actioned'
select is(
  (select status from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501'),
  'actioned',
  'Report status is atomically updated to actioned'
);

-- Attempting to re-resolve an already actioned report raises error (transition safety)
select throws_ok(
  $$ select public.apply_moderation_action(
       (select id from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501'),
       'dismiss',
       'Attempting duplicate resolution'
     ) $$,
  '22000',
  null,
  'Cannot re-resolve an already resolved report'
);

-- -----------------------------------------------------------------------------
-- Test F: Rate Limiting & Concurrency Serialization
-- -----------------------------------------------------------------------------

do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000030', true);
end $$;

-- Submit 8 additional distinct reports (bringing total to 10 in the hour)
select lives_ok(
  $$
  do $b$
  declare
    v_id uuid;
  begin
    for v_id in
      select id from public.lessons where id between '8f7c1a10-0000-4000-8000-000000000511' and '8f7c1a10-0000-4000-8000-000000000518'
    loop
      perform public.submit_moderation_report('lesson', v_id, 'spam', 'Batch rate limit test report');
    end loop;
  end $b$;
  $$,
  'Submitting up to 10 reports within an hour succeeds'
);

-- Submitting the 11th report raises P0004
select throws_ok(
  $$ select public.submit_moderation_report(
       'lesson',
       '8f7c1a10-0000-4000-8000-000000000520'::uuid,
       'spam',
       '11th report exceeding limit'
     ) $$,
  'P0004',
  null,
  'Submitting 11th report within the hour exceeds rate limit and raises P0004'
);

-- -----------------------------------------------------------------------------
-- Test G: Audit Trail Preservation on User Deletions (ON DELETE SET NULL)
-- -----------------------------------------------------------------------------

set local role postgres;

-- 1. Moderator deletion preserves action history
delete from auth.users where id = '8f7c1a10-0000-4000-8000-000000000099';

select is(
  (select count(*)::integer from public.moderation_actions where target_id = '8f7c1a10-0000-4000-8000-000000000501' and moderator_id is null),
  1,
  'Audit preserved on moderator deletion: moderation_actions retains record with moderator_id = null'
);

-- 2. Reporter deletion preserves report history
delete from auth.users where id = '8f7c1a10-0000-4000-8000-000000000030';

select is(
  (select count(*)::integer from public.moderation_reports where target_id = '8f7c1a10-0000-4000-8000-000000000501' and reporter_id is null),
  1,
  'Report preserved on reporter deletion: moderation_reports retains record with reporter_id = null'
);

rollback;
