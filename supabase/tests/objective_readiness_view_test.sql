-- pgTAP: readiness by objective (migration 20261124070000, ingestion plan §8.7).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(18);

-- Fictional, transaction-local fixtures, rolled back at the end.
insert into auth.users (id, email) values
  ('d5400000-0000-4000-8000-000000000001', 'objective-view-learner@example.invalid'),
  ('d5400000-0000-4000-8000-000000000002', 'objective-view-new@example.invalid')
on conflict (id) do nothing;
insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d5400000-0000-4000-8000-000000000011', 'standardized_exam',
  'Objective View Fictional Target', 'objective-view-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('d5400000-0000-4000-8000-000000000012', 'd5400000-0000-4000-8000-000000000011', 'ov-v1', 'draft'),
       ('d5400000-0000-4000-8000-000000000013', 'd5400000-0000-4000-8000-000000000011', 'ov-v2', 'draft');
-- D1 (weight 3): O1 has a lesson and 6 held-out checks; O2 has a lesson but
-- no checks; O3 has no lesson. D2 (weight 1) has nothing in LearningApp.
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, code, title, sort_order, weight) values
  ('d5400000-0000-4000-8000-000000000021', 'd5400000-0000-4000-8000-000000000012', null, 'domain', 'D1', 'Domain one', 1, 3),
  ('d5400000-0000-4000-8000-000000000022', 'd5400000-0000-4000-8000-000000000012', null, 'domain', 'D2', 'Domain two', 2, 1),
  ('d5400000-0000-4000-8000-000000000031', 'd5400000-0000-4000-8000-000000000012', 'd5400000-0000-4000-8000-000000000021', 'objective', 'O1', 'Objective one', 1, null),
  ('d5400000-0000-4000-8000-000000000032', 'd5400000-0000-4000-8000-000000000012', 'd5400000-0000-4000-8000-000000000021', 'objective', 'O2', 'Objective two', 2, null),
  ('d5400000-0000-4000-8000-000000000033', 'd5400000-0000-4000-8000-000000000012', 'd5400000-0000-4000-8000-000000000021', 'objective', 'O3', 'Objective three', 3, null);
insert into public.knowledge_concepts (id, slug, name) values
  ('d5400000-0000-4000-8000-000000000041', 'ov-fixture-concept-1', 'Objective view concept 1'),
  ('d5400000-0000-4000-8000-000000000042', 'ov-fixture-concept-2', 'Objective view concept 2'),
  ('d5400000-0000-4000-8000-000000000043', 'ov-fixture-concept-3', 'Objective view concept 3');
insert into public.curriculum_node_concepts (curriculum_node_id, concept_id) values
  ('d5400000-0000-4000-8000-000000000031', 'd5400000-0000-4000-8000-000000000041'),
  ('d5400000-0000-4000-8000-000000000032', 'd5400000-0000-4000-8000-000000000042'),
  ('d5400000-0000-4000-8000-000000000033', 'd5400000-0000-4000-8000-000000000043');
insert into public.lessons (id, title, visibility) values
  ('d5400000-0000-4000-8000-000000000051', 'Objective view lesson 1', 'public'),
  ('d5400000-0000-4000-8000-000000000052', 'Objective view lesson 2', 'public');
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id) values
  ('d5400000-0000-4000-8000-000000000031', 'd5400000-0000-4000-8000-000000000051'),
  ('d5400000-0000-4000-8000-000000000032', 'd5400000-0000-4000-8000-000000000052');

create function pg_temp.items(p_prefix text, p_concept text)
returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object(
    'key', p_prefix || '-' || g, 'interaction_type', 'numeric_entry',
    'prompt', 'Evaluate 4 + ' || g || ' (' || p_prefix || ')',
    'scoring_spec', jsonb_build_object('correct_value', 4 + g, 'tolerance', 0),
    'explanation', 'Add.', 'concept_slugs', jsonb_build_array(p_concept),
    'review', jsonb_build_object(
      'author_ref', 'ai-drafted-by-claude', 'ai_drafted', true,
      'reviewer_kind', 'ai', 'reviewer_model', 'fictional-model',
      'reviewer_ref', 'ai-review:independent-model', 'reviewer_qualification', 'AI review checklist v1 + SymPy',
      'reviewed_on', '2026-11-24', 'review_status', 'approved', 'rights_review_status', 'approved')))
  from generate_series(1, 6) g;
$$;
select public.ingest_held_out_items('d5400000-0000-4000-8000-000000000012', pg_temp.items('ov-o1', 'ov-fixture-concept-1'));
update public.target_versions set status = 'review_ready' where id = 'd5400000-0000-4000-8000-000000000012';
update public.target_versions set status = 'published' where id = 'd5400000-0000-4000-8000-000000000012';

-- The learner has strong evidence on concepts 1 and 2 (accuracy 0.95 over 10 items).
insert into public.user_concept_state (user_id, concept_id, retrieval_band, evidence_count, weighted_correct, weighted_total) values
  ('d5400000-0000-4000-8000-000000000001', 'd5400000-0000-4000-8000-000000000041', 'well_established', 10, 9.5, 10),
  ('d5400000-0000-4000-8000-000000000001', 'd5400000-0000-4000-8000-000000000042', 'well_established', 10, 9.5, 10);

create temporary table ov (label text primary key, result jsonb) on commit drop;
grant all on ov to authenticated, anon;
create function pg_temp.snap(p_label text, p_role text, p_user text, p_version text default 'd5400000-0000-4000-8000-000000000012')
returns void language plpgsql as $$
begin
  execute format('set local role %I', p_role);
  perform set_config('request.jwt.claim.sub', coalesce(p_user, ''), true);
  insert into ov values (p_label, public.get_target_objective_readiness(p_version::uuid));
  reset role;
end $$;
create function pg_temp.obj(p_label text, p_code text) returns jsonb language sql as $$
  select o from ov, jsonb_array_elements(result->'domains') d, jsonb_array_elements(d->'objectives') o
  where label = p_label and o->>'code' = p_code;
$$;
create function pg_temp.dom(p_label text, p_code text) returns jsonb language sql as $$
  select d from ov, jsonb_array_elements(result->'domains') d where label = p_label and d->>'code' = p_code;
$$;

-- 1. Activated by migration 20261124080000 (audited); while off it computes nothing.
select ok(exists(select 1 from private.site_feature_change_audit
                 where feature_key = 'learning.objective_readiness_view' and next_enabled
                   and reason like '%20261124080000%'),
  'the activation is recorded in the feature audit');
update private.site_feature_controls set enabled = false
  where feature_key = 'learning.objective_readiness_view';
select pg_temp.snap('off', 'authenticated', 'd5400000-0000-4000-8000-000000000001');
select is((select result from ov where label = 'off'), '{"enabled": false}'::jsonb, 'while off it returns only enabled: false');

update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.objective_readiness_view';

-- 2. Signed-in learner with strong evidence.
select pg_temp.snap('learner', 'authenticated', 'd5400000-0000-4000-8000-000000000001');
select is(pg_temp.obj('learner', 'O1')->>'status', 'strong', 'strong evidence plus 6 held-out checks is strong');
select is((pg_temp.obj('learner', 'O1')->>'checked')::boolean, true, 'O1 is marked as checked');
select is(pg_temp.obj('learner', 'O2')->>'status', 'building',
  'strong practice without held-out checks is only building (D-14)');
select is(pg_temp.obj('learner', 'O3')->>'status', 'not_available', 'an objective without lessons is not yet available');
select is(pg_temp.dom('learner', 'D1')->>'status', 'building', 'a domain is strong only when every available objective is');
select is(pg_temp.dom('learner', 'D2')->>'status', 'not_available', 'an empty domain is not yet available');
select is((pg_temp.dom('learner', 'D1')->>'weight_share')::numeric, 0.75, 'domain weight shares follow the blueprint');
select is((select (result->>'signed_in')::boolean from ov where label = 'learner'), true, 'reports a signed-in learner');

-- 3. Weak accuracy is building even when checked.
update public.user_concept_state set weighted_correct = 5
  where user_id = 'd5400000-0000-4000-8000-000000000001' and concept_id = 'd5400000-0000-4000-8000-000000000041';
select pg_temp.snap('weak', 'authenticated', 'd5400000-0000-4000-8000-000000000001');
select is(pg_temp.obj('weak', 'O1')->>'status', 'building', 'a weak score is building');

-- 4. A learner with no evidence has not started.
select pg_temp.snap('new', 'authenticated', 'd5400000-0000-4000-8000-000000000002');
select is(pg_temp.obj('new', 'O1')->>'status', 'not_started', 'no evidence means not started');
select is(pg_temp.dom('new', 'D1')->>'status', 'not_started', 'and the domain has not started');

-- 5. Guests read published public versions with no learner data.
select pg_temp.snap('guest', 'anon', null);
select is(pg_temp.obj('guest', 'O1')->>'status', 'not_started', 'a guest sees available objectives as not started');
select is(pg_temp.obj('guest', 'O3')->>'status', 'not_available', 'and missing content as not yet available');
select is((select (result->>'signed_in')::boolean from ov where label = 'guest'), false, 'reports a guest');
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$ select public.get_target_objective_readiness('d5400000-0000-4000-8000-000000000013') $$,
  '42501', null, 'a guest cannot read a draft version');
reset role;
select is((select count(*)::int from ov
           where result::text like '%d5400000-0000-4000-8000-00000000000_%'), 0,
  'results never include a learner id');

select * from finish();
rollback;
