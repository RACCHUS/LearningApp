-- pgTAP: public.lesson_replacement (migration 20261120030000).
-- A retired version's lesson maps to the same-title lesson in the target's
-- published version; anything else answers retired=false and reveals nothing.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into public.learning_targets (id, target_type, title, slug) values
  ('c5000000-0000-4000-8000-000000000001', 'curriculum_standard', 'Replacement Book', 'test-replacement-book'),
  ('c5000000-0000-4000-8000-000000000002', 'curriculum_standard', 'Other Book', 'test-replacement-other');
insert into public.target_versions (id, target_id, version_code, status) values
  ('c5000000-0000-4000-8000-000000000011', 'c5000000-0000-4000-8000-000000000001', 'R1', 'draft'),
  ('c5000000-0000-4000-8000-000000000012', 'c5000000-0000-4000-8000-000000000001', 'R2', 'draft'),
  ('c5000000-0000-4000-8000-000000000013', 'c5000000-0000-4000-8000-000000000002', 'R1', 'draft');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  -- retired R1
  ('c5000000-0000-4000-8000-000000000101', '6.1 Understand Percent', 'public', 'c5000000-0000-4000-8000-000000000011'),
  ('c5000000-0000-4000-8000-000000000102', '6.9 Dropped Section', 'public', 'c5000000-0000-4000-8000-000000000011'),
  ('c5000000-0000-4000-8000-000000000103', 'Twice', 'public', 'c5000000-0000-4000-8000-000000000011'),
  -- published R2
  ('c5000000-0000-4000-8000-000000000201', '6.1 Understand Percent', 'public', 'c5000000-0000-4000-8000-000000000012'),
  ('c5000000-0000-4000-8000-000000000202', 'Twice', 'public', 'c5000000-0000-4000-8000-000000000012'),
  ('c5000000-0000-4000-8000-000000000203', 'Twice', 'public', 'c5000000-0000-4000-8000-000000000012'),
  -- same title in another target's published version must not match
  ('c5000000-0000-4000-8000-000000000301', '6.9 Dropped Section', 'public', 'c5000000-0000-4000-8000-000000000013'),
  -- a plain lesson outside any version
  ('c5000000-0000-4000-8000-000000000401', 'Loose lesson', 'public', null);
-- Follow the real lifecycle: draft -> review_ready -> published -> retired.
update public.target_versions set status = 'review_ready' where id::text like 'c5000000-%';
update public.target_versions set status = 'published' where id::text like 'c5000000-%';
update public.target_versions set status = 'retired' where id = 'c5000000-0000-4000-8000-000000000011';

create temporary table r(label text, v jsonb) on commit drop;
grant all on r to anon;
set local role anon;
insert into r select 'moved',   public.lesson_replacement('c5000000-0000-4000-8000-000000000101');
insert into r select 'dropped', public.lesson_replacement('c5000000-0000-4000-8000-000000000102');
insert into r select 'twice',   public.lesson_replacement('c5000000-0000-4000-8000-000000000103');
insert into r select 'current', public.lesson_replacement('c5000000-0000-4000-8000-000000000201');
insert into r select 'loose',   public.lesson_replacement('c5000000-0000-4000-8000-000000000401');
insert into r select 'missing', public.lesson_replacement('c5000000-0000-4000-8000-0000000009ff');
reset role;

select is((select v from r where label = 'moved'),
  '{"retired": true, "replacement_id": "c5000000-0000-4000-8000-000000000201"}'::jsonb,
  'a retired lesson maps to the same-title lesson in the published version');
select is((select v->>'retired' from r where label = 'dropped'), 'true', 'a dropped section is still reported retired');
select ok((select v->'replacement_id' = 'null'::jsonb from r where label = 'dropped'),
  'but has no replacement, even when another target has the same title');
select ok((select v->'replacement_id' = 'null'::jsonb from r where label = 'twice'),
  'an ambiguous title gives no replacement');
select is((select v->>'retired' from r where label = 'current'), 'false', 'a published lesson is not retired');
select is((select v->>'retired' from r where label = 'loose'), 'false', 'a lesson outside any version is not retired');
select is((select v->>'retired' from r where label = 'missing'), 'false', 'an unknown id reveals nothing');
select ok(has_function_privilege('anon', 'public.lesson_replacement(uuid)', 'execute'),
  'guests may call it (contexts exist before sign-in)');

select * from finish();
rollback;
