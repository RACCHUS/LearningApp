-- pgTAP test for user_xp security, record_xp_award idempotency, semantic deduplication, and RLS write blockage
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(23);

-- 1. Create synthetic test users in auth.users
insert into auth.users (id, email) values
 ('ee111111-0000-4000-8000-000000000001', 'user1@example.invalid'),
 ('ee111111-0000-4000-8000-000000000002', 'user2@example.invalid')
on conflict (id) do nothing;

-- 2. Test unauthenticated call to increment_user_xp fails
set local role anon;
select throws_ok(
  $$ select increment_user_xp(10) $$,
  '42501',
  null,
  'Anon role cannot execute increment_user_xp'
);

-- 3. Test unauthenticated call to record_xp_award fails
select throws_ok(
  $$ select record_xp_award('11111111-1111-1111-1111-111111111111'::uuid, 'questionCorrect', 10) $$,
  '42501',
  null,
  'Anon role cannot execute record_xp_award'
);

-- 4. Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

-- 5. Authenticated user CANNOT execute increment_user_xp directly (service_role only)
select throws_ok(
  $$ select increment_user_xp(10) $$,
  '42501',
  null,
  'Authenticated role cannot execute increment_user_xp'
);

-- 6. Valid transactional XP award succeeds for own user
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'questionCorrect', 10, 'lesson-1', 'Correct answer') $$,
  'Authenticated user can award XP via record_xp_award'
);

select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  10,
  'User 1 total XP is 10 after award'
);

-- 7. Idempotency test: calling record_xp_award with same event_id does not double-award
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'questionCorrect', 10, 'lesson-1', 'Correct answer') $$,
  'Retrying same event_id executes safely'
);

select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  10,
  'User 1 total XP remains 10 (idempotent duplicate was ignored)'
);

-- 8. Server-side capping: questionCorrect requested with 999 XP is capped at 25 XP
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000002'::uuid, 'questionCorrect', 999, 'lesson-2', 'Tampered amount') $$,
  'Tampered XP amount is capped server-side'
);

select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  35,
  'User 1 total XP is 35 (10 + capped 25)'
);

-- 9. Semantic deduplication across casing aliases: lessonComplete vs lesson_complete
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 'lessonComplete', 50, 'lesson-alias', 'First completion') $$,
  'First lesson completion awards XP'
);
select is(
  (select (record_xp_award('aaaaaaaa-0000-0000-0000-000000000004'::uuid, 'lesson_complete', 50, 'lesson-alias', 'Duplicate attempt')->>'status')),
  'already_processed',
  'Casing alias (lesson_complete) cannot bypass semantic cooldown'
);

-- 10. Permanent achievement deduplication
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 'achievement', 100, 'badge-first-quiz', 'First Quiz') $$,
  'First achievement awards XP'
);
select is(
  (select (record_xp_award('aaaaaaaa-0000-0000-0000-000000000006'::uuid, 'achievement', 100, 'badge-first-quiz', 'Duplicate Quiz')->>'status')),
  'already_processed',
  'Permanent achievement deduplication blocks duplicate claims'
);

-- 11. Direct client INSERT on xp_events is rejected
select throws_ok(
  $$ insert into public.xp_events (id, user_id, event_type, xp_amount)
     values ('bbbbbbbb-0000-0000-0000-000000000001'::uuid, 'ee111111-0000-4000-8000-000000000001', 'questionCorrect', 100) $$,
  '42501',
  null,
  'Direct client INSERT into xp_events is rejected'
);

-- 12. Direct client UPDATE on user_xp is rejected
select throws_ok(
  $$ update public.user_xp set total_xp = 999999 where user_id = 'ee111111-0000-4000-8000-000000000001' $$,
  '42501',
  null,
  'Direct client UPDATE on user_xp is rejected'
);

-- 13. User 1 cannot view User 2 XP
do $$ begin
  -- create row for User 2 via service_role
  set local role service_role;
  insert into public.user_xp (user_id, total_xp) values ('ee111111-0000-4000-8000-000000000002', 100)
  on conflict (user_id) do update set total_xp = 100;
  
  -- switch back to User 1
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

select is(
  (select count(*)::integer from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000002'),
  0,
  'User 1 cannot view User 2 XP'
);

-- 14. service_role can increment XP with target user_id
set local role service_role;
select lives_ok(
  $$ select increment_user_xp(50, 'ee111111-0000-4000-8000-000000000001'::uuid) $$,
  'service_role can execute increment_user_xp with target user_id'
);

select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  235,
  'User 1 total XP reflects service_role increment (185 + 50 = 235)'
);

-- 15. Two different questions in the same lesson both succeed without collision
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000010'::uuid, 'question_correct', 10, 'lesson-multi:q-1', 'Question 1') $$,
  'Question 1 in lesson succeeds'
);

select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000011'::uuid, 'question_correct', 10, 'lesson-multi:q-2', 'Question 2') $$,
  'Question 2 in same lesson succeeds without collision'
);

-- 16. Retrying the same question with a fresh event ID triggers cooldown
select throws_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000012'::uuid, 'question_correct', 10, 'lesson-multi:q-1', 'Question 1 retry') $$,
  'P0001',
  null,
  'Retrying same question with new event ID triggers cooldown'
);

-- 17. Review session with context ID succeeds
select lives_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000013'::uuid, 'review_session', 20, 'review-session-test-alpha', 'Review session 1') $$,
  'Review session with context ID succeeds'
);

-- 18. Retrying the same review session with a fresh event ID triggers cooldown
select throws_ok(
  $$ select record_xp_award('aaaaaaaa-0000-0000-0000-000000000014'::uuid, 'review_session', 20, 'review-session-test-alpha', 'Review session 1 retry') $$,
  'P0001',
  null,
  'Retrying same review session context ID triggers cooldown'
);

select * from finish();
rollback;
