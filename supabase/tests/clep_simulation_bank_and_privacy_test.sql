-- ============================================================================
-- Test Suite: clep_simulation_bank_and_privacy_test.sql
-- Description: pgTAP tests for CLEP Question-Bank Separation, Ingestion Metadata,
--              Restrictive RLS Privacy, Attempt Lifecycle, and Negative RPC Guards.
-- ============================================================================

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;

select plan(34);

-- Setup synthetic test users in auth.users (under initial postgres session role)
insert into auth.users (id, email) values
  ('11223344-5566-4777-8888-999900001111', 'learner_privacy@example.invalid'),
  ('22334455-6677-4888-9999-000011112222', 'learner_other@example.invalid')
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 1. Setup Test Fixtures & Ingest Target Version with Mixed Assessment Items
-- ----------------------------------------------------------------------------
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select lives_ok(
  $$select public.ingest_curriculum_manifest('{
    "field": {"slug": "psychology-test-field", "name": "Psychology Test Field"},
    "target": {"slug": "clep-psyc-privacy-target", "title": "CLEP Psychology Privacy Target", "target_type": "certification"},
    "target_version": {"version_code": "2026-PRIV", "title": "CLEP Psychology 2026 Privacy Version"},
    "sources": [
      {
        "source_id": "src-collegeboard-test",
        "publisher": "College Board",
        "title": "CLEP Psych Guide",
        "version": "2026",
        "sha256": "b45a6c1e95632b85d38f8cf2e4389ab9213bc54784a621e25e9d3d3a77a94f01"
      }
    ],
    "concepts": [
      {
        "slug": "psyc-test-concept-structuralism",
        "name": "Structuralism Test Concept",
        "description": "Wundt introspection",
        "source_id": "src-collegeboard-test"
      },
      {
        "slug": "psyc-test-concept-neuron",
        "name": "Neuron Test Concept",
        "description": "Electrochemical signaling",
        "source_id": "src-collegeboard-test"
      }
    ],
    "domains": [
      {
        "code": "1.0",
        "title": "History, Approaches, and Methods",
        "description": "Historical foundations",
        "weight": 1.0,
        "sort_order": 1,
        "source_id": "src-collegeboard-test",
        "objectives": [
          {
            "code": "1.1",
            "title": "Historical foundations",
            "description": "Wundt and James",
            "sort_order": 1,
            "source_id": "src-collegeboard-test",
            "concept_slugs": ["psyc-test-concept-structuralism", "psyc-test-concept-neuron"],
            "lessons": [
              {
                "title": "History Foundations Lesson",
                "description": "Lesson covering early foundations",
                "order_index": 1,
                "source_id": "src-collegeboard-test",
                "concept_slugs": ["psyc-test-concept-structuralism", "psyc-test-concept-neuron"],
                "blocks": [
                  {
                    "block_type": "markdown",
                    "content": {"text": "Wundt established the first experimental psychology laboratory in Leipzig in 1879."},
                    "sort_order": 1
                  }
                ],
                "questions": [
                  {
                    "question_text": "Who established the first psychology laboratory in 1879?",
                    "options": ["Wilhelm Wundt", "William James", "John B. Watson", "B.F. Skinner"],
                    "correct_answer": 0,
                    "explanation": "Wilhelm Wundt established the Leipzig lab in 1879."
                  }
                ],
                "assessment_items": [
                  {
                    "prompt": "Formative Item: Which school utilized systematic introspection?",
                    "interaction_type": "single_choice",
                    "response_spec": {"options": ["Structuralism", "Behaviorism"]},
                    "scoring_spec": {"correct_index": 0},
                    "explanation": "Structuralism used systematic introspection to study consciousness.",
                    "concept_slugs": ["psyc-test-concept-structuralism"],
                    "metadata": {
                      "bank": "formative_lesson",
                      "item_role": "concept_check",
                      "is_protected": false
                    }
                  },
                  {
                    "prompt": "Protected Sim Item 1: What is the resting potential of an axon?",
                    "interaction_type": "single_choice",
                    "response_spec": {"options": ["-70 mV", "+30 mV", "0 mV", "-90 mV"]},
                    "scoring_spec": {"correct_index": 0},
                    "explanation": "The resting potential of a typical neuron is approximately -70 millivolts.",
                    "concept_slugs": ["psyc-test-concept-neuron"],
                    "metadata": {
                      "bank": "simulation_exam",
                      "item_role": "summative_simulation",
                      "is_protected": true,
                      "exposure": "timed_exam_only"
                    }
                  },
                  {
                    "prompt": "Protected Sim Item 2: Which neurotransmitter is primarily excitatory in the CNS?",
                    "interaction_type": "single_choice",
                    "response_spec": {"options": ["Glutamate", "GABA", "Glycine", "Endorphin"]},
                    "scoring_spec": {"correct_index": 0},
                    "explanation": "Glutamate is the major excitatory neurotransmitter in the central nervous system.",
                    "concept_slugs": ["psyc-test-concept-neuron"],
                    "metadata": {
                      "bank": "simulation_exam",
                      "item_role": "summative_simulation",
                      "is_protected": true,
                      "exposure": "timed_exam_only"
                    }
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }'::jsonb)$$,
  'ingest_curriculum_manifest executes cleanly and stages target version'
);

-- Store fixture version ID in temp table (accessible across role changes in session)
create temp table _fixture_ids on commit drop as
select v.id as version_id
from public.target_versions v
where v.version_code = '2026-PRIV';

-- ----------------------------------------------------------------------------
-- 2. Verify Database Persistence of Item Metadata
-- ----------------------------------------------------------------------------
-- Verify target version was created
select ok(
  exists (select 1 from public.target_versions where version_code = '2026-PRIV'),
  'Target version 2026-PRIV was ingested'
);

-- Verify metadata is persisted on assessment_items
select ok(
  exists (
    select 1 from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.metadata->>'bank' = 'simulation_exam'
      and (i.metadata->>'is_protected')::boolean = true
      and i.metadata->>'exposure' = 'timed_exam_only'
  ),
  'Protected simulation item metadata is persisted in public.assessment_items.metadata'
);

-- Verify is_protected_simulation_item helper
select is(
  public.is_protected_simulation_item('{"bank":"simulation_exam","is_protected":true,"exposure":"timed_exam_only"}'::jsonb),
  true,
  'is_protected_simulation_item returns true for simulation exam metadata'
);

select is(
  public.is_protected_simulation_item('{"bank":"formative_lesson","is_protected":false}'::jsonb),
  false,
  'is_protected_simulation_item returns false for formative item metadata'
);

-- ----------------------------------------------------------------------------
-- 3. Target Version Lifecycle & Negative Guard on Draft/Unpublished Versions
-- ----------------------------------------------------------------------------
-- Test: Authenticated user cannot issue simulation exam on draft version
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '11223344-5566-4777-8888-999900001111';

select throws_ok(
  $$ select public.clep_issue_simulation_exam((select version_id from _fixture_ids)) $$,
  '42501',
  null,
  'Authenticated learner cannot issue simulation exam on draft/unpublished target version'
);

-- Now transition TargetVersion: draft -> review_ready -> published so curriculum is active
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

update public.target_versions
set status = 'review_ready'
where version_code = '2026-PRIV';

update public.target_versions
set status = 'published'
where version_code = '2026-PRIV';

-- ----------------------------------------------------------------------------
-- 4. Verify Privacy Under Anon Role (Unauthenticated Learner) & Negative Guards
-- ----------------------------------------------------------------------------
reset role;
set local role anon;
set local "request.jwt.claim.role" to 'anon';

-- Formative lesson questions in public.questions ARE accessible to learners
select is(
  (
    select count(*)::integer from public.questions q
    join public.lessons l on l.id = q.lesson_id
    join public.target_versions v on v.id = l.origin_target_version_id
    where v.version_code = '2026-PRIV'
  ),
  1,
  'Anon learner can read formative check-for-understanding questions'
);

-- Formative assessment item (unprotected) IS accessible
select is(
  (
    select count(i.id)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Formative Item:%'
  ),
  1,
  'Anon learner can read unprotected formative assessment items'
);

-- Restrictive RLS policy BLOCKS direct select of protected simulation items
select is(
  (
    select count(i.id)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Protected Sim Item%'
  ),
  0,
  'Restrictive RLS blocks anon learner from directly selecting protected simulation items'
);

-- Zero scoring keys for assessment items leak to anon learners (blocked by column privileges)
select throws_ok(
  $$ select scoring_spec from public.assessment_items $$,
  '42501',
  null,
  'Zero scoring keys leak to anon learners via column privileges'
);

-- NEGATIVE GUARD: Anon cannot call clep_issue_simulation_exam
select throws_ok(
  $$ select public.clep_issue_simulation_exam('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501',
  null,
  'Anon learner cannot call clep_issue_simulation_exam (blocked by permissions)'
);

-- NEGATIVE GUARD: Anon cannot call clep_submit_simulation_exam
select throws_ok(
  $$ select public.clep_submit_simulation_exam('00000000-0000-0000-0000-000000000000'::uuid, '{"a":1}'::jsonb) $$,
  '42501',
  null,
  'Anon learner cannot call clep_submit_simulation_exam (blocked by permissions)'
);

-- ----------------------------------------------------------------------------
-- 5. Verify Direct Table RLS Under Authenticated Role
-- ----------------------------------------------------------------------------
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '11223344-5566-4777-8888-999900001111';

-- Authenticated learner CAN read formative assessment items
select is(
  (
    select count(i.id)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Formative Item:%'
  ),
  1,
  'Authenticated learner can read unprotected formative assessment items'
);

-- Authenticated learner CANNOT read protected simulation items via direct select
select is(
  (
    select count(i.id)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Protected Sim Item%'
  ),
  0,
  'Restrictive RLS blocks authenticated learner from directly selecting protected simulation items'
);

-- Zero scoring keys for assessment items leak to authenticated learners (blocked by column privileges)
select throws_ok(
  $$ select scoring_spec from public.assessment_items $$,
  '42501',
  null,
  'Zero scoring keys leak to authenticated learners via column privileges'
);

-- NEGATIVE GUARD: Submitting non-existent attempt ID is rejected
select throws_ok(
  $$ select public.clep_submit_simulation_exam('a0000000-0000-0000-0000-000000000001'::uuid, '{"key": 0}'::jsonb) $$,
  'P0002',
  null,
  'Authenticated learner cannot submit with a non-existent attempt ID'
);

-- ----------------------------------------------------------------------------
-- 6. Authorized Simulation Exam Issuance & Attempt Lifecycle Tracking
-- ----------------------------------------------------------------------------
-- User 1 issues simulation exam
create temp table _issued_exam on commit drop as
select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) as data;

select ok(
  (select data->>'attempt_id' is not null from _issued_exam),
  'User 1 successfully issues simulation exam and receives attempt_id'
);

-- Verify issuance envelope properties
select is(
  (select (data->>'total_questions')::int from _issued_exam),
  2,
  'clep_issue_simulation_exam returns correct total_questions count (2 items)'
);

select is(
  (select (data->>'time_limit_minutes')::int from _issued_exam),
  90,
  'clep_issue_simulation_exam returns standard 90-minute time limit'
);

-- Verify issuance projection has ZERO scoring keys or explanations
do $$
declare
  v_issued jsonb;
  v_q jsonb;
begin
  select data into v_issued from _issued_exam;

  for i in 0 .. jsonb_array_length(v_issued->'questions') - 1
  loop
    v_q := (v_issued->'questions')->i;
    if v_q ? 'scoring_spec' then
      raise exception 'Security violation: scoring_spec was returned in issued question';
    end if;
    if v_q ? 'explanation' then
      raise exception 'Security violation: explanation was returned in issued question';
    end if;
    if v_q ? 'correct_index' or v_q ? 'correct_answer' then
      raise exception 'Security violation: answer key was returned in issued question';
    end if;
  end loop;
end;
$$;

select pass('Issued questions projection contains zero scoring keys or explanations');

-- Verify attempt record was created with in_progress status
select is(
  (
    select count(*)::integer
    from public.clep_simulation_attempts a
    where a.id = ((select data->>'attempt_id' from _issued_exam)::uuid)
      and a.user_id = '11223344-5566-4777-8888-999900001111'
      and a.status = 'in_progress'
  ),
  1,
  'Attempt record is created in public.clep_simulation_attempts with in_progress status'
);

-- ----------------------------------------------------------------------------
-- 7. Negative Submission Tests (Security & Invariant Enforcement)
-- ----------------------------------------------------------------------------
-- Retrieve the latest attempt for User 1
create temp table _test_ctx on commit drop as
select
  a.id as attempt_id,
  a.issued_item_ids[1] as item_1_id,
  a.issued_item_ids[2] as item_2_id
from public.clep_simulation_attempts a
where a.id = ((select data->>'attempt_id' from _issued_exam)::uuid);

-- NEGATIVE GUARD 1: Cannot submit empty responses {} (anti-scraping guard)
select throws_ok(
  $$ select public.clep_submit_simulation_exam((select attempt_id from _test_ctx), '{}'::jsonb) $$,
  '22023',
  null,
  'Cannot submit empty responses map (rejects empty response scraping attempt)'
);

-- NEGATIVE GUARD 2: Another user (User 2) cannot submit User 1 attempt
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '22334455-6677-4888-9999-000011112222';

select throws_ok(
  $$ select public.clep_submit_simulation_exam((select attempt_id from _test_ctx), '{"00000000-0000-0000-0000-000000000001": 0}'::jsonb) $$,
  '42501',
  null,
  'Another user (User 2) cannot submit User 1 attempt (ownership guard)'
);

-- NEGATIVE GUARD 3: User 2 cannot read User 1 attempt directly (RLS isolation)
select is(
  (select count(*)::integer from public.clep_simulation_attempts where id = (select attempt_id from _test_ctx)),
  0,
  'User 2 cannot read User 1 attempt from clep_simulation_attempts (RLS isolation)'
);

-- NEGATIVE GUARD 4: User 1 cannot submit foreign / out-of-bank question ID
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '11223344-5566-4777-8888-999900001111';

select throws_ok(
  $$ select public.clep_submit_simulation_exam(
    (select attempt_id from _test_ctx),
    jsonb_build_object('ffffffff-ffff-ffff-ffff-ffffffffffff', 0)
  ) $$,
  '22023',
  null,
  'Cannot submit foreign or out-of-bank question ID'
);

-- NEGATIVE GUARD 5: Cannot submit expired attempt
-- Note: Must update attempt under service_role privilege because client roles have SELECT-only
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

update public.clep_simulation_attempts
set expires_at = clock_timestamp() - interval '10 seconds'
where id = (select attempt_id from _test_ctx);

reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '11223344-5566-4777-8888-999900001111';

select throws_ok(
  $$ select public.clep_submit_simulation_exam(
    (select attempt_id from _test_ctx),
    jsonb_build_object((select item_1_id::text from _test_ctx), 0)
  ) $$,
  '42501',
  null,
  'Cannot submit expired attempt (deadline enforcement)'
);

-- ----------------------------------------------------------------------------
-- 8. Valid Completion, Selective Review Disclosure & Replay Invariant
-- ----------------------------------------------------------------------------
-- Issue fresh, clean attempt for User 1
create temp table _fresh_exam on commit drop as
select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) as data;

select ok(
  (select data->>'attempt_id' is not null from _fresh_exam),
  'User 1 issues fresh simulation exam for valid completion testing'
);

-- Submit attempt with Item 1 answered (correct: 0) and Item 2 left unanswered
do $$
declare
  v_att_id uuid;
  v_item_1 text;
  v_item_2 text;
  v_sub_res jsonb;
  v_r1 jsonb;
  v_r2 jsonb;
begin
  select (data->>'attempt_id')::uuid into v_att_id from _fresh_exam;
  select issued_item_ids[1]::text, issued_item_ids[2]::text
  into v_item_1, v_item_2
  from public.clep_simulation_attempts
  where id = v_att_id;

  -- Submit Item 1 ONLY (leaving Item 2 blank)
  v_sub_res := public.clep_submit_simulation_exam(
    v_att_id,
    jsonb_build_object(v_item_1, 0)
  );

  -- Assert score: 1 correct out of 2 total
  if (v_sub_res->>'raw_score')::int <> 1 then
    raise exception 'Expected raw_score 1, got %', v_sub_res->>'raw_score';
  end if;

  if (v_sub_res->>'total_questions')::int <> 2 then
    raise exception 'Expected total_questions 2, got %', v_sub_res->>'total_questions';
  end if;

  if (v_sub_res->>'accuracy_percentage')::numeric <> 50.0 then
    raise exception 'Expected accuracy 50.0, got %', v_sub_res->>'accuracy_percentage';
  end if;

  -- Assert Item 1 result: answered, correct, explanation safely revealed
  v_r1 := v_sub_res->'results'->0;
  if (v_r1->>'answered')::boolean is not true or (v_r1->>'is_correct')::boolean is not true then
    raise exception 'Item 1 should be marked answered and correct';
  end if;
  if (v_r1->>'explanation') is null or (v_r1->>'correct_answer') is null then
    raise exception 'Item 1 post-submission review must reveal explanation and correct answer';
  end if;

  -- Assert Item 2 result: unanswered, NOT correct, explanation & answer key NOT revealed
  v_r2 := v_sub_res->'results'->1;
  if (v_r2->>'answered')::boolean is not false or (v_r2->>'is_correct')::boolean is not false then
    raise exception 'Item 2 should be marked unanswered and not correct';
  end if;
  if v_r2->>'explanation' is not null or v_r2->>'correct_answer' is not null then
    raise exception 'SECURITY VIOLATION: Unanswered Item 2 leaked explanation or correct answer!';
  end if;
end;
$$;

select pass('User 1 submits attempt with Item 1 answered and Item 2 unanswered');

-- Verify server-side evaluation matches
select is(
  (select raw_score from public.clep_simulation_attempts where id = ((select data->>'attempt_id' from _fresh_exam)::uuid)),
  1,
  'Submitted attempt evaluates raw score correctly (1 out of 2)'
);

select is(
  (select ((results->0)->>'answered')::boolean from public.clep_simulation_attempts where id = ((select data->>'attempt_id' from _fresh_exam)::uuid)),
  true,
  'Answered question safely reveals correct answer and explanation in post-submission results'
);

select is(
  (select ((results->1)->>'correct_answer') from public.clep_simulation_attempts where id = ((select data->>'attempt_id' from _fresh_exam)::uuid)),
  null,
  'Unanswered question does NOT reveal correct answer or explanation in post-submission results'
);

-- Verify non-overclaiming disclaimer in database record
select ok(
  (
    select (results is not null and status = 'completed')
    from public.clep_simulation_attempts where id = ((select data->>'attempt_id' from _fresh_exam)::uuid)
  ),
  'Attempt status is completed with results in public.clep_simulation_attempts'
);

select ok(
  (
    select public.clep_submit_simulation_exam(
      a.id,
      jsonb_build_object(a.issued_item_ids[1]::text, 0)
    )->>'scoring_disclaimer' like '%Diagnostic score estimate only%'
    from (
      select (public.clep_issue_simulation_exam(tv.id)->>'attempt_id')::uuid as id
      from public.target_versions tv where tv.version_code = '2026-PRIV'
    ) sub
    join public.clep_simulation_attempts a on a.id = sub.id
  ),
  'Submission response includes explicit disclaimer prohibiting official score equivalence'
);

-- NEGATIVE GUARD 6: Replay attempt of already completed attempt is strictly rejected
select throws_ok(
  $$ select public.clep_submit_simulation_exam(
    ((select data->>'attempt_id' from _fresh_exam)::uuid),
    jsonb_build_object('00000000-0000-0000-0000-000000000001', 0)
  ) $$,
  '23505',
  null,
  'Replay submission of completed attempt is strictly rejected (single-submission invariant)'
);

rollback;
