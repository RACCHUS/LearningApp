-- ANA-103: operational retention and transaction-level rate enforcement.
-- All identifiers are synthetic, and the entire fixture is rolled back.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(9);

-- Only a synthetic, rolled-back fixture may activate the release latch.
UPDATE analytics.product_release_gate
 SET approved_policy_version='pgtap-ana103-retention-v1',
     policy_approved_at=now(), reviewed_by='synthetic-test-owner',
     collection_enabled=true WHERE id=1;

INSERT INTO auth.users(id,email,is_anonymous,raw_app_meta_data)
VALUES
('a1031000-0000-4000-8000-000000000001','ana103-retain@example.invalid',false,'{}'),
('a1031000-0000-4000-8000-000000000002','ana103-bounded@example.invalid',false,'{}')
ON CONFLICT (id) DO NOTHING;

-- Test fixtures are intentionally opted in for synthetic storage tests.
INSERT INTO analytics.product_consents(user_id,consented) VALUES
 ('a1031000-0000-4000-8000-000000000001',true),
 ('a1031000-0000-4000-8000-000000000002',true)
ON CONFLICT (user_id) DO UPDATE SET consented=true;

SELECT ok(has_function_privilege('service_role',
 'analytics.purge_expired_product_events()','EXECUTE'),
 'Service role can run reviewed retention function');
SELECT ok(NOT has_function_privilege('authenticated',
 'analytics.purge_expired_product_events()','EXECUTE'),
 'Browser cannot execute retention purge');
SELECT ok(NOT has_function_privilege('authenticated',
 'analytics.product_retention_health()','EXECUTE'),
 'Browser cannot inspect retention table health');

INSERT INTO analytics.product_events(
 user_id,event_id,session_id,event_name,occurred_at_client,
 received_at,properties,payload_sha256)
VALUES
('a1031000-0000-4000-8000-000000000001',
 'a1031000-0000-4000-8000-000000000101',
 'a1031000-0000-4000-8000-000000000201','surface_viewed',
 now()-interval '91 days',now()-interval '91 days',
 '{"surface":"learn"}','old'),
('a1031000-0000-4000-8000-000000000001',
 'a1031000-0000-4000-8000-000000000102',
 'a1031000-0000-4000-8000-000000000201','surface_viewed',
 now(),now(),'{"surface":"learn"}','fresh');

SELECT is((analytics.product_retention_health()->>'expired_events')::integer,
 1,'Retention health identifies overdue raw events');
SELECT is(analytics.purge_expired_product_events(),1,
 '90-day maintenance deletes only overdue raw events');
SELECT is((SELECT count(*)::integer FROM analytics.product_events
 WHERE user_id='a1031000-0000-4000-8000-000000000001'),
 1,'Fresh events are retained following purge');
SELECT is((analytics.product_retention_health()->>'expired_events')::integer,
 0,'Verified retention health reports no overdue rows');

-- Simulate concurrent/bursty writes to a single user (without using RPC).
-- The row trigger must enforce at most 60 accepted records per minute.
INSERT INTO analytics.product_events(
 user_id,event_id,session_id,event_name,occurred_at_client,
 received_at,properties,payload_sha256)
SELECT 'a1031000-0000-4000-8000-000000000002'::uuid,
 ('a1031000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'a1031000-0000-4000-8000-000000000202'::uuid,
 'surface_viewed',now(),now(), '{"surface":"learn"}','limit'||i::text
FROM generate_series(1,60) i;

SELECT throws_ok($$
 INSERT INTO analytics.product_events(
 user_id,event_id,session_id,event_name,occurred_at_client,
 received_at,properties,payload_sha256)
 VALUES (
 'a1031000-0000-4000-8000-000000000002',
 'a1031000-0000-4000-8000-000000000061',
 'a1031000-0000-4000-8000-000000000202',
 'surface_viewed',now(),now(),'{"surface":"learn"}','61st')
$$,'22023',NULL,'61st event is rejected even through trusted write path');
SELECT is((SELECT count(*)::integer FROM analytics.product_events
 WHERE user_id='a1031000-0000-4000-8000-000000000002'),
 60,'No event beyond the user per-minute cap was inserted');

SELECT * FROM finish();
ROLLBACK;
