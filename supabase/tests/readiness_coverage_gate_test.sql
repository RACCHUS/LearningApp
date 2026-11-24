-- pgTAP: readiness coverage gate (migration 20261124010000, ingestion plan D-14).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

-- All fixtures are fictional, transaction-local, and rolled back.
insert into auth.users (id, email) values
  ('d1400000-0000-4000-8000-000000000001', 'coverage-learner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('d1400000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d1400000-0000-4000-8000-000000000011', 'licensure_exam',
  'Coverage Fictional Target', 'coverage-gate-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status, metadata)
values ('d1400000-0000-4000-8000-000000000012',
  'd1400000-0000-4000-8000-000000000011', 'coverage-v1', 'published',
  '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"core","display_name":"Core","curriculum_root_node_id":"d1400000-0000-4000-8000-000000000021"}]}}'::jsonb);

-- Blueprint: D1 (0.75) with objectives O1, O2; D2 (0.25) with objective O3.
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, title, sort_order, weight) values
  ('d1400000-0000-4000-8000-000000000021', 'd1400000-0000-4000-8000-000000000012', null, 'domain', 'D1', 1, 0.75),
  ('d1400000-0000-4000-8000-000000000022', 'd1400000-0000-4000-8000-000000000012', null, 'domain', 'D2', 2, 0.25),
  ('d1400000-0000-4000-8000-000000000031', 'd1400000-0000-4000-8000-000000000012', 'd1400000-0000-4000-8000-000000000021', 'objective', 'O1', 1, null),
  ('d1400000-0000-4000-8000-000000000032', 'd1400000-0000-4000-8000-000000000012', 'd1400000-0000-4000-8000-000000000021', 'objective', 'O2', 2, null),
  ('d1400000-0000-4000-8000-000000000033', 'd1400000-0000-4000-8000-000000000012', 'd1400000-0000-4000-8000-000000000022', 'objective', 'O3', 1, null);
insert into public.knowledge_concepts (id, name) values
  ('d1400000-0000-4000-8000-000000000041', 'Coverage concept 1'),
  ('d1400000-0000-4000-8000-000000000042', 'Coverage concept 2'),
  ('d1400000-0000-4000-8000-000000000043', 'Coverage concept 3');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id) values
  ('d1400000-0000-4000-8000-000000000031', 'd1400000-0000-4000-8000-000000000041'),
  ('d1400000-0000-4000-8000-000000000032', 'd1400000-0000-4000-8000-000000000042'),
  ('d1400000-0000-4000-8000-000000000033', 'd1400000-0000-4000-8000-000000000043');

insert into public.content_source_releases (id, publisher, title, version, source_url) values
  ('d1400000-0000-4000-8000-000000000014', 'Fictional', 'Fictional exam list', 'fictional-2027', 'https://example.gov/coverage-list.pdf'),
  ('d1400000-0000-4000-8000-000000000015', 'Fictional', 'Fictional reference', '2027-book', 'https://example.org/coverage-book.pdf');
insert into public.exam_reference_manifest_revisions (
  id, target_version_id, exam_part_key, revision, effective_from, effective_until,
  source_release_id, official_source_url, source_checked_at, author_ref,
  reviewer_ref, reviewed_at, review_status, publication_status, reference_entries
) values (
  'd1400000-0000-4000-8000-000000000016', 'd1400000-0000-4000-8000-000000000012', 'core', 1,
  '2027-01-01', '2027-12-31', 'd1400000-0000-4000-8000-000000000014',
  'https://example.gov/coverage-list.pdf', now() - interval '2 days',
  'fictional-author', 'fictional-reviewer', now() - interval '1 day',
  'approved', 'published',
  '[{"key":"example_book","edition":"2027-book","source_page":"2"}]'::jsonb
);

-- Creates p_count items on a concept and binds each with p_role/p_status.
create function pg_temp.add_items(p_concept uuid, p_count int, p_role text, p_status text, p_tag text)
returns void language plpgsql as $$
declare v_id uuid;
begin
  for i in 1..p_count loop
    insert into public.assessment_items
      (origin_target_version_id, interaction_type, prompt, response_spec, scoring_spec)
    values ('d1400000-0000-4000-8000-000000000012', 'single_choice',
      p_tag || ' item ' || i, '{"options":["A","B"]}', '{"correct_index":0}')
    returning id into v_id;
    insert into public.assessment_item_concepts (assessment_item_id, concept_id) values (v_id, p_concept);
    insert into public.assessment_item_reference_validity (
      assessment_item_id, manifest_revision_id, item_content_revision, item_content_sha256,
      answer_location_revision, reference_edition_key, reference_edition, source_release_id,
      expected_locations, author_ref, ai_drafted, reviewer_ref,
      reviewer_qualification_evidence, reviewer_edition_access_evidence,
      rights_review_status, review_status, reviewed_at, review_minutes, publication_status, usage_role
    ) values (
      v_id, 'd1400000-0000-4000-8000-000000000016', 1, public.exam_reference_item_fingerprint(v_id),
      1, 'example_book', '2027-book', 'd1400000-0000-4000-8000-000000000015',
      '[{"section":"1.1","source_page":"11"}]'::jsonb, 'fictional-author', false, 'another-qualified-human',
      'fictional qualified reviewer', 'fictional 2027 exact edition',
      case when p_status = 'published' then 'approved' else 'pending' end,
      case when p_status = 'published' then 'approved' else 'pending' end,
      case when p_status = 'published' then now() end,
      case when p_status = 'published' then 12 end,
      p_status, p_role);
  end loop;
end $$;

create temporary table coverage_fixture (label text primary key, result jsonb) on commit drop;
grant all on coverage_fixture to authenticated;
create function pg_temp.snap(p_label text) returns void language plpgsql as $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', 'd1400000-0000-4000-8000-000000000001', true);
  insert into coverage_fixture values (p_label,
    public.get_target_readiness_coverage('d1400000-0000-4000-8000-000000000012'));
  reset role;
end $$;

-- 1. Switch off: nothing is computed.
update private.site_feature_controls set enabled = false, release_ready = false
  where feature_key = 'learning.readiness_coverage_gate';
select is((select enabled from private.site_feature_controls where feature_key = 'learning.readiness_coverage_gate'),
  false, 'the switch is seeded and can be off');
select pg_temp.snap('off');
select is((select result from coverage_fixture where label = 'off'), '{"enabled": false}'::jsonb,
  'while off the function returns only {"enabled": false}');

-- 2. Access.
select ok(not has_function_privilege('anon', 'public.get_target_readiness_coverage(uuid)', 'execute'),
  'anonymous visitors cannot call it');
set local role authenticated;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$ select public.get_target_readiness_coverage('d1400000-0000-4000-8000-000000000012') $$,
  '42501', null, 'a call without a signed-in user is refused');
reset role;

update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_coverage_gate';

-- 3. Nothing held out yet: hidden.
select pg_temp.snap('empty');
select is((select result->>'state' from coverage_fixture where label = 'empty'), 'hidden',
  'no held-out items: readiness hidden');
select is((select (result->>'objectives_total')::int from coverage_fixture where label = 'empty'), 3,
  'all three objectives are counted');

-- 4. Practice-pool and draft bindings never count; five held-out items are not enough.
select pg_temp.add_items('d1400000-0000-4000-8000-000000000041', 6, 'practice_pool', 'published', 'pool');
select pg_temp.add_items('d1400000-0000-4000-8000-000000000041', 6, 'held_out_transfer', 'draft', 'draft');
select pg_temp.add_items('d1400000-0000-4000-8000-000000000041', 5, 'held_out_transfer', 'published', 'five');
select pg_temp.snap('not_enough');
select is((select (result->>'objectives_covered')::int from coverage_fixture where label = 'not_enough'), 0,
  'practice-pool items, draft bindings and only five held-out items leave O1 uncovered');

-- 5. Sixth held-out item covers O1 (0.375 of the blueprint): still hidden.
select pg_temp.add_items('d1400000-0000-4000-8000-000000000041', 1, 'held_out_transfer', 'published', 'sixth');
select pg_temp.snap('o1');
select is((select (result->>'covered_weight')::numeric from coverage_fixture where label = 'o1'), 0.375,
  'O1 is half of D1, so 0.375 of the blueprint');
select is((select result->>'state' from coverage_fixture where label = 'o1'), 'hidden',
  'below 60%: hidden');

-- 6. O3 (0.25) brings it to 0.625: provisional.
select pg_temp.add_items('d1400000-0000-4000-8000-000000000043', 6, 'held_out_transfer', 'published', 'o3');
select pg_temp.snap('o3');
select is((select result->>'state' from coverage_fixture where label = 'o3'), 'provisional',
  '60% up to 90%: provisional');
select is((select (result->>'covered_weight')::numeric from coverage_fixture where label = 'o3'), 0.625,
  'covered weight is 0.625');

-- 7. O2 completes it: full.
select pg_temp.add_items('d1400000-0000-4000-8000-000000000042', 6, 'held_out_transfer', 'published', 'o2');
select pg_temp.snap('full');
select is((select result->>'state' from coverage_fixture where label = 'full'), 'full',
  '90% or more: full');
select is((select (result->>'objectives_covered')::int from coverage_fixture where label = 'full'), 3,
  'all three objectives covered');
select is((select result->>'weights_editorial' from coverage_fixture where label = 'full'), 'false',
  'domain weights were all set');

-- 8. A missing domain weight makes domains share equally, and says so.
update public.curriculum_nodes set weight = null where id = 'd1400000-0000-4000-8000-000000000022';
select pg_temp.snap('editorial');
select is((select result->>'weights_editorial' from coverage_fixture where label = 'editorial'), 'true',
  'missing weights are reported as editorial');

-- 9. Output carries no item ids, content or learner data.
select is((select array_agg(k order by k) from coverage_fixture f, jsonb_object_keys(f.result) k
           where f.label = 'full'),
  array['covered_weight','enabled','full_threshold','min_held_out_items','objectives_covered',
        'objectives_total','provisional_threshold','state','weights_editorial'],
  'only aggregate fields are returned');

select * from finish();
rollback;
