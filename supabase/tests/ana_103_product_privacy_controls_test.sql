-- ANA-103: consent status, export pagination, eligibility reclassification,
-- account privacy, retention visibility, per-user rate-limit serialization.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(30);

-- Tests explicitly emulate a separately approved release. The default gate
-- stays OFF in production and this synthetic change is rolled back.
UPDATE analytics.product_release_gate
 SET approved_policy_version='pgtap-ana103-v1',
     policy_approved_at=now(), reviewed_by='synthetic-test-owner',
     collection_enabled=true WHERE id=1;

INSERT INTO auth.users(id,email,is_anonymous,raw_app_meta_data,raw_user_meta_data)
VALUES
('a1030000-0000-4000-8000-000000000001','ana103-unreviewed@example.invalid',false,'{}','{"product_analytics_eligible":true}'),
('a1030000-0000-4000-8000-000000000002','ana103-eligible@example.invalid',false,'{"product_analytics_eligible":true}','{}'),
('a1030000-0000-4000-8000-000000000003','ana103-guest@example.invalid',true,'{"product_analytics_eligible":true}','{}'),
('a1030000-0000-4000-8000-000000000004','ana103-other@example.invalid',false,'{"product_analytics_eligible":true}','{}')
ON CONFLICT (id) DO UPDATE SET
  is_anonymous=excluded.is_anonymous,
  raw_app_meta_data=excluded.raw_app_meta_data,
  raw_user_meta_data=excluded.raw_user_meta_data;

SELECT ok(NOT has_function_privilege('anon',
  'public.get_my_product_analytics_privacy_status()','EXECUTE'),
  'Anon cannot call privacy status');
SELECT ok(has_function_privilege('authenticated',
  'public.get_my_product_analytics_privacy_status()','EXECUTE'),
  'Signed in user can inspect server-stored consent');
SELECT ok(NOT has_function_privilege('anon',
  'public.export_my_product_events_page(timestamptz,uuid,integer)','EXECUTE'),
  'Anon cannot export events');
SELECT ok(NOT has_function_privilege('authenticated',
  'analytics.product_retention_health()','EXECUTE'),
  'Retention health is never exposed to browsers');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger
  WHERE tgname='trg_revoke_ineligible_product_analytics' AND NOT tgisinternal),
  'Eligibility revocation trigger is installed');
SELECT ok(EXISTS(SELECT 1 FROM pg_trigger
  WHERE tgname='trg_limit_product_event_insert_rate' AND NOT tgisinternal),
  'Concurrent insert rate guard is installed');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'a1030000-0000-4000-8000-000000000001',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'eligible','false',
  'Editable user_metadata cannot grant analytics eligibility');
SELECT is(public.get_my_product_analytics_privacy_status()->>'consented','false',
  'Unreviewed user is not opted in');
SELECT throws_ok($$ SELECT public.set_product_analytics_consent(true) $$,
  '42501',NULL,'Unreviewed user cannot grant own consent');

SELECT set_config('request.jwt.claim.sub',
  'a1030000-0000-4000-8000-000000000003',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'is_anonymous','true',
  'Guest status comes from trusted Auth row');
SELECT is(public.get_my_product_analytics_privacy_status()->>'eligible','false',
  'Guest remains ineligible even with trusted true flag');

SELECT set_config('request.jwt.claim.sub',
  'a1030000-0000-4000-8000-000000000002',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'eligible','true',
  'Reviewed permanent account is eligible');
SELECT is(public.get_my_product_analytics_privacy_status()->>'consented','false',
  'Eligibility alone does not imply consent');
SELECT is(public.get_my_product_analytics_privacy_status()->>'collection_active','true',
  'Synthetic test release is explicitly enabled; production default is off');
SELECT is((SELECT public.set_product_analytics_consent(true)->>'consented'),
  'true','Explicit opt-in persists on the server');
SELECT is(public.get_my_product_analytics_privacy_status()->>'consented','true',
  'Status reflects server-stored consent');

RESET ROLE;
-- Synthetic secondary account must also have an explicit current-policy
-- consent in order to exercise storage-level authorization.
INSERT INTO analytics.product_consents(user_id,consented)
VALUES ('a1030000-0000-4000-8000-000000000004',true)
ON CONFLICT (user_id) DO UPDATE SET consented=true;
-- Privileged fixture inserts deliberately bypass RPC; no user data is read.
-- Events are spaced 10 seconds apart so the 60/minute rate limit is respected.
INSERT INTO analytics.product_events
  (user_id,event_id,session_id,event_name,occurred_at_client,
   received_at,properties,payload_sha256)
SELECT 'a1030000-0000-4000-8000-000000000002'::uuid,
       ('a1030000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
       'a1030000-0000-4000-8000-000000000202'::uuid,
       'surface_viewed',now()-(i*interval '10 seconds'),
       now()-(i*interval '10 seconds'),
       '{"surface":"learn"}'::jsonb,'synthetic'||i::text
FROM generate_series(1,105) i;
INSERT INTO analytics.product_events
  (user_id,event_id,session_id,event_name,occurred_at_client,
   received_at,properties,payload_sha256)
VALUES
('a1030000-0000-4000-8000-000000000004',
 'a1030000-0000-4000-8000-000000000204',
 'a1030000-0000-4000-8000-000000000202',
 'surface_viewed',now(),now(),'{"surface":"library"}','other');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'a1030000-0000-4000-8000-000000000002',true);
CREATE TEMP TABLE ana103_first_page AS
SELECT public.export_my_product_events_page(
  NULL::timestamptz,NULL::uuid,100) AS payload;

SELECT is(jsonb_array_length((SELECT payload->'events' FROM ana103_first_page)),
  100,'First export page is capped at 100');
SELECT is((SELECT payload->>'has_more' FROM ana103_first_page),
  'true','Export supplies a continuation cursor when there are more rows');
SELECT is((SELECT payload->'events'->0->'properties'->>'surface'
  FROM ana103_first_page),'learn','Export contains only own allowlisted data');

CREATE TEMP TABLE ana103_second_page AS
SELECT public.export_my_product_events_page(
  (SELECT (payload->>'next_before_received_at')::timestamptz
   FROM ana103_first_page),
  (SELECT (payload->>'next_before_event_id')::uuid
   FROM ana103_first_page),100) AS payload;

SELECT is(jsonb_array_length((SELECT payload->'events' FROM ana103_second_page)),
  5,'Second page returns all remaining records without truncation');
SELECT is((SELECT payload->>'has_more' FROM ana103_second_page),
  'false','End of keyset export is explicit');
SELECT throws_ok(
  $$ SELECT public.export_my_product_events_page(
    now()::timestamptz,NULL::uuid,100) $$,
  '22023',NULL,'Missing half-cursor is rejected');
SELECT throws_ok(
  $$ SELECT public.export_my_product_events_page(
    NULL::timestamptz,NULL::uuid,101) $$,
  '22023',NULL,'Overlarge export pages are rejected');

-- The trusted eligibility flag can be revoked only in a privileged operation.
RESET ROLE;
UPDATE auth.users SET raw_app_meta_data='{}'::jsonb
WHERE id='a1030000-0000-4000-8000-000000000002';
SELECT is((SELECT count(*)::integer FROM analytics.product_events
  WHERE user_id='a1030000-0000-4000-8000-000000000002'),
  0,'Eligibility revocation erases every previously collected user event');
SELECT is((SELECT consented FROM analytics.product_consents
  WHERE user_id='a1030000-0000-4000-8000-000000000002'),
  false,'Eligibility revocation clears consent rather than preserving opt-in');
UPDATE auth.users
  SET raw_app_meta_data='{"product_analytics_eligible":true}'::jsonb
WHERE id='a1030000-0000-4000-8000-000000000002';
SELECT is((SELECT consented FROM analytics.product_consents
  WHERE user_id='a1030000-0000-4000-8000-000000000002'),
  false,'Becoming eligible again never auto-consents');

-- Retention operations are invisible to browser roles and report real counts.
SELECT ok((analytics.product_retention_health()->>'raw_events')::integer >= 1,
  'Privileged retention report shows stored events');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'a1030000-0000-4000-8000-000000000002',true);
SELECT is(public.get_my_product_analytics_privacy_status()->>'consented',
  'false','Post-revocation status remains opted out');
SELECT is(jsonb_array_length(
  public.export_my_product_events_page()->'events'),0,
  'Revoked account has no exportable events');
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY['{}'::jsonb]) $$,
  '42501',NULL,'Revoked consent blocks new product events');

SELECT * FROM finish();
ROLLBACK;
