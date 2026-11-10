-- ANA-001B: idempotent learner progress without privileged UI writes.
-- All records are synthetic; entire pgTAP fixture rolls back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(28);

INSERT INTO auth.users(id,email) VALUES
 ('ab100000-0000-4000-8000-000000000001','ana001b-owner@example.invalid'),
 ('ab100000-0000-4000-8000-000000000002','ana001b-guest@example.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.users(id,email,display_name)
VALUES ('ab100000-0000-4000-8000-000000000001',
 'ana001b-owner@example.invalid','ANA-001B owner')
ON CONFLICT (id) DO NOTHING;
DELETE FROM public.users WHERE id='ab100000-0000-4000-8000-000000000002';
INSERT INTO public.lessons(id,title,user_id)
VALUES ('ab100000-0000-4000-8000-000000000003',
 'ANA-001B legacy UUID lesson','ab100000-0000-4000-8000-000000000001')
ON CONFLICT (id) DO NOTHING;

SELECT ok(NOT has_table_privilege('authenticated',
  'public.learner_activity_progress','INSERT'),
 'No direct authenticated progress-projection INSERT');
SELECT ok(NOT has_table_privilege('authenticated',
  'public.learner_activity_progress','UPDATE'),
 'No direct authenticated progress-projection UPDATE');
SELECT ok(NOT has_table_privilege('authenticated',
  'public.learner_activity_progress','DELETE'),
 'No direct authenticated progress-projection DELETE');
SELECT ok(NOT has_table_privilege('authenticated',
  'private.learner_progress_events','INSERT'),
 'Private event ledger is not browser-writable');
SELECT ok(has_function_privilege('authenticated',
  'public.record_learner_progress(jsonb[])','EXECUTE'),
 'Approved progress RPC remains authenticated');
SELECT ok(NOT has_function_privilege('anon',
  'public.record_learner_progress(jsonb[])','EXECUTE'),
 'Anonymous visitors cannot call the progress RPC');

SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.record_learner_progress(
  ARRAY['{}'::jsonb]) $$,'42501',NULL,
 'Unauthenticated RPC call denied');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
 'ab100000-0000-4000-8000-000000000001',true);

SELECT throws_ok(
 $$ INSERT INTO public.learner_activity_progress(
   user_id,content_kind,content_id,version_key,reporting_date_utc,completed)
 VALUES ('ab100000-0000-4000-8000-000000000001',
 'bundled_asset_lesson','prog_01_variables','unversioned',current_date,true) $$,
 '42501',NULL,'Own-user client cannot forge progress');

CREATE TEMP TABLE ana001b_completion AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-completion-1',
   'event_type','lesson_completed','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',now()::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_completion),'accepted',
 'Bundled filename lesson completion accepted');
SELECT is((SELECT completed FROM public.learner_activity_progress
  WHERE content_id='prog_01_variables'
    AND user_id='ab100000-0000-4000-8000-000000000001'),
 true,'Completed projection written for own user');
SELECT is((SELECT active_seconds FROM public.learner_activity_progress
  WHERE content_id='prog_01_variables'
    AND user_id='ab100000-0000-4000-8000-000000000001'),
 NULL::integer,'Completion alone does not fabricate time');

CREATE TEMP TABLE ana001b_replay AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-completion-1',
   'event_type','lesson_completed','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',now()::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_replay),'duplicate_noop',
 'Identical retry returns duplicate_noop');
SELECT is((SELECT count(*)::integer FROM private.learner_progress_events
  WHERE user_id='ab100000-0000-4000-8000-000000000001'
    AND idempotency_key='ana001b-completion-1'),
 1,'No duplicate event ledger insert on replay');

CREATE TEMP TABLE ana001b_mismatch AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-completion-1',
   'event_type','lesson_uncompleted','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',now()::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_mismatch),'idempotency_payload_mismatch',
 'Reused idempotency key with changed content is rejected');
SELECT is((SELECT completed FROM public.learner_activity_progress
  WHERE content_id='prog_01_variables'
    AND user_id='ab100000-0000-4000-8000-000000000001'),
 true,'Mismatched replay cannot reverse completion');

CREATE TEMP TABLE ana001b_interval_one AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-interval-1',
   'event_type','active_study_interval','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',(now()-interval '20 seconds')::text,
   'interval_start',(now()-interval '80 seconds')::text,
   'interval_end',(now()-interval '20 seconds')::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_interval_one),'accepted',
 'Valid 60-second active interval accepted');
SELECT is((SELECT active_seconds FROM public.learner_activity_progress
  WHERE content_id='prog_01_variables'
    AND user_id='ab100000-0000-4000-8000-000000000001'),
 60,'One valid active-study interval yields exactly 60 seconds');

CREATE TEMP TABLE ana001b_interval_two AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-interval-2',
   'event_type','active_study_interval','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',(now()-interval '10 seconds')::text,
   'interval_start',(now()-interval '60 seconds')::text,
   'interval_end',(now()-interval '10 seconds')::text)
 ]) AS payload;
SELECT is((SELECT active_seconds FROM public.learner_activity_progress
  WHERE content_id='prog_01_variables'
    AND user_id='ab100000-0000-4000-8000-000000000001'),
 70,'Overlapping device intervals count union, not sum');

SELECT throws_ok(
 $$ SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-oversized',
   'event_type','active_study_interval','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',now()::text,
   'interval_start',(now()-interval '121 seconds')::text,
   'interval_end',now()::text)
 ]) $$, '22023',NULL,
 'Server rejects intervals longer than 120 seconds');
SELECT throws_ok(
 $$ SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-forgery',
   'event_type','lesson_completed','content_kind','bundled_asset_lesson',
   'content_id','prog_01_variables','version_key','unversioned',
   'occurred_at',now()::text,
   'user_id','ab100000-0000-4000-8000-000000000002')
 ]) $$, '22023',NULL,
 'Client-supplied user identity is rejected as an unknown field');
SELECT throws_ok(
 $$ SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-bad-legacy',
   'event_type','lesson_completed','content_kind','legacy_lesson',
   'content_id','not-a-uuid','version_key','unversioned',
   'occurred_at',now()::text)
 ]) $$, '22023',NULL,
 'Bundled string cannot be passed as legacy lesson UUID');

-- Accept an actual legacy lesson under its UUID string.
CREATE TEMP TABLE ana001b_legacy AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-legacy-1',
   'event_type','lesson_completed','content_kind','legacy_lesson',
   'content_id','ab100000-0000-4000-8000-000000000003',
   'version_key','unversioned','occurred_at',now()::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_legacy),'accepted',
 'Existing legacy UUID lesson accepted by the canonical RPC');

-- Both guest and real accounts use auth.users IDs, not public.users.
SELECT set_config('request.jwt.claim.sub',
 'ab100000-0000-4000-8000-000000000002',true);
CREATE TEMP TABLE ana001b_guest AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-guest-1',
   'event_type','lesson_completed','content_kind','bundled_asset_lesson',
   'content_id','prog_02_control_flow','version_key','unversioned',
   'occurred_at',now()::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_guest),'accepted',
 'Guest without public.users row can persist owner-scoped progress');
SELECT is((SELECT count(*)::integer FROM public.learner_activity_progress
 WHERE user_id='ab100000-0000-4000-8000-000000000001'),
 0,'Second learner cannot see first learner progress under RLS');
SELECT is((SELECT count(*)::integer FROM public.learner_activity_progress
 WHERE user_id='ab100000-0000-4000-8000-000000000002'),
 1,'Guest can see only their progress');

-- Simulated UTC midnight crossing, with true interval union per UTC day.
SELECT set_config('request.jwt.claim.sub',
 'ab100000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE ana001b_midnight AS
 SELECT public.record_learner_progress(ARRAY[
  jsonb_build_object('idempotency_key','ana001b-midnight-1',
   'event_type','active_study_interval','content_kind','bundled_asset_lesson',
   'content_id','prog_03_functions','version_key','unversioned',
   'occurred_at',(date_trunc('day',now() AT TIME ZONE 'UTC')
     AT TIME ZONE 'UTC' + interval '20 seconds')::text,
   'interval_start',(date_trunc('day',now() AT TIME ZONE 'UTC')
     AT TIME ZONE 'UTC' - interval '20 seconds')::text,
   'interval_end',(date_trunc('day',now() AT TIME ZONE 'UTC')
     AT TIME ZONE 'UTC' + interval '20 seconds')::text)
 ]) AS payload;
SELECT is((SELECT payload->'results'->0->>'status'
  FROM ana001b_midnight),'accepted',
 'Cross-midnight UTC interval accepted (within server bounds)');
SELECT is((SELECT active_seconds FROM public.learner_activity_progress
 WHERE content_id='prog_03_functions'
 AND reporting_date_utc=(now() AT TIME ZONE 'UTC')::date - 1),
 20,'Previous UTC day receives first 20 seconds');
SELECT is((SELECT active_seconds FROM public.learner_activity_progress
 WHERE content_id='prog_03_functions'
 AND reporting_date_utc=(now() AT TIME ZONE 'UTC')::date),
 20,'Current UTC day receives last 20 seconds');

SELECT * FROM finish();
ROLLBACK;
