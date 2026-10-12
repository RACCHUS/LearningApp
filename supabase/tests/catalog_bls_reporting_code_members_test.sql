begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(14);

select has_table('public','catalog_bls_reporting_code_members',
  'BLS hybrid code membership table exists');
select ok((select relrowsecurity from pg_class where oid =
           'public.catalog_bls_reporting_code_members'::regclass),
  'BLS hybrid relations are private with RLS');
select ok(not has_table_privilege('anon','public.catalog_bls_reporting_code_members','SELECT'),
  'No anonymous public access to raw BLS hybrid mappings');
select ok(not has_table_privilege('authenticated','public.catalog_bls_reporting_code_members','SELECT'),
  'No signed-in learner access to raw BLS hybrid mappings');
select is((select count(*) from public.catalog_bls_reporting_code_members),
  13::bigint, 'Exactly thirteen documented component-memberships');
select is((select count(distinct reporting_code) from public.catalog_bls_reporting_code_members),
  5::bigint, 'Five reconciled BLS hybrid reporting codes');
select is((select count(*) from public.catalog_bls_reporting_code_members
           where allocation_policy='not_allocated'),13::bigint,
  'No combined openings allocated to component SOC entries');
select ok(
    (select count(*) from public.occupation_nodes
     where taxonomy_system='bls_soc' and taxonomy_version='soc_2018'
       and is_active and level='detailed_occupation') < 867
    or not exists (
      select 1 from public.catalog_bls_reporting_code_members m
      where not exists (
        select 1 from public.occupation_nodes n
        where n.code=m.soc_2018_code and n.taxonomy_system='bls_soc'
          and n.taxonomy_version='soc_2018' and n.is_active
      )
    ),
    'After a complete SOC release is present, all 13 component codes resolve to active occupations'
  );
select is((select count(*) from public.catalog_bls_reporting_code_members m
           where exists (select 1 from public.catalog_official_demand_observations o
             where o.taxonomy_code=m.reporting_code
               and o.source_release='BLS_EMP_2025_2035')),
  0::bigint,
  'Disposable migration schema does not synthesize any jobs-data observation');
select throws_ok($$insert into public.catalog_bls_reporting_code_members
    (reporting_code,soc_2018_code,source_note,allocation_policy)
    values ('21-1018','21-1011','Invalid duplicate fractional allocation test',
    'equal_share')$$,
  '23514',null,'Cannot mislabel composite values as allocated exact SOC counts');
select has_view('public','v_catalog_bls_observation_coverage',
  'Single-observation BLS coverage view exists');
select ok(not has_table_privilege('anon','public.v_catalog_bls_observation_coverage','SELECT'),
  'Public cannot read BLS source coverage view');
select lives_ok(
  $ insert into public.catalog_official_demand_observations
    (taxonomy_system,taxonomy_version,taxonomy_code,metric,metric_value,
     metric_unit,period,dimension,publisher,source_release,source_url,
     source_sha256,method_note)
   values ('bls_soc','soc_2018','21-1018','bls_annual_openings_thousands',50.50,
     'thousands_of_jobs','2025-2035','all','BLS_EMP','BLS_EMP_2025_2035',
     'https://www.bls.gov/emp/ind-occ-matrix/occupation.xlsx',
     repeat('a',64),'Unit-test controlled, one combined reporting code observation.') 
   on conflict do nothing $,
   'Hybrid reporting code can be retained independently of 2018 SOC hierarchy');
select is((select coverage_status from public.v_catalog_bls_observation_coverage
           where bls_reporting_code='21-1018'),
  'combined_reporting_code',
  'The original 21-1018 data value is classified as combined, not duplicated');

select * from finish();
rollback;
