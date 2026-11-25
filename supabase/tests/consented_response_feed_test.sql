-- pgTAP: consented response feed and unreliable held-out checks
-- (migration 20261124120000, ingestion plan v1.2 §16.4).
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
select ('d7400000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, 'feed-' || g || '@example.invalid',
       false, '{"product_analytics_eligible": "true"}'::jsonb
from generate_series(1, 7) g
on conflict (id) do nothing;
-- Learners 1-6 consent; learner 7 does not.
insert into analytics.product_consents (user_id, consented)
select ('d7400000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid, true from generate_series(1, 6) g;

insert into public.lessons (id, title, visibility)
values ('d7400000-0000-4000-8000-000000000051', 'Feed lesson', 'public');
insert into public.assessment_items (id, lesson_id, interaction_type, prompt, response_spec, scoring_spec) values
  ('d7400000-0000-4000-8000-000000000061', 'd7400000-0000-4000-8000-000000000051', 'single_choice', 'Pick A',
   '{"options": ["A", "B", "C", "D"]}'::jsonb, '{"correct_index": 0}'::jsonb);

create function pg_temp.grade_as(p_user text, p_choice int) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  if p_user is null then
    set local role anon;
    perform set_config('request.jwt.claims', '', true);
  else
    set local role authenticated;
    perform set_config('request.jwt.claims',
      json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  end if;
  v := public.grade_and_record_assessment_items(jsonb_build_array(jsonb_build_object(
         'item_id', 'd7400000-0000-4000-8000-000000000061', 'response', p_choice)));
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end $$;
create function pg_temp.logged(p_user text) returns int language sql as $$
  select count(*)::int from private.item_response_log
  where user_id = p_user::uuid and item_id = 'd7400000-0000-4000-8000-000000000061';
$$;

-- 1. Grading is unchanged; only consenting learners are recorded, once.
select is(pg_temp.grade_as('d7400000-0000-4000-8000-000000000001', 0)->0->>'is_correct', 'true',
  'the recorder grades like grade_assessment_items');
select is(pg_temp.logged('d7400000-0000-4000-8000-000000000001'), 1, 'a consenting learner''s answer is recorded');
select is((select selected from private.item_response_log
           where user_id = 'd7400000-0000-4000-8000-000000000001'), '0', 'the chosen option is recorded');
select pg_temp.grade_as('d7400000-0000-4000-8000-000000000001', 2);
select is((select score from private.item_response_log
           where user_id = 'd7400000-0000-4000-8000-000000000001'), 1::numeric,
  'a later answer does not replace the first');
select is(pg_temp.grade_as('d7400000-0000-4000-8000-000000000007', 1)->0->>'is_correct', 'false',
  'a learner without consent is still graded');
select is(pg_temp.logged('d7400000-0000-4000-8000-000000000007'), 0, 'but not recorded');
select is(pg_temp.grade_as(null, 0)->0->>'is_correct', 'true', 'a guest is graded');
select is((select count(*)::int from private.item_response_log), 1, 'and nothing is recorded for a guest');

-- 2. Nobody but the server can read the log.
select ok(not has_table_privilege('authenticated', 'private.item_response_log', 'select')
          and not has_table_privilege('anon', 'private.item_response_log', 'select'),
  'learners and guests cannot read the response log');

-- 3. The statistics read the log (5+ consenting learners).
select pg_temp.grade_as('d7400000-0000-4000-8000-00000000000' || g, case when g <= 4 then 0 else 1 end)
from generate_series(2, 6) g;
select lives_ok($$ select public.compute_item_analytics(5) $$, 'statistics compute');
select is((select response_count from public.item_analytics where item_id = 'd7400000-0000-4000-8000-000000000061'),
  6, 'graded answers from the log reach the statistics');
select is((select (distractor_counts->>'1')::int from public.item_analytics
           where item_id = 'd7400000-0000-4000-8000-000000000061'), 2, 'with per-option counts');

-- 4. Withdrawing consent forgets the learner's answers.
update analytics.product_consents set consented = false
  where user_id = 'd7400000-0000-4000-8000-000000000006';
select is(pg_temp.logged('d7400000-0000-4000-8000-000000000006'), 0, 'withdrawing consent deletes the learner''s log');

-- 5. A held-out check flagged unreliable stops counting while its report is open.
update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_coverage_gate';
insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d7400000-0000-4000-8000-000000000011', 'standardized_exam', 'Feed Fictional Target', 'feed-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('d7400000-0000-4000-8000-000000000012', 'd7400000-0000-4000-8000-000000000011', 'fd-v1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, code, title, sort_order, weight) values
  ('d7400000-0000-4000-8000-000000000021', 'd7400000-0000-4000-8000-000000000012', null, 'domain', 'D1', 'Domain', 1, 1),
  ('d7400000-0000-4000-8000-000000000031', 'd7400000-0000-4000-8000-000000000012', 'd7400000-0000-4000-8000-000000000021', 'objective', 'O1', 'Objective', 1, null);
insert into public.knowledge_concepts (id, slug, name)
values ('d7400000-0000-4000-8000-000000000041', 'fd-fixture-concept', 'Feed concept');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
values ('d7400000-0000-4000-8000-000000000031', 'd7400000-0000-4000-8000-000000000041');
select public.ingest_held_out_items('d7400000-0000-4000-8000-000000000012', (
  select jsonb_agg(jsonb_build_object(
    'key', 'fd-' || g, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 6 + ' || g || ' (feed)',
    'scoring_spec', jsonb_build_object('correct_value', 6 + g, 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array('fd-fixture-concept'),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_kind', 'ai', 'reviewer_model', 'fictional-model',
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1',
      'reviewed_on', '2026-11-24', 'review_status', 'approved', 'rights_review_status', 'approved')))
  from generate_series(1, 6) g));
update public.target_versions set status = 'review_ready' where id = 'd7400000-0000-4000-8000-000000000012';
update public.target_versions set status = 'published' where id = 'd7400000-0000-4000-8000-000000000012';

create function pg_temp.coverage() returns jsonb language plpgsql as $$
declare v jsonb;
begin
  set local role anon;
  perform set_config('request.jwt.claims', '', true);
  v := public.get_target_readiness_coverage('d7400000-0000-4000-8000-000000000012');
  reset role;
  return v;
end $$;
select is(pg_temp.coverage()->>'state', 'full', 'six approved checks give full coverage');

-- Flag one check as unreliable with an open moderation report.
insert into public.moderation_reports (id, reporter_id, target_type, target_id, reason, description, status)
select 'd7400000-0000-4000-8000-000000000071', null, 'question', r.assessment_item_id, 'other',
       '[Item Analytics Auto-Flag] low_discrimination', 'pending'
from private.held_out_item_reviews r
where r.target_version_id = 'd7400000-0000-4000-8000-000000000012' limit 1;
insert into public.item_analytics (item_id, response_count, flagged_reasons, auto_flagged, moderation_report_id)
select target_id, 30, array['low_discrimination'], true, id
from public.moderation_reports where id = 'd7400000-0000-4000-8000-000000000071';

select ok(private.held_out_item_unreliable(
  (select target_id from public.moderation_reports where id = 'd7400000-0000-4000-8000-000000000071')),
  'the flagged check is unreliable while its report is open');
select is(pg_temp.coverage()->>'state', 'hidden', 'with only five reliable checks the objective is no longer covered');
select ok(not exists (select 1 from private.held_out_item_reviews r
                      where r.target_version_id = 'd7400000-0000-4000-8000-000000000012'
                        and r.review_status <> 'approved'),
  'nothing was retired or edited');

update public.moderation_reports set status = 'dismissed' where id = 'd7400000-0000-4000-8000-000000000071';
select is(pg_temp.coverage()->>'state', 'full', 'closing the report makes the check count again');

select * from finish();
rollback;
