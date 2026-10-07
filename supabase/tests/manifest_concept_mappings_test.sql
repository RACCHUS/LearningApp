-- ============================================================================
-- Test Suite: manifest_concept_mappings_test.sql
-- Description:
--   1. Verify manifest concept_mappings ingestion contract:
--      (from_version_code, from_concept_slug, to_concept_slug, mapping_type, transfer_weight, metadata)
--      resolves to (from_target_version_id, from_concept_id, to_target_version_id, to_concept_id).
--   2. Verify target visibility security hardening on:
--      - get_target_crosswalk_occupations
--      - get_cross_target_shared_concepts
--      - v_target_occupation_mappings (security_invoker = true)
--      - content_source_artifacts RLS (entity-gated)
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

-- Setup test users upfront under postgres session role
insert into auth.users (id, is_anonymous)
values
  ('11111111-2222-4333-8444-555555555555', false),
  ('99999999-9999-4999-8999-999999999999', false),
  ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee', false)
on conflict do nothing;

insert into public.users (id)
values
  ('11111111-2222-4333-8444-555555555555'),
  ('99999999-9999-4999-8999-999999999999'),
  ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Test 1: Verify is_target_visible helper exists
-- ----------------------------------------------------------------------------
select has_function('public', 'is_target_visible', ARRAY['uuid'], 'is_target_visible helper exists');

-- ----------------------------------------------------------------------------
-- Test 2: Ingest Base Version 1.0.0 via ingest_curriculum_manifest
-- ----------------------------------------------------------------------------
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select lives_ok(
  $$select public.ingest_curriculum_manifest('{
    "field": {"slug": "info-sec", "name": "Information Security"},
    "target": {"slug": "cert-sec-test", "title": "Security Test Cert", "target_type": "certification"},
    "target_version": {"version_code": "1.0.0", "title": "Security Test v1.0.0"},
    "source_releases": [
      {"publisher": "CompTIA", "title": "Security Blueprint", "version": "v1.0.0", "source_url": "https://example.com/v1"}
    ],
    "concepts": [
      {
        "slug": "sec-test-symmetric",
        "name": "Symmetric Ciphers",
        "short_definition": "Shared key encryption algorithms"
      },
      {
        "slug": "sec-test-legacy-hash",
        "name": "Legacy Hashes",
        "short_definition": "Deprecated MD5 and SHA-1 algorithms"
      }
    ],
    "domains": [
      {
        "code": "D1",
        "title": "Cryptography Domain",
        "weight": 1.0,
        "citation": "Section 1.0",
        "objectives": [
          {
            "code": "1.1",
            "title": "Crypto Primitives",
            "citation": "Section 1.1",
            "concept_slugs": ["sec-test-symmetric", "sec-test-legacy-hash"],
            "lessons": [
              {
                "title": "Crypto Lesson",
                "citation": "Lesson 1",
                "concept_slugs": ["sec-test-symmetric"],
                "blocks": [{"block_type": "markdown", "content": {"text": "Intro"}, "sort_order": 1}]
              }
            ]
          }
        ]
      }
    ]
  }'::jsonb)$$,
  'Ingest v1.0.0 base curriculum manifest cleanly'
);

-- Stage to review_ready then publish v1.0.0 target version so it can be mapped from
update public.target_versions
set status = 'review_ready'
where version_code = '1.0.0'
  and target_id = (select id from public.learning_targets where slug = 'cert-sec-test');

update public.target_versions
set status = 'published'
where version_code = '1.0.0'
  and target_id = (select id from public.learning_targets where slug = 'cert-sec-test');

-- ----------------------------------------------------------------------------
-- Test 3: Ingest Version 2.0.0 with Canonical concept_mappings
-- ----------------------------------------------------------------------------
select lives_ok(
  $$select public.ingest_curriculum_manifest('{
    "field": {"slug": "info-sec", "name": "Information Security"},
    "target": {"slug": "cert-sec-test", "title": "Security Test Cert", "target_type": "certification"},
    "target_version": {"version_code": "2.0.0", "title": "Security Test v2.0.0"},
    "source_releases": [
      {
        "publisher": "CompTIA",
        "title": "Security Blueprint",
        "version": "v2.0.0",
        "source_url": "https://example.com/v2",
        "artifacts": [
          {
            "artifact_name": "blueprint-v2.pdf",
            "source_url": "https://example.com/v2.pdf",
            "sha256": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
          }
        ]
      }
    ],
    "concepts": [
      {
        "slug": "sec-test-crypto-foundations",
        "name": "Cryptographic Foundations",
        "short_definition": "Modern symmetric and asymmetric encryption fundamentals"
      }
    ],
    "concept_mappings": [
      {
        "from_version_code": "1.0.0",
        "from_concept_slug": "sec-test-symmetric",
        "to_concept_slug": "sec-test-crypto-foundations",
        "mapping_type": "renamed",
        "transfer_weight": 0.85,
        "metadata": {"rationale": "Symmetric broadened into modern foundations"}
      },
      {
        "from_version_code": "1.0.0",
        "from_concept_slug": "sec-test-legacy-hash",
        "to_concept_slug": null,
        "mapping_type": "removed",
        "transfer_weight": 0.00,
        "metadata": {"rationale": "Legacy hashes removed from syllabus"}
      }
    ],
    "domains": [
      {
        "code": "D1",
        "title": "Cryptography Domain v2",
        "weight": 1.0,
        "citation": "Section 1.0",
        "objectives": [
          {
            "code": "1.1",
            "title": "Modern Crypto Primitives",
            "citation": "Section 1.1",
            "concept_slugs": ["sec-test-crypto-foundations"],
            "lessons": [
              {
                "title": "Modern Crypto Lesson",
                "citation": "Lesson 1",
                "concept_slugs": ["sec-test-crypto-foundations"],
                "blocks": [{"block_type": "markdown", "content": {"text": "Modern Crypto"}, "sort_order": 1}]
              }
            ]
          }
        ]
      }
    ]
  }'::jsonb)$$,
  'Ingest v2.0.0 curriculum manifest with concept_mappings cleanly'
);

-- ----------------------------------------------------------------------------
-- Test 4-8: Verify Ingested concept_mappings in target_version_concept_mappings
-- ----------------------------------------------------------------------------
select is(
  (
    select count(*)::integer
    from public.target_version_concept_mappings m
    join public.target_versions tv_from on tv_from.id = m.from_target_version_id
    join public.target_versions tv_to on tv_to.id = m.to_target_version_id
    where tv_from.version_code = '1.0.0' and tv_to.version_code = '2.0.0'
  ),
  2,
  'Exactly 2 cross-version concept mappings ingested from manifest'
);

select ok(
  exists (
    select 1
    from public.target_version_concept_mappings m
    join public.knowledge_concepts fc on fc.id = m.from_concept_id
    join public.knowledge_concepts tc on tc.id = m.to_concept_id
    where fc.slug = 'sec-test-symmetric'
      and tc.slug = 'sec-test-crypto-foundations'
      and m.mapping_type = 'renamed'
      and m.transfer_weight = 0.85
      and m.metadata->>'rationale' = 'Symmetric broadened into modern foundations'
  ),
  'Renamed mapping correctly resolved from/to concepts and stored transfer_weight 0.85'
);

select ok(
  exists (
    select 1
    from public.target_version_concept_mappings m
    join public.knowledge_concepts fc on fc.id = m.from_concept_id
    where fc.slug = 'sec-test-legacy-hash'
      and m.to_concept_id is null
      and m.mapping_type = 'removed'
      and m.transfer_weight = 0.00
      and m.metadata->>'rationale' = 'Legacy hashes removed from syllabus'
  ),
  'Removed mapping correctly stored null to_concept_id and 0.00 transfer_weight'
);

-- ----------------------------------------------------------------------------
-- Test 9: Verify evaluate_target_version_migration respects ingested mappings
-- ----------------------------------------------------------------------------
-- Setup a test user concept state in v1.0.0
insert into public.user_concept_state (
  user_id, concept_id, retrieval_band, confidence, evidence_count, weighted_correct, weighted_total
)
select
  '11111111-2222-4333-8444-555555555555',
  id,
  'well_retained',
  'high',
  10,
  9.0,
  10.0
from public.knowledge_concepts
where slug = 'sec-test-symmetric';

-- Stage to review_ready then publish v2.0.0 so evaluation is permitted
update public.target_versions
set status = 'review_ready'
where version_code = '2.0.0'
  and target_id = (select id from public.learning_targets where slug = 'cert-sec-test');

update public.target_versions
set status = 'published'
where version_code = '2.0.0'
  and target_id = (select id from public.learning_targets where slug = 'cert-sec-test');

select is(
  (
    select (public.evaluate_target_version_migration(
      '11111111-2222-4333-8444-555555555555',
      (select id from public.target_versions where version_code = '1.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test')),
      (select id from public.target_versions where version_code = '2.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test'))
    )->>'mapped_concepts_count')::integer
  ),
  2,
  'evaluate_target_version_migration counts both ingested mappings'
);

select is(
  (
    select (public.evaluate_target_version_migration(
      '11111111-2222-4333-8444-555555555555',
      (select id from public.target_versions where version_code = '1.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test')),
      (select id from public.target_versions where version_code = '2.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test'))
    )->>'retained_concepts_count')::integer
  ),
  1,
  'evaluate_target_version_migration correctly identifies 1 retained concept (weight > 0)'
);

select is(
  (
    select (public.evaluate_target_version_migration(
      '11111111-2222-4333-8444-555555555555',
      (select id from public.target_versions where version_code = '1.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test')),
      (select id from public.target_versions where version_code = '2.0.0' and target_id = (select id from public.learning_targets where slug = 'cert-sec-test'))
    )->>'removed_concepts_count')::integer
  ),
  1,
  'evaluate_target_version_migration correctly identifies 1 removed concept'
);

-- ----------------------------------------------------------------------------
-- Test 10-15: Target Visibility & Security Hardening
-- ----------------------------------------------------------------------------

-- Setup a private draft target owned by user-secret
insert into public.learning_targets (
  id, slug, title, target_type, status, is_public, created_by
) values (
  '88888888-0000-4000-8000-000000000001',
  'private-draft-target',
  'Private Draft Target',
  'certification',
  'draft',
  false,
  '99999999-9999-4999-8999-999999999999'
) on conflict do nothing;

insert into public.target_versions (
  id, target_id, version_code, title, status
) values (
  '77777777-2222-4222-8222-222222222222',
  '88888888-0000-4000-8000-000000000001',
  '1.0.0',
  'Draft v1.0.0',
  'draft'
) on conflict do nothing;

-- Public published target
insert into public.learning_targets (
  id, slug, title, target_type, status, is_public, created_by
) values (
  '88888888-0000-4000-8000-000000000002',
  'public-published-target',
  'Public Target',
  'certification',
  'published',
  true,
  '99999999-9999-4999-8999-999999999999'
) on conflict do nothing;

-- Test 10: Verify is_target_visible helper on public target
select ok(
  public.is_target_visible('88888888-0000-4000-8000-000000000002'),
  'Public published target is visible'
);

-- Switch to anon
set local role anon;
set local "request.jwt.claim.role" to 'anon';

-- Test 11: Private draft target is NOT visible to anon
select ok(
  not public.is_target_visible('88888888-0000-4000-8000-000000000001'),
  'Private draft target is NOT visible to anon'
);

-- Test 12: Anon cannot execute crosswalk RPC on private target
select throws_ok(
  $$select * from public.get_target_crosswalk_occupations('88888888-0000-4000-8000-000000000001')$$,
  'P0001',
  'Unauthorized or target not found: 88888888-0000-4000-8000-000000000001',
  'Anon cannot execute get_target_crosswalk_occupations on private target'
);

-- Test 13: Anon cannot execute shared concepts RPC with private target A
select throws_ok(
  $$select * from public.get_cross_target_shared_concepts('88888888-0000-4000-8000-000000000001', '88888888-0000-4000-8000-000000000002')$$,
  'P0001',
  'Unauthorized or target not found: 88888888-0000-4000-8000-000000000001',
  'Anon cannot execute get_cross_target_shared_concepts with private target A'
);

-- Test 14: Anon cannot execute shared concepts RPC with private target B
select throws_ok(
  $$select * from public.get_cross_target_shared_concepts('88888888-0000-4000-8000-000000000002', '88888888-0000-4000-8000-000000000001')$$,
  'P0001',
  'Unauthorized or target not found: 88888888-0000-4000-8000-000000000001',
  'Anon cannot execute get_cross_target_shared_concepts with private target B'
);

-- Test 15: Verify v_target_occupation_mappings hides private target under anon
select is(
  (
    select count(*)::integer
    from public.v_target_occupation_mappings
    where target_id = '88888888-0000-4000-8000-000000000001'
  ),
  0,
  'v_target_occupation_mappings hides private target from anon (security_invoker = true)'
);

-- ----------------------------------------------------------------------------
-- Test 16-18: Content Source Artifacts Visibility Hardening
-- ----------------------------------------------------------------------------
-- Reset to service_role to create a draft-only release and artifact
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

insert into public.content_source_releases (
  id, publisher, title, version, source_url
) values (
  '77777777-1111-4111-8111-111111111111',
  'Private Corp',
  'Secret Spec',
  'v0.1',
  'https://secret.example.com'
) on conflict do nothing;

insert into public.content_source_artifacts (
  source_release_id, artifact_name, source_url, sha256
) values (
  '77777777-1111-4111-8111-111111111111',
  'secret-exam.pdf',
  'https://secret.example.com/exam.pdf',
  '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
) on conflict do nothing;

-- Link it exclusively to the private draft target
insert into public.content_source_mappings (
  source_release_id, entity_type, entity_id, relationship
) values (
  '77777777-1111-4111-8111-111111111111',
  'target_version',
  '77777777-2222-4222-8222-222222222222',
  'official_blueprint'
) on conflict do nothing;

-- Switch to anon and verify artifact is hidden
set local role anon;
set local "request.jwt.claim.role" to 'anon';

-- Test 16: Anon cannot read artifacts linked exclusively to private target
select is(
  (
    select count(*)::integer
    from public.content_source_artifacts
    where source_release_id = '77777777-1111-4111-8111-111111111111'
  ),
  0,
  'Anon cannot read content_source_artifacts linked exclusively to private/unauthorized content'
);

-- Test 17: Service role CAN read all artifacts
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select is(
  (
    select count(*)::integer
    from public.content_source_artifacts
    where source_release_id = '77777777-1111-4111-8111-111111111111'
  ),
  1,
  'Service role can read content_source_artifacts'
);

-- Test 18: Anon CAN read artifacts linked to public published target
set local role anon;
set local "request.jwt.claim.role" to 'anon';

select is(
  (
    select count(*)::integer
    from public.content_source_artifacts
    where artifact_name = 'blueprint-v2.pdf'
  ),
  1,
  'Anon can read content_source_artifacts linked to published public target'
);

-- Test 19: Anon CAN execute crosswalk RPC on public published target
select lives_ok(
  $$select * from public.get_target_crosswalk_occupations((select id from public.learning_targets where slug = 'cert-sec-test'))$$,
  'Anon can execute get_target_crosswalk_occupations on public published target'
);

-- Test 20: Anon CAN execute shared concepts RPC on public published targets
select lives_ok(
  $$select * from public.get_cross_target_shared_concepts(
    (select id from public.learning_targets where slug = 'cert-sec-test'),
    '88888888-0000-4000-8000-000000000002'
  )$$,
  'Anon can execute get_cross_target_shared_concepts on public published targets'
);

-- ----------------------------------------------------------------------------
-- Test 21-22: Target Owner and Reviewer Visibility
-- ----------------------------------------------------------------------------
-- Test 21: Target owner can see their private target
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '99999999-9999-4999-8999-999999999999';

select ok(
  public.is_target_visible('88888888-0000-4000-8000-000000000001'),
  'Target owner can view their private draft target'
);

-- Test 22: Target reviewer can see private target
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

insert into public.curriculum_reviewers (user_id, target_id)
values ('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee', '88888888-0000-4000-8000-000000000001')
on conflict do nothing;

set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';

select ok(
  public.is_target_visible('88888888-0000-4000-8000-000000000001'),
  'Curriculum reviewer can view private draft target'
);

select * from finish();
rollback;
