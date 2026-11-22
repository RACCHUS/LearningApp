-- pgTAP: reuse-value priority score (migration 20261122030000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

insert into auth.users (id, email) values
  ('cd000000-0000-4000-8000-000000000001', 'wp-a@example.invalid'),
  ('cd000000-0000-4000-8000-000000000002', 'wp-mod@example.invalid'),
  ('cd000000-0000-4000-8000-000000000003', 'wp-v3@example.invalid'),
  ('cd000000-0000-4000-8000-000000000004', 'wp-v4@example.invalid'),
  ('cd000000-0000-4000-8000-000000000005', 'wp-v5@example.invalid'),
  ('cd000000-0000-4000-8000-000000000006', 'wp-v6@example.invalid'),
  ('cd000000-0000-4000-8000-000000000007', 'wp-v7@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like 'cd000000-%' on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values ('cd000000-0000-4000-8000-000000000002', 'moderator')
on conflict (user_id) do nothing;
update private.site_feature_controls set enabled = true, release_ready = true where feature_key = 'content.wanted_board';

-- Two curriculum targets with published lessons tagged "wp-percent".
insert into public.learning_targets (id, target_type, title, slug) values
  ('cd000000-0000-4000-8000-000000000010', 'curriculum_standard', 'WP Book 1', 'test-wp-1'),
  ('cd000000-0000-4000-8000-000000000020', 'curriculum_standard', 'WP Book 2', 'test-wp-2');
insert into public.target_versions (id, target_id, version_code, status) values
  ('cd000000-0000-4000-8000-000000000011', 'cd000000-0000-4000-8000-000000000010', 'A', 'draft'),
  ('cd000000-0000-4000-8000-000000000021', 'cd000000-0000-4000-8000-000000000020', 'A', 'draft');
insert into public.lessons (id, title, visibility, origin_target_version_id, tags) values
  ('cd000000-0000-4000-8000-000000000101', 'L1', 'public', 'cd000000-0000-4000-8000-000000000011', array['wp-percent']),
  ('cd000000-0000-4000-8000-000000000102', 'L2', 'public', 'cd000000-0000-4000-8000-000000000021', array['wp-percent']);
update public.target_versions set status = 'review_ready' where id::text like 'cd000000-%';
update public.target_versions set status = 'published' where id::text like 'cd000000-%';

insert into public.content_wanted_needs (id, title, subject_tag, status) values
  ('cd000000-0000-4000-8000-000000000201', 'Percent of a number please', 'wp-percent', 'open'),
  ('cd000000-0000-4000-8000-000000000202', 'Something nobody covers', 'wp-nothing', 'open'),
  ('cd000000-0000-4000-8000-000000000203', 'Partly covered already', null, 'open');
-- B: five votes (above the floor); C: two votes (below it) and a link.
insert into public.content_wanted_votes (need_id, user_id)
select 'cd000000-0000-4000-8000-000000000202', id from auth.users
 where id::text between 'cd000000-0000-4000-8000-000000000003' and 'cd000000-0000-4000-8000-000000000007';
insert into public.content_wanted_votes (need_id, user_id) values
  ('cd000000-0000-4000-8000-000000000203', 'cd000000-0000-4000-8000-000000000003'),
  ('cd000000-0000-4000-8000-000000000203', 'cd000000-0000-4000-8000-000000000004');
insert into public.content_contributions
  (id, lesson_id, contributor_id, version, status, license, rights_attested_at, ai_assisted, snapshot, snapshot_sha256)
values ('cd000000-0000-4000-8000-000000000301', 'cd000000-0000-4000-8000-000000000101',
        'cd000000-0000-4000-8000-000000000001', 1, 'submitted', 'CC-BY-4.0', now(), false,
        '{"title":"x","terms":[],"concepts":[],"questions":[]}', 'sha-x');
insert into public.content_wanted_links (need_id, contribution_id) values
  ('cd000000-0000-4000-8000-000000000203', 'cd000000-0000-4000-8000-000000000301');

select is((select fan_in from private.wanted_need_priority('cd000000-0000-4000-8000-000000000201')), 2,
  'fan-in counts distinct targets with tagged published lessons');
select is((select priority from private.wanted_need_priority('cd000000-0000-4000-8000-000000000201')), 2.000,
  'A: 2 targets x boost 1 x deficit 1 = 2');
select is((select gap_count from private.wanted_need_priority('cd000000-0000-4000-8000-000000000202')), 5,
  'votes from the floor up count');
select is((select frequency_boost from private.wanted_need_priority('cd000000-0000-4000-8000-000000000202')), 1.388,
  'boost is 1 + ln(6)/ln(101)');
select is((select fan_in from private.wanted_need_priority('cd000000-0000-4000-8000-000000000202')), 1,
  'fan-in floors at 1 for an individual need');
select is((select gap_count from private.wanted_need_priority('cd000000-0000-4000-8000-000000000203')), 0,
  'votes below the floor count as 0');
select is((select coverage_deficit from private.wanted_need_priority('cd000000-0000-4000-8000-000000000203')), 0.5,
  'a linked contribution halves the deficit');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'cd000000-0000-4000-8000-000000000001', true);
select results_eq(
  $$ select title from public.wanted_board() where id::text like 'cd000000-%' $$,
  $$ values ('Percent of a number please'::text), ('Something nobody covers'), ('Partly covered already') $$,
  'the board is ordered by priority');
select throws_ok($$ select public.wanted_priority_list() $$, '42501', null, 'the itemized list is for moderators');
select ok(not has_function_privilege('authenticated', 'private.wanted_need_priority(uuid)', 'execute'),
  'learners cannot read scores directly');
select set_config('request.jwt.claim.sub', 'cd000000-0000-4000-8000-000000000002', true);
select is((select (x->>'priority')::numeric from jsonb_array_elements(public.wanted_priority_list()) x
           where x->>'id' = 'cd000000-0000-4000-8000-000000000202'), 1.388,
  'moderators see each term and the priority');
reset role;

select * from finish();
rollback;
