-- ============================================================================
-- Test Suite: clep_simulation_bank_and_privacy_test.sql
-- Description: pgTAP tests for CLEP Question-Bank Separation, Ingestion Metadata,
--              Restrictive RLS Privacy, Attempt Lifecycle, and Negative RPC Guards.
-- ============================================================================

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;

select plan(44);

-- Setup synthetic test users in auth.users (under initial postgres session role)
insert into auth.users (id, email) values
  ('11223344-5566-4777-8888-999900001111', 'learner_privacy@example.invalid'),
  ('22334455-6677-4888-9999-000011112222', 'learner_other@example.invalid'),
  ('33445566-7788-4999-0000-111122223333', 'learner_nodomain@example.invalid'),
  ('44556677-8899-4000-1111-222233334444', 'learner_badquota@example.invalid')
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
                      "domain_code": "1.0",
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
                      "domain_code": "1.0",
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
grant all on table _fixture_ids to public, authenticated, service_role, anon;

-- ----------------------------------------------------------------------------
-- 2. Verify Database Persistence of Item Metadata
-- ----------------------------------------------------------------------------
-- Verify target version was created
select ok(
  exists (select 1 from public.target_versions where version_code = '2026-PRIV'),
  'Target version 2026-PRIV was ingested'
);

-- Verify TargetVersion metadata has bank = simulation_exam
select is(
  (select metadata->>'bank' from public.target_versions where version_code = '2026-PRIV'),
  'simulation_exam',
  'TargetVersion metadata automatically populates bank = simulation_exam for simulation courses'
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
grant all on table _issued_exam to public, authenticated, service_role, anon;

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
grant all on table _test_ctx to public, authenticated, service_role, anon;

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

-- ----------------------------------------------------------------------------
-- 8. Valid Completion, Confidential Simulation Bank & Anti-Scraping Regression
-- ----------------------------------------------------------------------------
create temp table _submission_res (data jsonb) on commit drop;
grant all on table _submission_res to public, authenticated, service_role, anon;

-- Submit attempt with ALL questions answered (guessing 0 for both Item 1 and Item 2)
-- Regression: learner attempts to scrape bank by answering all questions immediately
do $$
declare
  v_att_id uuid;
  v_item_1 text;
  v_item_2 text;
  v_sub_res jsonb;
  v_r jsonb;
begin
  select
    attempt_id,
    item_1_id::text,
    item_2_id::text
  into v_att_id, v_item_1, v_item_2
  from _test_ctx;

  -- Submit answers for ALL items
  v_sub_res := public.clep_submit_simulation_exam(
    v_att_id,
    jsonb_build_object(v_item_1, 0, v_item_2, 0)
  );

  insert into _submission_res (data) values (v_sub_res);

  -- Assert score: 2 correct out of 2 total (both items have correct_index = 0)
  if (v_sub_res->>'raw_score')::int <> 2 then
    raise exception 'Expected raw_score 2, got %', v_sub_res->>'raw_score';
  end if;

  if (v_sub_res->>'total_questions')::int <> 2 then
    raise exception 'Expected total_questions 2, got %', v_sub_res->>'total_questions';
  end if;

  if (v_sub_res->>'accuracy_percentage')::numeric <> 100.0 then
    raise exception 'Expected accuracy 100.0, got %', v_sub_res->>'accuracy_percentage';
  end if;

  -- Verify CONFIDENTIALITY: neither item leaks correct_answer or explanation
  for i in 0 .. jsonb_array_length(v_sub_res->'results') - 1
  loop
    v_r := (v_sub_res->'results')->i;

    if (v_r->>'answered')::boolean is not true then
      raise exception 'Item should be marked answered';
    end if;

    if (v_r->>'is_correct')::boolean is not true then
      raise exception 'Item should be marked correct';
    end if;

    if v_r ? 'correct_answer' and (v_r->>'correct_answer') is not null then
      raise exception 'SECURITY VIOLATION: Simulation item leaked correct_answer in submission response!';
    end if;

    if v_r ? 'explanation' and (v_r->>'explanation') is not null then
      raise exception 'SECURITY VIOLATION: Simulation item leaked explanation in submission response!';
    end if;

    if not (v_r ? 'concept_ids') then
      raise exception 'Simulation result must provide concept_ids for targeted remediation';
    end if;
  end loop;
end;
$$;

select pass('User 1 submits attempt with all questions answered and receives zero answer keys or explanations');

-- Verify server-side evaluation matches in database record
select is(
  (select raw_score from public.clep_simulation_attempts where id = (select attempt_id from _test_ctx)),
  2,
  'Submitted attempt evaluates raw score correctly (2 out of 2)'
);

-- Verify learner can read correctness and targeted remediation concepts under RLS
select is(
  (select ((results->0)->>'is_correct')::boolean from public.clep_simulation_attempts where id = (select attempt_id from _test_ctx)),
  true,
  'Attempt owner can read item correctness (is_correct) in post-submission results'
);

-- Verify owner-readable database record strictly omits correct_answer and explanation
select is(
  (
    select count(*)
    from jsonb_array_elements(
      (select results from public.clep_simulation_attempts where id = (select attempt_id from _test_ctx))
    ) elem
    where (elem ? 'correct_answer' and (elem->>'correct_answer') is not null)
       or (elem ? 'explanation' and (elem->>'explanation') is not null)
  ),
  0::bigint,
  'Owner-readable clep_simulation_attempts.results strictly omits correct_answer and explanation (anti-harvesting)'
);

-- Verify non-overclaiming disclaimer in database record
select ok(
  (
    select (results is not null and status = 'completed')
    from public.clep_simulation_attempts where id = (select attempt_id from _test_ctx)
  ),
  'Attempt status is completed with results in public.clep_simulation_attempts'
);

select ok(
  (
    select data->>'scoring_disclaimer' like '%Diagnostic score estimate only%'
    from _submission_res
  ),
  'Submission response includes explicit disclaimer prohibiting official score equivalence'
);

-- NEGATIVE GUARD 5: Replay attempt of already completed attempt is strictly rejected
select throws_ok(
  $$ select public.clep_submit_simulation_exam(
    (select attempt_id from _test_ctx),
    jsonb_build_object('00000000-0000-0000-0000-000000000001', 0)
  ) $$,
  '23505',
  null,
  'Replay submission of completed attempt is strictly rejected (single-submission invariant)'
);

-- ----------------------------------------------------------------------------
-- 9. Anti-Abuse Regressions: Formative Server Grading & Anti-Harvesting Attempt Limits
-- ----------------------------------------------------------------------------
-- Anti-Bypass Guard: grade_assessment_items must NOT grade or leak protected simulation items
select is(
  (
    select (res->0->>'error')
    from (
      select public.grade_assessment_items(
        jsonb_build_array(
          jsonb_build_object(
            'item_id', (select item_1_id from _test_ctx),
            'response', 0
          )
        )
      ) as res
    ) sub
  ),
  'not_available',
  'grade_assessment_items rejects protected simulation items with not_available error (zero key leakage)'
);

-- Anti-Harvesting Guard 1: User 1 cannot issue second simulation attempt for same exam version
select throws_ok(
  $$ select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) $$,
  '23505',
  null,
  'User 1 cannot issue second simulation attempt for same exam version (anti-harvesting)'
);

-- Anti-Harvesting Guard 2: User 1 cannot issue third simulation attempt for same exam version
select throws_ok(
  $$ select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) $$,
  '23505',
  null,
  'User 1 cannot issue third simulation attempt for same exam version (anti-harvesting)'
);

-- Anti-Harvesting Guard 3: Database unique index clep_sim_attempts_user_version_uidx blocks concurrent duplicate attempt insertion
-- Test under service_role so table permissions pass and PostgreSQL hits the unique index
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

select throws_ok(
  $$ insert into public.clep_simulation_attempts (
       user_id, target_id, target_version_id, status, issued_item_ids, total_questions, issued_at, expires_at
     ) values (
       '11223344-5566-4777-8888-999900001111',
       (select target_id from public.target_versions where version_code = '2026-PRIV'),
       (select id from public.target_versions where version_code = '2026-PRIV'),
       'in_progress',
       array[(select item_1_id from _test_ctx)],
       1,
       clock_timestamp(),
       clock_timestamp() + interval '95 minutes'
     ) $$,
  '23505',
  null,
  'Database unique index clep_sim_attempts_user_version_uidx blocks concurrent duplicate attempt insertion'
);

-- ----------------------------------------------------------------------------
-- 10. Multi-Tenant Learner Isolation & Deadline Expiration
-- ----------------------------------------------------------------------------
-- Authenticate as User 2 (a different authenticated learner)
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '22334455-6677-4888-9999-000011112222';

-- User 2 successfully issues their own simulation attempt for the same exam version
create temp table _user2_exam on commit drop as
select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) as data;
grant all on table _user2_exam to public, authenticated, service_role, anon;

select ok(
  (select data->>'attempt_id' is not null from _user2_exam),
  'Different authenticated learner (User 2) can issue their own simulation attempt for the same exam version'
);

-- User 2 cannot issue a second simulation attempt for the same exam version
select throws_ok(
  $$ select public.clep_issue_simulation_exam((select id from public.target_versions where version_code = '2026-PRIV')) $$,
  '23505',
  null,
  'User 2 cannot issue duplicate simulation attempt for the same exam version (anti-harvesting)'
);

-- Expire User 2's attempt to verify deadline enforcement on submission
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

update public.clep_simulation_attempts
set issued_at = clock_timestamp() - interval '100 minutes',
    expires_at = clock_timestamp() - interval '5 minutes'
where id = ((select data->>'attempt_id' from _user2_exam)::uuid);

reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '22334455-6677-4888-9999-000011112222';

select throws_ok(
  $$ select public.clep_submit_simulation_exam(
    ((select data->>'attempt_id' from _user2_exam)::uuid),
    jsonb_build_object((select item_1_id::text from _test_ctx), 0)
  ) $$,
  '42501',
  null,
  'Cannot submit expired attempt (deadline enforcement)'
);

-- ----------------------------------------------------------------------------
-- 11. Strict Pre-Issuance Psychometric Domain & Quota Validation
-- ----------------------------------------------------------------------------
-- Setup a target version with an item lacking a domain code
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

-- Create synthetic target version for domain validation testing
insert into public.learning_targets (id, title, slug, target_type, status, is_public)
values ('dd000000-0000-0000-0000-000000000001', 'Invalid Domain Target', 'invalid-domain-target', 'certification', 'published', true)
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_code, title, status, metadata)
values (
  'dd000000-0000-0000-0000-000000000002',
  'dd000000-0000-0000-0000-000000000001',
  '2026-NODOM',
  '2026 No Domain Version',
  'published',
  '{"role": "blueprint_authority", "bank": "simulation_exam", "exam_code": "TEST-NODOM"}'::jsonb
)
on conflict (id) do nothing;

-- Insert simulation item with NO concept mapping and NO domain_code metadata
insert into public.assessment_items (
  id, origin_target_version_id, interaction_type, prompt, response_spec, scoring_spec, metadata
) values (
  'dd000000-0000-0000-0000-000000000003',
  'dd000000-0000-0000-0000-000000000002',
  'single_choice',
  'Orphan item with no domain mapping',
  '{"options": ["A", "B"]}'::jsonb,
  '{"correct_index": 0}'::jsonb,
  '{"bank": "simulation_exam", "item_role": "summative_simulation", "is_protected": true}'::jsonb
)
on conflict (id) do nothing;

-- Authenticate as User 3
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '33445566-7788-4999-0000-111122223333';

-- Calling clep_issue_simulation_exam throws 22023 because item lacks domain_code
select throws_ok(
  $$ select public.clep_issue_simulation_exam('dd000000-0000-0000-0000-000000000002'::uuid) $$,
  '22023',
  null,
  'Simulation item lacking domain_code throws 22023 prior to attempt creation'
);

-- Crucial: verify NO attempt was created in clep_simulation_attempts for User 3
select is(
  (select count(*) from public.clep_simulation_attempts where user_id = '33445566-7788-4999-0000-111122223333'::uuid),
  0::bigint,
  'Pre-issuance domain validation failure aborts attempt insertion (zero attempts recorded)'
);

-- Setup a CLEP-ALG target version that violates four-domain quotas
reset role;
set local role service_role;
set local "request.jwt.claim.role" to 'service_role';

insert into public.learning_targets (id, title, slug, target_type, status, is_public)
values ('dd000000-0000-0000-0000-000000000010', 'Bad Quota Algebra Target', 'bad-quota-algebra-target', 'certification', 'published', true)
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_code, title, status, metadata)
values (
  'dd000000-0000-0000-0000-000000000020',
  'dd000000-0000-0000-0000-000000000010',
  '2026-BADQUOTA',
  '2026 Bad Quota Algebra Version',
  'published',
  '{"role": "blueprint_authority", "bank": "simulation_exam", "exam_code": "CLEP-ALG", "total_domains": 4}'::jsonb
)
on conflict (id) do nothing;

-- Add domains 1.0, 2.0, 3.0, 4.0
insert into public.curriculum_nodes (id, target_version_id, code, title, node_type, sort_order)
values
  ('dd000000-0000-0000-0000-000000000021', 'dd000000-0000-0000-0000-000000000020', '1.0', 'Operations', 'domain', 1),
  ('dd000000-0000-0000-0000-000000000022', 'dd000000-0000-0000-0000-000000000020', '2.0', 'Equations', 'domain', 2),
  ('dd000000-0000-0000-0000-000000000023', 'dd000000-0000-0000-0000-000000000020', '3.0', 'Functions', 'domain', 3),
  ('dd000000-0000-0000-0000-000000000024', 'dd000000-0000-0000-0000-000000000020', '4.0', 'Number Systems', 'domain', 4)
on conflict (id) do nothing;

-- Add only 2 items (violating 60 question and 15/15/18/12 quota)
insert into public.assessment_items (
  id, origin_target_version_id, interaction_type, prompt, response_spec, scoring_spec, metadata
) values
  ('dd000000-0000-0000-0000-000000000031', 'dd000000-0000-0000-0000-000000000020', 'single_choice', 'Q1', '{"options": ["A"]}'::jsonb, '{"correct_index": 0}'::jsonb, '{"bank": "simulation_exam", "item_role": "summative_simulation", "domain_code": "1.0", "is_protected": true}'::jsonb),
  ('dd000000-0000-0000-0000-000000000032', 'dd000000-0000-0000-0000-000000000020', 'single_choice', 'Q2', '{"options": ["B"]}'::jsonb, '{"correct_index": 0}'::jsonb, '{"bank": "simulation_exam", "item_role": "summative_simulation", "domain_code": "2.0", "is_protected": true}'::jsonb)
on conflict (id) do nothing;

-- Authenticate as User 4
reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '44556677-8899-4000-1111-222233334444';

-- Calling clep_issue_simulation_exam throws 22023 because CLEP-ALG four-domain quota is violated
select throws_ok(
  $$ select public.clep_issue_simulation_exam('dd000000-0000-0000-0000-000000000020'::uuid) $$,
  '22023',
  null,
  'CLEP-ALG four-domain quota violation throws 22023 prior to attempt creation'
);

-- Crucial: verify NO attempt was created in clep_simulation_attempts for User 4
select is(
  (select count(*) from public.clep_simulation_attempts where user_id = '44556677-8899-4000-1111-222233334444'::uuid),
  0::bigint,
  'Four-domain quota violation aborts attempt insertion before consuming attempt'
);

rollback;
