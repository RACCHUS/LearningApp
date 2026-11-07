-- Trusted Excel worker single-use processing lease contract.
-- Local/CI transaction only. No user files, host credentials or live deployment.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=public,extensions;
SELECT no_plan();

SELECT has_column('public','software_learning_attempts','processing_lease_id',
  'Attempt has an opaque processing lease');
SELECT has_column('public','software_learning_attempts','artifact_sha256',
  'Attempt can hold digest of privately ingested workbook');
SELECT has_column('public','software_learning_attempts','provisional_status',
  'Provisional assessment is distinct from trusted evidence');
SELECT has_function('software_learning_private','sl_claim_excel_processing',
  ARRAY['uuid','uuid','uuid']::text[],'Atomic backend-only claim exists');
SELECT has_function('software_learning_private','sl_complete_excel_processing',
  ARRAY['uuid','text','text','text']::text[],'One-time provisional completion exists');
SELECT has_function('software_learning_private','sl_fail_excel_processing',
  ARRAY['uuid']::text[],'Backend can finalize failed claims without reopening uploads');
SELECT ok(NOT has_function_privilege('authenticated',
  'software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)','EXECUTE'),
  'Clients cannot claim a processing lease');
SELECT ok(NOT has_function_privilege('anon',
  'software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)','EXECUTE'),
  'Anonymous clients cannot claim processing leases');
SELECT ok(NOT has_schema_privilege('authenticated','software_learning_private','USAGE'),
  'Private service functions remain outside the client data API');
SELECT ok(has_function_privilege('service_role',
  'software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)','EXECUTE'),
  'Backend service role may claim a processing lease');

INSERT INTO auth.users(id,email) VALUES
 ('ba510000-0000-4000-8000-000000000001','sl-processing-a@example.invalid'),
 ('ba510000-0000-4000-8000-000000000002','sl-processing-b@example.invalid')
ON CONFLICT(id) DO NOTHING;
INSERT INTO auth.sessions(id,user_id) VALUES
 ('ba520000-0000-4000-8000-000000000001','ba510000-0000-4000-8000-000000000001'),
 ('ba520000-0000-4000-8000-000000000002','ba510000-0000-4000-8000-000000000002')
ON CONFLICT(id) DO NOTHING;

SET LOCAL ROLE authenticated;
DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
   'ba510000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba510000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba520000-0000-4000-8000-000000000001"}',true);
END $jwt$;
CREATE TEMP TABLE sl_processing_attempt AS
 SELECT (public.sl_issue_excel_budget_attempt()->>'attempt_id')::uuid AS id;
CREATE TEMP TABLE sl_second_attempt AS
 SELECT (public.sl_issue_excel_budget_attempt()->>'attempt_id')::uuid AS id;
RESET ROLE;
UPDATE public.software_learning_attempts SET upload_enabled=true
 WHERE id=(SELECT id FROM sl_processing_attempt);

SET LOCAL ROLE service_role;
SELECT is(
 software_learning_private.sl_claim_excel_processing(
   (SELECT id FROM sl_processing_attempt),
   'ba510000-0000-4000-8000-000000000002'::uuid,
   'ba520000-0000-4000-8000-000000000002'::uuid),
 NULL::jsonb, 'Cross-owner claim fails without disclosing expected inputs');
SELECT is(
 software_learning_private.sl_claim_excel_processing(
   (SELECT id FROM sl_processing_attempt),
   'ba510000-0000-4000-8000-000000000001'::uuid,
   'ba520000-0000-4000-8000-000000000099'::uuid),
 NULL::jsonb, 'Unknown or revoked session cannot claim another attempt');

CREATE TEMP TABLE sl_processing_claim AS
 SELECT software_learning_private.sl_claim_excel_processing(
   (SELECT id FROM sl_processing_attempt),
   'ba510000-0000-4000-8000-000000000001'::uuid,
   'ba520000-0000-4000-8000-000000000001'::uuid) AS response;

SELECT ok((SELECT (response->>'lease_id')::uuid IS NOT NULL
           FROM sl_processing_claim),'Worker gets server-issued one-time lease');
SELECT is((SELECT response->>'exercise_id' FROM sl_processing_claim),
 'excel-budget-total-v1','Exercise is pinned by backend');
SELECT is((SELECT response->>'checker_version' FROM sl_processing_claim),
 '1','Checker version is pinned by backend');
SELECT is((SELECT count(*)::integer FROM sl_processing_claim,
           jsonb_object_keys(response->'expected_inputs')),
 8,'Private expected inputs are returned only to service processor');
SELECT is((SELECT status FROM public.software_learning_attempts
           WHERE id=(SELECT id FROM sl_processing_attempt)),
 'processing','Claim atomically transitions issued attempt to processing');
SELECT is((SELECT upload_enabled FROM public.software_learning_attempts
           WHERE id=(SELECT id FROM sl_processing_attempt)),
 false,'Claim closes further authenticated uploads');
SELECT is(
 software_learning_private.sl_claim_excel_processing(
   (SELECT id FROM sl_processing_attempt),
   'ba510000-0000-4000-8000-000000000001'::uuid,
   'ba520000-0000-4000-8000-000000000001'::uuid),
 NULL::jsonb,'Duplicate/replayed claim is denied');

SELECT is(software_learning_private.sl_complete_excel_processing(
   'ba540000-0000-4000-8000-000000000099'::uuid,
   repeat('a',64),'pass','Correctly computed'),
 false,'Guessed lease cannot complete grading');
SELECT is(software_learning_private.sl_complete_excel_processing(
   (SELECT (response->>'lease_id')::uuid FROM sl_processing_claim),
   'bad-digest','pass','Correctly computed'),
 false,'Malformed workbook hash cannot be stored');
SELECT is(software_learning_private.sl_complete_excel_processing(
   (SELECT (response->>'lease_id')::uuid FROM sl_processing_claim),
   repeat('a',64),'verified','Incorrect trust'),
 false,'Backend rejects attempts to store verified status');
SELECT is(software_learning_private.sl_complete_excel_processing(
   (SELECT (response->>'lease_id')::uuid FROM sl_processing_claim),
   repeat('a',64),'pass','Correctly computed'),
 true,'First valid completion stores provisional result');
SELECT is(software_learning_private.sl_complete_excel_processing(
   (SELECT (response->>'lease_id')::uuid FROM sl_processing_claim),
   repeat('a',64),'pass','Correctly computed'),
 false,'Second completion cannot overwrite grade');
SELECT is((SELECT status FROM public.software_learning_attempts
           WHERE id=(SELECT id FROM sl_processing_attempt)),
 'processed','Completed attempt no longer accepts work');
SELECT is((SELECT provisional_status FROM public.software_learning_attempts
           WHERE id=(SELECT id FROM sl_processing_attempt)),
 'pass','Provisional result is recorded without skill award');
SELECT ok((SELECT artifact_sha256=repeat('a',64)
  FROM public.software_learning_attempts
  WHERE id=(SELECT id FROM sl_processing_attempt)),
 'Canonical digest stored as audit provenance, not grade proof');
SELECT is(software_learning_private.sl_fail_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_processing_claim)),
 false,'Late fail callback cannot overwrite a completed grade');

RESET ROLE;
UPDATE public.software_learning_attempts SET upload_enabled=true
 WHERE id=(SELECT id FROM sl_second_attempt);
SET LOCAL ROLE service_role;
CREATE TEMP TABLE sl_processing_second_claim AS
 SELECT software_learning_private.sl_claim_excel_processing(
   (SELECT id FROM sl_second_attempt),
   'ba510000-0000-4000-8000-000000000001'::uuid,
   'ba520000-0000-4000-8000-000000000001'::uuid) AS response;
SELECT is(software_learning_private.sl_fail_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_processing_second_claim)),
 true,'Failed processing transitions attempt to final failed state');
SELECT is(software_learning_private.sl_fail_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_processing_second_claim)),
 false,'Repeated failure is idempotent');
SELECT is((SELECT upload_enabled FROM public.software_learning_attempts
           WHERE id=(SELECT id FROM sl_second_attempt)),
 false,'Failed processing cannot reopen an upload');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
