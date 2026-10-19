-- pgTAP Trust, Safety & Moderation Security Test Suite (ECO-00B)
-- Validates zero-argument authorization, RLS isolation, privilege separation,
-- audit preservation on user deletion, and atomic workflow transactions.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

-- 1. Setup synthetic test users in auth.users
insert into auth.users (id, email) values
  ('8f7c1a10-0000-4000-8000-000000000010', 'admin@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000020', 'moderator@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000030', 'reporter@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000040', 'learner@example.invalid'),
  ('8f7c1a10-0000-4000-8000-000000000099', 'deletable-mod@example.invalid')
on conflict (id) do nothing;

-- 2. Bootstrap moderation roles directly (as superuser/service_role)
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
-- Test C: Report Submission and Deduplication
-- -----------------------------------------------------------------------------

do $$ begin
  perform set_config('request.jwt.claim.sub', '8f7c1a10-0000-4000-8000-000000000030', true);
end $$;

-- Reporter submits a report via submit_moderation_report
select lives_ok(
  $$ select public.submit_moderation_report(
       'question',
       '8f7c1a10-0000-4000-8000-000000000501'::uuid,
       'spam',
       'Automated promotional link'
     ) $$,
  'Authenticated learner can submit a moderation report'
);

-- Duplicate pending report on the same target is blocked
select throws_ok(
  $$ select public.submit_moderation_report(
       'question',
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
-- Test D: Atomic Moderation Action Execution
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

-- -----------------------------------------------------------------------------
-- Test E: Audit Trail Preservation on User Deletion
-- -----------------------------------------------------------------------------

-- Switch to superuser to simulate deleting the moderator account
set local role postgres;

delete from auth.users where id = '8f7c1a10-0000-4000-8000-000000000099';

-- Verify the moderation action still exists with moderator_id = null
select is(
  (select count(*)::integer from public.moderation_actions where target_id = '8f7c1a10-0000-4000-8000-000000000501' and moderator_id is null),
  1,
  'Audit trail preserved: deleting moderator account leaves moderation_action record with moderator_id = null'
);

rollback;
