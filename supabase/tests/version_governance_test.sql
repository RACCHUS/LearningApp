begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(44);

-- Setup test users
insert into auth.users (id, is_anonymous)
values
  ('88888888-8888-4888-8888-888888888888', false),
  ('77777777-7777-4777-8777-777777777777', false),
  ('66666666-6666-4666-8666-666666666666', false);

insert into public.users (id)
values
  ('88888888-8888-4888-8888-888888888888'),
  ('77777777-7777-4777-8777-777777777777'),
  ('66666666-6666-4666-8666-666666666666');

-- 1-8: Structure checks
select has_table('public', 'user_version_migration_logs', 'user_version_migration_logs table exists');
select has_view('public', 'v_target_version_updates', 'v_target_version_updates view exists');
select has_function('public', 'evaluate_target_version_migration', ARRAY['uuid', 'uuid', 'uuid'], 'evaluate_target_version_migration RPC exists');
select has_function('public', 'migrate_user_context_target_version', ARRAY['uuid', 'uuid', 'uuid'], 'migrate_user_context_target_version RPC exists');
select has_function('public', 'audit_target_version_readiness', ARRAY['uuid'], 'audit_target_version_readiness RPC exists');
select has_function('public', 'publish_target_version', ARRAY['uuid', 'boolean'], 'publish_target_version RPC exists');
select has_function('public', 'retire_target_version', ARRAY['uuid'], 'retire_target_version RPC exists');
select has_function('public', 'has_historical_target_version_access', ARRAY['uuid', 'uuid'], 'has_historical_target_version_access helper exists');

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

-- Insert 3 target versions: V1 (published), V2 (review_ready), and V3 (draft)
insert into public.target_versions (id, target_id, version_code, title, status)
values
  ('99999999-aaaa-4999-8999-999999999999', '99999999-1111-4999-8999-999999999999', 'SY0-601', 'Security Edition 601', 'published'),
  ('99999999-bbbb-4999-8999-999999999999', '99999999-1111-4999-8999-999999999999', 'SY0-701', 'Security Edition 701', 'review_ready'),
  ('99999999-cccc-4999-8999-999999999999', '99999999-1111-4999-8999-999999999999', 'SY0-801', 'Security Edition 801 (Draft)', 'draft');

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

-- Seed a disposable resume pointer that must be cleared by version migration.
insert into public.resume_pointers
  (context_id, user_id, kind, activity_id, item_index)
values (
  '99999999-d001-4999-8999-999999999999',
  '88888888-8888-4888-8888-888888888888',
  'lesson',
  'legacy-version-lesson',
  3
);

-- Setup ordinary learner context on V1 (learner is NOT the target owner)
insert into public.learning_contexts
  (id, user_id, label, root_type, root_id, target_version_id, last_active_at)
values (
  '99999999-d002-4999-8999-999999999999',
  '66666666-6666-4666-8666-666666666666',
  'Learner Security Cert Prep',
  'target',
  '99999999-1111-4999-8999-999999999999',
  '99999999-aaaa-4999-8999-999999999999',
  now()
);

-- Pre-seed user concept state for learner 66666666 on c001
insert into public.user_concept_state
  (user_id, concept_id, retrieval_band, confidence, evidence_count, weighted_correct, weighted_total)
values
  ('66666666-6666-4666-8666-666666666666', '99999999-c001-4999-8999-999999999999', 'well_retained', 'high', 8, 7.0, 8.0);

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
  $$ select public.evaluate_target_version_migration(
    '77777777-7777-4777-8777-777777777777',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) $$,
  'P0001',
  'Unauthorized: destination target version is not published for this caller.',
  'Non-owner cannot evaluate migration into review-ready version'
);

-- 14. Unauthorized authenticated user cannot audit another owner's staged version
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $$ select public.audit_target_version_readiness('99999999-bbbb-4999-8999-999999999999') $$,
  'P0001',
  'Unauthorized: only service_role, target owner, or assigned reviewer may audit a target version.',
  'Non-owner cannot audit staged target version'
);

-- 15. Unauthorized authenticated user cannot publish another owner's version
select throws_ok(
  $$ select public.publish_target_version('99999999-bbbb-4999-8999-999999999999', true) $$,
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

-- 19. Verify an ordinary authenticated learner with a retired version detects updates in v_target_version_updates
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);

select is(
  (select is_outdated from public.v_target_version_updates where context_id = '99999999-d002-4999-8999-999999999999'),
  true,
  'Authenticated learner detects outdated context on retired version'
);

select is(
  (select is_retired from public.v_target_version_updates where context_id = '99999999-d002-4999-8999-999999999999'),
  true,
  'Authenticated learner detects retired context active version'
);

-- 20. Authenticated learner can evaluate migration from their own retired version to published V2
select ok(
  (public.evaluate_target_version_migration(
    '66666666-6666-4666-8666-666666666666',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) is not null),
  'Authenticated learner can evaluate migration from their own retired context version'
);

-- 21. Authenticated user without context cannot evaluate migration from retired version
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $$ select public.evaluate_target_version_migration(
    '77777777-7777-4777-8777-777777777777',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) $$,
  'P0001',
  'Unauthorized: source target version is not accessible for this caller.',
  'User without enrolled context cannot evaluate migration from retired version'
);

-- 22. Authenticated learner cannot evaluate migration to draft target version
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select throws_ok(
  $$ select public.evaluate_target_version_migration(
    '66666666-6666-4666-8666-666666666666',
    '99999999-aaaa-4999-8999-999999999999',
    '99999999-cccc-4999-8999-999999999999'
  ) $$,
  'P0001',
  'Unauthorized: destination target version is not published for this caller.',
  'Learner cannot evaluate migration to draft target version'
);

-- 23-26. Test historical-context access helper
select ok(
  public.has_historical_target_version_access('99999999-aaaa-4999-8999-999999999999', '66666666-6666-4666-8666-666666666666'),
  'has_historical_target_version_access is true for enrolled learner on retired version'
);

select ok(
  public.has_historical_target_version_access('99999999-aaaa-4999-8999-999999999999'),
  'has_historical_target_version_access 1-argument form defaults to caller auth.uid'
);

select ok(
  not public.has_historical_target_version_access('99999999-aaaa-4999-8999-999999999999', '77777777-7777-4777-8777-777777777777'),
  'has_historical_target_version_access is false for unenrolled user on retired version'
);

select ok(
  not public.has_historical_target_version_access('99999999-cccc-4999-8999-999999999999', '66666666-6666-4666-8666-666666666666'),
  'has_historical_target_version_access is false for draft target version'
);

-- 27-32. Test validate_learning_context_target_version trigger controls
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);

-- User 7777 cannot probe user 6666 enrollment (oracle blocked)
select ok(
  not public.has_historical_target_version_access('99999999-aaaa-4999-8999-999999999999', '66666666-6666-4666-8666-666666666666'),
  'has_historical_target_version_access blocks cross-user probe for non-service callers'
);

-- Cannot insert context pointing to draft version V3
select throws_ok(
  $$ insert into public.learning_contexts (id, user_id, label, root_type, root_id, target_version_id)
     values ('77777777-d003-4999-8999-999999999999', '77777777-7777-4777-8777-777777777777', 'Draft Exploit', 'target', '99999999-1111-4999-8999-999999999999', '99999999-cccc-4999-8999-999999999999') $$,
  'P0001',
  'Unauthorized: target version 99999999-cccc-4999-8999-999999999999 is not visible or accessible.',
  'Learner cannot insert context referencing draft target version'
);

-- Cannot insert context pointing to retired version V1
select throws_ok(
  $$ insert into public.learning_contexts (id, user_id, label, root_type, root_id, target_version_id)
     values ('77777777-d004-4999-8999-999999999999', '77777777-7777-4777-8777-777777777777', 'Retired Exploit', 'target', '99999999-1111-4999-8999-999999999999', '99999999-aaaa-4999-8999-999999999999') $$,
  'P0001',
  'Unauthorized: target version 99999999-aaaa-4999-8999-999999999999 is not visible or accessible.',
  'Learner cannot insert context referencing retired target version'
);

-- Cannot insert target context with mismatched root_id
select throws_ok(
  $$ insert into public.learning_contexts (id, user_id, label, root_type, root_id, target_version_id)
     values ('77777777-d005-4999-8999-999999999999', '77777777-7777-4777-8777-777777777777', 'Mismatched Target', 'target', '00000000-0000-4000-8000-000000000000', '99999999-bbbb-4999-8999-999999999999') $$,
  'P0001',
  'Learning context root_id does not match target version target_id.',
  'Learner cannot insert target context with mismatched root_id'
);

-- Learner CAN insert context referencing published version V2 with matching root_id
select lives_ok(
  $$ insert into public.learning_contexts (id, user_id, label, root_type, root_id, target_version_id)
     values ('77777777-d006-4999-8999-999999999999', '77777777-7777-4777-8777-777777777777', 'Valid Published Context', 'target', '99999999-1111-4999-8999-999999999999', '99999999-bbbb-4999-8999-999999999999') $$,
  'Learner can insert context referencing published target version'
);

-- Learner 66666666 CAN update non-version fields on existing context referencing retired version V1
select set_config('request.jwt.claim.sub', '66666666-6666-4666-8666-666666666666', true);
select lives_ok(
  $$ update public.learning_contexts
     set label = 'Learner Security Cert Prep (Active)', last_active_at = now()
     where id = '99999999-d002-4999-8999-999999999999' $$,
  'Learner can update non-version fields on existing retired version context'
);

-- Learner 66666666 CANNOT update existing context to point to draft version V3
select throws_ok(
  $$ update public.learning_contexts
     set target_version_id = '99999999-cccc-4999-8999-999999999999'
     where id = '99999999-d002-4999-8999-999999999999' $$,
  'P0001',
  'Unauthorized: target version 99999999-cccc-4999-8999-999999999999 is not visible or accessible.',
  'Learner cannot update context to point to draft target version'
);

-- 32. Authenticated caller cannot migrate another user's context
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $$ select public.migrate_user_context_target_version(
    '88888888-8888-4888-8888-888888888888',
    '99999999-d001-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  ) $$,
  'P0001',
  'Unauthorized: cannot migrate context for another user.',
  'Non-owner cannot migrate another user context'
);

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 33. Test migrate_user_context_target_version execution
select is(
  (public.migrate_user_context_target_version(
    '88888888-8888-4888-8888-888888888888',
    '99999999-d001-4999-8999-999999999999',
    '99999999-bbbb-4999-8999-999999999999'
  )->>'success')::boolean,
  true,
  'migrate_user_context_target_version succeeds'
);

-- 34. Verify learning context target_version_id was updated to V2
select is(
  (select target_version_id from public.learning_contexts where id = '99999999-d001-4999-8999-999999999999'),
  '99999999-bbbb-4999-8999-999999999999'::uuid,
  'Context target_version_id is updated to V2'
);

-- 35. Version migration clears stale resume breadcrumbs.
select is(
  (select count(*) from public.resume_pointers where context_id = '99999999-d001-4999-8999-999999999999')::integer,
  0,
  'Version migration clears stale resume pointer'
);

-- 36. Verify user_version_migration_logs recorded the migration
select is(
  (select count(*) from public.user_version_migration_logs where user_id = '88888888-8888-4888-8888-888888888888')::integer,
  1,
  'user_version_migration_logs recorded migration event'
);

-- 37. Verify user_concept_state carried forward scaled evidence to c002 (10 * 0.8 = 8)
select is(
  (select evidence_count from public.user_concept_state where user_id = '88888888-8888-4888-8888-888888888888' and concept_id = '99999999-c002-4999-8999-999999999999'),
  8,
  'Target concept c002 received evidence scaled by transfer_weight (8)'
);

-- 38. Unauthorized authenticated user cannot retire another owner's version
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '77777777-7777-4777-8777-777777777777', true);
select throws_ok(
  $$ select public.retire_target_version('99999999-bbbb-4999-8999-999999999999') $$,
  'P0001',
  'Unauthorized: only service_role or the target owner can retire a target version',
  'Non-owner cannot retire target version'
);

select set_config('request.jwt.claim.role', 'service_role', true);
select set_config('request.jwt.claim.sub', '88888888-8888-4888-8888-888888888888', true);

-- 39. Test retire_target_version RPC on V2
select is(
  (public.retire_target_version('99999999-bbbb-4999-8999-999999999999')->>'status')::text,
  'retired',
  'retire_target_version transitions V2 to retired'
);

select * from finish();
rollback;
