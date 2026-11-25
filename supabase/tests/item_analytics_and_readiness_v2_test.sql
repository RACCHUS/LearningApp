-- ============================================================================
-- pgTAP tests for Architecture Phase 1:
-- Item Analytics Feeding Moderation & Readiness Score v2 with FSRS Calibration
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(31);

-- 1. Create synthetic test users in auth.users and public.users
insert into auth.users (id, email) values
 ('aa111111-0000-4000-8000-000000000001', 'learner_high@example.invalid'),
 ('aa111111-0000-4000-8000-000000000002', 'learner_low@example.invalid')
on conflict (id) do nothing;

insert into public.users (id, email, display_name) values
 ('aa111111-0000-4000-8000-000000000001', 'learner_high@example.invalid', 'High Performer'),
 ('aa111111-0000-4000-8000-000000000002', 'learner_low@example.invalid', 'Low Performer')
on conflict (id) do nothing;

-- 2. Setup synthetic test questions
insert into public.skills (id, name, slug, category, description) values
 ('bb111111-0000-4000-8000-000000000001', 'Analytics Psychometrics Skill', 'analytics-skill', 'Psychometrics', 'Skill for testing item analytics')
on conflict (id) do nothing;

insert into public.skill_assessments (id, skill_id, title, description, passing_score, time_limit_minutes, is_active) values
 ('bb222222-0000-4000-8000-000000000001', 'bb111111-0000-4000-8000-000000000001', 'Psychometrics Assessment', 'Assessment for analytics tests', 70, 10, true)
on conflict (id) do nothing;

insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer, explanation, order_index) values
 ('bb333333-0000-4000-8000-000000000001', 'bb222222-0000-4000-8000-000000000001', 'Normal Item', '["A", "B", "C", "D"]'::jsonb, 0, 'A is correct', 0),
 ('bb333333-0000-4000-8000-000000000002', 'bb222222-0000-4000-8000-000000000001', 'Defective Miskeyed Item', '["A", "B", "C", "D"]'::jsonb, 1, 'B is supposedly correct', 1),
 ('bb333333-0000-4000-8000-000000000003', 'bb222222-0000-4000-8000-000000000001', 'General Benchmark Item', '["True", "False"]'::jsonb, 0, 'True is correct', 2)
on conflict (id) do nothing;

-- 3. TEST: Table public.item_analytics exists
select has_table('public', 'item_analytics', 'public.item_analytics exists');
select has_column('public', 'item_analytics', 'p_value', 'item_analytics has p_value column');
select has_column('public', 'item_analytics', 'point_biserial', 'item_analytics has point_biserial column');
select has_column('public', 'item_analytics', 'distractor_rates', 'item_analytics has distractor_rates column');
select has_column('public', 'item_analytics', 'median_latency_ms', 'item_analytics has median_latency_ms column');
select has_column('public', 'item_analytics', 'auto_flagged', 'item_analytics has auto_flagged column');

-- 4. TEST: Anon permissions (least privilege)
set local role anon;

select throws_ok(
  $$ select compute_item_analytics(5) $$,
  '42501',
  null,
  'Anon cannot execute compute_item_analytics'
);

select throws_ok(
  $$ select get_item_analytics('bb333333-0000-4000-8000-000000000001'::uuid) $$,
  '42501',
  null,
  'Anon cannot execute get_item_analytics'
);

select throws_ok(
  $$ select get_target_readiness_v2('cc111111-0000-4000-8000-000000000001'::uuid) $$,
  '42501',
  null,
  'Anon cannot execute get_target_readiness_v2'
);

select throws_ok(
  $$ insert into public.item_analytics (item_id) values ('bb333333-0000-4000-8000-000000000001'::uuid) $$,
  '42501',
  null,
  'Anon cannot insert into item_analytics'
);

set local role postgres;

-- 5. Question statistics under plan v1.2 §16.4 (migration 20261124110000):
-- only consenting learners count, once each (first response), items with
-- fewer than 5 learners are suppressed, flags need 30+ learners.
-- Consent needs an eligible, non-guest account and an approved analytics
-- release policy (ANA-103); both are set up inside this rolled-back test.
insert into analytics.product_release_gate (id, approved_policy_version, policy_approved_at, collection_enabled, reviewed_by)
values (1, 'pgtap-fixture', now(), true, 'pgtap fixture')
on conflict (id) do update set approved_policy_version = 'pgtap-fixture', policy_approved_at = now(),
  collection_enabled = true, reviewed_by = 'pgtap fixture';
insert into auth.users (id, email, is_anonymous, raw_app_meta_data)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'stat-learner-' || g || '@example.invalid',
       false, '{"product_analytics_eligible": "true"}'::jsonb
from generate_series(1, 55) g
on conflict (id) do nothing;
insert into analytics.product_consents (user_id, consented)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, true
from generate_series(1, 55) g;
insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer, explanation, order_index) values
 ('bb333333-0000-4000-8000-000000000004', 'bb222222-0000-4000-8000-000000000001', 'Rare Item', '["A", "B"]'::jsonb, 0, 'A', 3)
on conflict (id) do nothing;

-- Benchmark: learners 1-20 answer correctly (stronger), 21-40 incorrectly.
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000003', case when g <= 20 then 1.0 else 0.0 end,
       jsonb_build_object('selected', case when g <= 20 then '0' else '1' end), 4000, now() - interval '3 days', now() - interval '3 days'
from generate_series(1, 40) g;
-- Normal item: stronger learners and half the others correct (p = 0.75).
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000001', case when g <= 30 then 1.0 else 0.0 end,
       jsonb_build_object('selected', case when g <= 30 then '0' else '1' end), 5000, now() - interval '2 days', now() - interval '2 days'
from generate_series(1, 40) g;
-- (effective_occurred_at is the canonical event time; record_events sets it
-- from the client's clamped time, so the fixtures set it explicitly.)
-- A later repeat by learner 1 (wrong) must not count, and neither may the two
-- learners who have not consented.
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at) values
 ('aa220000-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 0.0, '{"selected":"2"}'::jsonb, 5000, now() - interval '1 day', now() - interval '1 day'),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 0.0, '{"selected":"3"}'::jsonb, 5000, now(), now()),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 0.0, '{"selected":"3"}'::jsonb, 5000, now(), now());
-- Defective item: the stronger learners miss it, the others get it right.
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000002', case when g <= 20 then 0.0 else 1.0 end,
       jsonb_build_object('selected', case when g <= 20 then '0' else '1' end), 6000, now() - interval '2 days', now() - interval '2 days'
from generate_series(1, 40) g;
-- Rare item: only 4 learners, so it is suppressed.
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000004', 1.0, '{"selected":"0"}'::jsonb, 5000, now() - interval '2 days', now() - interval '2 days'
from generate_series(1, 4) g;

-- Too easy: all 40 learners answer correctly.
insert into public.assessment_questions (id, assessment_id, question_text, options, correct_answer, explanation, order_index) values
 ('bb333333-0000-4000-8000-000000000005', 'bb222222-0000-4000-8000-000000000001', 'Easy Item', '["A", "B"]'::jsonb, 0, 'A', 4)
on conflict (id) do nothing;
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000005', 1.0, '{"selected":"0"}'::jsonb, 5000, now() - interval '2 days', now() - interval '2 days'
from generate_series(1, 40) g;
-- A single-choice assessment item with four options; 55 learners choose only
-- A (keyed) or B, so C and D are almost never chosen (counted as 0).
insert into public.assessment_items (id, interaction_type, prompt, response_spec, scoring_spec) values
 ('bb333333-0000-4000-8000-000000000006', 'single_choice', 'Distractor item',
  '{"options": ["A", "B", "C", "D"]}'::jsonb, '{"correct_index": 0}'::jsonb);
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms, occurred_at, effective_occurred_at)
select ('aa220000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'question_response', 'question',
       'bb333333-0000-4000-8000-000000000006', case when g % 3 = 0 then 0.0 else 1.0 end,
       jsonb_build_object('selected', case when g % 3 = 0 then '1' else '0' end), 5000, now() - interval '2 days', now() - interval '2 days'
from generate_series(1, 55) g;

-- 6. TEST: Run compute_item_analytics (direct database session)
select lives_ok($$ select compute_item_analytics(5) $$, 'compute_item_analytics executes successfully');

-- 7. TEST: Normal item
select is((select p_value from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001')::numeric,
  0.750::numeric, 'Normal item p_value is 0.75: first responses only, consenting learners only');
select is((select response_count from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001'),
  40, 'Each consenting learner counts once');
select ok((select point_biserial from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001') > 0.10,
  'Normal item discriminates');
select is((select auto_flagged from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001'),
  false, 'Normal item is not flagged');

-- 8. TEST: Defective item
select ok((select 'low_discrimination' = any (flagged_reasons) and auto_flagged
           from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000002'),
  'Defective item is flagged for low discrimination');

-- 9. TEST: A revision item opens in the moderation queue; nothing else changes
select ok(exists (select 1 from public.moderation_reports
                  where target_type = 'question' and target_id = 'bb333333-0000-4000-8000-000000000002'
                    and status = 'pending' and description like '[Item Analytics Auto-Flag] low_discrimination%'
                    and description like '%Nothing has been changed automatically%'),
  'A moderation report was created for the defective question');
select is((select count(*)::int from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000004'),
  0, 'An item with fewer than 5 learners keeps no statistics');

select ok((select 'too_easy' = any (flagged_reasons) from public.item_analytics
           where item_id = 'bb333333-0000-4000-8000-000000000005'),
  'An item everyone gets right is flagged too easy');
select ok((select 'rarely_chosen_distractor' = any (flagged_reasons)
                  and (distractor_counts->>'2')::int = 0 and (distractor_counts->>'3')::int = 0
           from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000006'),
  'Options nobody chose count as 0 and are flagged as rarely chosen');
select ok((select not ('rarely_chosen_distractor' = any (flagged_reasons))
           from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000005'),
  'The distractor rule needs an option list and 50+ learners');

-- 10. TEST: get_item_analytics RPC returns the payload to a privileged session
select is((get_item_analytics('bb333333-0000-4000-8000-000000000001'::uuid)->>'response_count')::integer,
  40, 'get_item_analytics returns correct response_count');

-- 10b. TEST: an ordinary learner can neither compute nor read statistics; a moderator can read
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aa220000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok($$ select compute_item_analytics(5) $$, '42501', null, 'A learner cannot compute statistics');
select throws_ok($$ select get_item_analytics('bb333333-0000-4000-8000-000000000001'::uuid) $$, '42501', null,
  'A learner cannot read an item''s statistics');
select is((select count(*)::int from public.item_analytics), 0, 'A learner sees no statistics rows');
reset role;
insert into public.moderation_roles (user_id, role) values ('aa220000-0000-4000-8000-000000000002', 'moderator');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aa220000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((get_item_analytics('bb333333-0000-4000-8000-000000000001'::uuid)->>'response_count')::integer,
  40, 'A moderator can read an item''s statistics');
reset role;
select set_config('request.jwt.claims', '', true);

-- 11. TEST: get_target_readiness_v2 setup and evaluation
-- Create synthetic target version, nodes, and core concepts with valid constraints
insert into public.learning_targets (id, title, slug, target_type, status, is_public) values
 ('cc111111-0000-4000-8000-000000000001', 'Test Target', 'test-target-p1', 'licensure_exam', 'published', true)
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_code, status) values
 ('cc222222-0000-4000-8000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'v1.0.0', 'published')
on conflict (id) do nothing;

insert into public.curriculum_nodes (id, target_version_id, title, node_type, sort_order) values
 ('cc333333-0000-4000-8000-000000000001', 'cc222222-0000-4000-8000-000000000001', 'Core Node 1', 'unit', 1)
on conflict (id) do nothing;

insert into public.knowledge_concepts (id, name, slug, description) values
 ('cc444444-0000-4000-8000-000000000001', 'Core Concept 1', 'concept-1-p1', 'First core concept'),
 ('cc444444-0000-4000-8000-000000000002', 'Core Concept 2', 'concept-2-p1', 'Second core concept')
on conflict (id) do nothing;

insert into public.curriculum_node_concepts (curriculum_node_id, concept_id, relevance, weight) values
 ('cc333333-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000001', 'core', 1.0),
 ('cc333333-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000002', 'core', 1.0)
on conflict (curriculum_node_id, concept_id) do nothing;

-- Setup concept evidence & FSRS card for High Performer
insert into public.user_concept_state (user_id, concept_id, retrieval_band, confidence, evidence_count, weighted_correct, weighted_total) values
 ('aa111111-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000001', 'well_established', 'high', 10, 9.0, 10.0),
 ('aa111111-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000002', 'well_retained', 'high', 8, 7.0, 8.0)
on conflict (user_id, concept_id) do update set
  retrieval_band = excluded.retrieval_band,
  weighted_correct = excluded.weighted_correct,
  weighted_total = excluded.weighted_total;

insert into public.review_items (id, user_id, content_id, content_type, lesson_id, title, stability, difficulty, last_reviewed_at) values
 ('ee111111-0000-4000-8000-000000000001', 'aa111111-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000001', 'concept', 'l1', 'Card 1', 30.0, 3.0, now() - interval '2 days'),
 ('ee111111-0000-4000-8000-000000000002', 'aa111111-0000-4000-8000-000000000001', 'cc444444-0000-4000-8000-000000000002', 'concept', 'l1', 'Card 2', 20.0, 4.0, now() - interval '3 days')
on conflict (id) do nothing;

-- 12. Authenticate as High Performer and evaluate readiness
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aa111111-0000-4000-8000-000000000001","role":"authenticated"}', true);

select is(
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid)->>'readiness_band')::text,
  'strongCoverage',
  'get_target_readiness_v2 assigns strongCoverage for high proficiency learner'
);

select is(
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid)->>'total_core_concepts')::integer,
  2,
  'get_target_readiness_v2 returns total core concept count 2'
);

select is(
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid)->>'assessed_concepts_count')::integer,
  2,
  'get_target_readiness_v2 returns assessed concept count 2'
);

select ok(
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid)->>'readiness_score')::numeric >= 0.85,
  'get_target_readiness_v2 readiness score is >= 0.85'
);

select ok(
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid, now() + interval '30 days')->>'average_retrievability')::numeric <
  (get_target_readiness_v2('cc222222-0000-4000-8000-000000000001'::uuid, now())->>'average_retrievability')::numeric,
  'Retrievability is lower at a 30-day future exam date reflecting memory decay (FSRS calibration)'
);

rollback;
