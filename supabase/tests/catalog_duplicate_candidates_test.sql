-- pgTAP: near-duplicate candidates across the catalog (migration 20261123010000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into auth.users (id, email) values
  ('d3000000-0000-4000-8000-000000000001', 'cat-mod@example.invalid'),
  ('d3000000-0000-4000-8000-000000000002', 'cat-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d3000000-0000-4000-8000-000000000001'), ('d3000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values ('d3000000-0000-4000-8000-000000000001', 'moderator')
on conflict (user_id) do nothing;

-- A retired version: its lessons are not catalog lessons.
insert into public.learning_targets (id, target_type, title, slug) values
  ('d3000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Dup Book', 'test-dup-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d3000000-0000-4000-8000-000000000011', 'd3000000-0000-4000-8000-000000000010', 'D1', 'draft');

insert into public.lessons (id, title, visibility, user_id) values
  ('d3000000-0000-4000-8000-000000000101', 'Zqx Photosynthesis Light Reactions', 'public', null),
  ('d3000000-0000-4000-8000-000000000102', 'Zqx photosynthesis: light reactions', 'public', null),
  ('d3000000-0000-4000-8000-000000000103', 'Zqx Mitochondria Energy Basics', 'public', null),
  ('d3000000-0000-4000-8000-000000000104', 'Zqx Cell Energy Overview', 'public', null),
  ('d3000000-0000-4000-8000-000000000105', 'Zqx Photosynthesis Light Reactions', 'private', 'd3000000-0000-4000-8000-000000000002'),
  ('d3000000-0000-4000-8000-000000000106', 'Zqx Photosynthesis Light Reactions', 'public', null);
update public.lessons set origin_target_version_id = 'd3000000-0000-4000-8000-000000000011'
  where id = 'd3000000-0000-4000-8000-000000000106';
update public.target_versions set status = 'review_ready' where id = 'd3000000-0000-4000-8000-000000000011';
update public.target_versions set status = 'published' where id = 'd3000000-0000-4000-8000-000000000011';
update public.target_versions set status = 'retired' where id = 'd3000000-0000-4000-8000-000000000011';
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('d3000000-0000-4000-8000-000000000103', 'markdown', 1, '{"text":"Mitochondria turn glucose and oxygen into usable cell energy called ATP."}'),
  ('d3000000-0000-4000-8000-000000000104', 'markdown', 1, '{"text":"Mitochondria turn glucose and oxygen into usable cell energy called ATP!"}');

create function pg_temp.pairs() returns setof jsonb language sql as $$
  select e from jsonb_array_elements(public.get_catalog_duplicate_candidates(200)) e
  where e->>'a_title' like 'Zqx%' and e->>'b_title' like 'Zqx%'
$$;
grant execute on function pg_temp.pairs() to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd3000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.get_catalog_duplicate_candidates() $$, '42501', null, 'learners cannot read candidates');
select throws_ok($$ select public.dismiss_catalog_duplicate('d3000000-0000-4000-8000-000000000101','d3000000-0000-4000-8000-000000000102') $$,
  '42501', null, 'learners cannot dismiss');

select set_config('request.jwt.claim.sub', 'd3000000-0000-4000-8000-000000000001', true);
select is((select count(*)::int from pg_temp.pairs() p
           where p->>'reason' = 'similar_title'
             and '{d3000000-0000-4000-8000-000000000101,d3000000-0000-4000-8000-000000000102}'::text[] @> array[p->>'a_id', p->>'b_id']),
  1, 'close titles are paired with their reason');
select is((select p->>'reason' from pg_temp.pairs() p
           where '{d3000000-0000-4000-8000-000000000103,d3000000-0000-4000-8000-000000000104}'::text[] @> array[p->>'a_id', p->>'b_id']),
  'similar_content', 'different titles with the same text are similar content');
select ok((select (p->>'confidence')::numeric between 0.5 and 1 from pg_temp.pairs() p
           where '{d3000000-0000-4000-8000-000000000103,d3000000-0000-4000-8000-000000000104}'::text[] @> array[p->>'a_id', p->>'b_id']),
  'each pair has a confidence');
select is((select count(*)::int from pg_temp.pairs() p
           where 'd3000000-0000-4000-8000-000000000105' in (p->>'a_id', p->>'b_id')), 0,
  'private lessons are never compared');
select is((select count(*)::int from pg_temp.pairs() p
           where 'd3000000-0000-4000-8000-000000000106' in (p->>'a_id', p->>'b_id')), 0,
  'lessons of a retired version are not catalog lessons');

select lives_ok($$ select public.dismiss_catalog_duplicate('d3000000-0000-4000-8000-000000000102','d3000000-0000-4000-8000-000000000101') $$,
  'a moderator dismisses a pair, in either order');
select is((select count(*)::int from pg_temp.pairs() p
           where '{d3000000-0000-4000-8000-000000000101,d3000000-0000-4000-8000-000000000102}'::text[] @> array[p->>'a_id', p->>'b_id']),
  0, 'a dismissed pair stops appearing');
reset role;

select * from finish();
rollback;
