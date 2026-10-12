begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

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
select * from finish();
rollback;
