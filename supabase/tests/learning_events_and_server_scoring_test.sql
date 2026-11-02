-- ============================================================================
-- pgTAP tests for Architecture Phase 1:
-- learning_events, record_events RPC, FSRS projections, and server-side assessment scoring
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

-- 1. Create synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid'),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, username) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid', 'learner1'),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid', 'learner2')
on conflict (id) do nothing;

-- 2. Setup synthetic skill, assessment, and questions
insert into public.skills (id, name, slug, category, description) values
 ('dd111111-0000-4000-8000-000000000001', 'Phase 1 Core Skill', 'p1-core-skill', 'Engineering', 'Skill for server scoring test')
on conflict (id) do nothing;

insert into public.skill_assessments (id, skill_id, title, description, passing_score, time_limit_minutes, is_active) values
 ('dd222222-0000-4000-8000-000000000001', 'dd111111-0000-4000-8000-000000000001', 'P1 Benchmark Assessment', 'Benchmark for testing', 70, 10, true)
on conflict (id) do nothing;

insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer, explanation, order_index) values
 ('dd333333-0000-4000-8000-000000000001', 'dd222222-0000-4000-8000-000000000001', 'What is 2 + 2?', '["3", "4", "5", "6"]'::jsonb, 1, 'Two plus two equals four', 0),
 ('dd333333-0000-4000-8000-000000000002', 'dd222222-0000-4000-8000-000000000001', 'What is the capital of France?', '["London", "Berlin", "Paris", "Madrid"]'::jsonb, 2, 'Paris is the capital of France', 1)
on conflict (id) do nothing;

-- Setup synthetic review item for User 1
insert into public.review_items (id, user_id, content_id, content_type, lesson_id, title, stability, difficulty, fsrs_state) values
 ('dd444444-0000-4000-8000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'card-1', 'term', 'lesson-1', 'Term 1', 2.0, 5.0, 1)
on conflict do nothing;

-- 3. TEST: Anon cannot execute record_events
set local role anon;
select throws_ok(
  $$ select record_events(array['{"event_type":"review","item_id":"card-1"}'::jsonb]) $$,
  '42501',
  null,
  'Anon role cannot execute record_events'
);

-- 4. TEST: Anon cannot execute submit_and_grade_assessment
select throws_ok(
  $$ select submit_and_grade_assessment('dd222222-0000-4000-8000-000000000001'::uuid, '{"dd333333-0000-4000-8000-000000000001": 1}'::jsonb) $$,
  '42501',
  null,
  'Anon role cannot execute submit_and_grade_assessment'
);

-- 5. TEST: Anon CAN call get_assessment_questions_for_taking
select lives_ok(
  $$ select * from get_assessment_questions_for_taking('dd222222-0000-4000-8000-000000000001'::uuid) $$,
  'Anon can fetch questions for taking'
);

-- 6. TEST: Questions returned for taking DO NOT expose correct_answer column
select is(
  (select count(*) from information_schema.columns 
   where table_name = 'get_assessment_questions_for_taking' and column_name = 'correct_answer'),
  0::bigint,
  'get_assessment_questions_for_taking does not expose correct_answer column'
);

-- 7. Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- 8. TEST: Authenticated User 1 can record learning event
select lives_ok(
  $$ select record_events(array[
       jsonb_build_object(
         'id', 'ee000000-0000-4000-8000-000000000001',
         'event_type', 'review',
         'item_type', 'term',
         'item_id', 'card-1',
         'rating', 3,
         'score', 1.0,
         'scheduler_state_after', jsonb_build_object(
           'stability', 3.5,
           'difficulty', 4.8,
           'state', 2,
           'step', 0,
           'due', (now() + interval '3 days')::text
         )
       )
     ]) $$,
  'Authenticated user can execute record_events'
);

-- 9. TEST: learning_events has 1 row for User 1
select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  1,
  'learning_events recorded 1 row for User 1'
);

-- 10. TEST: review_items projection was updated by record_events
select is(
  (select stability from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  3.5,
  'review_items stability updated to 3.5 by record_events'
);

select is(
  (select fsrs_state from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  2::smallint,
  'review_items fsrs_state updated to 2 (Review) by record_events'
);

-- 11. TEST: Idempotency of record_events
select lives_ok(
  $$ select record_events(array[
       jsonb_build_object(
         'id', 'ee000000-0000-4000-8000-000000000001',
         'event_type', 'review',
         'item_type', 'term',
         'item_id', 'card-1'
       )
     ]) $$,
  'Replaying duplicate event_id executes safely without failure'
);

select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  1,
  'learning_events row count remains 1 (idempotent ON CONFLICT DO NOTHING)'
);

-- 12. TEST: Cross-user isolation on learning_events
-- Switch to User 2
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000002', true);
end $$;

select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  0,
  'User 2 cannot view User 1 learning events'
);

-- 13. Switch back to User 1 for assessment submission test
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- Submit answers: Q1=1 (correct), Q2=2 (correct) -> 100% score, passing >= 70%
select lives_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 1,
         'dd333333-0000-4000-8000-000000000002', 2
       ),
       120,
       false
     ) $$,
  'User 1 successfully submits assessment for server grading'
);

-- 14. TEST: Server-graded attempt was created with is_verified = TRUE
select is(
  (select is_verified from public.assessment_attempts 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
   order by created_at desc limit 1),
  true,
  'Server-graded assessment attempt has is_verified = TRUE'
);

-- 15. TEST: Server-graded attempt calculated 100% score
select is(
  (select score from public.assessment_attempts 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
   order by created_at desc limit 1),
  100,
  'Server-graded assessment attempt calculated score = 100'
);

-- 16. TEST: user_skill_stats now has is_verified = TRUE
select is(
  (select is_verified from public.user_skill_stats 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
     and skill_id = 'dd111111-0000-4000-8000-000000000001'),
  true,
  'user_skill_stats has is_verified = TRUE after server-graded attempt'
);

-- 17. TEST: Direct authenticated INSERT of is_verified = TRUE is downgraded to FALSE
select lives_ok(
  $$ insert into public.assessment_attempts (
       id, assessment_id, user_id, score, is_verified, is_deleted
     ) values (
       'ee999999-0000-4000-8000-000000000001'::uuid,
       'dd222222-0000-4000-8000-000000000001'::uuid,
       'cc111111-0000-4000-8000-000000000001'::uuid,
       100,
       true, -- forged attempt
       false
     ) $$,
  'Direct client insert executes'
);

select is(
  (select is_verified from public.assessment_attempts 
   where id = 'ee999999-0000-4000-8000-000000000001'),
  false,
  'Direct client attempt with is_verified=true was downgraded to FALSE by trigger'
);

-- 18. TEST: Non-existent assessment submission throws exception
select throws_ok(
  $$ select submit_and_grade_assessment(
       '00000000-0000-0000-0000-000000000000'::uuid,
       '{}'::jsonb
     ) $$,
  'Active assessment not found: 00000000-0000-0000-0000-000000000000',
  'Submitting non-existent assessment throws exception'
);

-- 19. TEST: Server-graded submission with wrong answers calculates correct score
select lives_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 0, -- wrong
         'dd333333-0000-4000-8000-000000000002', 2  -- right
       ),
       60,
       false
     ) $$,
  'Submitting partially correct assessment succeeds'
);

select is(
  (select score from public.assessment_attempts 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
   order by created_at desc limit 1),
  50,
  'Partial score correctly graded as 50%'
);

select * from finish();
rollback;

