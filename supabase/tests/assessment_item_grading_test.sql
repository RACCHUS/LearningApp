begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

-- All fixtures are fictional, transaction-local, and rolled back.
insert into auth.users(id, email) values
  ('c3000000-0000-4000-8000-000000000001', 'grading-owner@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) values ('c3000000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

insert into public.lessons (id, title, visibility) values
  ('c3000000-0000-4000-8000-000000000101', 'Grading Public Lesson', 'public');
insert into public.lessons (id, title, visibility, user_id) values
  ('c3000000-0000-4000-8000-000000000102', 'Grading Private Lesson', 'private',
   'c3000000-0000-4000-8000-000000000001');

insert into public.assessment_items
  (id, lesson_id, interaction_type, prompt, response_spec, scoring_spec, explanation)
values
  ('c3000000-0000-4000-8000-000000000201', 'c3000000-0000-4000-8000-000000000101',
   'single_choice', 'Pick B', '{"options":["A","B","C"]}', '{"correct_index":1}', 'B is right.'),
  ('c3000000-0000-4000-8000-000000000202', 'c3000000-0000-4000-8000-000000000101',
   'multi_select', 'Pick A and C', '{"options":["A","B","C"]}', '{"correct_indices":[0,2]}', null),
  ('c3000000-0000-4000-8000-000000000203', 'c3000000-0000-4000-8000-000000000101',
   'multi_select', 'Pick A and C (partial)', '{"options":["A","B","C"]}',
   '{"correct_indices":[0,2],"scoring_method":"partial_credit"}', null),
  ('c3000000-0000-4000-8000-000000000204', 'c3000000-0000-4000-8000-000000000101',
   'ordered_response', 'Order them', '{"items":["second","first","third"]}',
   '{"correct_order":[1,0,2]}', null),
  ('c3000000-0000-4000-8000-000000000205', 'c3000000-0000-4000-8000-000000000101',
   'matching', 'Match them', '{"left":["x","y"],"right":["1","2"]}',
   '{"correct_pairs":{"x":"1","y":"2"}}', null),
  ('c3000000-0000-4000-8000-000000000206', 'c3000000-0000-4000-8000-000000000101',
   'numeric_entry', 'Type 4', '{}', '{"value":4}', 'Secret.'),
  ('c3000000-0000-4000-8000-000000000207', 'c3000000-0000-4000-8000-000000000102',
   'single_choice', 'Private', '{"options":["A","B"]}', '{"correct_index":0}', null);

-- Protected exam item: an approved, published reference binding (EXM-03).
insert into public.learning_targets
  (id, target_type, title, slug, status, is_public, is_official)
values ('c3000000-0000-4000-8000-000000000011', 'licensure_exam',
  'Grading Fictional Target', 'grading-rpc-protected-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status, metadata)
values ('c3000000-0000-4000-8000-000000000012',
  'c3000000-0000-4000-8000-000000000011', 'fictional-v1', 'published',
  '{"exam_preparation":{"schema_version":1,"exam_parts":[{"key":"project_management","display_name":"Fake PM","curriculum_root_node_id":"c3000000-0000-4000-8000-000000000013"}]}}'::jsonb);
insert into public.curriculum_nodes (id, target_version_id, node_type, title, sort_order)
values ('c3000000-0000-4000-8000-000000000013',
  'c3000000-0000-4000-8000-000000000012', 'domain', 'Fake part', 1);
insert into public.content_source_releases (id, publisher, title, version, source_url)
values
  ('c3000000-0000-4000-8000-000000000014', 'Fictional', 'Fictional exam list',
   'fictional-2027', 'https://example.gov/grading-list.pdf'),
  ('c3000000-0000-4000-8000-000000000015', 'Fictional', 'Fictional reference',
   '2027-book', 'https://example.org/grading-book.pdf');
insert into public.exam_reference_manifest_revisions (
  id, target_version_id, exam_part_key, revision, effective_from, effective_until,
  source_release_id, official_source_url, source_checked_at, author_ref,
  reviewer_ref, reviewed_at, review_status, publication_status, reference_entries
) values (
  'c3000000-0000-4000-8000-000000000016',
  'c3000000-0000-4000-8000-000000000012', 'project_management', 1,
  '2027-01-01', '2027-12-31', 'c3000000-0000-4000-8000-000000000014',
  'https://example.gov/grading-list.pdf', now() - interval '2 days',
  'fictional-author', 'fictional-reviewer', now() - interval '1 day',
  'approved', 'published',
  '[{"key":"example_book","edition":"2027-book","source_page":"2"}]'::jsonb
);
insert into public.assessment_items
  (id, origin_target_version_id, interaction_type, prompt, response_spec, scoring_spec)
values ('c3000000-0000-4000-8000-000000000208',
  'c3000000-0000-4000-8000-000000000012', 'single_choice', 'Protected?',
  '{"options":["A","B"]}', '{"correct_index":0}');
insert into public.assessment_item_reference_validity (
  id, assessment_item_id, manifest_revision_id,
  item_content_revision, item_content_sha256, answer_location_revision,
  reference_edition_key, reference_edition, source_release_id,
  expected_locations, author_ref, ai_drafted, reviewer_ref,
  reviewer_qualification_evidence, reviewer_edition_access_evidence,
  rights_review_status, review_status, reviewed_at, review_minutes, publication_status
) values (
  'c3000000-0000-4000-8000-000000000018',
  'c3000000-0000-4000-8000-000000000208',
  'c3000000-0000-4000-8000-000000000016',
  1, public.exam_reference_item_fingerprint('c3000000-0000-4000-8000-000000000208'), 1,
  'example_book', '2027-book', 'c3000000-0000-4000-8000-000000000015',
  '[{"section":"1.1","source_page":"11"}]'::jsonb,
  'fictional-author', true, 'another-qualified-human',
  'fictional qualified reviewer', 'fictional 2027 exact edition',
  'approved', 'approved', now(), 12, 'published'
);

create temporary table grading_fixture (label text primary key, result jsonb)
  on commit drop;
grant all on grading_fixture to anon;

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select ok(
  not has_column_privilege('anon', 'public.assessment_items', 'scoring_spec', 'SELECT')
  and not has_column_privilege('anon', 'public.assessment_items', 'explanation', 'SELECT'),
  'Answer keys and explanations remain hidden from direct anon reads'
);
select ok(
  has_function_privilege('anon', 'public.grade_assessment_items(jsonb)', 'EXECUTE'),
  'Anonymous learners can grade answered practice items'
);

insert into grading_fixture
select 'single_ok', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000201","response":1}]')->0;
insert into grading_fixture
select 'single_str', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000201","response":"1"}]')->0;
insert into grading_fixture
select 'single_bad', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000201","response":2}]')->0;
insert into grading_fixture
select 'multi_ok', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000202","response":[2,0]}]')->0;
insert into grading_fixture
select 'multi_subset', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000202","response":[0]}]')->0;
insert into grading_fixture
select 'partial_half', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000203","response":[0]}]')->0;
insert into grading_fixture
select 'partial_cancel', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000203","response":[0,1]}]')->0;
insert into grading_fixture
select 'order_ok', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000204","response":["first","second","third"]}]')->0;
insert into grading_fixture
select 'order_bad', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000204","response":["second","first","third"]}]')->0;
insert into grading_fixture
select 'match_ok', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000205","response":{" x ":"1 ","y":"2"}}]')->0;
insert into grading_fixture
select 'match_half', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000205","response":{"x":"1","y":"1"}}]')->0;
insert into grading_fixture
select 'unsupported', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000206","response":4}]')->0;
insert into grading_fixture
select 'no_response', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000201"}]')->0;
insert into grading_fixture
select 'private', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000207","response":0}]')->0;
insert into grading_fixture
select 'protected', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000208","response":0}]')->0;
insert into grading_fixture
select 'batch', public.grade_assessment_items(
  '[{"item_id":"c3000000-0000-4000-8000-000000000201","response":1},
    {"item_id":"not-a-uuid","response":1},
    {"item_id":"c3000000-0000-4000-8000-000000000202","response":[0,2]},
    {"item_id":"c3000000-0000-4000-8000-000000000205","response":{"x":"1","y":"2"}}]');

select ok(
  (select (result->>'is_correct')::boolean
     and result->'scoring_spec' = '{"correct_index":1}'::jsonb
     and result->>'explanation' = 'B is right.'
   from grading_fixture where label = 'single_ok'),
  'Correct single choice is graded and reveals its key and explanation'
);
select ok((select (result->>'is_correct')::boolean from grading_fixture where label = 'single_str'),
  'Single choice accepts an integer string response');
select ok((select not (result->>'is_correct')::boolean and (result->>'score')::numeric = 0
   from grading_fixture where label = 'single_bad'),
  'Incorrect single choice scores zero');
select ok((select (result->>'is_correct')::boolean from grading_fixture where label = 'multi_ok'),
  'All-or-nothing multi-select accepts the exact set in any order');
select ok((select not (result->>'is_correct')::boolean and not (result->>'is_partial')::boolean
   from grading_fixture where label = 'multi_subset'),
  'All-or-nothing multi-select rejects a subset');
select ok((select (result->>'is_partial')::boolean and (result->>'score')::numeric = 0.5
   from grading_fixture where label = 'partial_half'),
  'Partial-credit multi-select awards half credit for one of two');
select ok((select (result->>'score')::numeric = 0 and not (result->>'is_partial')::boolean
   from grading_fixture where label = 'partial_cancel'),
  'Partial-credit multi-select subtracts incorrect selections');
select ok((select (result->>'is_correct')::boolean from grading_fixture where label = 'order_ok'),
  'Ordered response compares item text against correct_order indices');
select ok((select not (result->>'is_correct')::boolean from grading_fixture where label = 'order_bad'),
  'Ordered response rejects the wrong order');
select ok((select (result->>'is_correct')::boolean from grading_fixture where label = 'match_ok'),
  'Matching trims keys and values');
select ok((select (result->>'is_partial')::boolean and (result->>'score')::numeric = 0.5
   from grading_fixture where label = 'match_half'),
  'Matching awards proportional partial credit');
select ok((select result->>'error' = 'unsupported_interaction_type'
     and not result ? 'scoring_spec' and not result ? 'explanation'
   from grading_fixture where label = 'unsupported'),
  'Unsupported interaction types fail closed without revealing keys');
select ok((select result->>'error' = 'response_required' and not result ? 'scoring_spec'
   from grading_fixture where label = 'no_response'),
  'Unanswered items never reveal keys');
select ok((select result->>'error' = 'not_available' and not result ? 'scoring_spec'
   from grading_fixture where label = 'private'),
  'Items in lessons the caller cannot see are not graded');
select ok((select result->>'error' = 'not_available' and not result ? 'scoring_spec'
   from grading_fixture where label = 'protected'),
  'EXM-03 protected exam items are never graded or revealed');
select is((select jsonb_array_length(result) from grading_fixture where label = 'batch'), 3,
  'Batches grade each valid entry and skip malformed item ids');

select throws_ok(
  $$ select public.grade_assessment_items('{"item_id":"x"}'::jsonb) $$,
  '22023', null, 'Non-array input is rejected');
select throws_ok(
  $$ select public.grade_assessment_items(
       (select jsonb_agg(jsonb_build_object('item_id', gen_random_uuid(), 'response', 0))
        from generate_series(1, 251))) $$,
  '54000', null, 'Oversized batches are rejected');

reset role;
select set_config('request.jwt.claims',
  '{"sub":"c3000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select ok(
  (select (public.grade_assessment_items(
     '[{"item_id":"c3000000-0000-4000-8000-000000000207","response":0}]')->0->>'is_correct')::boolean),
  'Lesson owners can grade items in their private lessons'
);
select throws_ok(
  $$ select scoring_spec from public.assessment_items limit 1 $$,
  '42501', null, 'Direct scoring_spec reads stay denied for authenticated users');

select * from finish();
rollback;
