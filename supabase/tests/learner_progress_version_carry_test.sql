-- pgTAP: learner history survives a new curriculum version (migration
-- 20261121000000, plan P5.2). Synthetic fixture; everything rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

-- Deferred until commit in production; run it at statement end here.
set constraints public.trg_target_version_retired_carry immediate;

insert into auth.users(id, email) values
  ('c6000000-0000-4000-8000-000000000001', 'carry-learner@example.invalid')
on conflict (id) do nothing;
insert into public.learning_targets (id, target_type, title, slug) values
  ('c6000000-0000-4000-8000-000000000010', 'curriculum_standard', 'Carry Book', 'test-carry-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('c6000000-0000-4000-8000-000000000011', 'c6000000-0000-4000-8000-000000000010', 'R1', 'draft'),
  ('c6000000-0000-4000-8000-000000000012', 'c6000000-0000-4000-8000-000000000010', 'R2', 'draft'),
  ('c6000000-0000-4000-8000-000000000013', 'c6000000-0000-4000-8000-000000000010', 'R3', 'draft');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  ('c6000000-0000-4000-8000-000000000101', 'Percent', 'public', 'c6000000-0000-4000-8000-000000000011'),
  ('c6000000-0000-4000-8000-000000000102', 'Dropped', 'public', 'c6000000-0000-4000-8000-000000000011'),
  ('c6000000-0000-4000-8000-000000000201', 'Percent', 'public', 'c6000000-0000-4000-8000-000000000012'),
  ('c6000000-0000-4000-8000-000000000301', 'Percent', 'public', 'c6000000-0000-4000-8000-000000000013');

update public.target_versions set status = 'review_ready' where id = 'c6000000-0000-4000-8000-000000000011';
update public.target_versions set status = 'published' where id = 'c6000000-0000-4000-8000-000000000011';

-- The learner studied R1.
insert into public.learner_activity_progress
  (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
values
  ('c6000000-0000-4000-8000-000000000001', 'legacy_lesson', 'c6000000-0000-4000-8000-000000000101',
   'v1', date '2026-11-20', true, 300);

-- Corrected R2 is published and R1 retired.
update public.target_versions set status = 'review_ready' where id = 'c6000000-0000-4000-8000-000000000012';
update public.target_versions set status = 'published' where id = 'c6000000-0000-4000-8000-000000000012';
update public.target_versions set status = 'retired' where id = 'c6000000-0000-4000-8000-000000000011';

select is((select new_lesson_id from private.lesson_lineage
           where old_lesson_id = 'c6000000-0000-4000-8000-000000000101'),
  'c6000000-0000-4000-8000-000000000201'::uuid, 'retiring R1 links its lesson to the R2 lesson');
select ok(not exists (select 1 from private.lesson_lineage
                      where old_lesson_id = 'c6000000-0000-4000-8000-000000000102'),
  'a dropped section gets no link');
select is((select completed from public.learner_activity_progress
           where content_id = 'c6000000-0000-4000-8000-000000000201'),
  true, 'completion carries to the new lesson');
select is((select active_seconds from public.learner_activity_progress
           where content_id = 'c6000000-0000-4000-8000-000000000201'),
  300, 'study time carries to the new lesson');
select ok(exists (select 1 from public.learner_activity_progress
                  where content_id = 'c6000000-0000-4000-8000-000000000101'),
  'the old row stays as history');
select is((select public.lesson_replacement('c6000000-0000-4000-8000-000000000101')->>'replacement_id'),
  'c6000000-0000-4000-8000-000000000201', 'the replacement lookup uses the lineage');

-- Running the carry again changes nothing.
select private.carry_lessons_from_version('c6000000-0000-4000-8000-000000000011');
select is((select count(*)::int from public.learner_activity_progress
           where content_id = 'c6000000-0000-4000-8000-000000000201'),
  1, 'the carry is idempotent');

-- A late event from an offline device for the retired lesson.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c6000000-0000-4000-8000-000000000001', true);
create temp table late as select public.record_learner_progress(array[
  jsonb_build_object('idempotency_key', 'carry-late-1', 'event_type', 'active_study_interval',
    'content_kind', 'legacy_lesson', 'content_id', 'c6000000-0000-4000-8000-000000000101',
    'version_key', 'v1', 'occurred_at', now()::text,
    'interval_start', (now() - interval '2 minutes')::text, 'interval_end', now()::text)
]) as payload;
select is((select payload->'results'->0->>'status' from late), 'accepted', 'the late event is accepted');
reset role;
select is((select content_id from private.learner_progress_events where idempotency_key = 'carry-late-1'),
  'c6000000-0000-4000-8000-000000000201', 'and recorded against the new lesson');
select ok(exists (select 1 from public.learner_activity_progress
                  where content_id = 'c6000000-0000-4000-8000-000000000201'
                    and reporting_date_utc = (now() at time zone 'utc')::date),
  'so today''s progress lands on the new lesson');

-- A second correction: R3 replaces R2; links stay one hop.
update public.target_versions set status = 'review_ready' where id = 'c6000000-0000-4000-8000-000000000013';
update public.target_versions set status = 'published' where id = 'c6000000-0000-4000-8000-000000000013';
update public.target_versions set status = 'retired' where id = 'c6000000-0000-4000-8000-000000000012';
select is((select new_lesson_id from private.lesson_lineage
           where old_lesson_id = 'c6000000-0000-4000-8000-000000000101'),
  'c6000000-0000-4000-8000-000000000301'::uuid, 'the first lesson now points at R3');
select is((select new_lesson_id from private.lesson_lineage
           where old_lesson_id = 'c6000000-0000-4000-8000-000000000201'),
  'c6000000-0000-4000-8000-000000000301'::uuid, 'R2 points at R3');
select is((select completed from public.learner_activity_progress
           where content_id = 'c6000000-0000-4000-8000-000000000301' and reporting_date_utc = date '2026-11-20'),
  true, 'history carries through two corrections');

-- Nothing here is reachable from the browser.
select ok(not has_table_privilege('authenticated', 'private.lesson_lineage', 'select'),
  'learners cannot read the lineage table directly');
select ok(not has_function_privilege('authenticated', 'private.carry_lessons_from_version(uuid)', 'execute'),
  'learners cannot run the carry');
select ok(not has_function_privilege('authenticated', 'private.record_learner_progress_core(jsonb[])', 'execute'),
  'the unwrapped progress function is not callable directly');

select * from finish();
rollback;
