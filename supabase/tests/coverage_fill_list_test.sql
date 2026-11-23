-- pgTAP: coverage fill list (migration 20261123000000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

insert into auth.users (id, email) values
  ('d2000000-0000-4000-8000-000000000001', 'fill-mod@example.invalid'),
  ('d2000000-0000-4000-8000-000000000002', 'fill-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d2000000-0000-4000-8000-000000000001'), ('d2000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values ('d2000000-0000-4000-8000-000000000001', 'moderator')
on conflict (user_id) do nothing;
-- Voters for the Wanted need (enough to pass the public floor).
insert into auth.users (id, email)
select ('d2000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid, 'fill-v' || i || '@example.invalid'
from generate_series(1, 12) i on conflict (id) do nothing;

-- Two published books. Book A objective 1.1 has teaching only; 1.2 lacks
-- only checks. Book B shares the topic tag "fl-percent" (fan-in 2).
insert into public.learning_targets (id, target_type, title, slug) values
  ('d2000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Fill A', 'test-fill-a'),
  ('d2000000-0000-4000-8000-000000000020', 'curriculum_standard', 'Fill B', 'test-fill-b');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d2000000-0000-4000-8000-000000000011', 'd2000000-0000-4000-8000-000000000010', 'A1', 'draft'),
  ('d2000000-0000-4000-8000-000000000021', 'd2000000-0000-4000-8000-000000000020', 'B1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code, sort_order) values
  ('d2000000-0000-4000-8000-000000000031', 'd2000000-0000-4000-8000-000000000011', 'objective', 'Percent basics', '1.1', 1),
  ('d2000000-0000-4000-8000-000000000032', 'd2000000-0000-4000-8000-000000000011', 'objective', 'Complete topic', '1.2', 2),
  ('d2000000-0000-4000-8000-000000000033', 'd2000000-0000-4000-8000-000000000021', 'objective', 'History only', '9.1', 1);
insert into public.lessons (id, title, visibility, origin_target_version_id, tags) values
  ('d2000000-0000-4000-8000-000000000101', 'A 1.1', 'public', 'd2000000-0000-4000-8000-000000000011', array['fl-percent','openstax','unreviewed']),
  ('d2000000-0000-4000-8000-000000000102', 'A 1.2', 'public', 'd2000000-0000-4000-8000-000000000011', array['fl-whole','openstax']),
  ('d2000000-0000-4000-8000-000000000103', 'B 9.1', 'public', 'd2000000-0000-4000-8000-000000000021', array['fl-percent','fl-history','openstax']);
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order) values
  ('d2000000-0000-4000-8000-000000000031', 'd2000000-0000-4000-8000-000000000101', 1),
  ('d2000000-0000-4000-8000-000000000032', 'd2000000-0000-4000-8000-000000000102', 1),
  ('d2000000-0000-4000-8000-000000000033', 'd2000000-0000-4000-8000-000000000103', 1);
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('d2000000-0000-4000-8000-000000000101', 'markdown', 1, '{"text":"Read this."}'),
  ('d2000000-0000-4000-8000-000000000102', 'markdown', 1, '{"text":"Read this."}'),
  ('d2000000-0000-4000-8000-000000000102', 'markdown', 2, '{"text":"**Example 1**"}'),
  ('d2000000-0000-4000-8000-000000000102', 'practice_prompt', 3, '{"prompt":"Try"}'),
  ('d2000000-0000-4000-8000-000000000103', 'markdown', 1, '{"text":"Read this."}'),
  ('d2000000-0000-4000-8000-000000000103', 'markdown', 2, '{"text":"**Example 1**"}'),
  ('d2000000-0000-4000-8000-000000000103', 'practice_prompt', 3, '{"prompt":"Try"}');
update public.target_versions set status = 'review_ready' where id::text like 'd2000000-%';
update public.target_versions set status = 'published' where id::text like 'd2000000-%';

-- A Wanted need on the percent topic with enough votes.
insert into public.content_wanted_needs (id, title, subject_tag, status) values
  ('d2000000-0000-4000-8000-000000000201', 'More percent practice', 'fl-percent', 'open');
insert into public.content_wanted_votes (need_id, user_id)
select 'd2000000-0000-4000-8000-000000000201', ('d2000000-0000-4000-8000-0000000001' || lpad(i::text, 2, '0'))::uuid
from generate_series(1, 12) i;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd2000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.get_coverage_fill_list() $$, '42501', null, 'learners cannot read the fill list');

select set_config('request.jwt.claim.sub', 'd2000000-0000-4000-8000-000000000001', true);
create temp table f as
  select e as row from jsonb_array_elements(public.get_coverage_fill_list(500)) e
  where e->>'target_slug' like 'test-fill-%';
select is((select count(*)::int from f), 3, 'every objective with a content gap is listed');
select is((select row->'missing' from f where row->>'code' = '1.2'), '["check"]'::jsonb, 'a single missing role');
select is((select row->'missing' from f where row->>'code' = '1.1'), '["example", "practice", "check"]'::jsonb,
  'missing roles are named');
select is((select row->>'fan_in' from f where row->>'code' = '1.1'), '2', 'fan-in counts books sharing a topic tag');
select ok((select not (row->'tags') ? 'openstax' from f where row->>'code' = '1.1'), 'provenance tags are not topic tags');
select ok((select (row->>'gap_count')::int >= 12 from f where row->>'code' = '1.1'), 'Wanted votes on the topic count');
select is((select row->>'coverage_deficit' from f where row->>'code' = '1.1'), '0.750', 'deficit is missing roles / 4');
select is((select row->>'code' from f order by (row->>'priority')::numeric desc limit 1), '1.1',
  'the topic with more reuse and more missing ranks first');
select ok((select (row->>'priority')::numeric > 0 from f where row->>'code' = '9.1'), 'every listed topic has a positive priority');
reset role;

select * from finish();
rollback;
