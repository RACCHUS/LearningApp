begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(14);

select ok(exists(select 1 from pg_constraint
 where conrelid='public.learning_targets'::regclass
  and conname='learning_targets_target_type_check'
  and pg_get_constraintdef(oid) like '%professional_license%'),
 'Existing target type constraint explicitly includes professional license');

select ok(exists(select 1 from pg_constraint
 where conrelid='public.learning_targets'::regclass
  and conname='learning_targets_professional_license_jurisdiction_check'),
 'License jurisdiction check is enforced in database');

select throws_ok(
 $fixture$insert into public.learning_targets
 (target_type,title,slug,status,is_public)
 values ('professional_license','Missing Jurisdiction Test','p2c-test-no-jurisdiction','draft',false)$fixture$,
 '23514',null,'Cannot create license without jurisdiction');

select throws_ok(
 $fixture$insert into public.learning_targets
 (target_type,title,slug,jurisdiction,status,is_public)
 values ('professional_license','Invalid Jurisdiction Test','p2c-test-wrong-jurisdiction',
 'Florida','draft',false)$fixture$,
 '23514',null,'Rejects unstructured professional-license jurisdiction');

select lives_ok(
 $fixture$insert into public.learning_targets
 (target_type,title,slug,jurisdiction,status,is_public)
 values ('professional_license','Florida License Test','p2c-test-fl-license',
 'US-FL','draft',false)$fixture$,
 'Well-formed Florida professional-license draft is accepted');

select ok(exists(select 1 from pg_policies
 where schemaname='public' and tablename='catalog_destination_goal_links'
  and policyname='destination_goal_links_owner_insert'
  and with_check like '%jurisdiction%'),
 'Owner link INSERT checks exact professional-license jurisdiction');

select ok((select relrowsecurity from pg_class
 where oid='public.catalog_destination_goal_links'::regclass),
 'Private goal source associations retain RLS');
select ok(not has_table_privilege('anon',
 'public.catalog_destination_goal_links','SELECT'),
 'Anonymous users cannot read any user goal source association');

select ok(exists(select 1 from pg_constraint
 where conrelid='public.catalog_destination_resources'::regclass
  and pg_get_constraintdef(oid) like '%regulator_license_checklist%'),
 'Regulator checklist is supported as an external resource kind');

insert into public.catalog_intake_candidates
(source_namespace,source_key,destination_type,title,issuer_name,issuer_url,
 source_url,jurisdiction,review_status,publication_status,source_rights,verified_at)
values ('pgtestfl','test-license','professional_license','Florida License Test',
 'Florida Test Regulator','https://example.org/license','https://example.org/license',
 'US-FL','approved','published','approved_for_display',now());

insert into public.catalog_verified_destinations
(source_namespace,source_key,destination_type,title,issuer_name,jurisdiction,
 official_url,verification_note,verified_at)
values ('pgtestfl','test-license','professional_license','Florida License Test',
'Florida Test Regulator','US-FL','https://example.org/license',
'Test-only issuer identity verification; this record is never published into production.',now());

insert into public.catalog_destination_goal_links
(target_id,source_namespace,source_key)
select id,'pgtestfl','test-license' from public.learning_targets
where slug='p2c-test-fl-license';

select is((select count(*)::int from public.catalog_destination_goal_links
 where source_namespace='pgtestfl'),1,
 'Fixture links professional-license draft to matching reviewed issuer');

select throws_ok(
 $fixture$update public.learning_targets
 set jurisdiction='US-GA' where slug='p2c-test-fl-license'$fixture$,
 'P0001',null,'Cannot silently switch jurisdiction of an issuer-linked license');

select throws_ok(
 $fixture$update public.learning_targets
 set target_type='licensure_exam' where slug='p2c-test-fl-license'$fixture$,
 'P0001',null,'Cannot misclassify linked professional license as an exam');

select throws_ok(
 $fixture$update public.learning_targets
 set is_official=true where slug='p2c-test-fl-license'$fixture$,
 'P0001',null,'Cannot mark a linked personal goal as issuer-official');

select lives_ok(
 $fixture$update public.learning_targets
 set title='My Florida Sales Associate Study Goal'
 where slug='p2c-test-fl-license'$fixture$,
 'Learner may still edit personal goal title without altering its official source');

select * from finish();
rollback;
