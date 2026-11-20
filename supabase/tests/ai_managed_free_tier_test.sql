-- pgTAP: ai.managed free Gemini generation. Gate OFF means zero admissions
-- (no provider call); caps per learner and shared; provider quota pause
-- until the next Pacific midnight; refunds; browser roles cannot admit,
-- refund or pause; status shows only the caller's own usage.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(29);

insert into auth.users (id, email) values
 ('a1000000-0000-4000-8000-000000000001', 'ai1@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002', 'ai2@example.invalid')
on conflict (id) do nothing;

select is(
  (select enabled from private.site_feature_controls where feature_key = 'ai.managed'),
  false, 'ai.managed is seeded OFF');
select is(
  (select release_ready from private.site_feature_controls where feature_key = 'ai.managed'),
  true, 'ai.managed is ready for owner activation');

-- Pacific day boundaries.
select is(private.ai_managed_day('2026-11-20 07:59+00'), '2026-11-19'::date,
  'before 08:00 UTC it is still the previous Pacific day (PST)');
select is(private.ai_managed_day('2026-11-20 08:00+00'), '2026-11-20'::date,
  'midnight Pacific starts the next day');
select is(private.ai_managed_next_reset('2026-11-20 12:00+00'),
  '2026-11-21 08:00+00'::timestamptz, 'next reset is the next Pacific midnight');

-- OFF: nothing admitted, nothing counted.
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') ->> 'code',
  'off', 'OFF refuses admission before any provider call');
select is((select count(*)::int from private.ai_managed_usage), 0,
  'OFF records no usage');

-- Browser roles cannot reach the service-only functions.
set local role anon;
select throws_ok($$ select public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') $$,
  '42501', null, 'anon cannot admit');
select throws_ok($$ select public.ai_managed_status() $$,
  '42501', null, 'anon cannot read status');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
select throws_ok($$ select public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') $$,
  '42501', null, 'a learner cannot admit themselves');
select throws_ok($$ select public.ai_managed_refund('a1000000-0000-4000-8000-000000000001') $$,
  '42501', null, 'a learner cannot refund');
select throws_ok($$ select public.ai_managed_record_quota_stop() $$,
  '42501', null, 'a learner cannot pause or unpause');
select throws_ok($$ select * from private.ai_managed_usage $$,
  '42501', null, 'no direct reads of usage');
select is(public.ai_managed_status() ->> 'enabled', 'false',
  'status says disabled while OFF');
reset role;

-- Switch ON (as the owner would), with small caps for the test.
update private.site_feature_controls set enabled = true where feature_key = 'ai.managed';
update private.ai_managed_settings set per_user_daily_limit = 2, shared_daily_limit = 3;

select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') ->> 'ok', 'true',
  'first request admitted');
select is((public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') ->> 'remaining_today')::int,
  0, 'second request admitted, none left');
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') ->> 'code',
  'user_limit', 'third request hits the learner cap');

-- A failed provider call is refunded.
select lives_ok($$ select public.ai_managed_refund('a1000000-0000-4000-8000-000000000001') $$,
  'refund runs');
select is((select requests from private.ai_managed_usage
           where user_id = 'a1000000-0000-4000-8000-000000000001'
             and usage_day = private.ai_managed_day()), 1, 'refund lowers the count');

-- Learner status shows only their own usage.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000002', true);
select is((public.ai_managed_status() ->> 'used_today')::int, 0,
  'another learner sees only their own count');
select is((public.ai_managed_status() ->> 'remaining_today')::int, 2,
  'and their own remaining requests');
reset role;

-- Shared cap: 1 (learner 1 after refund) + 2 (learner 2) = 3 = cap.
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000002') ->> 'ok', 'true',
  'learner 2 first request');
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000002') ->> 'ok', 'true',
  'learner 2 second request reaches the shared cap');
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000001') ->> 'code',
  'paused', 'the shared cap pauses everyone');
select is((select pause_reason from private.ai_managed_settings), 'shared_limit',
  'pause reason recorded');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-4000-8000-000000000001', true);
select is(public.ai_managed_status() ->> 'paused', 'true',
  'learners see the pause before asking');
reset role;

-- Provider quota stop pauses until the next Pacific midnight.
update private.ai_managed_settings set paused_until = null, pause_reason = null,
  shared_daily_limit = 100;
select is(public.ai_managed_record_quota_stop(), private.ai_managed_next_reset(),
  'quota stop pauses until the next reset');
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000002') ->> 'code',
  'paused', 'nothing is admitted while paused');

-- A pause from yesterday no longer blocks.
update private.ai_managed_settings set paused_until = now() - interval '1 minute';
update private.ai_managed_usage set requests = 0;
select is(public.ai_managed_admit('a1000000-0000-4000-8000-000000000002') ->> 'ok', 'true',
  'an expired pause lifts by itself');

select * from finish();
rollback;
