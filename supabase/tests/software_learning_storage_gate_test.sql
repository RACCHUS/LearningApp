-- Excel pilot private Storage admission security contract.
-- Runs in disposable local Supabase as a transaction; never uploads bytes.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT no_plan();

SELECT has_column('public','software_learning_attempts','upload_enabled',
  'Upload eligibility is a server-controlled, default-off field');
SELECT is((SELECT column_default FROM information_schema.columns
  WHERE table_schema='public' AND table_name='software_learning_attempts'
    AND column_name='upload_enabled'), 'false',
  'Upload eligibility defaults false');
SELECT has_function('public','sl_excel_storage_upload_authorized',
  ARRAY['text'],'Owner/session/attempt-path authorization exists');
SELECT ok(NOT has_function_privilege('anon',
  'public.sl_excel_storage_upload_authorized(text)','EXECUTE'),
  'Anonymous clients cannot query the upload gate');
SELECT ok(has_function_privilege('authenticated',
  'public.sl_excel_storage_upload_authorized(text)','EXECUTE'),
  'Authenticated clients may call restricted upload gate');

SELECT ok(EXISTS (SELECT 1 FROM storage.buckets b
 WHERE b.id='learningapp-excel-private' AND b.name=b.id
   AND b.public IS FALSE
   AND b.file_size_limit = 10485760
   AND b.allowed_mime_types =
     ARRAY['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']::text[]),
 'Dedicated private Storage bucket has 10MiB and XLSX MIME cap');
SELECT is((SELECT count(*)::integer FROM pg_policies
 WHERE schemaname='storage' AND tablename='objects'
   AND policyname IN ('sl_excel_insert_client_denied','sl_excel_insert_anon_denied')),
  2, 'Storage INSERT uses only restrictive denials for learners');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies
 WHERE schemaname='storage' AND tablename='objects'
   AND policyname='sl_excel_insert_client_denied'
   AND permissive='RESTRICTIVE' AND cmd='INSERT'
   AND with_check NOT LIKE '%sl_excel_storage_upload_authorized%'),
 'Even explicit server-gate enablement cannot reopen direct browser INSERT');
SELECT ok(EXISTS (SELECT 1 FROM pg_policies
 WHERE schemaname='storage' AND tablename='objects'
   AND policyname='sl_excel_insert_anon_denied'
   AND permissive='RESTRICTIVE' AND cmd='INSERT'
   AND with_check NOT LIKE '%sl_excel_storage_upload_authorized%'),
 'Anon restrictive policy does not evaluate the authenticated-only gate function');
SELECT is((SELECT count(*)::integer FROM pg_policies
 WHERE schemaname='storage' AND tablename='objects'
   AND policyname IN ('sl_excel_deny_read','sl_excel_deny_update','sl_excel_deny_delete')
   AND permissive='RESTRICTIVE'), 3,
 'No client read, overwrite or delete of private Excel objects even under other policies');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger t
 WHERE t.tgrelid='public.software_learning_attempts'::regclass
   AND t.tgname='sl_excel_prevent_orphan_delete'
   AND NOT t.tgisinternal), 'Attempt deletion has orphaned-file guard');

INSERT INTO auth.users (id,email) VALUES
 ('ba410000-0000-4000-8000-000000000001','sl-upload-owner@example.invalid'),
 ('ba410000-0000-4000-8000-000000000002','sl-upload-other@example.invalid')
ON CONFLICT(id) DO NOTHING;
INSERT INTO auth.sessions (id,user_id) VALUES
 ('ba420000-0000-4000-8000-000000000001','ba410000-0000-4000-8000-000000000001'),
 ('ba420000-0000-4000-8000-000000000002','ba410000-0000-4000-8000-000000000002')
ON CONFLICT(id) DO NOTHING;
SET LOCAL ROLE authenticated;
DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
  'ba410000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
  '{"sub":"ba410000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba420000-0000-4000-8000-000000000001"}',true);
END $jwt$;

CREATE TEMP TABLE sl_upload_attempt AS
 SELECT public.sl_issue_excel_budget_attempt() AS response;
CREATE TEMP TABLE sl_upload_path AS
 SELECT 'ba410000-0000-4000-8000-000000000001/' ||
   (response->>'attempt_id') || '/workbook.xlsx' AS object_path,
   (response->>'attempt_id')::uuid AS attempt_id
 FROM sl_upload_attempt;

SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), FALSE,
 'Server-issued attempt cannot upload until privileged release gate is explicitly enabled');
SELECT is(public.sl_excel_storage_upload_authorized(
 'ba410000-0000-4000-8000-000000000001/not-an-attempt/workbook.xlsx'), FALSE,
 'Arbitrary owner prefix alone cannot authorize a workbook');
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path) || '/../other.xlsx'), FALSE,
 'Path traversal and variant filename are rejected');

RESET ROLE;
UPDATE public.software_learning_attempts a SET upload_enabled=TRUE,
 upload_sha256=repeat('a',64), upload_object_version='v1',
 upload_committed_at=now()
 WHERE a.id=(SELECT attempt_id FROM sl_upload_path);
SET LOCAL ROLE authenticated;
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), TRUE,
 'Legacy helper may see a valid sealed path, but restrictive Storage policy still denies client INSERT');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claims',
  '{"sub":"ba410000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba420000-0000-4000-8000-000000000099"}',true);
END $jwt$;
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), FALSE,
 'A guessed/revoked session cannot upload under an issued attempt');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
  'ba410000-0000-4000-8000-000000000002',true);
 PERFORM set_config('request.jwt.claims',
  '{"sub":"ba410000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false,"session_id":"ba420000-0000-4000-8000-000000000002"}',true);
END $jwt$;
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), FALSE,
 'Another authenticated learner cannot upload to the first learner attempt');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
  'ba410000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
  '{"sub":"ba410000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true,"session_id":"ba420000-0000-4000-8000-000000000001"}',true);
END $jwt$;
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), FALSE,
 'Authenticated anonymous guests cannot bypass permanent-account requirement');

RESET ROLE;
UPDATE public.software_learning_attempts a SET expires_at=now()-interval '1 second',
 issued_at=now()-interval '45 minutes'
 WHERE a.id=(SELECT attempt_id FROM sl_upload_path);
SET LOCAL ROLE authenticated;
DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claims',
  '{"sub":"ba410000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba420000-0000-4000-8000-000000000001"}',true);
END $jwt$;
SELECT is(public.sl_excel_storage_upload_authorized(
 (SELECT object_path FROM sl_upload_path)), FALSE,
 'Expired attempt denies upload even after privileged enablement');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
