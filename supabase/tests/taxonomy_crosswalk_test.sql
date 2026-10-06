-- ============================================================================
-- Test Suite: taxonomy_crosswalk_test.sql
-- Description: pgTAP tests for Phase F Canonical Taxonomy & Crosswalk Expansion:
--   1. External Classification Nodes (CIP hierarchy & referential integrity)
--   2. Occupation Nodes (5-Tier Labor Taxonomy: major, minor, broad, detailed, onet_extension)
--   3. CIP-to-SOC Crosswalk Views (v_field_occupation_mappings & v_target_occupation_mappings)
--   4. Lateral Field Relations Symmetry & Bidirectional View
--   5. Labor Market Metrics Fail-Closed Privacy & Aggregation Threshold ($N >= 50$)
--   6. Decennial Taxonomy Lineage (Idempotency & resolve_taxonomy_lineage RPC)
--   7. Target Crosswalk Occupations RPC
--   8. Multidisciplinary Target-Field Bindings
--   9. Public & Anonymous RLS Verification
-- ============================================================================

begin;
create extension if not exists pgtap;

select plan(29);

-- ----------------------------------------------------------------------------
-- Test 1: Verify all 48 CIP 2-digit Series Exist in external_classification_nodes
-- ----------------------------------------------------------------------------
select cmp_ok(
  (select count(*)::integer from public.external_classification_nodes where system = 'cip' and level_code = 'series'),
  '>=',
  48,
  'External classification nodes contains at least 48 CIP 2020 two-digit series'
);

-- ----------------------------------------------------------------------------
-- Test 2: Verify 12 Presentation Catalog Clusters Exist
-- ----------------------------------------------------------------------------
select cmp_ok(
  (select count(*)::integer from public.catalog_clusters where is_active = true),
  '>=',
  12,
  'Catalog clusters contains all 12 presentation clusters'
);

-- ----------------------------------------------------------------------------
-- Test 3: Verify 5-Tier Occupation Hierarchy Levels Exist
-- ----------------------------------------------------------------------------
select ok(
  exists(select 1 from public.occupation_nodes where level = 'major_group'),
  'Occupation nodes contains major_group level'
);
select ok(
  exists(select 1 from public.occupation_nodes where level = 'detailed_occupation'),
  'Occupation nodes contains detailed_occupation level'
);
select ok(
  exists(select 1 from public.occupation_nodes where level = 'onet_extension'),
  'Occupation nodes contains onet_extension level'
);

-- ----------------------------------------------------------------------------
-- Test 4: Verify O*NET Taxonomy System Check Constraint
-- ----------------------------------------------------------------------------
select ok(
  (select count(*)::integer from public.occupation_nodes where level = 'onet_extension' and taxonomy_system <> 'onet_soc') = 0,
  'O*NET extensions strictly carry taxonomy_system onet_soc'
);

select ok(
  (select count(*)::integer from public.occupation_nodes where level <> 'onet_extension' and taxonomy_system = 'onet_soc') = 0,
  'Non-extension SOC nodes do not claim onet_soc taxonomy_system'
);

-- ----------------------------------------------------------------------------
-- Test 5: Verify Qualitative CIP-to-SOC Crosswalk Exists
-- ----------------------------------------------------------------------------
select cmp_ok(
  (select count(*)::integer from public.external_classification_occupation_mappings where mapping_kind = 'official_qualitative'),
  '>=',
  5,
  'Qualitative CIP-SOC crosswalk entries exist with official provenance'
);

-- ----------------------------------------------------------------------------
-- Test 6: Verify v_field_occupation_mappings View Resolves Correctly
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from public.v_field_occupation_mappings
    where occupation_code = '15-1252'
  ),
  'v_field_occupation_mappings exposes Software Developers (15-1252)'
);

-- ----------------------------------------------------------------------------
-- Test 7: Verify v_target_occupation_mappings View Resolves Correctly
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from public.v_target_occupation_mappings
    where target_slug = 'career-software-engineer' and occupation_code = '15-1252'
  ),
  'v_target_occupation_mappings links career-software-engineer to 15-1252 Software Developers'
);

-- ----------------------------------------------------------------------------
-- Test 8: Verify Lateral Field Relations & Bidirectional View
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from public.field_relations
    where relation_type = 'shares_foundations'
  ),
  'field_relations records symmetric shares_foundations relationship'
);

select cmp_ok(
  (select count(*)::integer from public.v_field_relations_bidirectional where relation_type = 'shares_foundations'),
  '=',
  (select (count(*) * 2)::integer from public.field_relations where relation_type = 'shares_foundations'),
  'v_field_relations_bidirectional duplicates symmetric shares_foundations in both directions'
);

-- ----------------------------------------------------------------------------
-- Test 9: Verify Field Relation Symmetry Constraint Rejects Unordered from_id > to_id
-- ----------------------------------------------------------------------------
do $$
declare
  v_f1 uuid;
  v_f2 uuid;
  v_err boolean := false;
begin
  select id into v_f1 from public.fields order by id asc limit 1;
  select id into v_f2 from public.fields order by id desc limit 1;

  if v_f1 > v_f2 then
    -- Swap to guarantee v_f1 < v_f2
    declare v_tmp uuid := v_f1; begin v_f1 := v_f2; v_f2 := v_tmp; end;
  end if;

  -- Inserting with from_id > to_id for symmetric relation should violate check constraint
  begin
    insert into public.field_relations (from_field_id, to_field_id, relation_type)
    values (v_f2, v_f1, 'shares_foundations');
  exception when check_violation then
    v_err := true;
  end;

  if not v_err then
    raise exception 'Check constraint failed to reject unordered symmetric field relation';
  end if;
end $$;

select pass('Symmetric field relation strictly enforces from_field_id < to_field_id');

-- ----------------------------------------------------------------------------
-- Test 10: Verify Labor Market Metrics Fail-Closed Privacy ($N >= 50)
-- ----------------------------------------------------------------------------
do $$
declare
  v_fid uuid;
  v_oid uuid;
  v_err boolean := false;
begin
  select id into v_fid from public.fields limit 1;
  select id into v_oid from public.occupation_nodes limit 1;

  -- Inserting app_user_transition_share with sample_size < 50 must violate check constraint
  begin
    insert into public.field_occupation_metrics (
      field_id, occupation_id, metric_type, metric_value, data_year, sample_size, privacy_threshold_met
    ) values (
      v_fid, v_oid, 'app_user_transition_share', 0.45, 2026, 25, false
    );
  exception when check_violation then
    v_err := true;
  end;

  if not v_err then
    raise exception 'Check constraint failed to reject learner transition metric with sample_size < 50';
  end if;
end $$;

select pass('Field occupation metrics check constraint strictly rejects app_user_transition_share with sample_size < 50');

-- ----------------------------------------------------------------------------
-- Test 11: Verify Decennial Taxonomy Lineage Seed Data
-- ----------------------------------------------------------------------------
select cmp_ok(
  (select count(*)::integer from public.taxonomy_node_lineage where source_system = 'cip'),
  '>=',
  5,
  'Taxonomy node lineage contains CIP decennial transitions'
);

-- ----------------------------------------------------------------------------
-- Test 12: Verify resolve_taxonomy_lineage RPC
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from public.resolve_taxonomy_lineage('cip', '2010', '11.0701')
    where to_code = '11.0701' and transition_type = 'unchanged'
  ),
  'resolve_taxonomy_lineage resolves unchanged CIP 11.0701 transition'
);

select ok(
  exists(
    select 1 from public.resolve_taxonomy_lineage('bls_soc', '2010', '15-1132')
    where to_code = '15-1252' and transition_type in ('moved_to', 'split_into')
  ),
  'resolve_taxonomy_lineage resolves SOC 15-1132 -> 15-1252 transition'
);

-- ----------------------------------------------------------------------------
-- Test 13: Verify get_target_crosswalk_occupations RPC
-- ----------------------------------------------------------------------------
do $$
declare
  v_target_id uuid;
  v_count integer;
begin
  select id into v_target_id from public.learning_targets where slug = 'career-software-engineer' limit 1;
  select count(*)::integer into v_count from public.get_target_crosswalk_occupations(v_target_id);

  if v_count < 1 then
    raise exception 'get_target_crosswalk_occupations returned 0 occupations for career-software-engineer';
  end if;
end $$;

select pass('get_target_crosswalk_occupations returns enriched occupation cards for learning target');

-- ----------------------------------------------------------------------------
-- Test 14: Verify Multidisciplinary Target-Field Roles
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from public.learning_target_fields ltf
    join public.learning_targets lt on lt.id = ltf.target_id
    where lt.slug = 'program-bs-computer-science' and ltf.role = 'primary'
  ),
  'program-bs-computer-science has primary field binding'
);

select ok(
  exists(
    select 1 from public.learning_target_fields ltf
    join public.learning_targets lt on lt.id = ltf.target_id
    where lt.slug = 'program-bs-computer-science' and ltf.role = 'supporting'
  ),
  'program-bs-computer-science has supporting field binding'
);

-- ----------------------------------------------------------------------------
-- Test 15: Verify Anonymous Public Read Access (RLS)
-- ----------------------------------------------------------------------------
set role anon;

select cmp_ok(
  (select count(*)::integer from public.external_classification_nodes where system = 'cip'),
  '>=',
  48,
  'Anon role can select external_classification_nodes'
);

select cmp_ok(
  (select count(*)::integer from public.occupation_nodes),
  '>=',
  18,
  'Anon role can select occupation_nodes'
);

select cmp_ok(
  (select count(*)::integer from public.taxonomy_node_lineage),
  '>=',
  5,
  'Anon role can select taxonomy_node_lineage'
);

select cmp_ok(
  (select count(*)::integer from public.catalog_clusters),
  '>=',
  12,
  'Anon role can select catalog_clusters'
);

reset role;

-- ----------------------------------------------------------------------------
-- Test 16: Verify occupation_nodes Unique Constraint with data_release_version
-- ----------------------------------------------------------------------------
select ok(
  exists(
    select 1 from pg_constraint
    where conrelid = 'public.occupation_nodes'::regclass
      and conname = 'occupation_nodes_system_version_release_code_key'
  ),
  'occupation_nodes includes unique constraint incorporating data_release_version'
);

-- ----------------------------------------------------------------------------
-- Test 17: Verify Service-Role Staging Tables & RLS
-- ----------------------------------------------------------------------------
select ok(
  (select count(*)::integer from pg_tables where schemaname = 'public' and tablename like 'stg_%') = 5,
  'All 5 service-role staging tables exist'
);

select ok(
  (
    select count(*)::integer from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in (
        'stg_taxonomy_source_artifacts',
        'stg_external_classification_nodes',
        'stg_occupation_nodes',
        'stg_external_classification_occupation_mappings',
        'stg_taxonomy_node_lineage'
      )
      and c.relrowsecurity = true
  ) = 5,
  'All 5 staging tables have Row Level Security enabled'
);

-- ----------------------------------------------------------------------------
-- Test 18: Verify finalize_official_taxonomy_import Security Definer & Anon Restrictions
-- ----------------------------------------------------------------------------
select ok(
  has_function_privilege('service_role', 'public.finalize_official_taxonomy_import(uuid)', 'EXECUTE'),
  'service_role has EXECUTE privilege on finalize_official_taxonomy_import'
);

select ok(
  not has_function_privilege('anon', 'public.finalize_official_taxonomy_import(uuid)', 'EXECUTE'),
  'anon does not have EXECUTE privilege on finalize_official_taxonomy_import'
);

select * from finish();
rollback;
