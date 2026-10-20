-- pgTAP Cost Quotas & Observability Security Test Suite (ECO-00C Hardened)
-- Validates quota metering, abuse prevention (metadata size, storage boundaries, event limits),
-- STT seconds metering, defense-in-depth table permission revocations, tenant RLS isolation,
-- and administrator-only telemetry access.

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(37);

-- 1. Setup synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
  ('8f7c1a20-0000-4000-8000-000000000001', 'cost-admin@example.invalid'),
  ('8f7c1a20-0000-4000-8000-000000000002', 'cost-learner-a@example.invalid'),
  ('8f7c1a20-0000-4000-8000-000000000003', 'cost-learner-b@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email) values
  ('8f7c1a20-0000-4000-8000-000000000001', 'cost-admin@example.invalid'),
  ('8f7c1a20-0000-4000-8000-000000000002', 'cost-learner-a@example.invalid'),
  ('8f7c1a20-0000-4000-8000-000000000003', 'cost-learner-b@example.invalid')
on conflict (id) do nothing;

-- Provision cost-admin with admin role in moderation_roles
insert into public.moderation_roles (user_id, role, granted_by)
values ('8f7c1a20-0000-4000-8000-000000000001', 'admin', '8f7c1a20-0000-4000-8000-000000000001')
on conflict (user_id) do update set role = 'admin';

-- -----------------------------------------------------------------------------
-- Test Schema Presence
-- -----------------------------------------------------------------------------
select has_table('public', 'usage_quotas', 'Table public.usage_quotas exists');
select has_table('public', 'usage_events', 'Table public.usage_events exists');
select has_function('public', 'check_and_record_usage', Array['text', 'integer', 'text', 'jsonb'], 'RPC check_and_record_usage exists');
select has_function('public', 'get_system_usage_telemetry', Array['integer'], 'RPC get_system_usage_telemetry exists');

-- -----------------------------------------------------------------------------
-- Unauthenticated Access Checks (Fail-Closed)
-- -----------------------------------------------------------------------------
set local role anon;
select throws_ok(
  $$ select public.check_and_record_usage('ai_tokens', 100) $$,
  '42501',
  null,
  'Unauthenticated call to check_and_record_usage raises 42501'
);

select throws_ok(
  $$ select public.get_system_usage_telemetry(24) $$,
  '42501',
  null,
  'Unauthenticated call to get_system_usage_telemetry raises 42501'
);

-- -----------------------------------------------------------------------------
-- Learner A Parameter Validation & Abuse-Prevention Guards
-- -----------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '8f7c1a20-0000-4000-8000-000000000002', true);

-- Reject invalid quantity
select throws_ok(
  $$ select public.check_and_record_usage('ai_tokens', 0) $$,
  '22023',
  null,
  'Zero quantity rejected with 22023'
);

select throws_ok(
  $$ select public.check_and_record_usage('ai_tokens', -5) $$,
  '22023',
  null,
  'Negative quantity rejected with 22023'
);

-- Reject invalid service type
select throws_ok(
  $$ select public.check_and_record_usage('bitcoin_miner', 100) $$,
  '22023',
  null,
  'Unknown service type rejected with 22023'
);

-- Guard 1: Reject metadata payload exceeding 4KB
select throws_ok(
  $$ select public.check_and_record_usage('ai_tokens', 100, 'internal', jsonb_build_object('data', repeat('A', 5000))) $$,
  '22023',
  null,
  'Metadata payload > 4KB rejected with 22023'
);

-- Guard 2: Reject storage allocation under 1024 bytes (1 KB)
select throws_ok(
  $$ select public.check_and_record_usage('storage_bytes', 10) $$,
  '22023',
  null,
  'Storage request < 1024 bytes rejected with 22023'
);

-- -----------------------------------------------------------------------------
-- Learner A Usage Deductions
-- -----------------------------------------------------------------------------
-- First valid deduction (500 AI tokens)
select is(
  (public.check_and_record_usage('ai_tokens', 500)->>'allowed')::boolean,
  true,
  'Learner A initial 500 AI token request allowed'
);

select is(
  (public.check_and_record_usage('ai_tokens', 500)->>'remaining_balance')::int,
  14000, -- 15000 - 500 - 500 = 14000
  'Learner A balance decreased to 14,000 remaining tokens'
);

-- Verify event recorded in usage_events
select is(
  (select count(*)::int from public.usage_events where user_id = '8f7c1a20-0000-4000-8000-000000000002' and service_type = 'ai_tokens'),
  2,
  'Learner A has exactly 2 usage events recorded'
);

-- Test Quota Exceeded (Requesting 20,000 tokens when 14,000 remains)
select is(
  (public.check_and_record_usage('ai_tokens', 20000)->>'allowed')::boolean,
  false,
  'Learner A request exceeding quota balance is rejected (allowed = false)'
);

select is(
  (public.check_and_record_usage('ai_tokens', 20000)->>'remaining_balance')::int,
  14000,
  'Remaining balance unaffected by rejected request'
);

-- Event count unchanged after rejected request
select is(
  (select count(*)::int from public.usage_events where user_id = '8f7c1a20-0000-4000-8000-000000000002' and service_type = 'ai_tokens'),
  2,
  'No event inserted for rejected quota request'
);

-- Test Cloud TTS deduction (2,000 characters)
select is(
  (public.check_and_record_usage('tts_chars', 2000)->>'allowed')::boolean,
  true,
  'Learner A 2,000 TTS character deduction allowed'
);

select is(
  (select tts_chars_used_today from public.usage_quotas where user_id = '8f7c1a20-0000-4000-8000-000000000002'),
  2000,
  'Learner A tts_chars_used_today correctly incremented'
);

-- Test Cloud STT deduction (120 seconds)
select is(
  (public.check_and_record_usage('stt_seconds', 120)->>'allowed')::boolean,
  true,
  'Learner A 120 STT seconds deduction allowed'
);

select is(
  (public.check_and_record_usage('stt_seconds', 120)->>'remaining_balance')::int,
  3360, -- 3600 - 120 - 120 = 3360
  'Learner A STT seconds remaining is 3360'
);

-- Test valid storage allocation (2048 bytes >= 1024)
select is(
  (public.check_and_record_usage('storage_bytes', 2048)->>'allowed')::boolean,
  true,
  'Learner A 2048 bytes storage request allowed'
);

-- -----------------------------------------------------------------------------
-- Tenant Isolation (RLS Verification)
-- -----------------------------------------------------------------------------
-- Learner A can see own quota row
select is(
  (select count(*)::int from public.usage_quotas where user_id = '8f7c1a20-0000-4000-8000-000000000002'),
  1,
  'Learner A can select own quota row'
);

-- Switch to Learner B
select set_config('request.jwt.claim.sub', '8f7c1a20-0000-4000-8000-000000000003', true);

-- Learner B CANNOT see Learner A's quota row
select is(
  (select count(*)::int from public.usage_quotas where user_id = '8f7c1a20-0000-4000-8000-000000000002'),
  0,
  'Learner B cannot see Learner A quota row (RLS isolation)'
);

-- Learner B CANNOT see Learner A's usage events
select is(
  (select count(*)::int from public.usage_events where user_id = '8f7c1a20-0000-4000-8000-000000000002'),
  0,
  'Learner B cannot see Learner A usage events (RLS isolation)'
);

-- Learner B cannot call administrative telemetry
select throws_ok(
  $$ select public.get_system_usage_telemetry(24) $$,
  '42501',
  null,
  'Learner B cannot access get_system_usage_telemetry (42501)'
);

-- -----------------------------------------------------------------------------
-- Defense-in-Depth Table Write Revocation Verification
-- -----------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.usage_quotas (user_id) values ('8f7c1a20-0000-4000-8000-000000000003') $$,
  '42501',
  null,
  'Direct INSERT on usage_quotas by authenticated client denied (42501)'
);

select throws_ok(
  $$ update public.usage_quotas set ai_tokens_used_today = 0 where user_id = '8f7c1a20-0000-4000-8000-000000000003' $$,
  '42501',
  null,
  'Direct UPDATE on usage_quotas by authenticated client denied (42501)'
);

select throws_ok(
  $$ insert into public.usage_events (user_id, service_type, quantity) values ('8f7c1a20-0000-4000-8000-000000000003', 'ai_tokens', 100) $$,
  '42501',
  null,
  'Direct INSERT on usage_events by authenticated client denied (42501)'
);

-- -----------------------------------------------------------------------------
-- Administrator Telemetry & Global Visibility
-- -----------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '8f7c1a20-0000-4000-8000-000000000001', true);

-- Admin CAN see Learner A's quota row
select is(
  (select count(*)::int from public.usage_quotas where user_id = '8f7c1a20-0000-4000-8000-000000000002'),
  1,
  'Admin can inspect Learner A quota row'
);

-- Admin CAN see Learner A's usage events
select ok(
  (select count(*) from public.usage_events where user_id = '8f7c1a20-0000-4000-8000-000000000002') >= 3,
  'Admin can inspect Learner A usage events'
);

-- Admin can execute get_system_usage_telemetry
select ok(
  (public.get_system_usage_telemetry(24)->>'total_ai_tokens')::bigint >= 1000,
  'get_system_usage_telemetry returns aggregated AI tokens'
);

select ok(
  (public.get_system_usage_telemetry(24)->>'total_tts_chars')::bigint >= 2000,
  'get_system_usage_telemetry returns aggregated TTS characters'
);

select ok(
  (public.get_system_usage_telemetry(24)->>'total_stt_seconds')::bigint >= 240,
  'get_system_usage_telemetry returns aggregated STT seconds'
);

select ok(
  (public.get_system_usage_telemetry(24)->>'estimated_cost_usd')::numeric >= 0,
  'get_system_usage_telemetry returns estimated USD spend'
);

-- -----------------------------------------------------------------------------
-- Guard 3: Daily Event Frequency Limit Enforcement
-- -----------------------------------------------------------------------------
-- Reset to test runner role to simulate reaching daily event limit
reset role;

update public.usage_quotas
   set events_recorded_today = events_daily_limit
 where user_id = '8f7c1a20-0000-4000-8000-000000000002';

-- Switch back to Learner A
set local role authenticated;
select set_config('request.jwt.claim.sub', '8f7c1a20-0000-4000-8000-000000000002', true);

select throws_ok(
  $$ select public.check_and_record_usage('ai_tokens', 10) $$,
  '42900',
  null,
  'Request exceeding daily event frequency ceiling raises 42900'
);

-- -----------------------------------------------------------------------------
-- Rolling Daily Window Rollover Test
-- -----------------------------------------------------------------------------
-- Reset to test runner role to simulate window expiration (authenticated clients have no direct update permissions)
reset role;

update public.usage_quotas
   set window_reset_at = now() - interval '1 hour'
 where user_id = '8f7c1a20-0000-4000-8000-000000000002';

-- Switch back to Learner A
set local role authenticated;
select set_config('request.jwt.claim.sub', '8f7c1a20-0000-4000-8000-000000000002', true);

-- Call should trigger window rollover, resetting used counters and event counter
select is(
  (public.check_and_record_usage('ai_tokens', 100)->>'remaining_balance')::int,
  14900, -- 15000 - 100 = 14900 (previous usage wiped by window rollover)
  'Window rollover successfully reset daily counters to 0'
);

select * from finish();
rollback;
