-- pgTAP: Coverage Matrix source data (migration 20261122040000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

insert into public.learning_targets (id, target_type, title, slug) values
  ('ce000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Cov Book', 'test-cov-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('ce000000-0000-4000-8000-000000000011', 'ce000000-0000-4000-8000-000000000010', 'C1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code, sort_order) values
  ('ce000000-0000-4000-8000-000000000021', 'ce000000-0000-4000-8000-000000000011', 'objective', 'Covered', '1.1', 1),
  ('ce000000-0000-4000-8000-000000000022', 'ce000000-0000-4000-8000-000000000011', 'objective', 'Empty', '1.2', 2);
insert into public.lessons (id, title, visibility, origin_target_version_id, tags) values
  ('ce000000-0000-4000-8000-000000000101', 'Lesson', 'public', 'ce000000-0000-4000-8000-000000000011', array['unreviewed','percent']);
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order) values
  ('ce000000-0000-4000-8000-000000000021', 'ce000000-0000-4000-8000-000000000101', 1);
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('ce000000-0000-4000-8000-000000000101', 'markdown', 1, '{"text":"Read this."}'),
  ('ce000000-0000-4000-8000-000000000101', 'markdown', 2, '{"text":"**Example 1: Find it**"}'),
  ('ce000000-0000-4000-8000-000000000101', 'practice_prompt', 3, '{"prompt":"Try it"}');

select is(public.get_coverage_matrix('test-cov-book')->'objectives', '[]'::jsonb,
  'drafts are not counted');
update public.target_versions set status = 'review_ready' where id = 'ce000000-0000-4000-8000-000000000011';
update public.target_versions set status = 'published' where id = 'ce000000-0000-4000-8000-000000000011';

create temp table m as select public.get_coverage_matrix('test-cov-book')->'objectives' as v;
select is(jsonb_array_length((select v from m)), 2, 'one row per objective');
select is((select v->0->>'teach_blocks' from m), '2', 'reading blocks count as teach');
select is((select v->0->>'example_blocks' from m), '1', 'imported worked examples count as examples');
select is((select v->0->>'unreviewed' from m), 'true', 'unreviewed content is flagged');
select is((select v->1->>'lessons' from m), '0', 'an objective with no lesson is a gap row');

select * from finish();
rollback;
