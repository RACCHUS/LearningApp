-- PR-D follow-up: disputed practice checks (20261119000000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

insert into auth.users (id, email, is_anonymous) values
  ('c0730000-0000-4000-8000-00000000000a', 'cd-learner@example.invalid', false),
  ('c0730000-0000-4000-8000-00000000000b', 'cd-learner2@example.invalid', false),
  ('c0730000-0000-4000-8000-00000000000c', 'cd-mod@example.invalid', false)
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('c0730000-0000-4000-8000-00000000000c', 'moderator')
on conflict (user_id) do nothing;

select ok(not has_table_privilege('authenticated', 'public.learning_check_disputes', 'INSERT'),
  'no direct inserts');
select ok(not has_table_privilege('authenticated', 'public.learning_check_disputes', 'UPDATE'),
  'no direct updates');
select ok(not has_function_privilege('anon',
  'public.submit_check_dispute(text,text,text,text,text)', 'EXECUTE'),
  'anonymous users cannot dispute');
select ok((select relrowsecurity from pg_class
            where oid = 'public.learning_check_disputes'::regclass),
  'row level security is on');
select is((select enabled and release_ready from private.site_feature_controls
            where feature_key = 'learning.check_disputes'), true,
  'gate activated by the owner-approved 20261119030000');
-- Keep the OFF-path coverage: switch it off inside this rolled-back test.
update private.site_feature_controls set enabled = false, release_ready = false
 where feature_key = 'learning.check_disputes';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0730000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-1', 'wrong_answer') $$,
  '42501', 'feature_disabled', 'refused while OFF');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'learning.check_disputes';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0730000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-1', 'it is bad') $$,
  '22023', 'invalid_dispute', 'reasons come from the triage list');
select throws_ok($$ select public.submit_check_dispute(
  'bridge percent; drop', '1.0.0', 'pc-check-1', 'wrong_answer') $$,
  '22023', 'invalid_dispute', 'content IDs are strictly formatted');
select throws_ok($$ select public.submit_check_dispute(
  'bridge-percent-change', 'latest', 'pc-check-1', 'wrong_answer') $$,
  '22023', 'invalid_dispute', 'content versions look like 1.0.0');
select ok(public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-1', 'wrong_answer', 'Key says 25%') is not null,
  'a learner disputes a check');
select throws_ok($$ select public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-1', 'unclear') $$,
  '23505', 'already_disputed', 'one open dispute per learner per check');

select set_config('request.jwt.claim.sub', 'c0730000-0000-4000-8000-00000000000b', true);
select ok(public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-1', 'unclear') is not null,
  'another learner disputes the same check');
select is((select count(*)::int from public.learning_check_disputes), 1,
  'learners see only their own disputes');
select throws_ok($$ select public.decide_check_disputes(
  'bridge-percent-change', '1.0.0', 'pc-check-1', true, null) $$,
  '42501', 'moderator_required', 'learners cannot decide');
select is((select count(*)::int from public.quarantined_check_items()), 0,
  'nothing is quarantined before a decision');
reset role;

-- Moderator decisions.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0730000-0000-4000-8000-00000000000c', true);
select is((select count(*)::int from public.learning_check_disputes), 2,
  'moderators see every dispute');
select throws_ok($$ select public.decide_check_disputes(
  'bridge-percent-change', '1.0.0', 'pc-check-1', false, '  ') $$,
  '22023', 'dismiss_reason_required', 'dismissing needs a note');
select is(public.decide_check_disputes(
  'bridge-percent-change', '1.0.0', 'pc-check-1', true, 'Key is wrong; fix in 1.0.1'),
  2, 'upholding settles every open dispute for the check');
select throws_ok($$ select public.decide_check_disputes(
  'bridge-percent-change', '1.0.0', 'pc-check-1', true, null) $$,
  'P0002', 'no_open_disputes', 'decided checks have nothing open');

-- A moderator cannot decide a check they disputed themselves.
select ok(public.submit_check_dispute(
  'bridge-percent-change', '1.0.0', 'pc-check-2', 'wrong_answer') is not null,
  'a moderator may dispute like any learner');
select throws_ok($$ select public.decide_check_disputes(
  'bridge-percent-change', '1.0.0', 'pc-check-2', false, 'Looks fine') $$,
  '42501', 'cannot_decide_own_dispute', 'no deciding your own dispute');
reset role;

-- The quarantine list is public, names only the check version, and ends
-- when a fixed version ships.
set local role anon;
select results_eq(
  $$ select content_kind, content_id, content_version, item_id
       from public.quarantined_check_items() $$,
  $$ values ('bridge'::text, 'bridge-percent-change'::text, '1.0.0'::text, 'pc-check-1'::text) $$,
  'anyone can read which check versions are quarantined');
reset role;

select * from finish();
rollback;
