begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

-- Setup test users
insert into auth.users (id, is_anonymous)
values
  ('88888888-8888-4888-8888-888888888888', false);

insert into public.users (id)
values
  ('88888888-8888-4888-8888-888888888888');

insert into auth.users (id, is_anonymous)
values
  ('77777777-7777-4777-8777-777777777777', false);

insert into public.users (id)
values
  ('77777777-7777-4777-8777-777777777777');

-- 1-7: Structure checks
select has_table('public', 'user_version_migration_logs', 'user_version_migration_logs table exists');
select has_view('public', 'v_target_version_updates', 'v_target_version_updates view exists');
select has_function('public', 'evaluate_target_version_migration', ARRAY['uuid', 'uuid', 'uuid'], 'evaluate_target_version_migration RPC exists');
select has_function('public', 'migrate_user_context_target_version', ARRAY['uuid', 'uuid', 'uuid'], 'migrate_user_context_target_version RPC exists');
select has_function('public', 'audit_target_version_readiness', ARRAY['uuid'], 'audit_target_version_readiness RPC exists');
select has_function('public', 'publish_target_version', ARRAY['uuid', 'boolean'], 'publish_target_version RPC exists');
select has_function('public', 'retire_target_version', ARRAY['uuid'], 'retire_target_version RPC exists');

-- Setup test target
insert into public.learning_targets
  (id, target_type, title, slug, created_by, is_official, status, is_public)
values (
  '99999999-1111-4999-8999-999999999999',
  'certification',
  'Governance Security Cert',
  'gov-sec-cert',
  '88888888-8888-4888-8888-888888888888',
  true,
  'published',
  true
);

-- Insert 2 target versions: V1 (published) and V2 (review_ready)
insert into public.target_versions (id, target_id, version_code, title, status)
values
  ('99999999-aaaa-4999-8999-999999999999', '99999999-1111-4999-8999-999999999999', 'SY0-601', 'Security Edition 601', 'published'),
  ('99999999-bbbb-4999-8999-999999999999', '99999999-1111-4999-8999-999999999999', 'SY0-701', 'Security Edition 701', 'review_ready');

-- Setup canonical concepts
insert into public.knowledge_concepts (id, slug, name, description)
values
  ('99999999-c001-4999-8999-999999999999', 'gov-threat-vectors', 'Threat Vectors', 'Vector analysis'),
  ('99999999-c002-4999-8999-999999999999', 'gov-cloud-threats', 'Cloud Attack Vectors', 'Cloud specific vectors'),
  ('99999999-c003-4999-8999-999999999999', 'gov-legacy-hashes', 'Deprecated Hashes (MD5/SHA1)', 'Legacy cryptographic primitives');

-- Setup curriculum nodes in V1
insert into public.curriculum_nodes (id, target_version_id, node_type, title, weight, sort_order)
values
  ('99999999-a001-4999-8999-999999999999', '99999999-aaaa-4999-8999-999999999999', 'domain', 'Threats & Attacks', 100.0, 1),
  ('99999999-a002-4999-8999-999999999999', '99999999-aaaa-4999-8999-999999999999', 'objective', 'Identify Threat Vectors', null, 2);
update public.curriculum_nodes set parent_id = '99999999-a001-4999-8999-999999999999' where id = '99999999-a002-4999-8999-999999999999';

-- Setup curriculum nodes in V2
insert into public.curriculum_nodes (id, target_version_id, node_type, title, weight, sort_order)
values
  ('99999999-b003-4999-8999-999999999999', '99999999-bbbb-4999-8999-999999999999', 'domain', 'General Security Concepts', 100.0, 1),
  ('99999999-b004-4999-8999-999999999999', '99999999-bbbb-4999-8999-999999999999', 'objective', 'Mitigate Cloud Threats', null, 2);
update public.curriculum_nodes set parent_id = '99999999-b003-4999-8999-999999999999' where id = '99999999-b004-4999-8999-999999999999';

-- Map concepts to nodes
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
values
  ('99999999-a002-4999-8999-999999999999', '99999999-c001-4999-8999-999999999999'),
  ('99999999-a002-4999-8999-999999999999', '99999999-c003-4999-8999-999999999999'),
  ('99999999-b004-4999-8999-999999999999', '99999999-c002-4999-8999-999999999999');

-- Add cross-version concept mappings:
-- c001 -> c002 with transfer_weight = 0.8 (expanded)
-- c003 is removed with transfer_weight = 0.0
insert into public.target_version_concept_mappings
  (from_target_version_id, from_concept_id, to_target_version_id, to_concept_id, mapping_type, transfer_weight)
values
  ('99999999-aaaa-4999-8999-999999999999', '99999999-c001-4999-8999-999999999999', '99999999-bbbb-4999-8999-999999999999', '99999999-c002-4999-8999-999999999999', 'expanded', 0.80),
  ('99999999-aaaa-4999-8999-999999999999', '99999999-c003-4999-8999-999999999999', '99999999-bbbb-4999-8999-999999999999', null, 'removed', 0.00);

-- Pre-seed user concept state for c001
insert into public.user_concept_state
  (user_id, concept_id, retrieval_band, confidence, evidence_count, weighted_correct, weighted_total)
values
  ('88888888-8888-4888-8888-888888888888', '99999999-c001-4999-8999-999999999999', 'well_retained', 'high', 10, 9.0, 10.0);

-- Setup user learning context on V1
insert into public.learning_contexts
  (id, user_id, label, root_type, root_id, target_version_id, last_active_at)
values (
  '99999999-d001-4999-8999-999999999999',
  '88888888-8888-4888-8888-888888888888',
  'Security Cert Prep',
  'target',
  '99999999-1111-4999-8999-999999999999',
  '99999999-aaaa-4999-8999-999999999999',
  now()
);

-- Exercise privileged governance functions as service_role unless a test overrides it.
select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 8. Test evaluate_target_version_migration
select is(
  (public.evaluate_target_version_migration(
    '88888888-8888-4888-8888-888888888888',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  )->>'retained_concepts_count')::integer,
  1,
  'evaluate_target_version_migration finds 1 retained concept'
);

-- 9. Test evaluate_target_version_migration removed count
select is(
  (public.evaluate_target_version_migration(
    '88888888-8888-4888-8888-888888888888',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  )->>'removed_concepts_count')::integer,
  1,
  'evaluate_target_version_migration finds 1 removed concept'
);

-- 10. Test evaluate_target_version_migration user assessed count
select is(
  (public.evaluate_target_version_migration(
    '88888888-8888-4888-8888-888888888888',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  )->>'user_assessed_concepts_count')::integer,
  1,
  'evaluate_target_version_migration identifies 1 user assessed concept in source'
);

-- 11. Test audit_target_version_readiness domain balance
select is(
  (public.audit_target_version_readiness('99999999-bbbb-4999-8999-999999999999')->>'is_domain_weight_balanced')::boolean,
  true,
  'audit_target_version_readiness confirms balanced domain weights (100.0%)'
);

-- 12. Test audit_target_version_readiness objective counts
select is(
  (public.audit_target_version_readiness('99999999-bbbb-4999-8999-999999999999')->>'objective_count')::integer,
  2,
  'audit_target_version_readiness counts root and child nodes'
);

-- 13. Non-owner cannot inspect an unpublished migration destination
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $ select public.evaluate_target_version_migration(
    '77777777-7777-4777-8777-777777777777',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) $,
  'P0001',
  'Unauthorized: destination target version is not published for this caller.',
  'Non-owner cannot evaluate migration into review-ready version'
);

-- 14. Unauthorized authenticated user cannot audit another owner's staged version
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $ select public.audit_target_version_readiness('99999999-bbbb-4999-8999-999999999999') $,
  'P0001',
  'Unauthorized: only service_role, target owner, or assigned reviewer may audit a target version.',
  'Non-owner cannot audit staged target version'
);

-- 15. Unauthorized authenticated user cannot publish another owner's version
select throws_ok(
  $ select public.publish_target_version('99999999-bbbb-4999-8999-999999999999', true) $,
  'P0001',
  'Unauthorized: only service_role or the target owner can publish a target version',
  'Non-owner cannot publish target version'
);

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 16. Test publish_target_version with retire_previous = true
select is(
  (public.publish_target_version('99999999-bbbb-4999-8999-999999999999', true)->>'status')::text,
  'published',
  'publish_target_version promotes V2 to published'
);

-- 17. Verify V1 was retired when V2 published with retire_previous
select is(
  (select status from public.target_versions where id = '99999999-aaaa-4999-8999-999999999999'),
  'retired',
  'V1 status is now retired'
);

-- 18. Verify v_target_version_updates flags the context as outdated and retired
select is(
  (select is_outdated from public.v_target_version_updates where context_id = '99999999-d001-4999-8999-999999999999'),
  true,
  'v_target_version_updates detects outdated context'
);

select is(
  (select is_retired from public.v_target_version_updates where context_id = '99999999-d001-4999-8999-999999999999'),
  true,
  'v_target_version_updates detects retired context active version'
);

-- 20. Authenticated caller cannot migrate another user's context
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $ select public.migrate_user_context_target_version(
    '88888888-8888-4888-8888-888888888888',
    '99999999-d001-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) $,
  'P0001',
  'Unauthorized: cannot migrate context for another user.',
  'Non-owner cannot migrate another user context'
);

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 21. Test migrate_user_context_target_version execution
select is(
  (public.migrate_user_context_target_version(
    '88888888-8888-4888-8888-888888888888',
    '99999999-d001-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  )->>'success')::boolean,
  true,
  'migrate_user_context_target_version succeeds'
);

-- 22. Verify learning context target_version_id was updated to V2
select is(
  (select target_version_id from public.learning_contexts where id = '99999999-d001-4999-8999-999999999999'),
  '99999999-bbbb-4999-8999-999999999999'::uuid,
  'Context target_version_id is updated to V2'
);

-- 23. Verify user_version_migration_logs recorded the migration
select is(
  (select count(*) from public.user_version_migration_logs where user_id = '88888888-8888-4888-8888-888888888888')::integer,
  1,
  'user_version_migration_logs recorded migration event'
);

-- 24. Verify user_concept_state carried forward scaled evidence to c002 (10 * 0.8 = 8)
select is(
  (select evidence_count from public.user_concept_state where user_id = '88888888-8888-4888-8888-888888888888' and concept_id = '99999999-c002-4999-8999-999999999999'),
  8,
  'Target concept c002 received evidence scaled by transfer_weight (8)'
);

-- 25. Unauthorized authenticated user cannot retire another owner's version
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $ select public.retire_target_version('99999999-bbbb-4999-8999-999999999999') $,
  'P0001',
  'Unauthorized: only service_role or the target owner can retire a target version',
  'Non-owner cannot retire target version'
);

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 26. Test retire_target_version RPC on V2
select is(
  (public.retire_target_version('99999999-bbbb-4999-8999-999999999999')->>'status')::text,
  'retired',
  'retire_target_version transitions V2 to retired'
);

select * from finish();
rollback;
