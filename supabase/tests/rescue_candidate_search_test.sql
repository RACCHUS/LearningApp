-- pgTAP: rescue candidate search (migration 20261123020000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into auth.users (id, email) values
  ('d4000000-0000-4000-8000-000000000001', 'resc-a@example.invalid'),
  ('d4000000-0000-4000-8000-000000000002', 'resc-b@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d4000000-0000-4000-8000-000000000001'), ('d4000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;

insert into public.lessons (id, title, visibility, user_id, tags) values
  -- the lesson the learner is stuck in
  ('d4000000-0000-4000-8000-000000000100', 'Rz percent word problems', 'public', null, array['rz-percent','rz-ratio','openstax']),
  -- two tags shared, with example and practice
  ('d4000000-0000-4000-8000-000000000101', 'Rz percent and ratio', 'public', null, array['rz-percent','rz-ratio','unreviewed']),
  -- one tag shared, reviewed, no example
  ('d4000000-0000-4000-8000-000000000102', 'Rz percent basics', 'public', null, array['rz-percent']),
  -- only a provenance tag shared: not a candidate
  ('d4000000-0000-4000-8000-000000000103', 'Rz unrelated openstax', 'public', null, array['openstax','rz-other']),
  -- private: never a candidate
  ('d4000000-0000-4000-8000-000000000104', 'Rz my private percent', 'private', 'd4000000-0000-4000-8000-000000000002', array['rz-percent']),
  -- someone else's private lesson used as the query
  ('d4000000-0000-4000-8000-000000000105', 'Rz secret', 'private', 'd4000000-0000-4000-8000-000000000002', array['rz-percent']);
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('d4000000-0000-4000-8000-000000000101', 'markdown', 1, '{"text":"**Example 1: 20% of 50**"}'),
  ('d4000000-0000-4000-8000-000000000101', 'practice_prompt', 2, '{"prompt":"Try"}');

update private.site_feature_controls set enabled = true, release_ready = true where feature_key = 'learning.quick_rescue';

set local role anon;
create temp table r as select public.find_rescue_candidates('d4000000-0000-4000-8000-000000000100', 10) as v;
reset role;
select is((select jsonb_array_length(v) from r), 2, 'only lessons sharing a topic tag, public, not itself');
select is((select v->0->>'lesson_id' from r), 'd4000000-0000-4000-8000-000000000101',
  'more shared topics rank first');
select is((select v->0->'shared_tags' from r), '["rz-percent", "rz-ratio"]'::jsonb, 'shared topics are named');
select is((select (v->0->>'has_example')::boolean and (v->0->>'has_practice')::boolean from r), true,
  'coverage flags come from the lesson blocks');
select is((select v->0->>'reviewed' from r), 'false', 'imported lessons say so');
select is((select v->1->>'reviewed' from r), 'true', 'reviewed lessons say so');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd4000000-0000-4000-8000-000000000001', true);
select is(public.find_rescue_candidates('d4000000-0000-4000-8000-000000000105'), '[]'::jsonb,
  'nothing is revealed about a lesson the caller cannot read');
select set_config('request.jwt.claim.sub', 'd4000000-0000-4000-8000-000000000002', true);
select is(jsonb_array_length(public.find_rescue_candidates('d4000000-0000-4000-8000-000000000105')), 3,
  'the owner of a private lesson gets candidates for it');
reset role;

update private.site_feature_controls set enabled = false where feature_key = 'learning.quick_rescue';
select is(public.find_rescue_candidates('d4000000-0000-4000-8000-000000000100'), '[]'::jsonb,
  'with Learning help off it returns nothing');

select * from finish();
rollback;
