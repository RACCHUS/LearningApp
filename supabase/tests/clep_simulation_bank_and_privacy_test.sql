-- ============================================================================
-- Test Suite: clep_simulation_bank_and_privacy_test.sql
-- Description: pgTAP tests for CLEP Question-Bank Separation, Ingestion Metadata,
--              Restrictive RLS Privacy, and Authorized Server-Side Simulation RPCs.
-- ============================================================================

begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions, pg_temp;

select plan(18);

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
                    "prompt": "Protected Sim Item: What is the resting potential of an axon?",
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
-- 3. Verify Privacy Under Anon Role (Unauthenticated Learner)
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
    select count(*)::integer from public.assessment_items i
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
    select count(*)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Protected Sim Item:%'
  ),
  0,
  'Restrictive RLS blocks anon learner from directly selecting protected simulation items'
);

-- Restrictive RLS BLOCKS direct read of scoring_spec for simulation items
select is(
  (
    select count(*)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.scoring_spec->>'correct_index' is not null
      and i.prompt like 'Protected Sim Item:%'
  ),
  0,
  'Zero scoring keys for protected simulation items leak to anon learners'
);

-- ----------------------------------------------------------------------------
-- 4. Verify Privacy Under Authenticated Learner Role
-- ----------------------------------------------------------------------------
-- Setup synthetic authenticated user
reset role;
set local role service_role;
insert into auth.users (id, email)
values ('11223344-5566-4777-8888-999900001111', 'learner_privacy@example.invalid')
on conflict (id) do nothing;

reset role;
set local role authenticated;
set local "request.jwt.claim.role" to 'authenticated';
set local "request.jwt.claim.sub" to '11223344-5566-4777-8888-999900001111';

-- Authenticated learner also CANNOT read protected simulation items via direct select
select is(
  (
    select count(*)::integer from public.assessment_items i
    join public.target_versions v on v.id = i.origin_target_version_id
    where v.version_code = '2026-PRIV'
      and i.prompt like 'Protected Sim Item:%'
  ),
  0,
  'Restrictive RLS blocks authenticated learner from directly selecting protected simulation items'
);

-- ----------------------------------------------------------------------------
-- 5. Exercise Authorized Simulation Exam Issuance RPC
-- ----------------------------------------------------------------------------
do $$
declare
  v_version_id uuid;
  v_issued jsonb;
  v_q jsonb;
begin
  select id into v_version_id from public.target_versions where version_code = '2026-PRIV';
  v_issued := public.clep_issue_simulation_exam(v_version_id);

  if jsonb_array_length(v_issued->'questions') <> 1 then
    raise exception 'Expected exactly 1 issued question, got %', jsonb_array_length(v_issued->'questions');
  end if;

  v_q := (v_issued->'questions')->0;

  -- Verify prompt and options exist
  if (v_q->>'prompt') is null or (v_q->'response_spec'->'options') is null then
    raise exception 'Issued question missing prompt or options';
  end if;

  -- Verify scoring_spec and explanation are NOT leaked
  if v_q ? 'scoring_spec' then
    raise exception 'Security violation: scoring_spec was returned by exam issuer';
  end if;

  if v_q ? 'explanation' then
    raise exception 'Security violation: explanation was returned by exam issuer';
  end if;
end;
$$;

select pass('clep_issue_simulation_exam issues safe projection with zero scoring keys or explanations');

-- Verify issuance envelope properties
select is(
  (select (public.clep_issue_simulation_exam(id)->>'total_questions')::int from public.target_versions where version_code = '2026-PRIV'),
  1,
  'clep_issue_simulation_exam returns correct total_questions count'
);

select is(
  (select (public.clep_issue_simulation_exam(id)->>'time_limit_minutes')::int from public.target_versions where version_code = '2026-PRIV'),
  90,
  'clep_issue_simulation_exam returns standard 90-minute time limit'
);

-- ----------------------------------------------------------------------------
-- 6. Exercise Server-Side Submission and Post-Exam Grading RPC
-- ----------------------------------------------------------------------------
do $$
declare
  v_version_id uuid;
  v_item_id text;
  v_submit_res jsonb;
  v_first_result jsonb;
begin
  select id into v_version_id from public.target_versions where version_code = '2026-PRIV';
  select (public.clep_issue_simulation_exam(v_version_id)->'questions'->0->>'id') into v_item_id;

  -- Submit correct response: choice 0 (-70 mV)
  v_submit_res := public.clep_submit_simulation_exam(
    v_version_id,
    jsonb_build_object(v_item_id, 0),
    1200
  );

  if (v_submit_res->>'raw_score')::int <> 1 then
    raise exception 'Expected raw_score 1, got %', v_submit_res->>'raw_score';
  end if;

  if (v_submit_res->>'accuracy_percentage')::numeric <> 100.0 then
    raise exception 'Expected 100.0 percent, got %', v_submit_res->>'accuracy_percentage';
  end if;

  if (v_submit_res->>'is_calibrated_clep_score')::boolean is not false then
    raise exception 'Overclaiming violation: is_calibrated_clep_score must be false';
  end if;

  -- Verify post-submission results safely reveal explanations
  v_first_result := v_submit_res->'results'->0;
  if (v_first_result->>'is_correct')::boolean is not true then
    raise exception 'Expected result to be marked correct';
  end if;

  if (v_first_result->>'explanation') is null then
    raise exception 'Post-submission review must include pedagogical explanation';
  end if;
end;
$$;

select pass('clep_submit_simulation_exam evaluates answers on server and returns accurate score');

-- Test incorrect answer submission
do $$
declare
  v_version_id uuid;
  v_item_id text;
  v_submit_res jsonb;
begin
  select id into v_version_id from public.target_versions where version_code = '2026-PRIV';
  select (public.clep_issue_simulation_exam(v_version_id)->'questions'->0->>'id') into v_item_id;

  -- Submit incorrect response: choice 1 (+30 mV)
  v_submit_res := public.clep_submit_simulation_exam(
    v_version_id,
    jsonb_build_object(v_item_id, 1),
    1500
  );

  if (v_submit_res->>'raw_score')::int <> 0 then
    raise exception 'Expected raw_score 0 for incorrect answer, got %', v_submit_res->>'raw_score';
  end if;

  if (v_submit_res->>'accuracy_percentage')::numeric <> 0.0 then
    raise exception 'Expected 0.0 percent, got %', v_submit_res->>'accuracy_percentage';
  end if;

  if ((v_submit_res->'results'->0)->>'is_correct')::boolean is not false then
    raise exception 'Expected result to be marked false';
  end if;
end;
$$;

select pass('clep_submit_simulation_exam correctly handles incorrect responses');

-- ----------------------------------------------------------------------------
-- 7. Confirm Non-Overclaiming Scoring Disclaimers
-- ----------------------------------------------------------------------------
select ok(
  (
    select public.clep_submit_simulation_exam(
      id,
      jsonb_build_object((public.clep_issue_simulation_exam(id)->'questions'->0->>'id'), 0),
      1200
    )->>'scoring_disclaimer' like '%Diagnostic score estimate only%'
    from public.target_versions where version_code = '2026-PRIV'
  ),
  'clep_submit_simulation_exam includes explicit disclaimer prohibiting official score equivalence'
);

rollback;
