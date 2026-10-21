begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(16);

select has_table('public','exam_part_practice_assignments',
 'Backend-issued question sets have a private assignment store');
select has_function('public','exm03_record_assigned_practice',
 array['uuid','jsonb'],'Canonical scoring transaction exists');
select has_function('public','exm03_erase_part_attempts',
 array['uuid','text'],'Owner atomic exact-part erasure exists');
select ok((select relrowsecurity from pg_class
 where oid='public.exam_part_practice_assignments'::regclass),
 'Private assignments enforce RLS');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_assignments','SELECT'),
 'Untrusted learners cannot enumerate assignments');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_assignments','INSERT'),
 'Untrusted learners cannot mint answer sets');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_attempts','INSERT'),
 'Untrusted learners cannot forge scored attempts');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_attempts','UPDATE'),
 'Attempt summaries cannot be edited by clients');
select ok(not has_table_privilege('authenticated',
 'public.exam_part_practice_attempts','DELETE'),
 'Direct deletion is blocked to prevent replay resurrection');
select ok(not has_function_privilege('authenticated',
 'public.exm03_record_assigned_practice(uuid,jsonb)','EXECUTE'),
 'Private grader not exposed to authenticated clients');
select ok(not has_function_privilege('anon',
 'public.exm03_record_assigned_practice(uuid,jsonb)','EXECUTE'),
 'Private grader not exposed to anon');
select ok(has_function_privilege('service_role',
 'public.exm03_record_assigned_practice(uuid,jsonb)','EXECUTE'),
 'Only backend service can use canonical scorer');
select ok(has_function_privilege('authenticated',
 'public.exm03_erase_part_attempts(uuid,text)','EXECUTE'),
 'Owners may request exact-part erasure through guarded RPC');
select throws_ok($q$
 select public.exm03_record_assigned_practice(null,'{}'::jsonb)
$q$,'22023',null,'Missing trusted assignment ID fails before writes');
select throws_ok($q$
 select public.exm03_record_assigned_practice(
 '00000000-0000-4000-8000-000000000001'::uuid,'{}'::jsonb)
$q$,'42501',null,'Unissued practice assignment cannot be scored');
select throws_ok($q$
 select public.exm03_erase_part_attempts(
 '00000000-0000-4000-8000-000000000001'::uuid,'part_a')
$q$,'42501',null,'Missing permanent JWT cannot erase practice history');
select * from finish();
rollback;
