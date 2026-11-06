-- ============================================================================
-- pgTAP tests for Architecture Phase 2 Deliverable:
-- Versioned API Schema & Fast Scope Resolver (ARCH-2)
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, api;
select plan(20);

-- 1. Create synthetic test users and learning targets
insert into auth.users (id, email) values
 ('cc111111-0000-4000-8000-000000000001', 'api_test_user@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name) values
 ('cc111111-0000-4000-8000-000000000001', 'api_test_user@example.invalid', 'API Test User')
on conflict (id) do nothing;

insert into public.learning_targets (id, slug, title, description, target_type, provider_name) values
 ('cc222222-0000-4000-8000-000000000001', 'test-cert-api', 'Test API Certification Target', 'Target for testing api schema and scope resolver', 'certification', 'LearningApp Certs')
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_code, title, status) values
 ('cc333333-0000-4000-8000-000000000001', 'cc222222-0000-4000-8000-000000000001', 'v1.0-api', 'Edition 1.0', 'published')
on conflict (id) do nothing;

insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order) values
 ('cc444444-0000-4000-8000-000000000001', 'cc333333-0000-4000-8000-000000000001', 'module', 'MOD-1', 'Module 1: Foundations', 1),
 ('cc444444-0000-4000-8000-000000000002', 'cc333333-0000-4000-8000-000000000001', 'module', 'MOD-2', 'Module 2: Advanced', 2)
on conflict (id) do nothing;

insert into public.knowledge_concepts (id, name, slug) values
 ('cc555555-0000-4000-8000-000000000001', 'API Architecture Core', 'concept-api-core'),
 ('cc555555-0000-4000-8000-000000000002', 'API Architecture Supporting', 'concept-api-supp')
on conflict (id) do nothing;

insert into public.curriculum_node_concepts (curriculum_node_id, concept_id, relevance, weight) values
 ('cc444444-0000-4000-8000-000000000001', 'cc555555-0000-4000-8000-000000000001', 'core', 1.0),
 ('cc444444-0000-4000-8000-000000000002', 'cc555555-0000-4000-8000-000000000002', 'supporting', 0.8)
on conflict do nothing;

insert into public.review_items (
  id, user_id, content_id, content_type, lesson_id, title, stability, difficulty, fsrs_state, total_reviews, correct_reviews, next_review_date
) values (
  'cc666666-0000-4000-8000-000000000001',
  'cc111111-0000-4000-8000-000000000001',
  'item-due-now',
  'question',
  'test-lesson-id',
  'Test Review Item Title',
  3.5,
  4.2,
  2,
  5,
  4,
  now() - interval '1 hour'
) on conflict do nothing;

-- 2. SCHEMA AND FUNCTION EXISTENCE TESTS (Assertions 1-7)
select has_schema('api', 'schema api exists');
select has_function('api', 'resolve_scope', ARRAY['jsonb'], 'api.resolve_scope(jsonb) exists');
select has_function('public', 'resolve_scope', ARRAY['jsonb'], 'public.resolve_scope(jsonb) exists');
select has_function('api', 'get_learner_summary', ARRAY['uuid'], 'api.get_learner_summary(uuid) exists');
select has_function('public', 'get_learner_summary', ARRAY['uuid'], 'public.get_learner_summary(uuid) exists');
select has_function('api', 'search_catalog', ARRAY['text', 'text', 'integer'], 'api.search_catalog exists');
select has_function('public', 'search_catalog', ARRAY['text', 'text', 'integer'], 'public.search_catalog exists');

-- 3. SEARCH CATALOG EXECUTION TESTS (Assertions 8-10)
select is(
  (select jsonb_typeof(api.search_catalog('Test API Certification', null, 5))),
  'array',
  'api.search_catalog returns a JSONB array'
);

select is(
  (select jsonb_typeof(public.search_catalog('Test API Certification', null, 5))),
  'array',
  'public.search_catalog alias returns a JSONB array'
);

select is(
  (select count(*)::integer from jsonb_array_elements(api.search_catalog(null, 'certification', 10))),
  (select count(*)::integer from public.learning_targets where target_type = 'certification'),
  'api.search_catalog filters correctly by category'
);

-- 4. RESOLVE SCOPE TESTS (Assertions 11-12)
select is(
  (select api.resolve_scope(jsonb_build_object(
    'context_id', 'ctx-test-01',
    'root_type', 'target',
    'root_id', 'cc222222-0000-4000-8000-000000000001',
    'target_version_id', 'cc333333-0000-4000-8000-000000000001'
  ))->>'context_id'),
  'ctx-test-01',
  'api.resolve_scope returns correct context_id'
);

select is(
  (select jsonb_array_length(public.resolve_scope(jsonb_build_object(
    'context_id', 'ctx-test-02',
    'root_type', 'target',
    'root_id', 'cc222222-0000-4000-8000-000000000001',
    'target_version_id', 'cc333333-0000-4000-8000-000000000001'
  ))->'curriculum_node_ids')),
  2,
  'public.resolve_scope returns correct curriculum nodes count'
);

-- 5. LEARNER SUMMARY TESTS WITH AUTH (Assertions 13-15)
-- Unauthenticated call must raise 42501
select throws_ok(
  $$ select api.get_learner_summary() $$,
  '42501',
  null,
  'api.get_learner_summary requires authentication'
);

-- Set authenticated session as test user
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select (api.get_learner_summary())->>'user_id'),
  'cc111111-0000-4000-8000-000000000001',
  'api.get_learner_summary returns summary for authenticated user'
);

select is(
  (select (public.get_learner_summary())->>'due_reviews_count')::integer,
  1,
  'public.get_learner_summary correctly counts overdue review items'
);

-- 6. ANONYMOUS LEAST PRIVILEGE TESTS (Assertions 16-20)
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

select lives_ok(
  $$ select api.search_catalog('Test', null, 5) $$,
  'anon can execute api.search_catalog'
);

select lives_ok(
  $$ select public.search_catalog('Test', null, 5) $$,
  'anon can execute public.search_catalog'
);

select lives_ok(
  $$ select api.resolve_scope(jsonb_build_object('root_type', 'target', 'root_id', 'test-cert-api')) $$,
  'anon can execute api.resolve_scope'
);

select throws_ok(
  $$ select api.get_learner_summary() $$,
  '42501',
  null,
  'anon is blocked from executing api.get_learner_summary'
);

select lives_ok(
  $$ select 1 from public.learning_targets limit 1 $$,
  'anon role can read learning_targets'
);

rollback;

