-- pgTAP: companion outcome report (migration 20261126010000, companion plan
-- v1.0 EX-10). Opted-in learners only, small groups withheld (including by
-- subtraction), no names or links, and no way to read it as a learner.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);

-- Fictional fixtures, rolled back. Consent needs an eligible, non-guest
-- account and an approved analytics release policy (ANA-103).
insert into analytics.product_release_gate (id, approved_policy_version, policy_approved_at, collection_enabled, reviewed_by)
values (1, 'pgtap-fixture', now(), true, 'pgtap fixture')
on conflict (id) do update set approved_policy_version = 'pgtap-fixture', policy_approved_at = now(),
  collection_enabled = true, reviewed_by = 'pgtap fixture';
insert into auth.users (id, email, is_anonymous, raw_app_meta_data)
select ('5e200000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'outcome-' || g || '@example.invalid',
       false, '{"product_analytics_eligible": "true"}'::jsonb
from generate_series(1, 20) g
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like '5e200000-%' on conflict (id) do nothing;
-- Learners 1-18 consent; 19 and 20 do not. Learner 20 is an admin.
insert into analytics.product_consents (user_id, consented)
select ('5e200000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, true from generate_series(1, 18) g;
insert into public.moderation_roles (user_id, role)
values ('5e200000-0000-4000-8000-000000000020', 'admin');

insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('5e200000-0000-4000-8000-000000000a10', 'standardized_exam', 'Outcome Fictional Target', 'test-outcome', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('5e200000-0000-4000-8000-000000000a11', '5e200000-0000-4000-8000-000000000a10', 'oc-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, code, title, sort_order) values
  ('5e200000-0000-4000-8000-000000000a21', '5e200000-0000-4000-8000-000000000a11', 'objective', 'CO1', 'Checked objective', 1),
  ('5e200000-0000-4000-8000-000000000a22', '5e200000-0000-4000-8000-000000000a11', 'objective', 'CO2', 'Objective without checks', 2);
insert into public.knowledge_concepts (id, slug, name)
values ('5e200000-0000-4000-8000-000000000a41', 'oc-fixture-concept', 'Outcome concept');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
values ('5e200000-0000-4000-8000-000000000a21', '5e200000-0000-4000-8000-000000000a41');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  ('5e200000-0000-4000-8000-000000000b01', 'Outcome lesson', 'public', '5e200000-0000-4000-8000-000000000a11');
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order) values
  ('5e200000-0000-4000-8000-000000000a22', '5e200000-0000-4000-8000-000000000b01', 1);
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('5e200000-0000-4000-8000-000000000b01', 'markdown', 1, '{"text":"Read this."}');

select public.ingest_held_out_items('5e200000-0000-4000-8000-000000000a11', (
  select jsonb_agg(jsonb_build_object(
    'key', 'oc-' || g, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 3 + ' || g || ' (outcome)',
    'scoring_spec', jsonb_build_object('correct_value', 3 + g, 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array('oc-fixture-concept'),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_kind', 'ai', 'reviewer_model', 'fictional-model',
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1',
      'reviewed_on', '2026-11-25', 'review_status', 'approved', 'rights_review_status', 'approved')))
  from generate_series(1, 6) g));
update public.target_versions set status = 'review_ready' where id = '5e200000-0000-4000-8000-000000000a11';
update public.target_versions set status = 'published' where id = '5e200000-0000-4000-8000-000000000a11';

-- Study progress on the goal: learners 1-14, and 19 (no consent).
insert into public.learner_activity_progress (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
select ('5e200000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'legacy_lesson',
       '5e200000-0000-4000-8000-000000000b01', 'v1', '2026-11-20', false, 300
from (select g from generate_series(1, 14) g union all select 19) u;

-- An outside resource on the goal: learners 1-12, 15 (no study progress
-- here) and 19 (no consent). The title and link must never be reported.
insert into public.learner_external_resources (id, user_id, target_id, title, kind, url)
select ('5e200000-0000-4000-8000-0000000c' || lpad(g::text, 4, '0'))::uuid,
       ('5e200000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
       '5e200000-0000-4000-8000-000000000a10', 'Secret course title ' || g, 'course',
       'https://secret.example/course/' || g
from (select g from generate_series(1, 12) g union all select 15 union all select 19) u;
-- Mapping: 1-5 used their own AI, 6-10 the word match, 11-12 ticked by hand,
-- 15 only listed it.
insert into public.learner_resource_sections (resource_id, user_id, position, title, objective_keys, map_source)
select r.id, r.user_id, 1, 'Unit 1', array['CO1'],
       case when right(r.id::text, 4)::int <= 5 then 'own_ai' else 'outline_match' end
from public.learner_external_resources r
where r.target_id = '5e200000-0000-4000-8000-000000000a10' and right(r.id::text, 4)::int <= 10;
-- Covered objectives: learners 1-12 and 19 tick CO1 and CO2. Learners 1-10
-- and 19 mark both studied on 2026-11-20.
insert into public.learner_resource_objectives (resource_id, user_id, objective_key, studied_at)
select r.id, r.user_id, k.key,
       case when right(r.id::text, 4)::int <= 10 or right(r.id::text, 4)::int = 19
            then '2026-11-20 09:00+00'::timestamptz end
from public.learner_external_resources r
cross join (values ('CO1'), ('CO2')) k(key)
where r.target_id = '5e200000-0000-4000-8000-000000000a10' and right(r.id::text, 4)::int <> 15;

-- Independent checks on CO1. Learners 1-4 and 19 answer the next day.
-- Learner 6 answers 15 days later and learner 7 the day before studying:
-- neither counts as a check that followed the study.
insert into private.item_response_log (item_id, user_id, score, responded_at)
select i.assessment_item_id, ('5e200000-0000-4000-8000-' || lpad(u.g::text, 12, '0'))::uuid, 1, u.at
from (select g, '2026-11-21 10:00+00'::timestamptz as at from generate_series(1, 4) g
      union all select 19, '2026-11-21 10:00+00'
      union all select 6, '2026-12-05 10:00+00'
      union all select 7, '2026-11-19 10:00+00') u
cross join (select assessment_item_id from private.held_out_item_reviews
            where target_version_id = '5e200000-0000-4000-8000-000000000a11' limit 1) i;

create function pg_temp.report_as(p_role text, p_user text, p_version uuid default '5e200000-0000-4000-8000-000000000a11')
returns jsonb language plpgsql as $$
declare v jsonb;
begin
  execute format('set local role %I', p_role);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', p_role)::text, true);
  v := public.get_companion_outcome_report(p_version);
  set local role postgres;
  return v;
end $$;

-- Access.
select throws_ok($$ select pg_temp.report_as('anon', null) $$, '42501', null, 'guests cannot read the report');
set local role postgres;
select throws_ok($$ select pg_temp.report_as('authenticated', '5e200000-0000-4000-8000-000000000001') $$,
  '42501', null, 'ordinary learners cannot read the report');
set local role postgres;
select throws_ok(
  $$ select pg_temp.report_as('authenticated', '5e200000-0000-4000-8000-000000000020', '5e200000-0000-4000-8000-00000000dead') $$,
  'P0002', 'target_version_not_found', 'an unknown goal version is refused');
set local role postgres;

-- First state: small leftovers everywhere.
select set_config('test.oc_a', pg_temp.report_as('authenticated', '5e200000-0000-4000-8000-000000000020')::text, true);
select is((current_setting('test.oc_a')::jsonb ->> 'goal_learners')::int, 15,
  'opted-in learners with progress or an outside resource on the goal are counted once each');
select ok(
  current_setting('test.oc_a')::jsonb ->> 'outside_resource_status' = 'small_cohort_suppressed'
  and current_setting('test.oc_a')::jsonb -> 'with_outside_resource' = 'null'::jsonb
  and current_setting('test.oc_a')::jsonb -> 'outside_resource_share' = 'null'::jsonb,
  'a share is withheld when only 2 learners are left over (they could be worked out by subtraction)');
select ok(
  current_setting('test.oc_a')::jsonb #>> '{mapping,status}' = 'small_cohort_suppressed'
  and current_setting('test.oc_a')::jsonb #> '{mapping,outline_own_ai}' = 'null'::jsonb,
  'the mapping breakdown is withheld while any rung holds 1 to 4 learners');
select ok(
  current_setting('test.oc_a')::jsonb #>> '{studied_then_checked,status}' = 'small_cohort_suppressed'
  and current_setting('test.oc_a')::jsonb #> '{studied_then_checked,studied_pairs}' = 'null'::jsonb,
  'studied-then-checked is withheld while only 4 learners were checked');

-- Second state: three more opted-in learners study the goal, the hand
-- tickers and the lister paste an outline, and a fifth learner is checked.
insert into public.learner_activity_progress (user_id, content_kind, content_id, version_key, reporting_date_utc, completed, active_seconds)
select ('5e200000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'legacy_lesson',
       '5e200000-0000-4000-8000-000000000b01', 'v1', '2026-11-20', false, 300
from generate_series(16, 18) g;
insert into public.learner_resource_sections (resource_id, user_id, position, title, objective_keys, map_source)
select r.id, r.user_id, 1, 'Unit 1', array['CO1'], 'outline_match'
from public.learner_external_resources r
where r.target_id = '5e200000-0000-4000-8000-000000000a10' and right(r.id::text, 4)::int in (11, 12, 15);
insert into private.item_response_log (item_id, user_id, score, responded_at)
select assessment_item_id, '5e200000-0000-4000-8000-000000000005', 1, '2026-11-22 10:00+00'
from private.held_out_item_reviews where target_version_id = '5e200000-0000-4000-8000-000000000a11' limit 1;

select set_config('test.oc_b', pg_temp.report_as('authenticated', '5e200000-0000-4000-8000-000000000020')::text, true);
select is((current_setting('test.oc_b')::jsonb ->> 'goal_learners')::int, 18,
  'goal learners now number 18; the learner without consent is never counted');
select ok(
  (current_setting('test.oc_b')::jsonb ->> 'with_outside_resource')::int = 13
  and (current_setting('test.oc_b')::jsonb ->> 'outside_resource_share')::numeric = 0.722,
  '13 of 18 added an outside resource, and the share is shown once 5 are left over');
select is(
  current_setting('test.oc_b')::jsonb -> 'mapping',
  '{"status": "ok", "listed_only": 0, "ticked_objectives": 0, "outline_word_match": 8, "outline_own_ai": 5}'::jsonb,
  'each learner is counted at the furthest mapping rung they reached');
select is((current_setting('test.oc_b')::jsonb #>> '{studied_then_checked,studied_pairs}')::int, 10,
  'only objectives LearningApp can check are counted, one pair per learner and objective');
select ok(
  (current_setting('test.oc_b')::jsonb #>> '{studied_then_checked,checked_within_7_days}')::int = 5
  and (current_setting('test.oc_b')::jsonb #>> '{studied_then_checked,checked_share}')::numeric = 0.5,
  'a check counts only if it came after the study mark and within 7 days');
select is((current_setting('test.oc_b')::jsonb #>> '{studied_then_checked,mean_check_score}')::numeric, 1.000,
  'the mean score of the checks that followed is reported');

-- Never the learner's own words or links, and no per-learner rows.
select ok(
  current_setting('test.oc_b') !~* 'secret' and current_setting('test.oc_b') !~* 'Unit 1'
  and current_setting('test.oc_b') !~ '5e200000-0000-4000-8000-0000000000(0[1-9]|1[0-9])',
  'the report holds no resource name, link, outline title or learner id');
select is(jsonb_array_length(current_setting('test.oc_b')::jsonb -> 'not_measured'), 4,
  'what cannot be measured yet is listed with its reason');

-- It only reads, it is not a readiness or coverage function, and it is the
-- only function besides the companion writers that mentions these tables.
select is((select provolatile::text from pg_proc where oid = 'public.get_companion_outcome_report(uuid)'::regprocedure),
  's', 'the report function cannot write');
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and (p.prosrc ilike '%learner_resource_objectives%' or p.prosrc ilike '%learner_resource_sections%'
             or p.prosrc ilike '%learner_external_resources%')
        and p.proname not in ('save_learner_external_resource', 'set_learner_resource_objectives',
                              'set_learner_resource_objective_studied', 'delete_learner_external_resource',
                              'set_learner_resource_sections', 'set_learner_resource_section_studied',
                              'get_companion_outcome_report') $$,
  'only the companion writers and this report mention the outside-resource tables');
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public', 'private')
       and (p.proname ilike '%readiness%' or p.proname ilike '%coverage%' or p.proname ilike '%mastery%')
       and (p.prosrc ilike '%learner_resource%' or p.prosrc ilike '%learner_external%'
            or p.prosrc ilike '%get_companion_outcome_report%')),
  'no readiness, coverage or mastery function reads outside study or this report');

select * from finish();
rollback;
