-- ANA-001A: demonstrate the actual deployed legacy progress failures.
-- These assertions verify WHY the current writers cannot be salvaged by
-- a blind retry. They do not change any hosted data or approve a new schema.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(7);

-- Synthetic users and a real legacy lesson (inside a rolled-back transaction).
insert into auth.users(id,email) values
  ('a9000000-0000-4000-8000-000000000001','ana001a_profile@example.invalid'),
  ('a9000000-0000-4000-8000-000000000002','ana001a_no_profile@example.invalid')
on conflict (id) do nothing;
insert into public.users(id,email,display_name) values
  ('a9000000-0000-4000-8000-000000000001','ana001a_profile@example.invalid','ANA-001A owner')
on conflict (id) do nothing;
delete from public.users where id='a9000000-0000-4000-8000-000000000002';
insert into public.lessons(id,title,user_id) values
  ('a9000000-0000-4000-8000-000000000003','ANA-001A real UUID lesson',
   'a9000000-0000-4000-8000-000000000001')
on conflict (id) do nothing;

select throws_ok(
  $$ insert into public.user_progress (user_id, lesson_id, study_mode)
     values ('a9000000-0000-4000-8000-000000000001',
             'a9000000-0000-4000-8000-000000000003','lesson') $$,
  '42703', null, 'StudyNotifier study_mode does not exist remotely');

select throws_ok(
  $$ insert into public.user_progress (user_id, lesson_id, content_id)
     values ('a9000000-0000-4000-8000-000000000001',
             'a9000000-0000-4000-8000-000000000003','any') $$,
  '42703', null, 'Local UserProgress content_id is not a remote column');

select throws_ok(
  $$ insert into public.user_progress (user_id, lesson_id, last_position)
     values ('a9000000-0000-4000-8000-000000000001',
             'a9000000-0000-4000-8000-000000000003',1) $$,
  '42703', null, 'Local UserProgress last_position is not a remote column');

select throws_ok(
  $$ insert into public.user_progress (user_id, lesson_id, metadata)
     values ('a9000000-0000-4000-8000-000000000001',
             'a9000000-0000-4000-8000-000000000003','{}'::jsonb) $$,
  '42703', null, 'Local UserProgress metadata is not a remote column');

select throws_ok(
  $$ insert into public.user_progress (id,user_id,lesson_id)
     values ('a9000000_lesson_1730000000000',
             'a9000000-0000-4000-8000-000000000001',
             'a9000000-0000-4000-8000-000000000003') $$,
  '22P02', null, 'Synthetic Hive record ID is not a valid server UUID');

select throws_ok(
  $$ insert into public.user_progress (user_id,lesson_id)
     values ('a9000000-0000-4000-8000-000000000001','prog_01_variables') $$,
  '22P02', null, 'Bundled asset lesson filename ID cannot enter legacy UUID FK');

select throws_ok(
  $$ insert into public.user_progress (user_id,lesson_id)
     values ('a9000000-0000-4000-8000-000000000002',
             'a9000000-0000-4000-8000-000000000003') $$,
  '23503', null, 'Auth account missing public.users profile breaks legacy user FK');

select * from finish();
rollback;
