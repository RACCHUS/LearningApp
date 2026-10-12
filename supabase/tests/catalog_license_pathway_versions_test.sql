begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(15);

select has_table('public','catalog_license_pathway_versions',
  'Versioned state license pathway facts have a separate table');
select has_function('public','catalog_license_tree_valid',array['jsonb','integer'],
  'Regulator pathways must pass nested expression validation');
select ok((select relrowsecurity from pg_class where oid='public.catalog_license_pathway_versions'::regclass),
  'Pathway RLS is enabled');
select ok(has_table_privilege('anon','public.catalog_license_pathway_versions','SELECT'),
  'Anonymous readers can see vetted, current paths');
select ok(not has_table_privilege('authenticated','public.catalog_license_pathway_versions','INSERT'),
  'Learners cannot publish regulatory licensing rules');
select ok(not has_table_privilege('authenticated','public.catalog_license_pathway_versions','UPDATE'),
  'Learners cannot change regulatory rules');
select ok(not public.catalog_license_tree_valid(
  '{"op":"any","children":[{"op":"step","label":"Incomplete"}]}'::jsonb),
  'Malformed OR-group and uncited steps cannot enter');
select ok(public.catalog_license_tree_valid(
 '{"op":"any","children":[{"op":"step","label":"Complete recognized education","stage":"education","source_url":"https://example.org/state"},{"op":"step","label":"Qualifying education alternative","stage":"education","source_url":"https://example.org/other"}]}'::jsonb),
 'Reviewer can encode separately sourced alternative education routes');

insert into public.catalog_intake_candidates (
  source_namespace,source_key,destination_type,title,issuer_name,issuer_url,source_url,jurisdiction,
  review_status,publication_status,source_rights,verified_at
) values (
  'p2e_fixture','rn-test','professional_license','Example Florida Nursing License',
  'Example State Nursing Board','https://example.org/board',
  'https://example.org/board','US-FL',
  'approved','published','approved_for_display',now()
);
insert into public.catalog_verified_destinations (
  source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,
  official_url,verification_note,verified_at
) values (
  'p2e_fixture','rn-test','professional_license','Example Florida Nursing License',
  'Example State Nursing Board','US-FL','https://example.org/board',
  'The state board name and official link were verified for this disposable fixture only.',
  now()
);

select throws_ok(
  $fixture$insert into public.catalog_license_pathway_versions (
    source_namespace,source_key,revision,jurisdiction,title,overview,source_url,
    source_checked_at,pathway_tree,review_status,publication_status
  ) values (
    'p2e_fixture','rn-test',1,'US-FL','State nursing license checklist',
    'Selected source-backed steps for a testing-only pathway. This is not a full license eligibility evaluation.',
    'https://example.org/board',now(),
    '{"op":"all","children":[{"op":"step","label":"Complete approved education","stage":"education","source_url":"https://example.org/edu"},{"op":"step","label":"Complete background screening","stage":"background_screening","source_url":"https://example.org/check"}]}',
    'pending','published'
  )$fixture$,
  '23514',null,'Draft or unreviewed pathways cannot be published');

select lives_ok(
  $fixture$insert into public.catalog_license_pathway_versions (
    source_namespace,source_key,revision,jurisdiction,title,overview,source_url,
    source_checked_at,pathway_tree
  ) values (
    'p2e_fixture','rn-test',1,'US-FL','State nursing license checklist',
    'Selected source-backed steps for a testing-only pathway. This is not a full license eligibility evaluation.',
    'https://example.org/board',now(),
    '{"op":"all","children":[{"op":"step","label":"Complete approved education","stage":"education","source_url":"https://example.org/edu"},{"op":"step","label":"Complete background screening","stage":"background_screening","source_url":"https://example.org/check"}]}'
  )$fixture$,
  'Private unapproved pathway draft can be staged');

select lives_ok(
  $fixture$update public.catalog_license_pathway_versions
  set review_status='approved',reviewed_at=now(),reviewer='Regulatory QA',publication_status='published'
  where source_namespace='p2e_fixture' and source_key='rn-test'$fixture$,
  'Only reviewed, sourced, current pathway may become public');

select throws_ok(
  $fixture$update public.catalog_license_pathway_versions
  set overview='Changed after publication'
  where source_namespace='p2e_fixture' and source_key='rn-test'$fixture$,
  'P0001',null,'Published licensing content cannot be silently mutated');

set local role anon;
select is(
  (select count(*)::integer from public.catalog_license_pathway_versions where source_namespace='p2e_fixture'),
  1,'Public can see only approved linked current pathway');
reset role;

update public.catalog_intake_candidates
set review_status='rejected',publication_status='retired'
where source_namespace='p2e_fixture' and source_key='rn-test';

select is(
  (select publication_status from public.catalog_license_pathway_versions
    where source_namespace='p2e_fixture' and source_key='rn-test'),
  'retired','Revoking issuer immediately retires its pathway');
set local role anon;
select is(
  (select count(*)::integer from public.catalog_license_pathway_versions where source_namespace='p2e_fixture'),
  0,'Revoked issuer pathways are hidden for anonymous users');
reset role;

select * from finish();
rollback;
