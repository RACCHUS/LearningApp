-- pgTAP: set_curriculum_lesson_tags (migration 20261121020000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into public.learning_targets (id, target_type, title, slug) values
  ('c9000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Tag Book', 'test-tag-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('c9000000-0000-4000-8000-000000000011', 'c9000000-0000-4000-8000-000000000010', 'D1', 'draft'),
  ('c9000000-0000-4000-8000-000000000012', 'c9000000-0000-4000-8000-000000000010', 'P1', 'draft');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  ('c9000000-0000-4000-8000-000000000101', '1.2 Exponents', 'public', 'c9000000-0000-4000-8000-000000000011'),
  ('c9000000-0000-4000-8000-000000000201', '1.2 Exponents', 'public', 'c9000000-0000-4000-8000-000000000012');
update public.target_versions set status = 'review_ready' where id = 'c9000000-0000-4000-8000-000000000012';
update public.target_versions set status = 'published' where id = 'c9000000-0000-4000-8000-000000000012';

select ok(not has_function_privilege('authenticated', 'public.set_curriculum_lesson_tags(uuid,jsonb)', 'execute'),
  'learners cannot set tags');
select ok(not has_function_privilege('anon', 'public.set_curriculum_lesson_tags(uuid,jsonb)', 'execute'),
  'guests cannot set tags');

select is((public.set_curriculum_lesson_tags('c9000000-0000-4000-8000-000000000011',
  '[{"title":"1.2 Exponents","tags":["algebra","exponents","exponents"]}]'))->>'updated', '1',
  'a draft lesson gets its tags');
select is((select tags from public.lessons where id = 'c9000000-0000-4000-8000-000000000101'),
  array['algebra','exponents'], 'tags are stored once each');
select throws_ok($$ select public.set_curriculum_lesson_tags('c9000000-0000-4000-8000-000000000012',
  '[{"title":"1.2 Exponents","tags":["algebra"]}]') $$, '22023', null,
  'published versions cannot be changed');
select throws_ok($$ select public.set_curriculum_lesson_tags('c9000000-0000-4000-8000-000000000011',
  '[{"title":"1.2 Exponents","tags":["Not A Tag"]}]') $$, '22023', null,
  'tags must be lowercase slugs');
select throws_ok($$ select public.set_curriculum_lesson_tags('c9000000-0000-4000-8000-000000000011',
  '[{"title":"No such lesson","tags":["algebra"]}]') $$, '22023', null,
  'an unknown title is an error, not a silent skip');
select is((select tags from public.lessons where id = 'c9000000-0000-4000-8000-000000000201'),
  '{}'::text[], 'the published lesson is untouched');

select * from finish();
rollback;
