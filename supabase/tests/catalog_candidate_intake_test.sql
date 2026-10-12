begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(11);

select has_table('public', 'catalog_intake_candidates',
  'Private candidate review queue exists');
select has_table('public', 'catalog_intake_demand_signals',
  'Private demand observations exist');
select has_column('public', 'catalog_intake_candidates', 'review_status',
  'Candidates distinguish unpublished review state');
select has_column('public', 'catalog_intake_candidates', 'publication_status',
  'Candidate publication separately gated');
select has_column('public', 'catalog_intake_demand_signals', 'observed_period',
  'Demand evidence records period');

select ok((select relrowsecurity from pg_class
           where oid='public.catalog_intake_candidates'::regclass),
  'Candidate RLS enabled');
select ok((select relrowsecurity from pg_class
           where oid='public.catalog_intake_demand_signals'::regclass),
  'Demand evidence RLS enabled');

select ok(not has_table_privilege('anon', 'public.catalog_intake_candidates', 'SELECT'),
  'Anon cannot read the review queue');
select ok(not has_table_privilege('authenticated', 'public.catalog_intake_candidates', 'SELECT'),
  'Authenticated learners cannot read unverified candidates');
select ok(not has_table_privilege('authenticated', 'public.catalog_intake_demand_signals', 'SELECT'),
  'Raw demand evidence cannot leak through user API');
select ok(has_table_privilege('service_role', 'public.catalog_intake_candidates', 'INSERT'),
  'Privileged admin ingestion remains permitted');

select * from finish();
rollback;
