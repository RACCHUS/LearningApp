-- ============================================================================
-- Test Suite: content_hardening_test.sql
-- Description: pgTAP tests for Content Hardening Migration (20261005000000):
--   1. Assessment Stimuli Privacy (User stimuli isolated unless in public lesson).
--   2. Assessment Items Privacy (Standalone user items isolated).
--   3. Concept Junction Read Isolation.
--   4. review_ready Frozen Content State (Curriculum nodes locked).
--   5. Removed Concept Mappings (Nullable to_concept_id).
--   6. clean_draft_target_version RPC (Idempotency and draft-only guard).
--   7. Ambiguity-Safe resolve_canonical_concept RPC.
-- ============================================================================

begin;
create extension if not exists pgtap;

select plan(27);

-- ----------------------------------------------------------------------------
-- Setup Test Fixtures
-- ----------------------------------------------------------------------------
create user test_user_alpha with password 'secret1';
create user test_user_beta with password 'secret2';

do $$
declare
  v_u1 uuid := '11111111-1111-1111-1111-111111111111';
  v_u2 uuid := '22222222-2222-2222-2222-222222222222';
  v_field_cs uuid := 'aaaaaaaa-1111-1111-1111-111111111111';
  v_field_med uuid := 'bbbbbbbb-2222-2222-2222-222222222222';
  v_target_id uuid := 'cccccccc-3333-3333-3333-333333333333';
  v_v_draft uuid := 'dddddddd-4444-4444-4444-444444444444';
  v_v_review uuid := 'eeeeeeee-5555-5555-5555-555555555555';
  v_v_pub uuid := 'ffffffff-6666-6666-6666-666666666666';
  v_c1 uuid := '00000001-0000-0000-0000-000000000001';
  v_c2 uuid := '00000002-0000-0000-0000-000000000002';
  v_stim_sys uuid := '55550001-0000-0000-0000-000000000001';
  v_stim_priv uuid := '55550002-0000-0000-0000-000000000002';
  v_item_priv uuid := '66660001-0000-0000-0000-000000000001';
  v_node_id uuid := '77770001-0000-0000-0000-000000000001';
  v_lesson_id uuid := '88880001-0000-0000-0000-000000000001';
  v_legacy_lesson_id uuid := '88880002-0000-0000-0000-000000000002';
begin
  -- Auth users
  insert into auth.users (id, email)
  values
    (v_u1, 'alpha@example.com'),
    (v_u2, 'beta@example.com')
  on conflict (id) do nothing;

  -- Fields
  insert into public.fields (id, slug, name)
  values
    (v_field_cs, 'computer-science-test', 'Computer Science Test'),
    (v_field_med, 'medicine-test', 'Medicine Test')
  on conflict (id) do nothing;

  -- Canonical Concepts for ambiguity testing
  -- Two distinct concepts with the SAME generic name "State", but in different fields
  insert into public.knowledge_concepts (id, field_id, slug, name, short_definition, status)
  values
    (v_c1, v_field_cs, 'cs-automata-state', 'State', 'FSM node in automata theory', 'active'),
    (v_c2, v_field_med, 'med-state-of-health', 'State', 'Clinical physical condition of patient', 'active')
  on conflict (id) do nothing;

  -- Learning target owned by user Alpha
  insert into public.learning_targets (id, target_type, field_id, title, slug, created_by, is_official)
  values (v_target_id, 'certification', v_field_cs, 'Hardening Test Target', 'target-hardening-test', v_u1, false)
  on conflict (id) do nothing;

  -- Target Versions (draft, review_ready, published)
  insert into public.target_versions (id, target_id, version_code, status)
  values
    (v_v_draft, v_target_id, 'v-draft', 'draft'),
    (v_v_review, v_target_id, 'v-review', 'review_ready'),
    (v_v_pub, v_target_id, 'v-pub', 'published')
  on conflict (id) do nothing;

  -- Node in draft version
  insert into public.curriculum_nodes (id, target_version_id, node_type, title, code)
  values (v_node_id, v_v_draft, 'domain', 'Test Domain', 'D1')
  on conflict (id) do nothing;

  -- Official lesson created by draft version and bound to draft node
  insert into public.lessons (id, title, visibility, user_id, origin_target_version_id)
  values (v_lesson_id, 'Official Lesson 1', 'public', null, v_v_draft)
  on conflict (id) do nothing;

  insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
  values (v_node_id, v_lesson_id, 1)
  on conflict do nothing;

  -- Legacy lesson with NULL origin_target_version_id bound to draft node
  insert into public.lessons (id, title, visibility, user_id, origin_target_version_id)
  values (v_legacy_lesson_id, 'Legacy System Lesson', 'public', null, null)
  on conflict (id) do nothing;

  insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
  values (v_node_id, v_legacy_lesson_id, 2)
  on conflict do nothing;

  -- Stimuli
  insert into public.assessment_stimuli (id, stimulus_type, title, body, created_by)
  values
    (v_stim_sys, 'scenario', 'Official System Stimulus', 'System body', null),
    (v_stim_priv, 'scenario', 'Alpha Private Stimulus', 'Private alpha details', v_u1)
  on conflict (id) do nothing;

  -- Private standalone assessment item owned by Alpha
  insert into public.assessment_items (id, lesson_id, stimulus_id, interaction_type, prompt, user_id)
  values (v_item_priv, null, null, 'single_choice', 'Alpha Private Question?', v_u1)
  on conflict (id) do nothing;

  -- Concept link to private item
  insert into public.assessment_item_concepts (assessment_item_id, concept_id)
  values (v_item_priv, v_c1)
  on conflict do nothing;
end $$;

-- ----------------------------------------------------------------------------
-- 1. Assessment Stimuli Privacy Tests
-- ----------------------------------------------------------------------------
-- Official stimulus readable by anon
set role anon;
select set_config('request.jwt.claims', '{"role": "anon"}', true);
select isnt_empty(
  'select 1 from public.assessment_stimuli where id = ''55550001-0000-0000-0000-000000000001''',
  'Anon can view official stimulus (created_by is null)'
);

-- Alpha private stimulus CANNOT be read by anon
select is_empty(
  'select 1 from public.assessment_stimuli where id = ''55550002-0000-0000-0000-000000000002''',
  'Anon CANNOT view private user stimulus'
);

-- Beta CANNOT read Alpha's private stimulus
set role authenticated;
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}', true);
select is_empty(
  'select 1 from public.assessment_stimuli where id = ''55550002-0000-0000-0000-000000000002''',
  'User Beta CANNOT view user Alpha private stimulus'
);

-- Alpha CAN read own private stimulus
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
select isnt_empty(
  'select 1 from public.assessment_stimuli where id = ''55550002-0000-0000-0000-000000000002''',
  'User Alpha CAN view their own private stimulus'
);

-- ----------------------------------------------------------------------------
-- 2. Assessment Items Privacy Tests
-- ----------------------------------------------------------------------------
-- Beta CANNOT read Alpha's standalone private assessment item
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}', true);
select is_empty(
  'select 1 from public.assessment_items where id = ''66660001-0000-0000-0000-000000000001''',
  'User Beta CANNOT view user Alpha standalone assessment item'
);

-- Alpha CAN read own standalone private item
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
select isnt_empty(
  'select 1 from public.assessment_items where id = ''66660001-0000-0000-0000-000000000001''',
  'User Alpha CAN view their own private assessment item'
);

-- ----------------------------------------------------------------------------
-- 3. Assessment Item Concept Junction Read Isolation
-- ----------------------------------------------------------------------------
-- Beta CANNOT read concept links for Alpha's private item
select set_config('request.jwt.claims', '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}', true);
select is_empty(
  'select 1 from public.assessment_item_concepts where assessment_item_id = ''66660001-0000-0000-0000-000000000001''',
  'Concept junction for private assessment item is hidden from Beta'
);

-- Alpha CAN read concept links for own item
select set_config('request.jwt.claims', '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}', true);
select isnt_empty(
  'select 1 from public.assessment_item_concepts where assessment_item_id = ''66660001-0000-0000-0000-000000000001''',
  'Concept junction for private assessment item is visible to Alpha'
);

-- ----------------------------------------------------------------------------
-- 4. Frozen review_ready Staging State Tests
-- ----------------------------------------------------------------------------
-- Alpha CAN insert a curriculum node in draft version
select lives_ok(
  $$insert into public.curriculum_nodes (target_version_id, node_type, title, code) values ('dddddddd-4444-4444-4444-444444444444', 'objective', 'Draft Obj', 'O1')$$,
  'Owner CAN insert curriculum node when version is draft'
);

-- Alpha CANNOT insert a curriculum node in review_ready version (frozen content)
select throws_ok(
  $$insert into public.curriculum_nodes (target_version_id, node_type, title, code) values ('eeeeeeee-5555-5555-5555-555555555555', 'objective', 'Frozen Obj', 'O2')$$,
  '42501',
  null,
  'Owner CANNOT insert curriculum node when version is review_ready (content frozen for QA)'
);

-- Alpha CAN transition version from draft to review_ready
select lives_ok(
  $$update public.target_versions set status = 'review_ready' where id = 'dddddddd-4444-4444-4444-444444444444'$$,
  'Owner can advance draft version to review_ready'
);

-- Alpha CAN transition version from review_ready back to draft to edit
select lives_ok(
  $$update public.target_versions set status = 'draft' where id = 'dddddddd-4444-4444-4444-444444444444'$$,
  'Owner can move review_ready version back to draft for modifications'
);

-- ----------------------------------------------------------------------------
-- 5. Nullable to_concept_id for Removed Concept Mappings
-- ----------------------------------------------------------------------------
reset role;

-- Removed mapping with null to_concept_id succeeds
select lives_ok(
  $$insert into public.target_version_concept_mappings (
      from_target_version_id, from_concept_id, to_target_version_id, to_concept_id, mapping_type, transfer_weight
    ) values (
      'dddddddd-4444-4444-4444-444444444444',
      '00000001-0000-0000-0000-000000000001',
      'eeeeeeee-5555-5555-5555-555555555555',
      null,
      'removed',
      0.0
    )$$,
  'Removed concept mapping allows NULL to_concept_id'
);

-- Non-removed mapping with null to_concept_id fails constraint
select throws_ok(
  $$insert into public.target_version_concept_mappings (
      from_target_version_id, from_concept_id, to_target_version_id, to_concept_id, mapping_type, transfer_weight
    ) values (
      'dddddddd-4444-4444-4444-444444444444',
      '00000002-0000-0000-0000-000000000002',
      'eeeeeeee-5555-5555-5555-555555555555',
      null,
      'unchanged',
      1.0
    )$$,
  '23514',
  null,
  'Non-removed concept mapping rejects NULL to_concept_id'
);

-- ----------------------------------------------------------------------------
-- 6. clean_draft_target_version RPC Tests
-- ----------------------------------------------------------------------------
-- Attempting to clean a published version throws exception
select throws_ok(
  $$select public.clean_draft_target_version('ffffffff-6666-6666-6666-666666666666')$$,
  'Cannot clean TargetVersion with status "published". Only draft versions may be reset.',
  'clean_draft_target_version blocks cleaning published version'
);

-- Attempting to clean review_ready throws exception
select throws_ok(
  $$select public.clean_draft_target_version('eeeeeeee-5555-5555-5555-555555555555')$$,
  'Cannot clean TargetVersion with status "review_ready". Only draft versions may be reset.',
  'clean_draft_target_version blocks cleaning review_ready version'
);

-- Cleaning draft version succeeds
select lives_ok(
  $$select public.clean_draft_target_version('dddddddd-4444-4444-4444-444444444444')$$,
  'clean_draft_target_version executes cleanly on draft version'
);

-- Confirm nodes and bound official lessons of draft version were cleaned
select is_empty(
  'select 1 from public.curriculum_nodes where target_version_id = ''dddddddd-4444-4444-4444-444444444444''',
  'Curriculum nodes for draft version were removed'
);

select is_empty(
  'select 1 from public.lessons where id = ''88880001-0000-0000-0000-000000000001''',
  'Official lesson attached to draft node was removed'
);

select isnt_empty(
  'select 1 from public.lessons where id = ''88880002-0000-0000-0000-000000000002''',
  'Legacy lesson with NULL origin_target_version_id is preserved by clean_draft_target_version'
);

-- Re-running clean is idempotent
select lives_ok(
  $$select public.clean_draft_target_version('dddddddd-4444-4444-4444-444444444444')$$,
  'Second clean_draft_target_version call is idempotent'
);

-- ----------------------------------------------------------------------------
-- 7. Ambiguity-Safe resolve_canonical_concept Tests
-- ----------------------------------------------------------------------------
-- Exact slug matches unambiguously
select is(
  (select match_type from public.resolve_canonical_concept('cs-automata-state')),
  'exact_slug',
  'Exact slug matches with exact_slug'
);

select is(
  (select is_ambiguous from public.resolve_canonical_concept('cs-automata-state')),
  false,
  'Exact slug match is not ambiguous'
);

-- Generic name "State" without field has multiple candidates -> returns ambiguous!
select is(
  (select is_ambiguous from public.resolve_canonical_concept('state', 'State', null)),
  true,
  'Generic concept name across multiple fields returns is_ambiguous = true'
);

select is(
  (select match_type from public.resolve_canonical_concept('state', 'State', null)),
  'ambiguous_name',
  'Ambiguous generic name reports ambiguous_name match_type'
);

-- Generic name "State" WITH field_id resolves unambiguously to that field's concept!
select is(
  (select id from public.resolve_canonical_concept('state', 'State', 'aaaaaaaa-1111-1111-1111-111111111111'::uuid)),
  '00000001-0000-0000-0000-000000000001'::uuid,
  'Generic name with field_id disambiguates to computer science concept'
);

select is(
  (select match_type from public.resolve_canonical_concept('state', 'State', 'aaaaaaaa-1111-1111-1111-111111111111'::uuid)),
  'field_exact_name',
  'Field-scoped match reports field_exact_name'
);

select * from finish();
rollback;
