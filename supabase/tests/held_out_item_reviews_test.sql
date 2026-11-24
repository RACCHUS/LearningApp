-- pgTAP: general held-out check items (migration 20261124020000, ingestion plan D-14 option B).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

-- All fixtures are fictional, transaction-local, and rolled back.
insert into auth.users (id, email) values
  ('d2400000-0000-4000-8000-000000000001', 'held-out-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d2400000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d2400000-0000-4000-8000-000000000011', 'standardized_exam',
  'Held-out Fictional Target', 'held-out-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('d2400000-0000-4000-8000-000000000012', 'd2400000-0000-4000-8000-000000000011', 'ho-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, title, sort_order) values
  ('d2400000-0000-4000-8000-000000000021', 'd2400000-0000-4000-8000-000000000012', null, 'domain', 'D', 1),
  ('d2400000-0000-4000-8000-000000000031', 'd2400000-0000-4000-8000-000000000012', 'd2400000-0000-4000-8000-000000000021', 'objective', 'O1', 1),
  ('d2400000-0000-4000-8000-000000000032', 'd2400000-0000-4000-8000-000000000012', 'd2400000-0000-4000-8000-000000000021', 'objective', 'O2', 2);
insert into public.knowledge_concepts (id, slug, name) values
  ('d2400000-0000-4000-8000-000000000041', 'ho-fixture-concept-1', 'Held-out concept 1'),
  ('d2400000-0000-4000-8000-000000000042', 'ho-fixture-concept-2', 'Held-out concept 2'),
  ('d2400000-0000-4000-8000-000000000043', 'ho-fixture-outside', 'Concept of another version');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id) values
  ('d2400000-0000-4000-8000-000000000031', 'd2400000-0000-4000-8000-000000000041'),
  ('d2400000-0000-4000-8000-000000000032', 'd2400000-0000-4000-8000-000000000042');

-- One approved numeric item; fields can be overridden for the failure cases.
create function pg_temp.item(p_key text, p_concept text, p_override jsonb default '{}'::jsonb)
returns jsonb language sql as $$
  select jsonb_build_object(
    'key', p_key, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 2 + ' || length(p_key) || ' (' || p_key || ')',
    'scoring_spec', jsonb_build_object('correct_value', 2 + length(p_key), 'tolerance', 0),
    'explanation', 'Add.', 'difficulty', 'beginner', 'cognitive_level', 'application',
    'citation', 'Fictional book 1.1', 'concept_slugs', jsonb_build_array(p_concept),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_ref', 'reviewer-001', 'reviewer_qualification', 'Fictional certified math teacher',
      'reviewed_on', '2026-11-24', 'review_status', 'approved', 'rights_review_status', 'approved',
      'reviewer_kind', 'human')
  ) || p_override;
$$;
create function pg_temp.items(p_prefix text, p_concept text, p_n int)
returns jsonb language sql as $$
  select jsonb_agg(pg_temp.item(p_prefix || '-' || g, p_concept)) from generate_series(1, p_n) g;
$$;

-- 1. Access.
select ok(not has_table_privilege('authenticated', 'private.held_out_item_reviews', 'select')
          and not has_table_privilege('anon', 'private.held_out_item_reviews', 'select'),
  'learners cannot read held-out approvals');
select ok(not has_function_privilege('authenticated', 'public.ingest_held_out_items(uuid, jsonb)', 'execute')
          and not has_function_privilege('anon', 'public.ingest_held_out_items(uuid, jsonb)', 'execute'),
  'only the service role can ingest held-out items');

-- 2. Approved items go in, outside any lesson.
select is((public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
             pg_temp.items('ho-a', 'ho-fixture-concept-1', 6))->>'held_out_items')::int, 6,
  'six approved items are ingested');
select is((select count(*)::int from public.assessment_items
           where origin_target_version_id = 'd2400000-0000-4000-8000-000000000012'
             and lesson_id is null and metadata->>'usage_role' = 'held_out_check'), 6,
  'they belong to the version, to no lesson, and are marked held-out');
select is((select count(*)::int from public.assessment_item_concepts aic
           join public.assessment_items ai on ai.id = aic.assessment_item_id
           where ai.metadata->>'held_out_key' like 'ho-a-%'
             and aic.concept_id = 'd2400000-0000-4000-8000-000000000041'), 6,
  'each is linked to its objective''s concept');
select is((select count(*)::int from private.held_out_item_reviews
           where target_version_id = 'd2400000-0000-4000-8000-000000000012' and ai_drafted), 6,
  'each has an approval that records it was AI-drafted');
select is((select count(*)::int from public.content_import_artifacts
           where target_version_id = 'd2400000-0000-4000-8000-000000000012' and entity_type = 'assessment_item'), 6,
  'they are registered for draft cleanup');

-- 3. What is refused (nothing is written).
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('ho-pending', 'ho-fixture-concept-1',
    jsonb_build_object('review', jsonb_build_object('review_status', 'pending'))))) $$,
  '22023', null, 'an unapproved item is refused');
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('ho-self', 'ho-fixture-concept-1') ||
    jsonb_build_object('review', (pg_temp.item('x', 'y')->'review') || '{"reviewer_ref": "AI-Drafted-by-Claude"}'))) $$,
  '23514', null, 'the author cannot be the reviewer');
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('ho-badkey', 'ho-fixture-concept-1',
    '{"interaction_type": "single_choice", "response_spec": {"options": ["A","B"]}, "scoring_spec": {"correct_index": 2}}'))) $$,
  '22023', 'Held-out item ho-badkey has an invalid answer key', 'an out-of-range answer key is refused');
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('ho-outside', 'ho-fixture-outside'))) $$,
  '22023', null, 'a concept outside the version is refused');
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  jsonb_build_array(pg_temp.item('ho-a-1', 'ho-fixture-concept-1'))) $$,
  '23505', null, 'an item key can be used once per version');
select is((select count(*)::int from private.held_out_item_reviews), 6,
  'failed calls wrote nothing');

-- 4. Approvals are immutable; retiring is the only change.
select throws_ok($$ update private.held_out_item_reviews set reviewer_ref = 'someone-else'
  where item_key = 'ho-a-1' $$, '42501', null, 'an approval cannot be edited');
select lives_ok($$ update private.held_out_item_reviews set review_status = 'retired'
  where item_key = 'ho-a-6' $$, 'an approval can be retired');

-- 5. O2 gets six more; then the version is published.
select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  pg_temp.items('ho-b', 'ho-fixture-concept-2', 6));
update public.target_versions set status = 'review_ready' where id = 'd2400000-0000-4000-8000-000000000012';
update public.target_versions set status = 'published' where id = 'd2400000-0000-4000-8000-000000000012';
select throws_ok($$ select public.ingest_held_out_items('d2400000-0000-4000-8000-000000000012',
  pg_temp.items('ho-c', 'ho-fixture-concept-2', 1)) $$,
  '22023', 'Held-out items can only be added to a draft target version', 'a published version takes no new items');
select throws_ok($$ delete from private.held_out_item_reviews where item_key = 'ho-a-1' $$,
  '42501', null, 'approvals of a published version cannot be deleted');

-- 6. Coverage counts approved general reviews.
update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_coverage_gate';
create temporary table cov (label text primary key, result jsonb) on commit drop;
grant all on cov to authenticated;
create function pg_temp.snap(p_label text) returns void language plpgsql as $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', 'd2400000-0000-4000-8000-000000000001', true);
  insert into cov values (p_label, public.get_target_readiness_coverage('d2400000-0000-4000-8000-000000000012'));
  reset role;
end $$;

select pg_temp.snap('five');
select is((select (result->>'objectives_covered')::int from cov where label = 'five'), 1,
  'O1 has 5 approved (one retired), so only O2 counts');
select is((select result->>'state' from cov where label = 'five'), 'hidden',
  'one of two equal objectives (50%) is hidden');

-- A changed item no longer matches its approval.
update public.assessment_items set explanation = 'Changed after review.'
  where metadata->>'held_out_key' = 'ho-b-1';
select pg_temp.snap('drift');
select is((select (result->>'objectives_covered')::int from cov where label = 'drift'), 0,
  'an item changed after approval stops counting');

-- 7. Learners can take the item but not see its key.
select ok(not has_column_privilege('authenticated', 'public.assessment_items', 'scoring_spec', 'select'),
  'answer keys stay hidden from learners');

select * from finish();
rollback;
