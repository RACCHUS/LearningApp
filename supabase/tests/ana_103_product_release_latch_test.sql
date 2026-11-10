-- A trusted eligible account and a client opt-in cannot bypass the
-- separately approved, default-off database release switch.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(10);

INSERT INTO auth.users(id,email,is_anonymous,raw_app_meta_data)
VALUES ('a1032000-0000-4000-8000-000000000001',
 'ana103-release@example.invalid',false,
 '{"product_analytics_eligible":true}')
ON CONFLICT(id) DO NOTHING;

SELECT is((SELECT collection_enabled FROM analytics.product_release_gate
 WHERE id=1),false,'A newly deployed analytics pipeline is OFF by default');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
 'a1032000-0000-4000-8000-000000000001',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'policy_ready',
 'false','No default policy authorization is advertised');
SELECT is(public.get_my_product_analytics_privacy_status()->>'collection_active',
 'false','Collection is not active immediately after deployment');
SELECT throws_ok($$ SELECT public.set_product_analytics_consent(true) $$,
 '42501',NULL,'Direct API opt-in is blocked before policy approval');

RESET ROLE;
-- Only a privileged, transaction-local synthetic test policy can proceed.
UPDATE analytics.product_release_gate SET
 approved_policy_version='synthetic-pgtap-v1',
 policy_approved_at=now(),reviewed_by='synthetic-test-owner',
 collection_enabled=true WHERE id=1;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
 'a1032000-0000-4000-8000-000000000001',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'policy_ready',
 'true','Explicitly approved fixture is reported as policy ready');
SELECT is((SELECT public.set_product_analytics_consent(true)->>'consented'),
 'true','An approved policy permits affirmative opt-in');
SELECT is((SELECT public.record_product_events(ARRAY[
 jsonb_build_object('event_id','a1032000-0000-4000-8000-000000000101',
  'session_id','a1032000-0000-4000-8000-000000000102',
  'event_name','surface_viewed','schema_version',1,
  'occurred_at_client',now()::text,
  'properties','{"surface":"learn"}'::jsonb)
 ])->'results'->0->>'status'),
 'accepted','Fully approved and consented synthetic event is accepted');

RESET ROLE;
UPDATE analytics.product_release_gate SET
 collection_enabled=false WHERE id=1;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
 'a1032000-0000-4000-8000-000000000001',true);
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY[
 jsonb_build_object('event_id','a1032000-0000-4000-8000-000000000103',
  'session_id','a1032000-0000-4000-8000-000000000102',
  'event_name','surface_viewed','schema_version',1,
  'occurred_at_client',now()::text,
  'properties','{"surface":"learn"}'::jsonb)]) $$,
 '42501',NULL,'Disabling the release blocks storage even after prior consent');

RESET ROLE;
UPDATE analytics.product_release_gate SET
 approved_policy_version='synthetic-pgtap-v2',
 policy_approved_at=now(),reviewed_by='synthetic-test-owner',
 collection_enabled=true WHERE id=1;
SELECT is((SELECT consented FROM analytics.product_consents
 WHERE user_id='a1032000-0000-4000-8000-000000000001'),
 false,'Changing disclosure version invalidates previous consent');
SELECT is((SELECT count(*)::integer FROM analytics.product_events
 WHERE user_id='a1032000-0000-4000-8000-000000000001'),
 0,'Policy version rotation erases previous-version raw events');

SELECT * FROM finish();
ROLLBACK;
