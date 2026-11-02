-- ============================================================================
-- pgTAP tests for Architecture Phase 1:
-- learning_events, record_events RPC, FSRS projections, and server-side assessment scoring
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(24);

-- 1. Create synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
 ('cc111111-0000-4000-8000-000000000001', 'learner1@example.invalid'),
 ('cc111111-0000-4000-8000-000000000002', 'learner2@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name) values
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
insert into public.review_items (id, user_id, content_id, content_type, lesson_id, title, stability, difficulty, fsrs_state, total_reviews) values
 ('dd444444-0000-4000-8000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'card-1', 'term', 'lesson-1', 'Term 1', 2.0, 5.0, 1, 0)
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

-- 5. TEST: Anon cannot directly SELECT correct_answer from public.assessment_questions (FIX-12)
select throws_ok(
  $$ select correct_answer from public.assessment_questions $$,
  '42501',
  null,
  'Anon cannot directly SELECT correct_answer from public.assessment_questions'
);

-- 6. TEST: Anon cannot directly SELECT scoring_spec from public.assessment_items (FIX-12)
select throws_ok(
  $$ select scoring_spec from public.assessment_items $$,
  '42501',
  null,
  'Anon cannot directly SELECT scoring_spec from public.assessment_items'
);

-- 7. TEST: Anon CAN call get_assessment_questions_for_taking
select lives_ok(
  $$ select * from get_assessment_questions_for_taking('dd222222-0000-4000-8000-000000000001'::uuid) $$,
  'Anon can fetch questions for taking'
);

-- 8. TEST: Sanitized RPC response contains options and question_text
select is(
  (select count(*)::int from get_assessment_questions_for_taking('dd222222-0000-4000-8000-000000000001'::uuid)
   where question_text is not null and options is not null),
  2,
  'get_assessment_questions_for_taking returns valid sanitized question payload'
);

-- 9. Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- 10. TEST: Authenticated User 1 can record learning event with presented_order
select lives_ok(
  $$ select record_events(array[
       jsonb_build_object(
         'id', 'ee000000-0000-4000-8000-000000000001',
         'event_type', 'review',
         'item_type', 'term',
         'item_id', 'card-1',
         'rating', 3,
         'score', 1.0,
         'presented_order', jsonb_build_array(1, 0, 2, 3),
         'scheduler_state_after', jsonb_build_object(
           'stability', 3.5,
           'difficulty', 4.8,
           'state', 2,
           'step', 0,
           'total_reviews', 1,
           'correct_reviews', 1,
           'due', (now() + interval '3 days')::text
         )
       )
     ]) $$,
  'Authenticated user can execute record_events with presented_order'
);

-- 11. TEST: learning_events recorded 1 row and persisted presented_order
select is(
  (select presented_order from public.learning_events where id = 'ee000000-0000-4000-8000-000000000001'),
  array[1, 0, 2, 3]::smallint[],
  'learning_events correctly persisted presented_order array'
);

-- 12. TEST: review_items projection updated with FSRS values
select is(
  (select stability::numeric from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  3.5::numeric,
  'review_items stability updated to 3.5 by record_events'
);

select is(
  (select total_reviews::int from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews set to 1 by record_events'
);

-- 13. TEST: Idempotency of record_events - replaying duplicate does not re-increment projection
select lives_ok(
  $$ select record_events(array[
       jsonb_build_object(
         'id', 'ee000000-0000-4000-8000-000000000001',
         'event_type', 'review',
         'item_type', 'term',
         'item_id', 'card-1',
         'scheduler_state_after', jsonb_build_object(
           'total_reviews', 1
         )
       )
     ]) $$,
  'Replaying duplicate event executes safely'
);

select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  1,
  'learning_events row count remains 1'
);

select is(
  (select total_reviews from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews not double-incremented on event replay'
);

-- 14. TEST: Cross-user isolation on learning_events
-- Switch to User 2
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000002', true);
end $$;

select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  0,
  'User 2 cannot view User 1 learning events'
);

-- 15. Switch back to User 1
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- 16. TEST: Direct authenticated INSERT of is_verified = TRUE is rejected with 42501
select throws_ok(
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
  '42501',
  null,
  'Direct client insert of is_verified = TRUE is rejected with 42501'
);

-- 17. TEST: User 1 starts unverified attempt
select lives_ok(
  $$ insert into public.assessment_attempts (
       id, assessment_id, user_id, is_verified, started_at
     ) values (
       'ee888888-0000-4000-8000-000000000001'::uuid,
       'dd222222-0000-4000-8000-000000000001'::uuid,
       'cc111111-0000-4000-8000-000000000001'::uuid,
       false,
       now() - interval '2 minutes'
     ) $$,
  'User 1 successfully starts unverified attempt'
);

-- 18. TEST: Server-graded submission completing the original attempt
select lives_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 1,
         'dd333333-0000-4000-8000-000000000002', 2
       ),
       'ee888888-0000-4000-8000-000000000001'::uuid
     ) $$,
  'User 1 submits answers for original attempt'
);

-- 19. TEST: The original attempt is now completed with is_verified = TRUE
select is(
  (select is_verified from public.assessment_attempts where id = 'ee888888-0000-4000-8000-000000000001'),
  true,
  'Original attempt was completed and marked is_verified = TRUE by server scoring'
);

select is(
  (select score from public.assessment_attempts where id = 'ee888888-0000-4000-8000-000000000001'),
  100,
  'Original attempt score calculated as 100%'
);

-- 20. TEST: user_skill_stats now has is_verified = TRUE
select is(
  (select is_verified from public.user_skill_stats 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
     and skill_id = 'dd111111-0000-4000-8000-000000000001'),
  true,
  'user_skill_stats has is_verified = TRUE after server-graded attempt'
);

-- 21. TEST: Re-submitting already completed attempt is rejected
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 1,
         'dd333333-0000-4000-8000-000000000002', 2
       ),
       'ee888888-0000-4000-8000-000000000001'::uuid
     ) $$,
  'Assessment attempt already completed: ee888888-0000-4000-8000-000000000001',
  'Submitting already completed attempt throws exception'
);

-- 22. TEST: Non-existent assessment submission throws exception
select throws_ok(
  $$ select submit_and_grade_assessment(
       '00000000-0000-0000-0000-000000000000'::uuid,
       '{}'::jsonb
     ) $$,
  'Active assessment not found: 00000000-0000-0000-0000-000000000000',
  'Submitting non-existent assessment throws exception'
);

-- 23. TEST: Server-graded submission with partial answers calculates correct score
select is(
  ((select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 0, -- wrong
         'dd333333-0000-4000-8000-000000000002', 2  -- right
       )
     ))->>'score')::int,
  50,
  'Submitting standalone partially correct assessment returns 50% score'
);

-- 24. TEST: Standalone attempt recorded in database with is_verified = TRUE and score = 50
select is(
  (select count(*)::int from public.assessment_attempts 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
     and score = 50 
     and is_verified = true),
  1,
  'Partial score attempt correctly recorded in database with is_verified = TRUE'
);

select * from finish();
rollback;
