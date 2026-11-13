-- PR-H slice 4: refresh proposals (20261113020000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);

insert into auth.users (id, email, is_anonymous) values
  ('c0720000-0000-4000-8000-00000000000a', 'rp-owner@example.invalid', false),
  ('c0720000-0000-4000-8000-00000000000b', 'rp-reader@example.invalid', false),
  ('c0720000-0000-4000-8000-00000000000c', 'rp-mod@example.invalid', false),
  ('c0720000-0000-4000-8000-00000000000e', 'rp-other@example.invalid', false)
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('c0720000-0000-4000-8000-00000000000a', 'rp-owner@example.invalid')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('c0720000-0000-4000-8000-00000000000c', 'moderator')
on conflict (user_id) do nothing;
insert into public.lessons (id, title, user_id, visibility) values
  ('c0720000-0000-4000-8000-000000000101', 'Shared', 'c0720000-0000-4000-8000-00000000000a', 'private');
insert into public.content_contributions
  (id, lesson_id, contributor_id, version, status, license, rights_attested_at,
   ai_assisted, snapshot, snapshot_sha256)
values
  ('c0720000-0000-4000-8000-000000000201', 'c0720000-0000-4000-8000-000000000101',
   'c0720000-0000-4000-8000-00000000000a', 1, 'published', 'CC-BY-4.0', now(),
   false, '{"title":"Shared","questions":[{"question_text":"Q"}]}', repeat('a', 64)),
  ('c0720000-0000-4000-8000-000000000202', null,
   'c0720000-0000-4000-8000-00000000000a', 1, 'rejected', 'CC-BY-4.0', now(),
   false, '{"title":"Old"}', repeat('b', 64));

select ok(not has_table_privilege('authenticated', 'public.content_refresh_proposals', 'INSERT'),
  'no direct inserts');
select ok(not has_function_privilege('anon',
  'public.propose_contribution_refresh(uuid,text,text,text,text)', 'EXECUTE'),
  'anonymous users cannot propose');
select is((select enabled or release_ready from private.site_feature_controls
            where feature_key = 'content.refresh_proposals'), false,
  'gate seeded OFF and not release-ready');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000b', true);
select throws_ok($$ select public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000201', 'correction', 'The answer to Q is wrong now.') $$,
  '42501', 'feature_disabled', 'refused while OFF');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.refresh_proposals';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000b', true);
select throws_ok($$ select public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000202', 'correction', 'Long enough description.') $$,
  'P0002', 'not_published', 'only published copies');
select throws_ok($$ select public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000201', 'correction', 'short') $$,
  '22023', 'invalid_proposal', 'description must be meaningful');
select throws_ok($$ select public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000201', 'source_changed', 'The source has a new edition.',
  'questions[0]', 'http://insecure.example') $$,
  '22023', 'invalid_proposal', 'source links must be https');
select throws_ok($$ select public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000201', 'correction', 'Bad reference given here.',
  'questions[0]; drop table x', null) $$,
  '22023', 'invalid_proposal', 'item references are strictly formatted');
select ok(public.propose_contribution_refresh(
  'c0720000-0000-4000-8000-000000000201', 'source_changed', 'The source has a new edition.',
  'questions[0]', 'https://openstax.org/books/prealgebra-2e/pages/6-2') is not null,
  'a reader proposes an update');

-- Contributor sees it; an unrelated user does not.
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000a', true);
select is((select count(*)::int from public.content_refresh_proposals), 1,
  'the contributor can read proposals on their lesson');
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000e', true);
select is((select count(*)::int from public.content_refresh_proposals), 0,
  'unrelated users cannot read proposals');
select throws_ok(format($$ select public.decide_refresh_proposal(%L, true, null) $$,
  (select id from public.content_refresh_proposals limit 1)),
  '42501', 'moderator_required', 'learners cannot decide');
reset role;

-- Moderator decides; nothing about the copy changes.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000c', true);
select throws_ok(format($$ select public.decide_refresh_proposal(%L, false, ' ') $$,
  (select id from public.content_refresh_proposals limit 1)),
  '22023', 'decline_reason_required', 'declining needs a reason');
select is(public.decide_refresh_proposal(
  (select id from public.content_refresh_proposals limit 1), true, 'Valid, please update'),
  'accepted', 'moderator accepts');
select throws_ok(format($$ select public.decide_refresh_proposal(%L, false, 'again') $$,
  (select id from public.content_refresh_proposals limit 1)),
  '22000', null, 'decisions are final');
reset role;

select is((select status from public.content_contributions
            where id = 'c0720000-0000-4000-8000-000000000201'),
  'published', 'accepting never edits or unpublishes the copy');
select is((select count(*)::int from public.content_refresh_proposal_events), 2,
  'open and accepted are both audited');

-- Proposer can withdraw only open proposals they own.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0720000-0000-4000-8000-00000000000e', true);
select throws_ok(format($$ select public.withdraw_refresh_proposal(%L) $$,
  (select id from public.content_refresh_proposals limit 1)),
  '42501', 'proposal_not_owned', 'others cannot withdraw');
reset role;

select * from finish();
rollback;
