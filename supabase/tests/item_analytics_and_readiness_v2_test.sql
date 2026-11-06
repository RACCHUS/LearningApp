-- ============================================================================
-- pgTAP tests for Architecture Phase 1:
-- Item Analytics Feeding Moderation & Readiness Score v2 with FSRS Calibration
-- ============================================================================
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

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
 ('bb333333-0000-4000-8000-000000000002', 'bb222222-0000-4000-8000-000000000001', 'Defective Miskeyed Item', '["A", "B", "C", "D"]'::jsonb, 1, 'B is supposedly correct', 1)
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

-- 5. Seed synthetic learning_events to test psychometric calculations
set local role postgres;

-- Normal item responses (8 responses: 6 correct, 2 incorrect; high performer correct, low performer incorrect)
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms) values
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 4000),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 4500),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 5000),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 4200),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 6000),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 1.0, '{"selected":"0"}'::jsonb, 5500),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 0.0, '{"selected":"1"}'::jsonb, 7000),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000001', 0.0, '{"selected":"2"}'::jsonb, 8000);

-- Defective item responses (8 responses: high performer scores 0.0, low performer scores 1.0 -> negative discrimination!)
insert into public.learning_events (user_id, event_type, item_type, item_id, score, response, latency_ms) values
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"0"}'::jsonb, 12000),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"0"}'::jsonb, 11000),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"2"}'::jsonb, 10500),
 ('aa111111-0000-4000-8000-000000000001', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"2"}'::jsonb, 9500),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 1.0, '{"selected":"1"}'::jsonb, 4000),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 1.0, '{"selected":"1"}'::jsonb, 4200),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"3"}'::jsonb, 6000),
 ('aa111111-0000-4000-8000-000000000002', 'question_response', 'question', 'bb333333-0000-4000-8000-000000000002', 0.0, '{"selected":"3"}'::jsonb, 6500);

-- 6. TEST: Run compute_item_analytics
select lives_ok(
  $$ select compute_item_analytics(5) $$,
  'compute_item_analytics executes successfully'
);

-- 7. TEST: Verify item analytics for Normal Item
select is(
  (select p_value from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001')::numeric,
  0.750::numeric,
  'Normal item p_value is 0.75 (6 / 8)'
);

select ok(
  (select point_biserial from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001') > 0.0,
  'Normal item point_biserial is positive'
);

select ok(
  (select auto_flagged from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000001') = false,
  'Normal item is not auto-flagged'
);

-- 8. TEST: Verify item analytics and auto-flagging for Defective Item
select is(
  (select p_value from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000002')::numeric,
  0.250::numeric,
  'Defective item p_value is 0.25 (2 / 8)'
);

select ok(
  (select point_biserial from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000002') < 0.0,
  'Defective item has negative point_biserial (discrimination defect)'
);

select is(
  (select auto_flagged from public.item_analytics where item_id = 'bb333333-0000-4000-8000-000000000002'),
  true,
  'Defective item is auto-flagged'
);

-- 9. TEST: Moderation report was created for defective item
select ok(
  exists (
    select 1 from public.moderation_reports
    where target_type = 'question'
      AND target_id = 'bb333333-0000-4000-8000-000000000002'
      AND reason = 'other'
      AND status = 'pending'
      AND description like '[Item Analytics Auto-Flag]%'
  ),
  'Moderation report was automatically created for defective question'
);

-- 10. TEST: get_item_analytics RPC returns populated payload
select is(
  (get_item_analytics('bb333333-0000-4000-8000-000000000001'::uuid)->>'response_count')::integer,
  8,
  'get_item_analytics returns correct response_count'
);

-- 11. TEST: get_target_readiness_v2 setup and evaluation
-- Create synthetic target version, nodes, and core concepts
insert into public.learning_targets (id, title, target_type, status, is_public) values
 ('cc111111-0000-4000-8000-000000000001', 'Test Target', 'exam', 'published', true)
on conflict (id) do nothing;

insert into public.target_versions (id, target_id, version_tag, status) values
 ('cc222222-0000-4000-8000-000000000001', 'cc111111-0000-4000-8000-000000000001', 'v1.0.0', 'published')
on conflict (id) do nothing;

insert into public.curriculum_nodes (id, target_version_id, title, node_type, sequence_order) values
 ('cc333333-0000-4000-8000-000000000001', 'cc222222-0000-4000-8000-000000000001', 'Core Node 1', 'unit', 1)
on conflict (id) do nothing;

insert into public.knowledge_concepts (id, key, name, description) values
 ('cc444444-0000-4000-8000-000000000001', 'concept_1', 'Core Concept 1', 'First core concept'),
 ('cc444444-0000-4000-8000-000000000002', 'concept_2', 'Core Concept 2', 'Second core concept')
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

insert into public.review_items (id, user_id, content_id, concept_id, content_type, lesson_id, title, stability, difficulty, fsrs_state, last_reviewed_at) values
 ('ee111111-0000-4000-8000-000000000001', 'aa111111-0000-4000-8000-000000000001', 'c1', 'cc444444-0000-4000-8000-000000000001', 'card', 'l1', 'Card 1', 30.0, 3.0, 2, now() - interval '2 days'),
 ('ee111111-0000-4000-8000-000000000002', 'aa111111-0000-4000-8000-000000000001', 'c2', 'cc444444-0000-4000-8000-000000000002', 'card', 'l1', 'Card 2', 20.0, 4.0, 2, now() - interval '3 days')
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

