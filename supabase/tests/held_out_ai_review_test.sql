-- pgTAP: AI-reviewed held-out items and review_basis (migration 20261124030000, decision D-16).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

-- All fixtures are fictional, transaction-local, and rolled back.
insert into auth.users (id, email) values
  ('d3400000-0000-4000-8000-000000000001', 'ai-review-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d3400000-0000-4000-8000-000000000001')
on conflict (id) do nothing;
insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d3400000-0000-4000-8000-000000000011', 'standardized_exam',
  'AI Review Fictional Target', 'ai-review-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('d3400000-0000-4000-8000-000000000012', 'd3400000-0000-4000-8000-000000000011', 'air-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, title, sort_order) values
  ('d3400000-0000-4000-8000-000000000021', 'd3400000-0000-4000-8000-000000000012', null, 'domain', 'D', 1),
  ('d3400000-0000-4000-8000-000000000031', 'd3400000-0000-4000-8000-000000000012', 'd3400000-0000-4000-8000-000000000021', 'objective', 'O1', 1),
  ('d3400000-0000-4000-8000-000000000032', 'd3400000-0000-4000-8000-000000000012', 'd3400000-0000-4000-8000-000000000021', 'objective', 'O2', 2);
insert into public.knowledge_concepts (id, slug, name) values
  ('d3400000-0000-4000-8000-000000000041', 'air-fixture-concept-1', 'AI review concept 1'),
  ('d3400000-0000-4000-8000-000000000042', 'air-fixture-concept-2', 'AI review concept 2');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id) values
  ('d3400000-0000-4000-8000-000000000031', 'd3400000-0000-4000-8000-000000000041'),
  ('d3400000-0000-4000-8000-000000000032', 'd3400000-0000-4000-8000-000000000042');

create function pg_temp.item(p_key text, p_concept text, p_review jsonb)
returns jsonb language sql as $$
  select jsonb_build_object(
    'key', p_key, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 3 + ' || length(p_key) || ' (' || p_key || ')',
    'scoring_spec', jsonb_build_object('correct_value', 3 + length(p_key), 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array(p_concept),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1 + SymPy',
      'reviewed_on', '2026-11-24', 'review_status', 'approved', 'rights_review_status', 'approved') || p_review);
$$;
create function pg_temp.items(p_prefix text, p_concept text, p_review jsonb)
returns jsonb language sql as $$
  select jsonb_agg(pg_temp.item(p_prefix || '-' || g, p_concept, p_review)) from generate_series(1, 6) g;
$$;

-- 1. Every review states its kind; an AI review names its model.
select throws_ok($$ select public.ingest_held_out_items('d3400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('air-nokind', 'air-fixture-concept-1', '{}'))) $$,
  '22023', 'Held-out item air-nokind needs reviewer_kind ai or human', 'a review without a kind is refused');
select throws_ok($$ select public.ingest_held_out_items('d3400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('air-nomodel', 'air-fixture-concept-1', '{"reviewer_kind": "ai"}'))) $$,
  '23514', null, 'an AI review must name the reviewing model');
select is((select column_default from information_schema.columns
           where table_schema = 'private' and table_name = 'held_out_item_reviews' and column_name = 'reviewer_kind'),
  null, 'reviewer_kind has no default, so new rows can''t silently claim a person');

-- 2. AI-reviewed items are accepted and recorded as such.
select is((public.ingest_held_out_items('d3400000-0000-4000-8000-000000000012',
  pg_temp.items('air-a', 'air-fixture-concept-1', '{"reviewer_kind": "ai", "reviewer_model": "fictional-model-2"}'))->>'held_out_items')::int,
  6, 'six AI-reviewed items are ingested');
select is((select count(*)::int from private.held_out_item_reviews
           where target_version_id = 'd3400000-0000-4000-8000-000000000012'
             and reviewer_kind = 'ai' and reviewer_model = 'fictional-model-2'), 6,
  'their approvals say AI, and which model');

-- 3. Coverage reports who reviewed the checks.
update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_coverage_gate';
create temporary table cov (label text primary key, result jsonb) on commit drop;
grant all on cov to authenticated;
create function pg_temp.snap(p_label text) returns void language plpgsql as $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', 'd3400000-0000-4000-8000-000000000001', true);
  insert into cov values (p_label, public.get_target_readiness_coverage('d3400000-0000-4000-8000-000000000012'));
  reset role;
end $$;
select pg_temp.snap('ai');
select is((select result->>'review_basis' from cov where label = 'ai'), 'ai',
  'with only AI-reviewed checks, review_basis is ai');
select is((select result->>'state' from cov where label = 'ai'), 'hidden',
  'one of two objectives covered is still hidden');

select public.ingest_held_out_items('d3400000-0000-4000-8000-000000000012',
  pg_temp.items('air-b', 'air-fixture-concept-2', '{"reviewer_kind": "human", "reviewer_ref": "reviewer-001"}'));
select pg_temp.snap('mixed');
select is((select result->>'review_basis' from cov where label = 'mixed'), 'mixed',
  'AI and human reviews together are reported as mixed');
select is((select result->>'state' from cov where label = 'mixed'), 'full',
  'both objectives covered: full');

select * from finish();
rollback;
