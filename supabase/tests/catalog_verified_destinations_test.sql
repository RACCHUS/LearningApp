begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;

select plan(11);

select has_table('public','catalog_verified_destinations','Minimal issuer-link public directory exists');
select ok((select relrowsecurity from pg_class
           where oid='public.catalog_verified_destinations'::regclass),
          'Directory has RLS enabled');
select ok(has_table_privilege('anon','public.catalog_verified_destinations','SELECT'),
          'Anonymous visitors may read approved issuer links');
select ok(has_table_privilege('authenticated','public.catalog_verified_destinations','SELECT'),
          'Signed-in learners may read approved issuer links');
select ok(not has_table_privilege('anon','public.catalog_verified_destinations','INSERT'),
          'Anonymous visitors cannot publish issuer links');
select ok(not has_table_privilege('authenticated','public.catalog_verified_destinations','UPDATE'),
          'Learners cannot alter reviewed metadata');

insert into public.catalog_intake_candidates
  (source_namespace,source_key,destination_type,title,issuer_name,issuer_url,
   source_url,jurisdiction)
values ('pgfixture','approved-test','certification','Example Training Certification',
'Example Test Issuer','https://example.org/certification',
'https://example.org/certification','US');

select throws_ok(
 $fixture$insert into public.catalog_verified_destinations
(source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,
 official_url,verification_note,verified_at)
values ('pgfixture','approved-test','certification','Example Training Certification',
'Example Test Issuer','US','https://example.org/certification',
'Only the credential identity and outbound issuer link are checked; no exam requirements.',now())$fixture$,
 'P0001',null,'Pending, unapproved candidate cannot be published');

update public.catalog_intake_candidates
set review_status='approved',publication_status='published',
    source_rights='approved_for_display',verified_at=now()
where source_namespace='pgfixture' and source_key='approved-test';

select lives_ok(
 $fixture$insert into public.catalog_verified_destinations
(source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,
 official_url,verification_note,verified_at)
values ('pgfixture','approved-test','certification','Example Training Certification',
'Example Test Issuer','US','https://example.org/certification',
'Only the credential identity and outbound issuer link are checked; no exam requirements.',now())$fixture$,
 'Admin-approved issuer identity may be published after review');
select is(
 (select requirements_status from public.catalog_verified_destinations
 where source_namespace='pgfixture' and source_key='approved-test'),
 'not_verified','Published link does not claim that exam eligibility was reviewed');

update public.catalog_intake_candidates set review_status='rejected',publication_status='retired'
where source_namespace='pgfixture' and source_key='approved-test';

select is(
 (select publication_status from public.catalog_verified_destinations
 where source_namespace='pgfixture' and source_key='approved-test'),
 'retired','Revoked source approval immediately retires the public listing');
select is(
 (select count(*)::integer from public.catalog_verified_destinations
 where publication_status='published' and source_namespace='pgfixture'),
 0,'Rejected issuer link cannot remain publicly published');

select * from finish();
rollback;
