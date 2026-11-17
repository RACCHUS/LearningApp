-- pgTAP: learning.study_reminders gate, owner isolation, server-computed
-- schedule, at-most-once dispatch and push-result bookkeeping.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(37);

insert into auth.users (id, email) values
 ('5e100000-0000-4000-8000-000000000001', 'rem1@example.invalid'),
 ('5e100000-0000-4000-8000-000000000002', 'rem2@example.invalid')
on conflict (id) do nothing;

select is(
  (select enabled from private.site_feature_controls
    where feature_key = 'learning.study_reminders'),
  false, 'learning.study_reminders is seeded OFF');
select is(
  (select release_ready from private.site_feature_controls
    where feature_key = 'learning.study_reminders'),
  true, 'learning.study_reminders is available for operator activation');

-- Schedule maths (pure helper, run as owner).
select is(
  private.next_study_reminder_fire('09:00', array[1]::smallint[], 'UTC',
                                   '2026-11-16 08:00+00'),   -- a Monday
  '2026-11-16 09:00+00'::timestamptz, 'same day when the time is still ahead');
select is(
  private.next_study_reminder_fire('09:00', array[1]::smallint[], 'UTC',
                                   '2026-11-16 09:00+00'),
  '2026-11-23 09:00+00'::timestamptz, 'strictly after: exactly now moves to next week');
select is(
  private.next_study_reminder_fire('09:00', array[3, 5]::smallint[], 'UTC',
                                   '2026-11-16 10:00+00'),
  '2026-11-18 09:00+00'::timestamptz, 'next listed weekday');
select is(
  private.next_study_reminder_fire('09:00', array[1,2,3,4,5,6,7]::smallint[],
                                   'America/New_York', '2026-11-16 12:00+00'),
  '2026-11-16 14:00+00'::timestamptz, 'local wall time in the reminder time zone');

set local role anon;
select throws_ok(
  $$ select public.save_study_reminder(null, '09:00', array[1]::smallint[], 'UTC') $$,
  '42501', null, 'anon cannot save reminders');

set local role authenticated;
select set_config('request.jwt.claim.sub', '5e100000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.save_study_reminder(null, '09:00', array[1]::smallint[], 'UTC') $$,
  '42501', 'feature_disabled', 'saving is refused while the gate is OFF');
select throws_ok(
  $$ select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/test-a',
       'p256dh-key-0123456789abcdef', 'auth-secret-01') $$,
  '42501', 'feature_disabled', 'registering a browser is refused while OFF');
select throws_ok(
  $$ select * from public.claim_due_study_reminders() $$,
  '42501', null, 'browsers cannot run the dispatcher');
select throws_ok(
  $$ insert into public.study_reminders (user_id, local_time, days_of_week, timezone)
     values ('5e100000-0000-4000-8000-000000000001', '09:00', array[1]::smallint[], 'UTC') $$,
  '42501', null, 'no direct browser writes to study_reminders');

reset role;
update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'learning.study_reminders';

set local role authenticated;
select set_config('request.jwt.claim.sub', '5e100000-0000-4000-8000-000000000001', true);

select throws_ok(
  $$ select public.save_study_reminder(null, '09:00', array[8]::smallint[], 'UTC') $$,
  '22023', 'invalid_days', 'weekdays must be 1..7');
select throws_ok(
  $$ select public.save_study_reminder(null, '09:00', array[]::smallint[], 'UTC') $$,
  '22023', 'invalid_days', 'at least one weekday');
select throws_ok(
  $$ select public.save_study_reminder(null, '09:00', array[1]::smallint[], 'Mars/Olympus') $$,
  '22023', 'invalid_timezone', 'unknown time zone is rejected');

select ok(
  (public.save_study_reminder(null, '09:00', array[1,1,3]::smallint[], 'UTC')
     ->>'next_fire_at') is not null,
  'a saved active reminder gets a server-computed next_fire_at');
select is(
  (select days_of_week from public.study_reminders limit 1),
  array[1, 3]::smallint[], 'weekdays are de-duplicated and sorted');

-- Only real Web Push services are accepted (matches the dispatcher check).
select throws_ok(
  $$ select public.register_push_subscription('https://attacker.example/collect',
       'p256dh-key-0123456789abcdef', 'auth-secret-01') $$,
  '22023', 'unsupported_push_service', 'arbitrary hosts are refused');
select throws_ok(
  $$ select public.register_push_subscription('http://fcm.googleapis.com/fcm/send/x',
       'p256dh-key-0123456789abcdef', 'auth-secret-01') $$,
  '22023', 'unsupported_push_service', 'plain http is refused');
select throws_ok(
  $$ select public.register_push_subscription('https://fcm.googleapis.com:8443/fcm/send/x',
       'p256dh-key-0123456789abcdef', 'auth-secret-01') $$,
  '22023', 'unsupported_push_service', 'a custom port is refused');
select throws_ok(
  $$ select public.register_push_subscription('https://user@fcm.googleapis.com/fcm/send/x',
       'p256dh-key-0123456789abcdef', 'auth-secret-01') $$,
  '22023', 'unsupported_push_service', 'user info in the URL is refused');
reset role;
select ok(
  private.is_trusted_push_endpoint('https://wns2-par02p.notify.windows.com/w/?token=abc')
  and private.is_trusted_push_endpoint('https://web.push.apple.com/QGuQ')
  and private.is_trusted_push_endpoint('https://updates.push.services.mozilla.com/wpush/v2/x'),
  'Windows, Apple and Mozilla push hosts are accepted');
select ok(
  not private.is_trusted_push_endpoint('https://fcm.googleapis.com.evil.example/x')
  and not private.is_trusted_push_endpoint(null),
  'look-alike hosts and null are refused');
set local role authenticated;
select set_config('request.jwt.claim.sub', '5e100000-0000-4000-8000-000000000001', true);

select public.register_push_subscription('https://fcm.googleapis.com/fcm/send/test-a',
  'p256dh-key-0123456789abcdef', 'auth-secret-01');
select is((select count(*)::int from public.push_subscriptions), 1,
  'the owner sees their registered browser');

-- Paused reminders have no next fire time.
select is(
  public.save_study_reminder((select id from public.study_reminders limit 1),
     '09:00', array[1]::smallint[], 'UTC', false)->>'next_fire_at',
  null::text, 'pausing clears next_fire_at');
select public.save_study_reminder((select id from public.study_reminders limit 1),
  '09:00', array[1]::smallint[], 'UTC', true);

-- Limit: five reminders per learner.
select public.save_study_reminder(null, '10:00', array[2]::smallint[], 'UTC');
select public.save_study_reminder(null, '11:00', array[2]::smallint[], 'UTC');
select public.save_study_reminder(null, '12:00', array[2]::smallint[], 'UTC');
select public.save_study_reminder(null, '13:00', array[2]::smallint[], 'UTC');
select throws_ok(
  $$ select public.save_study_reminder(null, '14:00', array[2]::smallint[], 'UTC') $$,
  '54000', 'reminder_limit', 'a sixth reminder is refused');

-- Another learner sees nothing and cannot edit or delete.
reset role;
select set_config('test.other_reminder', (select id::text from public.study_reminders
  where user_id = '5e100000-0000-4000-8000-000000000001' limit 1), true);
set local role authenticated;
select set_config('request.jwt.claim.sub', '5e100000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from public.study_reminders), 0, 'reminders are private');
select is((select count(*)::int from public.push_subscriptions), 0, 'subscriptions are private');
select throws_ok(
  format($$ select public.save_study_reminder(%L, '09:00', array[1]::smallint[], 'UTC') $$,
    current_setting('test.other_reminder')),
  'P0002', 'not_found', 'cannot edit another learner''s reminder');

-- Dispatch: make two of learner 1's reminders due (one on time, one stale).
reset role;
delete from public.study_reminders
 where user_id = '5e100000-0000-4000-8000-000000000001' and local_time > '10:00';
update public.study_reminders set next_fire_at = now() - interval '1 minute'
 where user_id = '5e100000-0000-4000-8000-000000000001' and local_time = '09:00';
update public.study_reminders set next_fire_at = now() - interval '2 hours'
 where user_id = '5e100000-0000-4000-8000-000000000001' and local_time = '10:00';

set local role service_role;
select is(
  (select count(*)::int from public.claim_due_study_reminders()),
  1, 'one push for the on-time reminder; the stale one is skipped');
select is(
  (select count(*)::int from public.claim_due_study_reminders()),
  0, 'a second run claims nothing (at most once)');
select ok(
  (select bool_and(next_fire_at > now()) from public.study_reminders
    where user_id = '5e100000-0000-4000-8000-000000000001'),
  'both reminders moved to their next occurrence');
select ok(
  (select last_sent_at is null from public.study_reminders
    where user_id = '5e100000-0000-4000-8000-000000000001' and local_time = '10:00'),
  'the skipped stale reminder is not marked sent');

-- Delivery bookkeeping.
select public.record_push_delivery(
  (select id from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/test-a'), 201);
select ok(
  (select last_success_at is not null from public.push_subscriptions
    where endpoint = 'https://fcm.googleapis.com/fcm/send/test-a'),
  '2xx records a success');
select public.record_push_delivery(
  (select id from public.push_subscriptions where endpoint = 'https://fcm.googleapis.com/fcm/send/test-a'), 410);
select is((select count(*)::int from public.push_subscriptions), 0,
  '410 Gone deletes the subscription');

-- Gate OFF: the dispatcher sends nothing even with due reminders.
reset role;
update public.study_reminders set next_fire_at = now() - interval '1 minute';
update private.site_feature_controls set enabled = false
 where feature_key = 'learning.study_reminders';
set local role service_role;
select is((select count(*)::int from public.claim_due_study_reminders()), 0,
  'gate OFF: the dispatcher claims nothing');

-- Learners can still delete with the gate OFF; data goes with the account.
set local role authenticated;
select set_config('request.jwt.claim.sub', '5e100000-0000-4000-8000-000000000001', true);
select public.delete_study_reminder(
  (select id from public.study_reminders where local_time = '10:00'));
select is((select count(*)::int from public.study_reminders), 1,
  'delete works while the gate is OFF');
reset role;
delete from auth.users where id = '5e100000-0000-4000-8000-000000000001';
select is((select count(*)::int from public.study_reminders
            where user_id = '5e100000-0000-4000-8000-000000000001'), 0,
  'reminders are removed with the account');

select * from finish();
rollback;
