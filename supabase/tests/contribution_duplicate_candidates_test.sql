-- pgTAP: near-duplicate candidates for contributions (migration 20261122020000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into auth.users (id, email) values
  ('cc000000-0000-4000-8000-000000000001', 'dup-a@example.invalid'),
  ('cc000000-0000-4000-8000-000000000002', 'dup-mod@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('cc000000-0000-4000-8000-000000000001'), ('cc000000-0000-4000-8000-000000000002')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values ('cc000000-0000-4000-8000-000000000002', 'moderator')
on conflict (user_id) do nothing;

insert into public.lessons (id, title, visibility, user_id) values
  ('cc000000-0000-4000-8000-000000000101', 'Understanding Percent Change', 'private', 'cc000000-0000-4000-8000-000000000001'),
  ('cc000000-0000-4000-8000-000000000102', 'Percent change explained', 'private', 'cc000000-0000-4000-8000-000000000001'),
  ('cc000000-0000-4000-8000-000000000103', 'Copy of someone else', 'private', 'cc000000-0000-4000-8000-000000000001'),
  ('cc000000-0000-4000-8000-000000000104', 'Photosynthesis basics', 'private', 'cc000000-0000-4000-8000-000000000001'),
  ('cc000000-0000-4000-8000-000000000201', 'Understanding percent change!', 'public', null);

create function pg_temp.snap(t text, idea text) returns jsonb language sql as $$
  select jsonb_build_object('title', t, 'terms', '[]'::jsonb,
    'concepts', jsonb_build_array(jsonb_build_object('concept_text', idea)), 'questions', '[]'::jsonb)
$$;

insert into public.content_contributions
  (id, lesson_id, contributor_id, version, status, license, rights_attested_at, ai_assisted, snapshot, snapshot_sha256)
values
  -- the one under review
  ('cc000000-0000-4000-8000-000000000301', 'cc000000-0000-4000-8000-000000000101', 'cc000000-0000-4000-8000-000000000001',
   1, 'submitted', 'CC-BY-4.0', now(), false,
   pg_temp.snap('Understanding Percent Change', 'Percent change compares the new value with the original value'), 'sha-a'),
  -- an earlier version of the same lesson: not a duplicate
  ('cc000000-0000-4000-8000-000000000300', 'cc000000-0000-4000-8000-000000000101', 'cc000000-0000-4000-8000-000000000001',
   2, 'superseded', 'CC-BY-4.0', now(), false,
   pg_temp.snap('Understanding Percent Change', 'old'), 'sha-old'),
  -- same content, different lesson
  ('cc000000-0000-4000-8000-000000000302', 'cc000000-0000-4000-8000-000000000103', 'cc000000-0000-4000-8000-000000000001',
   1, 'published', 'CC-BY-4.0', now(), false,
   pg_temp.snap('Copy', 'x'), 'sha-a'),
  -- reads alike
  ('cc000000-0000-4000-8000-000000000303', 'cc000000-0000-4000-8000-000000000102', 'cc000000-0000-4000-8000-000000000001',
   1, 'published', 'CC-BY-4.0', now(), false,
   pg_temp.snap('Percent change explained', 'Percent change compares the new value with the original value'), 'sha-c'),
  -- unrelated
  ('cc000000-0000-4000-8000-000000000304', 'cc000000-0000-4000-8000-000000000104', 'cc000000-0000-4000-8000-000000000001',
   1, 'published', 'CC-BY-4.0', now(), false,
   pg_temp.snap('Photosynthesis basics', 'Plants turn light into chemical energy'), 'sha-d');

create temp table r as select '[]'::jsonb as v;
grant all on r to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'cc000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.contribution_duplicate_candidates('cc000000-0000-4000-8000-000000000301') $$,
  '42501', null, 'contributors cannot run it');
select set_config('request.jwt.claim.sub', 'cc000000-0000-4000-8000-000000000002', true);
update r set v = public.contribution_duplicate_candidates('cc000000-0000-4000-8000-000000000301');
reset role;

select is((select x->>'reason' from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000302'),
  'same_snapshot', 'identical content is found first');
select is((select (x->>'confidence')::numeric from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000302'),
  1.0, 'with full confidence');
select is((select x->>'reason' from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000303'),
  'similar_content', 'a contribution that reads alike is found');
select is((select x->>'kind' from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000201'),
  'lesson', 'a published lesson with a close title is found');
select ok(not exists (select 1 from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000300'),
  'an earlier version of the same lesson is not a duplicate');
select ok(not exists (select 1 from r, jsonb_array_elements(v) x where x->>'id' = 'cc000000-0000-4000-8000-000000000304'),
  'unrelated content is not suggested');
select is((select count(*)::int from r, jsonb_array_elements(v) x), 3, 'each candidate appears once');

select * from finish();
rollback;
