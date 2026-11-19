-- PR-H slice 5: Wanted Board (20261119010000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(35);

insert into auth.users (id, email, is_anonymous) values
  ('c0740000-0000-4000-8000-00000000000a', 'wb-learner@example.invalid', false),
  ('c0740000-0000-4000-8000-00000000000b', 'wb-voter2@example.invalid', false),
  ('c0740000-0000-4000-8000-00000000000c', 'wb-mod@example.invalid', false),
  ('c0740000-0000-4000-8000-00000000000d', 'wb-voter3@example.invalid', false),
  ('c0740000-0000-4000-8000-00000000000e', 'wb-contrib@example.invalid', false)
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('c0740000-0000-4000-8000-00000000000c', 'moderator')
on conflict (user_id) do nothing;
insert into public.content_contributions
  (id, lesson_id, contributor_id, version, status, license, rights_attested_at,
   ai_assisted, snapshot, snapshot_sha256)
values
  ('c0740000-0000-4000-8000-000000000301', null,
   'c0740000-0000-4000-8000-00000000000e', 1, 'submitted', 'CC-BY-4.0', now(),
   false, '{"title":"VLOOKUP"}', repeat('c', 64)),
  ('c0740000-0000-4000-8000-000000000302', null,
   'c0740000-0000-4000-8000-00000000000a', 1, 'published', 'CC-BY-4.0', now(),
   false, '{"title":"Other"}', repeat('d', 64));

select ok(not has_table_privilege('authenticated', 'public.content_wanted_needs', 'INSERT'),
  'no direct inserts of needs');
select ok(not has_table_privilege('authenticated', 'public.content_wanted_votes', 'INSERT'),
  'no direct votes');
select ok(not has_table_privilege('anon', 'public.content_wanted_needs', 'SELECT'),
  'anonymous users cannot read needs');
select ok(not has_function_privilege('anon', 'public.wanted_board()', 'EXECUTE'),
  'anonymous users cannot read the board');
select is((select enabled or release_ready from private.site_feature_controls
            where feature_key = 'content.wanted_board'), false,
  'gate seeded OFF and not release-ready');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.propose_wanted_need('How VLOOKUP works') $$,
  '42501', 'feature_disabled', 'proposals refused while OFF');
select throws_ok($$ select * from public.wanted_board() $$,
  '42501', 'feature_disabled', 'board refused while OFF');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.wanted_board';

-- A learner proposes; it stays private until reviewed.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.propose_wanted_need('Hi') $$,
  '22023', 'invalid_need', 'titles must be meaningful');
select throws_ok($$ select public.propose_wanted_need('Pivot tables', null, 'Excel Stuff!') $$,
  '22023', 'invalid_need', 'tags are strict slugs');
select ok(public.propose_wanted_need('How VLOOKUP works', 'Step by step, with a worked example', 'excel')
  is not null, 'a learner proposes a need');
select is((select status from public.content_wanted_needs), 'proposed',
  'a learner proposal starts as proposed');
select is((select count(*)::int from public.wanted_board()), 0,
  'proposals are not on the public board');
select throws_ok(format($$ select public.vote_wanted_need(%L, true) $$,
  (select id from public.content_wanted_needs limit 1)),
  'P0002', 'need_not_open', 'no votes on proposals');

select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000b', true);
select is((select count(*)::int from public.content_wanted_needs), 0,
  'other learners cannot read someone else''s proposal');
select throws_ok(format($$ select public.review_wanted_need(%L, true) $$,
  (select id from public.content_wanted_needs where false)),
  '42501', 'moderator_required', 'learners cannot review');
reset role;

-- Moderator approves; rejecting needs a note.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000c', true);
select throws_ok(format($$ select public.review_wanted_need(%L, false, ' ') $$,
  (select id from public.content_wanted_needs limit 1)),
  '22023', 'rejection_reason_required', 'rejecting needs a reason');
select is(public.review_wanted_need(
  (select id from public.content_wanted_needs limit 1), true), 'open',
  'moderator approves');
select is((select status from public.content_wanted_needs
            where proposed_by = 'c0740000-0000-4000-8000-00000000000c'
              and title = 'Mod posted need'), null,
  'sanity: no moderator need yet');
select is((select count(*)::int from (select public.propose_wanted_need('Mod posted need')) x), 1,
  'a moderator posts a need directly');
select is((select status from public.content_wanted_needs where title = 'Mod posted need'),
  'open', 'a moderator need is open at once');
reset role;

-- Votes are suppressed below 3.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000a', true);
select ok(public.vote_wanted_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'), true),
  'a learner votes');
select ok(public.vote_wanted_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'), true),
  'voting twice is harmless');
select is((select votes from public.wanted_board() where title = 'How VLOOKUP works'),
  null, 'one vote is not shown as a number');
select is((select has_voted from public.wanted_board() where title = 'How VLOOKUP works'),
  true, 'the voter sees their own vote');
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000b', true);
select ok(public.vote_wanted_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'), true), 'second vote');
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000d', true);
select ok(public.vote_wanted_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'), true), 'third vote');
select is((select votes from public.wanted_board() where title = 'How VLOOKUP works'),
  3, 'from 3 votes the count is shown');
select is((select count(*)::int from public.content_wanted_votes), 1,
  'a learner can read only their own vote row');

-- Linking: only your own contribution.
select throws_ok(format($$ select public.link_contribution_to_need(%L, %L) $$,
  (select id from public.wanted_board() where title = 'How VLOOKUP works'),
  'c0740000-0000-4000-8000-000000000301'),
  '42501', 'contribution_not_owned', 'cannot link someone else''s contribution');
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000e', true);
select ok(public.link_contribution_to_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'),
  'c0740000-0000-4000-8000-000000000301'), 'the contributor links their own lesson');
reset role;

-- Fulfilment needs a linked PUBLISHED contribution.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000c', true);
select throws_ok(format($$ select public.set_wanted_need_status(%L, 'fulfilled', %L) $$,
  (select id from public.content_wanted_needs where title = 'How VLOOKUP works'),
  'c0740000-0000-4000-8000-000000000301'),
  '22023', 'published_link_required', 'a submitted (unpublished) lesson cannot fulfil');
reset role;

-- The learner links their published lesson; then fulfilment works.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000a', true);
select ok(public.link_contribution_to_need(
  (select id from public.wanted_board() where title = 'How VLOOKUP works'),
  'c0740000-0000-4000-8000-000000000302'), 'a published lesson is linked');
select set_config('request.jwt.claim.sub', 'c0740000-0000-4000-8000-00000000000c', true);
select is(public.set_wanted_need_status(
  (select id from public.content_wanted_needs where title = 'How VLOOKUP works'),
  'fulfilled', 'c0740000-0000-4000-8000-000000000302'), 'fulfilled',
  'a moderator fulfils with a published linked lesson');
select is((select status from public.content_contributions
            where id = 'c0740000-0000-4000-8000-000000000301'), 'submitted',
  'fulfilment never publishes or changes a contribution');
select is((select count(*)::int from public.wanted_board() where title = 'How VLOOKUP works'),
  0, 'a fulfilled need leaves the board');
reset role;

select * from finish();
rollback;
