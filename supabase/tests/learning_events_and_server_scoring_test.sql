-- ============================================================================
-- pgTAP tests for Architecture Phase 1:
-- learning_events, record_events RPC, FSRS projections, and server-side assessment scoring
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

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
insert into public.review_items (id, user_id, content_id, content_type, lesson_id, title, stability, difficulty, fsrs_state, total_reviews, correct_reviews) values
 ('dd444444-0000-4000-8000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'card-1', 'term', 'lesson-1', 'Term 1', 2.0, 5.0, 1, 0, 0)
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
  $$ select submit_and_grade_assessment('dd222222-0000-4000-8000-000000000001'::uuid, '{"dd333333-0000-4000-8000-000000000001": 1}'::jsonb, 'ee888888-0000-4000-8000-000000000001'::uuid) $$,
  '42501',
  null,
  'Anon role cannot execute submit_and_grade_assessment'
);

-- 5. TEST: Anon cannot execute start_assessment_attempt
select throws_ok(
  $$ select start_assessment_attempt('dd222222-0000-4000-8000-000000000001'::uuid) $$,
  '42501',
  null,
  'Anon role cannot execute start_assessment_attempt'
);

-- 6. TEST: Anon cannot directly SELECT correct_answer from public.assessment_questions (FIX-12)
select throws_ok(
  $$ select correct_answer from public.assessment_questions $$,
  '42501',
  null,
  'Anon cannot directly SELECT correct_answer from public.assessment_questions'
);

-- 7. TEST: Anon cannot directly SELECT scoring_spec from public.assessment_items (FIX-12)
select throws_ok(
  $$ select scoring_spec from public.assessment_items $$,
  '42501',
  null,
  'Anon cannot directly SELECT scoring_spec from public.assessment_items'
);

-- 8. TEST: Anon CAN call get_assessment_questions_for_taking
select lives_ok(
  $$ select * from get_assessment_questions_for_taking('dd222222-0000-4000-8000-000000000001'::uuid) $$,
  'Anon can fetch questions for taking'
);

-- 9. TEST: Sanitized RPC response contains options and question_text
select is(
  (select count(*)::int from get_assessment_questions_for_taking('dd222222-0000-4000-8000-000000000001'::uuid)
   where question_text is not null and options is not null),
  2,
  'get_assessment_questions_for_taking returns valid sanitized question payload'
);

-- 10. Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- 11. TEST: Direct authenticated call to record_xp_award is rejected with 42501 (FIX-2)
select throws_ok(
  $$ select record_xp_award('ee999999-0000-4000-8000-000000000099'::uuid, 'course_complete', 100, 'src-1', 'direct forged xp') $$,
  '42501',
  null,
  'Authenticated users cannot directly execute record_xp_award'
);

-- 12. TEST: Direct client UPDATE on review_items is blocked (ARCH-1, ARCH-3)
select throws_ok(
  $$ update public.review_items set stability = 10.0 where id = 'dd444444-0000-4000-8000-000000000001' $$,
  '42501',
  null,
  'Direct client UPDATE on review_items is blocked'
);

-- 13. TEST: reset_review_item_progress resets item to baseline FSRS state
select lives_ok(
  $$ select reset_review_item_progress('dd444444-0000-4000-8000-000000000001'::uuid) $$,
  'Authenticated user can reset review item progress via RPC'
);

-- 14. TEST: review_items row reset verified
select is(
  (select stability::numeric from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  2.0::numeric,
  'review_items stability reset to baseline 2.0'
);

-- 15. TEST: Submitting without attempt ID is rejected (Answer-Key Oracle closed)
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       '{}'::jsonb,
       null::uuid
     ) $$,
  '42501',
  null,
  'Submitting without attempt ID is rejected with 42501'
);

-- 16. TEST: Submitting non-existent attempt ID is rejected with P0002
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       '{}'::jsonb,
       '00000000-0000-0000-0000-000000000000'::uuid
     ) $$,
  'P0002',
  null,
  'Submitting non-existent attempt ID throws P0002'
);

-- 17. TEST: User 1 starts attempt via start_assessment_attempt RPC
select lives_ok(
  $$ select start_assessment_attempt('dd222222-0000-4000-8000-000000000001'::uuid) $$,
  'User 1 successfully starts assessment attempt via server RPC'
);

-- 18. TEST: Client cannot directly modify started_at of uncompleted attempt
select throws_ok(
  $$ update public.assessment_attempts
     set started_at = now() - interval '1 hour'
     where user_id = 'cc111111-0000-4000-8000-000000000001' $$,
  '42501',
  null,
  'Client cannot modify started_at of an assessment attempt'
);

-- 19. TEST: Client cannot directly modify score or completion fields
select throws_ok(
  $$ update public.assessment_attempts
     set score = 100, completed_at = now()
     where user_id = 'cc111111-0000-4000-8000-000000000001' $$,
  '42501',
  null,
  'Client cannot directly modify completion or scoring fields'
);

-- 20. TEST: Authenticated User 1 can record learning event with presented_order (without explicit correct_reviews)
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
           'due', (now() + interval '3 days')::text
         )
       )
     ]) $$,
  'Authenticated user can execute record_events'
);

-- 21. TEST: correct_reviews is automatically incremented server-side to 1
select is(
  (select correct_reviews::int from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  1,
  'correct_reviews automatically incremented to 1 based on rating'
);

-- 22. TEST: Idempotency of record_events - duplicate event does not double increment
select lives_ok(
  $$ select record_events(array[
       jsonb_build_object(
         'id', 'ee000000-0000-4000-8000-000000000001',
         'event_type', 'review',
         'item_id', 'card-1',
         'scheduler_state_after', jsonb_build_object('stability', 3.5)
       )
     ]) $$,
  'Replaying duplicate event executes safely'
);

select is(
  (select total_reviews from public.review_items where id = 'dd444444-0000-4000-8000-000000000001'),
  1,
  'review_items total_reviews not double-incremented on event replay'
);

-- 23. TEST: Cross-user isolation on learning_events
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000002', true);
end $$;

select is(
  (select count(*)::int from public.learning_events where user_id = 'cc111111-0000-4000-8000-000000000001'),
  0,
  'User 2 cannot view User 1 learning events'
);

-- Switch back to User 1
do $$ begin
  perform set_config('request.jwt.claim.sub', 'cc111111-0000-4000-8000-000000000001', true);
end $$;

-- 24. TEST: Direct authenticated INSERT of is_verified = TRUE is rejected with 42501
select throws_ok(
  $$ insert into public.assessment_attempts (
       id, assessment_id, user_id, score, is_verified, is_deleted
     ) values (
       'ee999999-0000-4000-8000-000000000001'::uuid,
       'dd222222-0000-4000-8000-000000000001'::uuid,
       'cc111111-0000-4000-8000-000000000001'::uuid,
       100,
       true,
       false
     ) $$,
  '42501',
  null,
  'Direct client insert of is_verified = TRUE is rejected with 42501'
);

-- Setup known uncompleted attempt for User 1 (started 2 minutes ago)
insert into public.assessment_attempts (
  id, assessment_id, user_id, is_verified, started_at
) values (
  'ee888888-0000-4000-8000-000000000001'::uuid,
  'dd222222-0000-4000-8000-000000000001'::uuid,
  'cc111111-0000-4000-8000-000000000001'::uuid,
  false,
  now() - interval '2 minutes'
);

-- 24. TEST: Empty answers submission is rejected with 22023
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       '{}'::jsonb,
       'ee888888-0000-4000-8000-000000000001'::uuid
     ) $$,
  '22023',
  null,
  'Submitting empty answers is rejected with 22023'
);

-- 25. TEST: Incomplete answers submission (1 of 2 questions answered) is rejected with 22023
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       '{"dd333333-0000-4000-8000-000000000001": 1}'::jsonb,
       'ee888888-0000-4000-8000-000000000001'::uuid
     ) $$,
  '22023',
  null,
  'Submitting incomplete answers is rejected with 22023'
);

-- Setup rapid attempt started at now()
insert into public.assessment_attempts (
  id, assessment_id, user_id, is_verified, started_at
) values (
  'ee777777-0000-4000-8000-000000000001'::uuid,
  'dd222222-0000-4000-8000-000000000001'::uuid,
  'cc111111-0000-4000-8000-000000000001'::uuid,
  false,
  now()
);

-- 26. TEST: Rapid assessment submission (< 2 seconds duration) is rejected with 22023
select throws_ok(
  $$ select submit_and_grade_assessment(
       'dd222222-0000-4000-8000-000000000001'::uuid,
       jsonb_build_object(
         'dd333333-0000-4000-8000-000000000001', 1,
         'dd333333-0000-4000-8000-000000000002', 2
       ),
       'ee777777-0000-4000-8000-000000000001'::uuid
     ) $$,
  '22023',
  null,
  'Rapid submission (< 2s) is rejected with 22023'
);

-- Setup failing attempt started 2 minutes ago
insert into public.assessment_attempts (
  id, assessment_id, user_id, is_verified, started_at
) values (
  'ee666666-0000-4000-8000-000000000001'::uuid,
  'dd222222-0000-4000-8000-000000000001'::uuid,
  'cc111111-0000-4000-8000-000000000001'::uuid,
  false,
  now() - interval '2 minutes'
);

-- 27. TEST: Failing attempt withholds correct_answer for missed questions
select is(
  (select (submit_and_grade_assessment(
     'dd222222-0000-4000-8000-000000000001'::uuid,
     jsonb_build_object(
       'dd333333-0000-4000-8000-000000000001', 0,
       'dd333333-0000-4000-8000-000000000002', 0
     ),
     'ee666666-0000-4000-8000-000000000001'::uuid
   )->'question_results'->0->>'correct_answer')),
  null,
  'Failing attempt withholds correct_answer for missed questions to prevent harvesting'
);

-- 28. TEST: Legitimate passing attempt discloses correct answers for post-assessment review
select is(
  (select (submit_and_grade_assessment(
     'dd222222-0000-4000-8000-000000000001'::uuid,
     jsonb_build_object(
       'dd333333-0000-4000-8000-000000000001', 1,
       'dd333333-0000-4000-8000-000000000002', 2
     ),
     'ee888888-0000-4000-8000-000000000001'::uuid
   )->'question_results'->0->>'correct_answer')::int),
  1,
  'Passing attempt discloses correct_answer for legitimate post-assessment review'
);

-- 29. TEST: The original attempt is now completed with is_verified = TRUE and score = 100
select is(
  (select is_verified from public.assessment_attempts where id = 'ee888888-0000-4000-8000-000000000001'),
  true,
  'Original attempt was completed and marked is_verified = TRUE by server scoring'
);

-- 30. TEST: user_skill_stats now has is_verified = TRUE
select is(
  (select is_verified from public.user_skill_stats 
   where user_id = 'cc111111-0000-4000-8000-000000000001' 
     and skill_id = 'dd111111-0000-4000-8000-000000000001'),
  true,
  'user_skill_stats has is_verified = TRUE after server-graded attempt'
);

-- 31. TEST: Re-submitting already completed attempt is rejected
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

select * from finish();
rollback;
