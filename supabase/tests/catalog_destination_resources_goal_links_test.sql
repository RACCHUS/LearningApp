begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(11);

select has_table('public','catalog_destination_goal_links',
 'Private learner-to-reviewed-destination references exist');
select has_table('public','catalog_destination_resources',
 'Official preparation resources are outbound links only');
select ok((select relrowsecurity from pg_class where oid='public.catalog_destination_goal_links'::regclass),
 'Goal reference RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.catalog_destination_resources'::regclass),
 'Issuer resource RLS enabled');
select ok(not has_table_privilege('anon','public.catalog_destination_goal_links','SELECT'),
 'Anonymous learners cannot enumerate private goal links');
select ok(not has_table_privilege('anon','public.catalog_destination_goal_links','INSERT'),
 'Anonymous learners cannot write private goal links');
select ok(has_table_privilege('authenticated','public.catalog_destination_goal_links','INSERT'),
 'Authenticated learners may link their own private goals');
select ok(not has_table_privilege('authenticated','public.catalog_destination_goal_links','UPDATE'),
 'Learners cannot retarget an existing goal link');
select ok(has_table_privilege('anon','public.catalog_destination_resources','SELECT'),
 'Anonymous learners can inspect reviewed public issuer resources');
select ok(not has_table_privilege('authenticated','public.catalog_destination_resources','INSERT'),
 'Learners cannot forge issuer study resource endorsements');
select ok(exists(
 select 1 from pg_policies
 where schemaname='public' and tablename='catalog_destination_resources'
  and policyname='destination_resource_published_parent'
  and qual like '%publication_status%'),
 'Resource RLS requires its reviewed issuer parent to stay published');

select * from finish();
rollback;
