-- Excel software-learning server issuance — owner/session/quota/erasure contract.
-- Transactional pgTAP regression; no hosted data changes.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT no_plan();

SELECT has_table('public','software_learning_attempts',
  'Provisional Excel attempts have owner-visible metadata');
SELECT has_table('software_learning_private','excel_attempt_inputs',
  'Server-owned per-attempt numeric inputs are not stored in public');
SELECT has_function('public','sl_issue_excel_budget_attempt',ARRAY[]::TEXT[],
  'Server-issued attempt RPC exists');
SELECT has_function('public','sl_delete_excel_budget_attempt',ARRAY['uuid'],
  'Owner-only erasure RPC exists');

SELECT ok((SELECT relrowsecurity FROM pg_class
 WHERE oid='public.software_learning_attempts'::regclass),
 'Attempt metadata uses RLS');
SELECT ok((SELECT relrowsecurity FROM pg_class
 WHERE oid='software_learning_private.excel_attempt_inputs'::regclass),
 'Expected-input records also use RLS for defense in depth');

SELECT ok(NOT has_function_privilege('anon',
 'public.sl_issue_excel_budget_attempt()','EXECUTE'),
 'Anonymous clients cannot issue Excel attempts');
SELECT ok(has_function_privilege('authenticated',
 'public.sl_issue_excel_budget_attempt()','EXECUTE'),
 'Authenticated clients can call the gated issuer');
SELECT ok(NOT has_table_privilege('authenticated',
 'public.software_learning_attempts','INSERT'),
 'Clients cannot create forged attempt records');
SELECT ok(NOT has_table_privilege('authenticated',
 'public.software_learning_attempts','UPDATE'),
 'Clients cannot change attempt metadata/status');
SELECT ok(NOT has_table_privilege('authenticated',
 'public.software_learning_attempts','DELETE'),
 'Clients cannot erase attempts bypassing the owner RPC');
SELECT ok(NOT has_schema_privilege('authenticated',
 'software_learning_private','USAGE'),
 'Authenticated clients cannot enter private input schema');
SELECT ok(NOT has_table_privilege('authenticated',
 'software_learning_private.excel_attempt_inputs','SELECT'),
 'Authenticated clients cannot read private input records');
SELECT ok(NOT has_table_privilege('anon',
 'public.software_learning_attempts','SELECT'),
 'Anonymous clients cannot list attempts');

INSERT INTO auth.users(id,email) VALUES
 ('ba310000-0000-4000-8000-000000000001','sl-learner-a@example.invalid'),
 ('ba310000-0000-4000-8000-000000000002','sl-learner-b@example.invalid')
ON CONFLICT(id) DO NOTHING;
INSERT INTO auth.sessions(id,user_id) VALUES
 ('ba320000-0000-4000-8000-000000000001','ba310000-0000-4000-8000-000000000001'),
 ('ba320000-0000-4000-8000-000000000002','ba310000-0000-4000-8000-000000000002')
ON CONFLICT(id) DO NOTHING;

SET LOCAL ROLE anon;
SELECT throws_ok($q$ SELECT public.sl_issue_excel_budget_attempt() $q$,
 '42501',NULL,'Anonymous role cannot call restricted issuer');

RESET ROLE;
SET LOCAL ROLE authenticated;
DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
   'ba310000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba310000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba320000-0000-4000-8000-000000000099"}',true);
END $jwt$;
SELECT throws_ok($q$ SELECT public.sl_issue_excel_budget_attempt() $q$,
 '42501',NULL,'Forged or revoked session cannot issue attempt');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba310000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba320000-0000-4000-8000-000000000001"}',true);
END $jwt$;

CREATE TEMP TABLE sl_issue_a AS SELECT public.sl_issue_excel_budget_attempt() AS response;
SELECT is((SELECT response->>'exercise_id' FROM sl_issue_a),
 'excel-budget-total-v1','Only the server-selected Excel pilot exercise is issued');
SELECT is((SELECT response->>'checker_version' FROM sl_issue_a),
 '1','Checker version is server-controlled and pinned');
SELECT is((SELECT response->>'status' FROM sl_issue_a),
 'issued','Issuer does not claim graded or verified success');
SELECT is((SELECT (SELECT count(*)::integer FROM jsonb_object_keys((SELECT response->'inputs' FROM sl_issue_a))) FROM sl_issue_a),
 8,'Server returns exactly eight synthetic transaction amounts');

SELECT is((SELECT count(*)::integer FROM public.software_learning_attempts),
 1,'Client sees only its issued attempt metadata');
SELECT is((SELECT count(*)::integer
   FROM public.software_learning_attempts a
   WHERE a.owner_id='ba310000-0000-4000-8000-000000000001'
      AND a.issued_session_id='ba320000-0000-4000-8000-000000000001'
      AND a.status='issued'
      AND a.expires_at>a.issued_at
      AND a.expires_at <= a.issued_at+interval '45 minutes'),
 1,'Attempt is bound to owner/session and short expiry');
SELECT is((SELECT jsonb_typeof(response->'inputs') FROM sl_issue_a),
 'object','Issued inputs are a machine-readable object');

CREATE TEMP TABLE sl_issue_a2 AS SELECT public.sl_issue_excel_budget_attempt() AS response;
SELECT isnt((SELECT response->>'attempt_id' FROM sl_issue_a),
 (SELECT response->>'attempt_id' FROM sl_issue_a2),
 'Every issuance receives a distinct server-generated attempt ID');
SELECT throws_ok($q$ SELECT public.sl_issue_excel_budget_attempt() $q$,
 '42501',NULL,'Concurrent active-attempt quota prevents unlimited issuance');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
   'ba310000-0000-4000-8000-000000000002',true);
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba310000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":false,"session_id":"ba320000-0000-4000-8000-000000000002"}',true);
END $jwt$;

SELECT is((SELECT count(*)::integer FROM public.software_learning_attempts),
 0,'Second learner cannot read the first learner attempts');
SELECT is(public.sl_delete_excel_budget_attempt(
 (SELECT (response->>'attempt_id')::uuid FROM sl_issue_a)),
 FALSE,'Second learner cannot erase someone else attempt');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claim.sub',
   'ba310000-0000-4000-8000-000000000001',true);
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba310000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false,"session_id":"ba320000-0000-4000-8000-000000000001"}',true);
END $jwt$;

SELECT is(public.sl_delete_excel_budget_attempt(
 (SELECT (response->>'attempt_id')::uuid FROM sl_issue_a)),
 TRUE,'Owner can erase their synthetic attempt');
SELECT is(public.sl_delete_excel_budget_attempt(
 (SELECT (response->>'attempt_id')::uuid FROM sl_issue_a)),
 FALSE,'Replayed deletion is an idempotent no-op');
SELECT is((SELECT count(*)::integer FROM public.software_learning_attempts),
 1,'Deleting one attempt preserves another owner attempt');
SELECT is((SELECT count(*)::integer FROM software_learning_private.excel_attempt_inputs),
 1,'Erasure cascades to private expected values');

DO $jwt$ BEGIN
 PERFORM set_config('request.jwt.claims',
   '{"sub":"ba310000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true,"session_id":"ba320000-0000-4000-8000-000000000001"}',true);
END $jwt$;
SELECT throws_ok($q$ SELECT public.sl_issue_excel_budget_attempt() $q$,
 '42501',NULL,'Temporary anonymous sign-in cannot use the privileged issuer');

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
