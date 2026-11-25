-- pgTAP: the Coverage Matrix's Check role counts independent checks
-- (migration 20261124130000, ingestion plan v1.2 §8.2 slice 8).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('ce100000-0000-4000-8000-000000000010', 'standardized_exam', 'Indep Fictional Target', 'test-cov-indep', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('ce100000-0000-4000-8000-000000000011', 'ce100000-0000-4000-8000-000000000010', 'ci-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order) values
  ('ce100000-0000-4000-8000-000000000021', 'ce100000-0000-4000-8000-000000000011', 'objective', 'I1', 'Checked', 1),
  ('ce100000-0000-4000-8000-000000000022', 'ce100000-0000-4000-8000-000000000011', 'objective', 'I2', 'Practice only', 2);
insert into public.knowledge_concepts (id, slug, name)
values ('ce100000-0000-4000-8000-000000000041', 'ci-fixture-concept', 'Indep concept');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
values ('ce100000-0000-4000-8000-000000000021', 'ce100000-0000-4000-8000-000000000041');

-- I2: a lesson with teaching, an example, a graded assessment item and a
-- graded lesson question, but no independent check.
insert into public.lessons (id, title, visibility, origin_target_version_id)
values ('ce100000-0000-4000-8000-000000000101', 'Practice lesson', 'public', 'ce100000-0000-4000-8000-000000000011');
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
values ('ce100000-0000-4000-8000-000000000022', 'ce100000-0000-4000-8000-000000000101', 1);
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('ce100000-0000-4000-8000-000000000101', 'markdown', 1, '{"text":"Read this."}'),
  ('ce100000-0000-4000-8000-000000000101', 'markdown', 2, '{"text":"**Example 1: Find it**"}');
insert into public.assessment_items (lesson_id, interaction_type, prompt, response_spec, scoring_spec)
values ('ce100000-0000-4000-8000-000000000101', 'single_choice', 'Pick A',
        '{"options": ["A", "B"]}'::jsonb, '{"correct_index": 0}'::jsonb);
insert into public.questions (lesson_id, question_text, options, correct_answer)
values ('ce100000-0000-4000-8000-000000000101', 'Pick B', '["A", "B"]'::jsonb, 1);

-- I1: six approved held-out checks through its concept.
select public.ingest_held_out_items('ce100000-0000-4000-8000-000000000011', (
  select jsonb_agg(jsonb_build_object(
    'key', 'ci-' || g, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 7 + ' || g || ' (indep)',
    'scoring_spec', jsonb_build_object('correct_value', 7 + g, 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array('ci-fixture-concept'),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_kind', 'ai', 'reviewer_model', 'fictional-model',
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1',
      'reviewed_on', '2026-11-25', 'review_status', 'approved', 'rights_review_status', 'approved')))
  from generate_series(1, 6) g));
update public.target_versions set status = 'review_ready' where id = 'ce100000-0000-4000-8000-000000000011';
update public.target_versions set status = 'published' where id = 'ce100000-0000-4000-8000-000000000011';

create function pg_temp.matrix() returns jsonb language plpgsql as $$
declare v jsonb;
begin
  set local role anon;
  perform set_config('request.jwt.claims', '', true);
  v := public.get_coverage_matrix('test-cov-indep')->'objectives';
  reset role;
  return v;
end $$;

create temp table m as select pg_temp.matrix() as v;
select is((select v->0->>'held_out_items' from m), '6', 'approved held-out checks count per objective');
select is((select v->1->>'held_out_items' from m), '0', 'lesson questions are not independent checks');
select is((select v->1->>'graded_practice_items' from m), '2',
  'graded practice counts assessment items and lesson questions');
select is((select v->1->>'check_items' from m), '1', 'check_items keeps its old value for older clients');
-- I2 has teach, example and practice; Check is missing (0 < 6): 1/4.
select is((select v->1->>'priority' from m), '0.250', 'graded practice is not a check: only Check missing');
-- I1 has no lesson (teach, example, practice missing) but six checks: 3/4.
select is((select v->0->>'priority' from m), '0.750', 'six checks: Check is covered');

-- A check flagged unreliable while its report is open stops counting.
insert into public.moderation_reports (id, reporter_id, target_type, target_id, reason, description, status)
select 'ce100000-0000-4000-8000-000000000071', null, 'question', r.assessment_item_id, 'other',
       '[Item Analytics Auto-Flag] low_discrimination', 'pending'
from private.held_out_item_reviews r
where r.target_version_id = 'ce100000-0000-4000-8000-000000000011' limit 1;
insert into public.item_analytics (item_id, response_count, flagged_reasons, auto_flagged, moderation_report_id)
select target_id, 30, array['low_discrimination'], true, id
from public.moderation_reports where id = 'ce100000-0000-4000-8000-000000000071';
select is((pg_temp.matrix()->0->>'held_out_items'), '5', 'an unreliable check is not counted');
select is((pg_temp.matrix()->0->>'priority'), '1.000', 'five checks are below the minimum of six');

select ok(has_function_privilege('anon', 'public.get_coverage_matrix(text)', 'execute'),
  'guests can read the matrix');

select * from finish();
rollback;
