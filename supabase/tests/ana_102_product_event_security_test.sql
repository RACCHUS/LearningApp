-- ANA-102: fully isolated synthetic eligibility, consent, RPC and admin tests.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(28);

-- Synthetic, transaction-local policy approval. Production defaults OFF.
UPDATE analytics.product_release_gate
 SET approved_policy_version='pgtap-ana102-v1',
     policy_approved_at=now(), reviewed_by='synthetic-test-owner',
     collection_enabled=true WHERE id=1;

INSERT INTO auth.users (id,email,is_anonymous,raw_app_meta_data) VALUES
('a1020000-0000-4000-8000-000000000001','ana102-admin@example.invalid',false,'{}'),
('a1020000-0000-4000-8000-000000000002','ana102-learner@example.invalid',false,'{"product_analytics_eligible":true}'),
('a1020000-0000-4000-8000-000000000003','ana102-guest@example.invalid',true,'{"product_analytics_eligible":true}'),
('a1020000-0000-4000-8000-000000000004','ana102-unreviewed@example.invalid',false,'{}')
ON CONFLICT (id) DO UPDATE SET
is_anonymous=excluded.is_anonymous,raw_app_meta_data=excluded.raw_app_meta_data;
INSERT INTO public.users(id,email) VALUES
('a1020000-0000-4000-8000-000000000001','ana102-admin@example.invalid')
ON CONFLICT (id) DO NOTHING;
INSERT INTO public.moderation_roles(id,user_id,role) VALUES
('a1020000-0000-4000-8000-000000000011',
'a1020000-0000-4000-8000-000000000001','admin'),
('a1020000-0000-4000-8000-000000000013',
'a1020000-0000-4000-8000-000000000003','admin')
ON CONFLICT (id) DO NOTHING;

SELECT ok(NOT has_schema_privilege('authenticated','analytics','USAGE'),
  'Browser roles cannot access raw analytics schema');
SELECT ok(NOT has_table_privilege('authenticated','analytics.product_events','SELECT'),
  'Browser roles cannot read raw events');
SELECT ok(NOT has_table_privilege('authenticated','analytics.product_events','INSERT'),
  'Browser roles cannot insert raw events');
SELECT ok(NOT has_table_privilege('authenticated','analytics.product_consents','UPDATE'),
  'Consent cannot be forged with direct DML');
SELECT ok(NOT has_function_privilege('anon',
  'public.record_product_events(jsonb[])','EXECUTE'),
  'No unauthenticated ingest access');
SELECT ok(has_function_privilege('authenticated',
  'public.record_product_events(jsonb[])','EXECUTE'),
  'Authenticated users can enter guarded RPC');
SELECT ok((SELECT prosecdef FROM pg_proc
  WHERE oid='public.record_product_events(jsonb[])'::regprocedure),
  'Ingestion is explicitly privileged');
SELECT is((SELECT proconfig[1] FROM pg_proc
  WHERE oid='public.record_product_events(jsonb[])'::regprocedure),
  'search_path=""','Privileged function pins empty search path');

SET LOCAL ROLE anon;
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY['{}'::jsonb]) $$,
  '42501',NULL,'Unauthenticated access denied by grant');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000004',true);
SELECT throws_ok($$ SELECT public.set_product_analytics_consent(true) $$,
  '42501',NULL,'Unreviewed account cannot consent');
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY['{}'::jsonb]) $$,
  '42501',NULL,'Unreviewed account cannot ingest');

SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$ SELECT public.set_product_analytics_consent(true) $$,
  '42501',NULL,'Anonymous Supabase Auth user cannot opt in');

SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY['{}'::jsonb]) $$,
  '42501',NULL,'No events allowed before opt in');
SELECT is((SELECT public.set_product_analytics_consent(true)->>'consented'),
  'true','Reviewed eligible account can consent');
SELECT is((SELECT public.record_product_events(ARRAY[
  jsonb_build_object('event_id','a1020000-0000-4000-8000-000000000101',
    'session_id','a1020000-0000-4000-8000-000000000102',
    'event_name','surface_viewed','schema_version',1,
    'occurred_at_client',now()::text,
    'properties',jsonb_build_object('surface','learn'))
  ])->'results'->0->>'status'),'accepted',
  'Valid categorical event accepted');
SELECT is((SELECT public.record_product_events(ARRAY[
  jsonb_build_object('event_id','a1020000-0000-4000-8000-000000000101',
    'session_id','a1020000-0000-4000-8000-000000000102',
    'event_name','surface_viewed','schema_version',1,
    'occurred_at_client',now()::text,
    'properties',jsonb_build_object('surface','learn'))
  ])->'results'->0->>'status'),'duplicate_noop',
  'Identical retry does not duplicate');
SELECT is((SELECT public.record_product_events(ARRAY[
  jsonb_build_object('event_id','a1020000-0000-4000-8000-000000000101',
    'session_id','a1020000-0000-4000-8000-000000000102',
    'event_name','surface_viewed','schema_version',1,
    'occurred_at_client',now()::text,
    'properties',jsonb_build_object('surface','library'))
  ])->'results'->0->>'status'),'idempotency_payload_mismatch',
  'Changed payload cannot reuse an event ID');
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY[
  jsonb_build_object('event_id','a1020000-0000-4000-8000-000000000111',
    'session_id','a1020000-0000-4000-8000-000000000112',
    'event_name','resource_search_submitted','schema_version',1,
    'occurred_at_client',now()::text,
    'properties',jsonb_build_object('raw_query','private thoughts'))]) $$,
  '22023',NULL,'Raw search terms are never accepted');
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY[
  jsonb_build_object('event_id','a1020000-0000-4000-8000-000000000113',
    'session_id','a1020000-0000-4000-8000-000000000114',
    'event_name','external_resource_clicked','schema_version',1,
    'occurred_at_client',now()::text,
    'properties',jsonb_build_object('provider_category','https://example.org'))]) $$,
  '22023',NULL,'URLs are rejected as dimensions');
SELECT is(jsonb_array_length(public.export_my_product_events(100)),1,
  'User portability exports their one accepted event');

SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000001',true);
SELECT is((SELECT public.get_product_analytics_overview(7)->>'status'),
  'small_cohort_suppressed','Admin must suppress cohorts smaller than five');
SELECT ok((SELECT public.get_product_analytics_overview(7)->'event_count')
  = 'null'::jsonb,'Small cohort counts cannot be recovered');

SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000003',true);
SELECT throws_ok($$ SELECT public.get_product_analytics_overview(7) $$,
  '42501',NULL,'Anonymous user denied even with an admin role');
SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000002',true);
SELECT throws_ok($$ SELECT public.get_product_analytics_overview(7) $$,
  '42501',NULL,'Normal learner cannot query admin aggregates');
SELECT is((SELECT public.set_product_analytics_consent(false)->>'consented'),
  'false','Consent withdrawal accepted');
SELECT is(jsonb_array_length(public.export_my_product_events(100)),0,
  'Opt-out erases raw events');
SELECT throws_ok($$ SELECT public.record_product_events(ARRAY['{}'::jsonb]) $$,
  '42501',NULL,'Further events denied after withdrawal');
SELECT set_config('request.jwt.claim.sub',
  'a1020000-0000-4000-8000-000000000001',true);
SELECT is((SELECT public.get_product_analytics_overview(7)->>'status'),
  'not_measured','No eligible events yields Not measured');
SELECT * FROM finish();
ROLLBACK;
