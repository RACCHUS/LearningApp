-- pgTAP: learning.xp_achievements gate, server-fixed activity XP, replay and
-- rate limits, and once-only server-derived achievements.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(24);

insert into auth.users (id, email) values
 ('ac400000-0000-4000-8000-000000000001', 'xp1@example.invalid'),
 ('ac400000-0000-4000-8000-000000000002', 'xp2@example.invalid'),
 ('ac400000-0000-4000-8000-000000000003', 'xp3@example.invalid')
on conflict (id) do nothing;

-- Registry: activated by owner approval (20261117230000). The OFF-path
-- checks below switch it off inside this rolled-back transaction.
select is(
  (select enabled and release_ready from private.site_feature_controls
    where feature_key = 'learning.xp_achievements'),
  true, 'learning.xp_achievements is activated (owner approval)');
update private.site_feature_controls set enabled = false
 where feature_key = 'learning.xp_achievements';

-- The browser cannot pass an amount: the only signature is (uuid, text, text).
select has_function('public', 'claim_activity_xp', array['uuid', 'text', 'text'],
  'claim_activity_xp takes no XP amount');

set local role anon;
select throws_ok(
  $$ select public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-a') $$,
  '42501', null, 'anon cannot claim XP');

-- Gate OFF: authenticated callers are refused with no side effect.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-a') $$,
  '42501', 'feature_disabled', 'claims are refused while the gate is OFF');
reset role;
select is((select count(*)::int from public.xp_events
            where user_id = 'ac400000-0000-4000-8000-000000000001'),
  0, 'gate OFF writes no XP');

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'learning.xp_achievements';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000001', true);

select throws_ok(
  $$ insert into public.user_achievements (user_id, achievement_key)
     values ('ac400000-0000-4000-8000-000000000001', 'lessons_50') $$,
  '42501', null, 'browsers cannot write achievements directly');

select throws_ok(
  $$ select public.claim_activity_xp(gen_random_uuid(), 'question_correct', 'q-1') $$,
  '22023', 'invalid_kind', 'only lesson_complete and review_session are claimable');
select throws_ok(
  $$ select public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', '  ') $$,
  '22023', 'invalid_source_id', 'blank source id is rejected');

-- First lesson: 50 XP and the first_lesson achievement.
select is(
  public.claim_activity_xp('ac400000-1111-4000-8000-000000000001', 'lesson_complete', 'lesson-a'),
  '{"status": "awarded", "awarded_xp": 50, "total_xp": 50, "new_achievements": ["first_lesson"]}'::jsonb,
  'first lesson awards server-fixed 50 XP and first_lesson');

select is(
  public.claim_activity_xp('ac400000-1111-4000-8000-000000000001', 'lesson_complete', 'lesson-a')->>'status',
  'already_processed', 'replaying the same event id awards nothing');
select is(
  (public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-a')->>'awarded_xp')::int,
  0, 'the same lesson again within 24 hours awards nothing');

select is(
  public.claim_activity_xp(gen_random_uuid(), 'review_session', 'session-1')->'new_achievements',
  '["first_review"]'::jsonb, 'first review session earns first_review');

select is((select total_xp from public.user_xp
            where user_id = 'ac400000-0000-4000-8000-000000000001'),
  75, 'total is 50 + 25');
select is((select count(*)::int from public.user_achievements),
  2, 'the learner sees their own two achievements');

-- Achievements are once-only.
select is(
  public.claim_activity_xp(gen_random_uuid(), 'review_session', 'session-2')->'new_achievements',
  '[]'::jsonb, 'first_review is not earned twice');

-- Another learner sees none of them.
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000002', true);
select is((select count(*)::int from public.user_achievements), 0,
  'achievements are private to their owner');
select is((select count(*)::int from public.xp_events), 0,
  'XP events are private to their owner');

-- Daily claim limit: 10 review sessions per 24 hours.
reset role;
insert into public.xp_events (id, user_id, event_type, xp_amount, source_id, earned_at)
select gen_random_uuid(), 'ac400000-0000-4000-8000-000000000002', 'review_session', 25,
       'seed-' || g, now() - interval '1 hour'
  from generate_series(1, 10) as g;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000002', true);
select is(
  public.claim_activity_xp(gen_random_uuid(), 'review_session', 'session-x')->>'status',
  'limit_reached', 'an eleventh review session in 24 hours earns nothing');
select is(
  public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-z')->>'status',
  'awarded', 'the review limit does not block lessons');

-- Rolling 2000 XP ceiling is respected before calling record_xp_award.
reset role;
insert into public.xp_events (id, user_id, event_type, xp_amount, source_id, earned_at)
values (gen_random_uuid(), 'ac400000-0000-4000-8000-000000000003', 'course_complete', 2000,
        'seed-ceiling', now() - interval '2 hours');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000003', true);
select is(
  public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-b')->>'status',
  'limit_reached', 'the 2000 XP rolling ceiling returns limit_reached instead of an error');

-- Derived thresholds: 10 distinct lessons and 7 active days.
reset role;
delete from public.xp_events where user_id = 'ac400000-0000-4000-8000-000000000003';
insert into public.xp_events (id, user_id, event_type, xp_amount, source_id, earned_at)
select gen_random_uuid(), 'ac400000-0000-4000-8000-000000000003', 'lesson_complete', 50,
       'old-lesson-' || g, now() - (g || ' days')::interval
  from generate_series(1, 9) as g;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000003', true);
select is(
  public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-new')->'new_achievements',
  '["active_days_7", "first_lesson", "lessons_10"]'::jsonb,
  'ten distinct lessons over ten days earn lessons_10 and active_days_7');

-- Turning the gate OFF again stops awards immediately.
reset role;
update private.site_feature_controls set enabled = false
 where feature_key = 'learning.xp_achievements';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ac400000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.claim_activity_xp(gen_random_uuid(), 'lesson_complete', 'lesson-c') $$,
  '42501', 'feature_disabled', 'switching the gate OFF stops awards');
select is((select total_xp from public.user_xp), 100, 'no XP was added after OFF (50 + 25 + 25)');
select is((select count(*)::int from public.user_achievements), 2,
  'existing achievements are kept when the gate is OFF');

select * from finish();
rollback;
