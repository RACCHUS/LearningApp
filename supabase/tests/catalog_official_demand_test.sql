begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

select has_table('public', 'catalog_official_demand_observations',
  'P1 numerical taxonomy demand observations exist');
select has_table('public', 'catalog_official_demand_imports',
  'P1 checksummed import provenance exists');
select has_column('public', 'catalog_official_demand_observations', 'source_sha256',
  'Every observation tracks its official download hash');
select has_column('public', 'catalog_official_demand_observations', 'metric_unit',
  'Jobs in thousands cannot be confused with exact counts');
select has_column('public', 'catalog_official_demand_observations', 'dimension',
  'IPEDS completions can preserve award level');
select ok((select relrowsecurity from pg_class
           where oid='public.catalog_official_demand_observations'::regclass),
  'P1 evidence rows are protected by RLS');
select ok((select relrowsecurity from pg_class
           where oid='public.catalog_official_demand_imports'::regclass),
  'P1 import provenance is protected by RLS');
select ok(not has_table_privilege('anon',
  'public.catalog_official_demand_observations','SELECT'),
  'Anonymous users cannot read unreviewed numeric evidence');
select ok(not has_table_privilege('authenticated',
  'public.catalog_official_demand_observations','SELECT'),
  'Authenticated learners cannot read unreviewed numeric evidence');
select ok(not has_table_privilege('authenticated',
  'public.catalog_official_demand_imports','SELECT'),
  'Import provenance does not leak to client API');
select ok(has_table_privilege('service_role',
  'public.catalog_official_demand_observations','INSERT'),
  'Trusted admin ingestion can populate P1 evidence');
select throws_ok(
  $$ insert into public.catalog_official_demand_observations
  (taxonomy_system,taxonomy_version,taxonomy_code,metric,metric_value,
  metric_unit,period,dimension,publisher,source_release,source_url,source_sha256,method_note)
  values ('cip','2020','11.0701','bls_annual_openings_thousands',123,
  'thousands_of_jobs','2025-2035','all','BLS_EMP','BLS_EMP_2025_2035',
  'https://www.bls.gov/emp/',repeat('a',64),
  'This must be rejected as an invalid academic-to-labor inference.') $$,
  '23514', NULL,
  'A CIP academic code cannot masquerade as BLS labor-market openings'
);

select * from finish();
rollback;
