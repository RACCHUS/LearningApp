-- ============================================================================
-- Test: import_ownership_and_staging_test.sql
-- Description: pgTAP tests for Phase C.5 Final Hardening:
--   1. clean_draft_target_version Authorization & Isolation
--   2. Artifact Ownership Protection (Defense-in-depth, Forged Artifact Defense)
--   3. Service-role Protection on content_import_artifacts Table
--   4. Pre-Publication Visibility (Draft & Review Content & Provenance Hidden)
--   5. Beta Reviewer Authorization (review_ready Preview Across Teaching Junctions)
--   6. TargetVersion Lifecycle State Machine Trigger (Status-Only Transitions & Published Immutability)
--   7. Fully Transactional Ingestion RPC (Canonical Concepts & Comprehensive Provenance)
-- ============================================================================

begin;

create extension if not exists pgtap;

select plan(44);

-- ----------------------------------------------------------------------------
-- Setup Test Fixtures
-- ----------------------------------------------------------------------------
create or replace function pg_temp.setup_test_fixtures()
returns void language plpgsql as $$
declare
  v_user_owner uuid := '11111111-aaaa-bbbb-cccc-111111111111';
  v_user_beta uuid := '22222222-aaaa-bbbb-cccc-222222222222';
  v_user_other uuid := '33333333-aaaa-bbbb-cccc-333333333333';
  v_target_a uuid := 'aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa';
  v_target_b uuid := 'bbbbbbbb-1111-1111-1111-bbbbbbbbbbbb';
  v_version_a_draft uuid := 'aaaaaaaa-2222-2222-2222-aaaaaaaaaaaa';
  v_version_b_draft uuid := 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb';
  v_concept uuid := 'cccccccc-1111-1111-1111-cccccccccccc';
  v_lesson_a uuid := 'aaaaaaaa-3333-3333-3333-aaaaaaaaaaaa';
  v_lesson_b uuid := 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb';
  v_fc_a uuid := 'aaaaaaaa-4444-4444-4444-aaaaaaaaaaaa';
  v_fc_b uuid := 'bbbbbbbb-4444-4444-4444-bbbbbbbbbbbb';
  v_stim_a uuid := 'aaaaaaaa-5555-5555-5555-aaaaaaaaaaaa';
  v_rel_a uuid := 'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa';
  v_node_a uuid := 'aaaaaaaa-7777-7777-7777-aaaaaaaaaaaa';
  v_node_b uuid := 'bbbbbbbb-7777-7777-7777-bbbbbbbbbbbb';
begin
  -- Users
  insert into auth.users (id, email)
  values
    (v_user_owner, 'owner@example.com'),
    (v_user_beta, 'beta@example.com'),
    (v_user_other, 'other@example.com')
  on conflict (id) do nothing;

  -- Targets
  insert into public.learning_targets (id, slug, title, target_type, created_by, status, is_public)
  values
    (v_target_a, 'target-a', 'Target A', 'certification', v_user_owner, 'published', true),
    (v_target_b, 'target-b', 'Target B', 'certification', v_user_owner, 'published', true)
  on conflict (id) do nothing;

  -- Versions (both start as draft)
  insert into public.target_versions (id, target_id, version_code, status)
  values
    (v_version_a_draft, v_target_a, 'v1-a', 'draft'),
    (v_version_b_draft, v_target_b, 'v1-b', 'draft')
  on conflict (id) do nothing;

  -- Shared Canonical Concept
  insert into public.knowledge_concepts (id, slug, name, description)
  values (v_concept, 'shared-data-structures', 'Shared Data Structures', 'Concept shared across targets')
  on conflict (id) do nothing;

  -- Target A Artifacts
  insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order)
  values (v_node_a, v_version_a_draft, 'domain', 'D1-A', 'Domain A', 1)
  on conflict (id) do nothing;

  insert into public.lessons (id, title, description, visibility, origin_target_version_id)
  values (v_lesson_a, 'Lesson A', 'Desc A', 'public', v_version_a_draft)
  on conflict (id) do nothing;

  insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
  values (v_node_a, v_lesson_a, 1)
  on conflict do nothing;

  insert into public.flashcards (id, front, back, origin_target_version_id)
  values (v_fc_a, 'Front A', 'Back A', v_version_a_draft)
  on conflict (id) do nothing;

  insert into public.flashcard_concepts (flashcard_id, concept_id)
  values (v_fc_a, v_concept)
  on conflict do nothing;

  insert into public.assessment_stimuli (id, title, body, stimulus_type, origin_target_version_id)
  values (v_stim_a, 'Stimulus A', 'Body A', 'scenario', v_version_a_draft)
  on conflict (id) do nothing;

  insert into public.content_source_releases (id, publisher, title, version)
  values (v_rel_a, 'Publisher A', 'Blueprint A', '1.0')
  on conflict (id) do nothing;

  insert into public.content_source_mappings (source_release_id, entity_type, entity_id, relationship)
  values (v_rel_a, 'lesson', v_lesson_a, 'derived_from')
  on conflict do nothing;

  -- Register Target A artifacts
  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
  values
    (v_version_a_draft, 'curriculum_node', v_node_a),
    (v_version_a_draft, 'lesson', v_lesson_a),
    (v_version_a_draft, 'flashcard', v_fc_a),
    (v_version_a_draft, 'assessment_stimulus', v_stim_a)
  on conflict do nothing;

  -- Target B Artifacts
  insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order)
  values (v_node_b, v_version_b_draft, 'domain', 'D1-B', 'Domain B', 1)
  on conflict (id) do nothing;

  insert into public.lessons (id, title, description, visibility, origin_target_version_id)
  values (v_lesson_b, 'Lesson B', 'Desc B', 'public', v_version_b_draft)
  on conflict (id) do nothing;

  insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
  values (v_node_b, v_lesson_b, 1)
  on conflict do nothing;

  insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
  values (v_node_b, v_concept)
  on conflict do nothing;

  insert into public.flashcards (id, front, back, origin_target_version_id)
  values (v_fc_b, 'Front B', 'Back B', v_version_b_draft)
  on conflict (id) do nothing;

  insert into public.flashcard_concepts (flashcard_id, concept_id)
  values (v_fc_b, v_concept)
  on conflict do nothing;

  insert into public.content_source_mappings (source_release_id, entity_type, entity_id, relationship)
  values (v_rel_a, 'lesson', v_lesson_b, 'derived_from')
  on conflict do nothing;

  -- Register Target B artifacts
  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
  values
    (v_version_b_draft, 'curriculum_node', v_node_b),
    (v_version_b_draft, 'lesson', v_lesson_b),
    (v_version_b_draft, 'flashcard', v_fc_b)
  on conflict do nothing;

  -- FORGED / MALICIOUS ARTIFACT SIMULATION:
  -- Target A's version erroneously or maliciously points to Target B's lesson!
  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
  values (v_version_a_draft, 'lesson', v_lesson_b)
  on conflict do nothing;

  -- Assign Beta Reviewer for Target A
  insert into public.curriculum_reviewers (target_id, user_id, role)
  values (v_target_a, v_user_beta, 'reviewer')
  on conflict do nothing;

end;
$$;

select pg_temp.setup_test_fixtures();

-- ----------------------------------------------------------------------------
-- 1. clean_draft_target_version Authorization & content_import_artifacts Protection
-- ----------------------------------------------------------------------------

-- Other user (not owner, not service_role) CANNOT clean Target A draft
set local role authenticated;
set local "request.jwt.claim.sub" to '33333333-aaaa-bbbb-cccc-333333333333';
set local "request.jwt.claim.role" to 'authenticated';

select throws_ok(
  $$select public.clean_draft_target_version('aaaaaaaa-2222-2222-2222-aaaaaaaaaaaa'::uuid)$$,
  'Unauthorized: only service_role or the target owner can clean a draft target version',
  'Non-owner authenticated user CANNOT execute clean_draft_target_version'
);

-- Authenticated user CANNOT insert into content_import_artifacts directly (table locked to service_role)
select throws_ok(
  $$insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
    values ('aaaaaaaa-2222-2222-2222-aaaaaaaaaaaa', 'lesson', '33333333-3333-3333-3333-333333333333')$$,
  null,
  'Authenticated user CANNOT directly insert into content_import_artifacts (permission denied)'
);

-- Target owner CAN clean Target A draft
set local "request.jwt.claim.sub" to '11111111-aaaa-bbbb-cccc-111111111111';

select lives_ok(
  $$select public.clean_draft_target_version('aaaaaaaa-2222-2222-2222-aaaaaaaaaaaa'::uuid)$$,
  'Target owner CAN execute clean_draft_target_version'
);

-- ----------------------------------------------------------------------------
-- 2. Artifact Ownership Defense-in-Depth (Target B Remains Fully Intact)
-- ----------------------------------------------------------------------------
reset role;

-- Target A items were deleted
select is_empty(
  $$select 1 from public.lessons where id = 'aaaaaaaa-3333-3333-3333-aaaaaaaaaaaa'$$,
  'Target A lesson was deleted by cleanup'
);

select is_empty(
  $$select 1 from public.flashcards where id = 'aaaaaaaa-4444-4444-4444-aaaaaaaaaaaa'$$,
  'Target A flashcard was deleted by cleanup'
);

select is_empty(
  $$select 1 from public.assessment_stimuli where id = 'aaaaaaaa-5555-5555-5555-aaaaaaaaaaaa'$$,
  'Target A stimulus was deleted by cleanup (no orphan stimulus)'
);

-- Target B items REMAIN INTACT despite sharing concept and despite forged artifact entry!
select isnt_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Target B lesson was NOT touched by Target A cleanup'
);

select isnt_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb' and origin_target_version_id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Target B lesson SURVIVES cleanup even with a forged artifact pointing to it'
);

select isnt_empty(
  $$select 1 from public.flashcards where id = 'bbbbbbbb-4444-4444-4444-bbbbbbbbbbbb'$$,
  'Target B flashcard was NOT touched by Target A cleanup'
);

select isnt_empty(
  $$select 1 from public.flashcard_concepts where flashcard_id = 'bbbbbbbb-4444-4444-4444-bbbbbbbbbbbb'$$,
  'Target B flashcard concept link was NOT touched by Target A cleanup'
);

-- ----------------------------------------------------------------------------
-- 3. Pre-Publication Visibility (Draft Content & Provenance Hidden from Anon)
-- ----------------------------------------------------------------------------

-- Anonymous user cannot read Target B draft lesson or flashcard
set local role anon;
set local "request.jwt.claim.sub" to '';
set local "request.jwt.claim.role" to 'anon';

select is_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Anonymous user CANNOT read draft lesson even if visibility is public'
);

select is_empty(
  $$select 1 from public.flashcards where id = 'bbbbbbbb-4444-4444-4444-bbbbbbbbbbbb'$$,
  'Anonymous user CANNOT read draft flashcard'
);

select is_empty(
  $$select 1 from public.content_source_mappings where entity_type = 'lesson' and entity_id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Anonymous user CANNOT read content source mapping for draft lesson (no provenance leakage)'
);

-- ----------------------------------------------------------------------------
-- 4. TargetVersion Lifecycle State Machine Trigger
-- ----------------------------------------------------------------------------
reset role;

-- 1. Direct draft -> published is BLOCKED (must go through review_ready)
select throws_ok(
  $$update public.target_versions set status = 'published' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Invalid status transition: draft must be staged to "review_ready" before publishing.',
  'Direct transition from draft to published is rejected by lifecycle trigger'
);

-- 2. Transition draft -> review_ready succeeds
select lives_ok(
  $$update public.target_versions set status = 'review_ready' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Transition from draft to review_ready succeeds'
);

-- 3. While in review_ready, metadata is frozen
select throws_ok(
  $$update public.target_versions set title = 'Modified Title' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'TargetVersion is frozen in "review_ready" status. Revert status to "draft" before making edits.',
  'Metadata updates in review_ready status are blocked by lifecycle trigger'
);

-- 4. While in review_ready, deletion is blocked
select throws_ok(
  $$delete from public.target_versions where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Cannot delete target_version with status "review_ready". Only draft versions may be deleted.',
  'Deleting review_ready target version is blocked by lifecycle trigger'
);

-- ----------------------------------------------------------------------------
-- 5. Beta Reviewer Authorization (review_ready Preview Across Teaching Junctions)
-- ----------------------------------------------------------------------------

-- Regular user (other user) CANNOT read Target B review_ready version, lessons, or teaching junctions
set local role authenticated;
set local "request.jwt.claim.sub" to '33333333-aaaa-bbbb-cccc-333333333333';
set local "request.jwt.claim.role" to 'authenticated';

select is_empty(
  $$select 1 from public.target_versions where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Unassigned user CANNOT read review_ready target version'
);

select is_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Unassigned user CANNOT read review_ready lesson'
);

select is_empty(
  $$select 1 from public.curriculum_node_lessons where curriculum_node_id = 'bbbbbbbb-7777-7777-7777-bbbbbbbbbbbb'$$,
  'Unassigned user CANNOT read curriculum_node_lessons junction for review_ready target'
);

-- Assign beta user to Target B
reset role;
insert into public.curriculum_reviewers (target_id, user_id, role)
values ('bbbbbbbb-1111-1111-1111-bbbbbbbbbbbb', '22222222-aaaa-bbbb-cccc-222222222222', 'reviewer');

-- Beta user CAN read Target B review_ready version, lessons, AND teaching junctions
set local role authenticated;
set local "request.jwt.claim.sub" to '22222222-aaaa-bbbb-cccc-222222222222';
set local "request.jwt.claim.role" to 'authenticated';

select isnt_empty(
  $$select 1 from public.target_versions where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Designated beta reviewer CAN preview review_ready target version'
);

select isnt_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Designated beta reviewer CAN preview review_ready lesson'
);

select isnt_empty(
  $$select 1 from public.curriculum_node_lessons where curriculum_node_id = 'bbbbbbbb-7777-7777-7777-bbbbbbbbbbbb'$$,
  'Designated beta reviewer CAN read curriculum_node_lessons junction for review_ready target'
);

select isnt_empty(
  $$select 1 from public.curriculum_node_concepts where curriculum_node_id = 'bbbbbbbb-7777-7777-7777-bbbbbbbbbbbb'$$,
  'Designated beta reviewer CAN read curriculum_node_concepts junction for review_ready target'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings where entity_type = 'lesson' and entity_id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Designated beta reviewer CAN read content source mapping for review_ready lesson'
);

-- Anonymous user still CANNOT read provenance mapping of review_ready lesson
set local role anon;
set local "request.jwt.claim.sub" to '';
set local "request.jwt.claim.role" to 'anon';

select is_empty(
  $$select 1 from public.content_source_mappings where entity_type = 'lesson' and entity_id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Anonymous user CANNOT read content source mapping for review_ready lesson'
);

-- ----------------------------------------------------------------------------
-- 6. Tightened review_ready -> published and Published Immutability
-- ----------------------------------------------------------------------------
reset role;

-- Modifying attributes while setting status to published is BLOCKED
select throws_ok(
  $$update public.target_versions set status = 'published', title = 'Tampered' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Cannot modify TargetVersion attributes during publication from "review_ready". Publication must be a status-only transition.',
  'Modifying TargetVersion attributes while publishing from review_ready is blocked by lifecycle trigger'
);

-- Status-only transition to published SUCCEEDS
select lives_ok(
  $$update public.target_versions set status = 'published' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Status-only transition from review_ready to published succeeds'
);

-- Now anonymous user CAN read published Target B lesson, flashcard, and source mapping
set local role anon;
set local "request.jwt.claim.sub" to '';
set local "request.jwt.claim.role" to 'anon';

select isnt_empty(
  $$select 1 from public.lessons where id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Anonymous user CAN read lesson once target version is published'
);

select isnt_empty(
  $$select 1 from public.flashcards where id = 'bbbbbbbb-4444-4444-4444-bbbbbbbbbbbb'$$,
  'Anonymous user CAN read flashcard once target version is published'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings where entity_type = 'lesson' and entity_id = 'bbbbbbbb-3333-3333-3333-bbbbbbbbbbbb'$$,
  'Anonymous user CAN read content source mapping once target version is published'
);

-- Published immutability is enforced against service_role updates
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select throws_ok(
  $$update public.target_versions set title = 'Tampered by Service Role' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Published versions are immutable and cannot be updated. Only transition to "retired" status is permitted.',
  'Modifying TargetVersion attributes on published version is blocked even for service_role'
);

select throws_ok(
  $$update public.target_versions set status = 'retired', title = 'Tampered' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Cannot modify TargetVersion attributes when retiring a published version. It must be a status-only transition.',
  'Modifying attributes while retiring published version is blocked even for service_role'
);

select lives_ok(
  $$update public.target_versions set status = 'retired' where id = 'bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb'$$,
  'Status-only retirement of published version succeeds under service_role'
);

-- ----------------------------------------------------------------------------
-- 7. Fully Transactional Ingestion RPC (ingest_curriculum_manifest)
-- ----------------------------------------------------------------------------
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select lives_ok(
  $$select public.ingest_curriculum_manifest('{
    "field": {"slug": "security-tech", "name": "Security & Tech"},
    "target": {"slug": "rpc-test-target", "title": "RPC Test Target", "target_type": "certification"},
    "target_version": {"version_code": "V-RPC-1", "title": "RPC Version 1"},
    "sources": [
      {"source_id": "src-comptia", "publisher": "CompTIA", "title": "Security+", "version": "SY0-701"}
    ],
    "concepts": [
      {
        "slug": "rpc-concept-zero-trust",
        "name": "Zero Trust Architecture",
        "description": "Zero Trust security model",
        "source_id": "src-comptia",
        "citation_location": "Domain 2.1"
      }
    ],
    "stimuli": [
      {
        "stimulus_key": "rpc-stim-1",
        "title": "Exhibit 1",
        "body": "Test body",
        "stimulus_type": "scenario",
        "source_id": "src-comptia",
        "citation_location": "Exhibit Sec"
      }
    ],
    "flashcards": [
      {
        "front": "RPC Front",
        "back": "RPC Back",
        "explanation": "RPC Exp",
        "source_id": "src-comptia",
        "citation_location": "Flashcard Sec"
      }
    ],
    "domains": [
      {
        "code": "D-RPC-1",
        "title": "Domain 1",
        "sort_order": 1,
        "objectives": [
          {
            "code": "O-RPC-1.1",
            "title": "Objective 1.1",
            "sort_order": 1,
            "source_id": "src-comptia",
            "citation_location": "Objective 1.1",
            "lessons": [
              {
                "title": "RPC Lesson",
                "slug": "rpc-lesson-1",
                "source_id": "src-comptia",
                "citation_location": "Lesson 1.1",
                "concepts": ["rpc-concept-zero-trust"],
                "blocks": [
                  {
                    "block_type": "markdown",
                    "content": {"body": "Hello"},
                    "source_id": "src-comptia",
                    "citation_location": "Block 1.1"
                  }
                ],
                "assessment_items": [
                  {
                    "prompt": "Test Prompt?",
                    "interaction_type": "single_choice",
                    "response_spec": {"options": ["A", "B"]},
                    "scoring_spec": {"correct_index": 0},
                    "source_id": "src-comptia",
                    "citation_location": "Item 1.1",
                    "concepts": ["rpc-concept-zero-trust"]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }'::jsonb)$$,
  'ingest_curriculum_manifest executes cleanly and atomically via service_role'
);

-- Verify canonical concept was resolved/created transactionally
select isnt_empty(
  $$select 1 from public.knowledge_concepts where slug = 'rpc-concept-zero-trust'$$,
  'ingest_curriculum_manifest created canonical concept in knowledge_concepts'
);

select isnt_empty(
  $$select 1 from public.concept_fields cf
    join public.knowledge_concepts kc on kc.id = cf.concept_id
    where kc.slug = 'rpc-concept-zero-trust'$$,
  'ingest_curriculum_manifest mapped concept to field in concept_fields'
);

-- Verify comprehensive provenance mappings for lower-level entities
select isnt_empty(
  $$select 1 from public.content_source_mappings m
    join public.knowledge_concepts kc on kc.id = m.entity_id
    where m.entity_type = 'knowledge_concept' and kc.slug = 'rpc-concept-zero-trust'$$,
  'Provenance created for knowledge_concept in content_source_mappings'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings m
    join public.assessment_items ai on ai.id = m.entity_id
    where m.entity_type = 'assessment_item' and ai.prompt = 'Test Prompt?'$$,
  'Provenance created for assessment_item in content_source_mappings'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings m
    join public.lesson_blocks lb on lb.id = m.entity_id
    where m.entity_type = 'lesson_block' and lb.citation_location = 'Block 1.1'$$,
  'Provenance created for lesson_block in content_source_mappings'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings m
    join public.flashcards f on f.id = m.entity_id
    where m.entity_type = 'flashcard' and f.front = 'RPC Front'$$,
  'Provenance created for flashcard in content_source_mappings'
);

select isnt_empty(
  $$select 1 from public.content_source_mappings m
    join public.assessment_stimuli ast on ast.id = m.entity_id
    where m.entity_type = 'assessment_stimulus' and ast.stimulus_key = 'rpc-stim-1'$$,
  'Provenance created for assessment_stimulus in content_source_mappings'
);

-- Re-running ingestion replaces the draft idempotently without duplicates
select lives_ok(
  $$select public.ingest_curriculum_manifest('{
    "field": {"slug": "security-tech", "name": "Security & Tech"},
    "target": {"slug": "rpc-test-target", "title": "RPC Test Target", "target_type": "certification"},
    "target_version": {"version_code": "V-RPC-1", "title": "RPC Version 1"},
    "domains": [
      {
        "code": "D-RPC-1",
        "title": "Domain 1",
        "sort_order": 1,
        "objectives": [
          {
            "code": "O-RPC-1.1",
            "title": "Objective 1.1",
            "sort_order": 1,
            "lessons": [
              {
                "title": "RPC Lesson",
                "slug": "rpc-lesson-1"
              }
            ]
          }
        ]
      }
    ]
  }'::jsonb)$$,
  'Re-running ingest_curriculum_manifest on existing draft replaces it idempotently'
);

-- Verify lesson count is exactly 1 (not duplicated!)
select is(
  (select count(*)::int from public.lessons where title = 'RPC Lesson'),
  1,
  'Idempotent replace-the-draft: lesson count is exactly 1 without duplicates'
);

rollback;
