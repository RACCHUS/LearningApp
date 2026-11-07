-- Server-brokered, single-seal workbook admission and evidence trust boundary.
-- Disposable CI pgTAP only. No uploaded bytes, real users or production writes.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path=public,extensions;
SELECT no_plan();

SELECT has_column('public','software_learning_attempts','upload_sha256',
 'Uploaded file has server-held readback digest');
SELECT has_column('public','software_learning_attempts','upload_object_version',
 'Uploaded file has server-held object version');
SELECT has_column('public','software_learning_attempts','upload_committed_at',
 'Uploaded file has transactional seal timestamp');
SELECT has_function('software_learning_private','sl_lock_excel_upload',
 ARRAY['uuid','uuid','uuid']::text[], 'Backend lock RPC exists');
SELECT has_function('software_learning_private','sl_seal_excel_upload',
 ARRAY['uuid','uuid','uuid','text','text']::text[], 'Backend seal RPC exists');
SELECT ok(NOT has_function_privilege('authenticated',
 'software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)','EXECUTE'),
 'No learner may lock or inspect the private upload permit');
SELECT ok(NOT has_function_privilege('authenticated',
 'software_learning_private.sl_seal_excel_upload(uuid,uuid,uuid,text,text)','EXECUTE'),
 'No learner may seal or forge a workbook digest');
SELECT ok(has_function_privilege('service_role',
 'software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)','EXECUTE'),
 'Only trusted backend role may lock via the private session-check RPC');

SELECT ok(EXISTS(
 SELECT 1 FROM pg_policies p WHERE p.schemaname='storage'
  AND p.tablename='objects' AND p.policyname='sl_excel_insert_client_denied'
  AND p.cmd='INSERT' AND p.permissive='RESTRICTIVE'
 ), 'Learner Storage INSERT remains restricted regardless of upload flag');
SELECT is((SELECT count(*)::integer FROM pg_policies
 WHERE schemaname='storage' AND tablename='objects'
  AND policyname IN ('sl_excel_insert_owner','sl_excel_insert_enforce')),
 0, 'Old client-upload allow rules are not present');

INSERT INTO auth.users(id,email) VALUES
 ('ba610000-0000-4000-8000-000000000001','broker-a@example.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO auth.sessions(id,user_id) VALUES
 ('ba620000-0000-4000-8000-000000000001','ba610000-0000-4000-8000-000000000001')
ON CONFLICT(id) DO NOTHING;
SET LOCAL ROLE authenticated;
DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
 'ba610000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
 '{"sub":"ba610000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba620000-0000-4000-8000-000000000001"}',true);
END $jwt$;
CREATE TEMP TABLE sl_unsealed AS
 SELECT (public.sl_issue_excel_budget_attempt()->>'attempt_id')::uuid AS id;
GRANT SELECT ON sl_unsealed TO service_role;

RESET ROLE;
SET LOCAL ROLE service_role;
SELECT is(software_learning_private.sl_claim_excel_processing(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid),
 NULL::jsonb, 'Processing cannot claim an unsealed synthetic attempt');

RESET ROLE;
SELECT throws_ok($q$
 UPDATE public.software_learning_attempts SET upload_enabled=true
 WHERE id=(SELECT id FROM sl_unsealed)
$q$,'23514',NULL,'Broker seal is mandatory before upload readiness');

SELECT throws_ok($q$
 UPDATE public.software_learning_attempts
 SET upload_sha256='bad',upload_object_version='v1',
     upload_committed_at=now(), upload_enabled=true
 WHERE id=(SELECT id FROM sl_unsealed)
$q$,'23514',NULL,'Malformed broker SHA is rejected');

SET LOCAL ROLE service_role;
SELECT is(software_learning_private.sl_lock_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000099'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid),
 NULL::jsonb, 'Cross-account broker lock does not disclose an attempt');
CREATE TEMP TABLE sl_broker_lock AS
 SELECT software_learning_private.sl_lock_excel_upload(
  (SELECT id FROM sl_unsealed),
  'ba610000-0000-4000-8000-000000000001'::uuid,
  'ba620000-0000-4000-8000-000000000001'::uuid) AS response;
SELECT is((SELECT response->>'attempt_id' FROM sl_broker_lock),
 (SELECT id::text FROM sl_unsealed),
 'Private broker validates live session and obtains the attempt lock');
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 'bad','revision-1'),false,
 'Malformed broker digest cannot authorize processing');
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 repeat('a',64),repeat('v',257)),false,
 'Oversized object revision rejects cleanly without a PostgreSQL regex error');
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 repeat('a',64),'invalid/revision'),false,
 'Object revision whitelist rejects path-like values');
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 repeat('a',64),'revision-1'),true,
 'First valid service-side seal commits a synthetic workbook attestation');
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_unsealed),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 repeat('b',64),'revision-2'),false,
 'Replayed seal cannot overwrite the first workbook attestation');
CREATE TEMP TABLE sl_sealed_claim AS
 SELECT software_learning_private.sl_claim_excel_processing(
  (SELECT id FROM sl_unsealed),
  'ba610000-0000-4000-8000-000000000001'::uuid,
  'ba620000-0000-4000-8000-000000000001'::uuid
 ) AS response;
SELECT is((SELECT response->>'expected_sha256' FROM sl_sealed_claim),
 repeat('a',64), 'Claim carries server readback SHA');
SELECT is((SELECT response->>'object_version' FROM sl_sealed_claim),
 'revision-1', 'Claim pins sealed object revision');
SELECT is((SELECT response->>'can_award_skill' FROM sl_sealed_claim),
 'false', 'Broker seal does not grant mastery authority');
SELECT is(software_learning_private.sl_complete_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_sealed_claim),
 repeat('b',64),'pass','Wrong file'),
 false,'Wrong digest cannot complete even with a live processing lease');
SELECT is(software_learning_private.sl_complete_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_sealed_claim),
 repeat('a',64),'pass','Provisional feedback'),
 true,'Matching sealed digest can complete provisionally once');
SELECT is(software_learning_private.sl_complete_excel_processing(
 (SELECT (response->>'lease_id')::uuid FROM sl_sealed_claim),
 repeat('a',64),'pass','Provisional feedback'),
 false,'Processing lease remains single-use');
SELECT is((SELECT status FROM public.software_learning_attempts
 WHERE id=(SELECT id FROM sl_unsealed)), 'processed',
 'Only a sealed file can reach provisional processed state');

RESET ROLE;
CREATE TEMP TABLE sl_session_revoke_attempt AS SELECT gen_random_uuid() AS id;
GRANT SELECT ON sl_session_revoke_attempt TO service_role;
INSERT INTO public.software_learning_attempts
 (id,owner_id,issued_session_id,issued_at,expires_at)
SELECT id,'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 now(),now()+interval '45 minutes'
FROM sl_session_revoke_attempt;
SET LOCAL ROLE service_role;
SELECT ok(software_learning_private.sl_lock_excel_upload(
 (SELECT id FROM sl_session_revoke_attempt),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid) IS NOT NULL,
 'Before revocation a valid live session can lock an unsealed attempt');
RESET ROLE;
DELETE FROM auth.sessions
 WHERE id='ba620000-0000-4000-8000-000000000001'::uuid;
SET LOCAL ROLE service_role;
SELECT is(software_learning_private.sl_seal_excel_upload(
 (SELECT id FROM sl_session_revoke_attempt),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid,
 repeat('a',64),'revision-1'),false,
 'Revoked session cannot seal an in-flight upload');
SELECT is(software_learning_private.sl_lock_excel_upload(
 (SELECT id FROM sl_session_revoke_attempt),
 'ba610000-0000-4000-8000-000000000001'::uuid,
 'ba620000-0000-4000-8000-000000000001'::uuid),
 NULL::jsonb,
 'Revoked session cannot obtain a fresh upload lock');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
