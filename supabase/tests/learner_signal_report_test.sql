-- pgTAP: learner-signal report (migration 20261125010000, ingestion plan
-- v1.2 slice 13 and §16.4).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(19);

-- Fictional fixtures, rolled back. Consent needs an eligible, non-guest
-- account and an approved analytics release policy (ANA-103).
insert into analytics.product_release_gate (id, approved_policy_version, policy_approved_at, collection_enabled, reviewed_by)
values (1, 'pgtap-fixture', now(), true, 'pgtap fixture')
on conflict (id) do update set approved_policy_version = 'pgtap-fixture', policy_approved_at = now(),
  collection_enabled = true, reviewed_by = 'pgtap fixture';
insert into auth.users (id, email, is_anonymous, raw_app_meta_data)
select ('5e100000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'signal-' || g || '@example.invalid',
       false, '{"product_analytics_eligible": "true"}'::jsonb
from generate_series(1, 20) g
on conflict (id) do nothing;
-- Learners 1-18 consent; 19 and 20 do not. Learner 20 is an admin.
insert into analytics.product_consents (user_id, consented)
select ('5e100000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, true from generate_series(1, 18) g;
insert into public.moderation_roles (user_id, role)
values ('5e100000-0000-4000-8000-000000000020', 'admin');

update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_projection';

insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('5e100000-0000-4000-8000-000000000a10', 'standardized_exam', 'Signal Fictional Target', 'test-signal', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('5e100000-0000-4000-8000-000000000a11', '5e100000-0000-4000-8000-000000000a10', 'sg-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order) values
  ('5e100000-0000-4000-8000-000000000a21', '5e100000-0000-4000-8000-000000000a11', 'objective', 'S1', 'Busy objective', 1),
  ('5e100000-0000-4000-8000-000000000a22', '5e100000-0000-4000-8000-000000000a11', 'objective', 'S2', 'Quiet objective', 2);
insert into public.knowledge_concepts (id, slug, name)
values ('5e100000-0000-4000-8000-000000000a41', 'sg-fixture-concept', 'Signal concept');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
values ('5e100000-0000-4000-8000-000000000a21', '5e100000-0000-4000-8000-000000000a41');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  ('5e100000-0000-4000-8000-000000000b01', 'Busy lesson', 'public', '5e100000-0000-4000-8000-000000000a11'),
  ('5e100000-0000-4000-8000-000000000b02', 'Quiet lesson', 'public', '5e100000-0000-4000-8000-000000000a11');
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order) values
  ('5e100000-0000-4000-8000-000000000a21', '5e100000-0000-4000-8000-000000000b01', 1),
  ('5e100000-0000-4000-8000-000000000a22', '5e100000-0000-4000-8000-000000000b02', 1);
-- A short reading: the estimate floors at 5 minutes.
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('5e100000-0000-4000-8000-000000000b01', 'markdown', 1, '{"text":"Read this."}'),
  ('5e100000-0000-4000-8000-000000000b02', 'markdown', 1, '{"text":"Read this."}');

select public.ingest_held_out_items('5e100000-0000-4000-8000-000000000a11', (
  select jsonb_agg(jsonb_build_object(
    'key', 'sg-' || g, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 9 + ' || g || ' (signal)',
    'scoring_spec', jsonb_build_object('correct_value', 9 + g, 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array('sg-fixture-concept'),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_kind', 'ai', 'reviewer_model', 'fictional-model',
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1',
      'reviewed_on', '2026-11-25', 'review_status', 'approved', 'rights_review_status', 'approved')))
  from generate_series(1, 6) g));
update public.target_versions set status = 'review_ready' where id = '5e100000-0000-4000-8000-000000000a11';
update public.target_versions set status = 'published' where id = '5e100000-0000-4000-8000-000000000a11';

-- S1: learners 1-12 and 19 (no consent) complete the lesson on 2026-11-20,
-- each after 20 active minutes (an unfinished visit the day before).
insert into public.learner_activity_progress (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
select ('5e100000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'legacy_lesson',
       '5e100000-0000-4000-8000-000000000b01', 'v1', d.day, d.done, 600
from (select g from generate_series(1, 12) g union all select 19) u
cross join (values ('2026-11-19'::date, false), ('2026-11-20'::date, true)) d(day, done);
-- Learner 13 started but never completed.
insert into public.learner_activity_progress (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
values ('5e100000-0000-4000-8000-000000000013', 'legacy_lesson', '5e100000-0000-4000-8000-000000000b01', 'v1', '2026-11-20', false, 900);

-- Check answers: learners 1-6 fail (0), 7-11 pass (1), all after completing.
-- Learner 12 answered only before completing; learner 19 has no consent.
insert into private.item_response_log (item_id, user_id, score, responded_at)
select r.assessment_item_id, ('5e100000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       case when g <= 6 then 0 else 1 end, '2026-11-21 10:00+00'
from generate_series(1, 11) g
cross join (select assessment_item_id from private.held_out_item_reviews
            where target_version_id = '5e100000-0000-4000-8000-000000000a11' limit 2) r;
insert into private.item_response_log (item_id, user_id, score, responded_at)
select assessment_item_id, '5e100000-0000-4000-8000-000000000012', 0, '2026-11-18 10:00+00'
from private.held_out_item_reviews where target_version_id = '5e100000-0000-4000-8000-000000000a11' limit 1;

-- S2: three completers only.
insert into public.learner_activity_progress (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
select ('5e100000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'legacy_lesson',
       '5e100000-0000-4000-8000-000000000b02', 'v1', '2026-11-20', true, 120
from generate_series(1, 3) g;

-- Access: guests and ordinary learners are refused.
create function pg_temp.report_as(p_role text, p_user text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  execute format('set local role %I', p_role);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', p_role)::text, true);
  v := public.get_learner_signal_report('5e100000-0000-4000-8000-000000000a11');
  set local role postgres;
  return v;
end $$;
select throws_ok($$ select pg_temp.report_as('anon', null) $$, '42501', null, 'guests cannot read the report');
set local role postgres;
select throws_ok($$ select pg_temp.report_as('authenticated', '5e100000-0000-4000-8000-000000000001') $$,
  '42501', null, 'ordinary learners cannot read the report');
set local role postgres;

create temp table rep as
  select pg_temp.report_as('authenticated', '5e100000-0000-4000-8000-000000000020') as v;
set local role postgres;
create temp table s1 as select o as v from rep, jsonb_array_elements(rep.v->'objectives') o where o->>'code' = 'S1';
create temp table s2 as select o as v from rep, jsonb_array_elements(rep.v->'objectives') o where o->>'code' = 'S2';

select is((select v->>'consenting_learners' from rep), '13', 'consenting learners with any progress on the target');
select is((select v->>'completed_learners' from s1), '12', 'completers count consenting learners who finished every linked lesson');
select is((select v->>'checked_after_teaching' from s1), '11', 'answers before completing do not count');
select is((select v->>'fail_rate' from s1), '0.545', 'fail rate is the share with a mean check score below 0.6');
select is((select v->>'median_active_minutes' from s1), '20.0', 'median active minutes across all visits');
select is((select v->>'estimate_high' from s1), '5', 'the estimate range comes from get_target_study_estimates');
select is((select v->'signals' from s1),
  '["repeated_failure_after_teaching", "time_off_estimate"]'::jsonb, 'both signals fire at 10+ learners');
select is((select v->>'status' from s2), 'small_cohort_suppressed', 'fewer than 5 completers is suppressed');
select ok((select v->'completed_learners' = 'null'::jsonb and v->'median_active_minutes' = 'null'::jsonb from s2),
  'suppressed objectives withhold counts and medians');
select is((select v->'signals' from s2), '[]'::jsonb, 'no signal from a suppressed group');

-- Withdrawn consent removes a learner from the report.
update analytics.product_consents set consented = false where user_id = '5e100000-0000-4000-8000-000000000001';
select is((select o->>'completed_learners'
           from jsonb_array_elements(pg_temp.report_as('authenticated', '5e100000-0000-4000-8000-000000000020')->'objectives') o
           where o->>'code' = 'S1'), '11', 'a learner who withdraws consent is no longer counted');
set local role postgres;

-- Opening review items: one per repeated-failure signal, never twice.
create function pg_temp.open_as(p_user text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  set local role authenticated;
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  v := public.open_learner_signal_reviews('5e100000-0000-4000-8000-000000000a11');
  set local role postgres;
  return v;
end $$;
select throws_ok($$ select pg_temp.open_as('5e100000-0000-4000-8000-000000000002') $$,
  '42501', null, 'ordinary learners cannot open review items');
set local role postgres;
select is(pg_temp.open_as('5e100000-0000-4000-8000-000000000020')->>'opened', '1', 'one review item opened');
set local role postgres;
select is((select count(*)::int from public.moderation_reports
           where target_type = 'lesson' and target_id = '5e100000-0000-4000-8000-000000000b01'
             and status = 'pending' and description like '[Learner Signal] repeated_failure_after_teaching%'),
  1, 'the item is a pending report on the objective''s lesson');
select is(pg_temp.open_as('5e100000-0000-4000-8000-000000000020')->>'already_open', '1', 'an open item is not duplicated');
set local role postgres;
select is((select count(*)::int from public.lesson_blocks where lesson_id = '5e100000-0000-4000-8000-000000000b01'),
  1, 'nothing is edited');
select ok(not has_function_privilege('anon', 'public.get_learner_signal_report(uuid)', 'execute'),
  'guests have no execute grant');

select * from finish();
rollback;
