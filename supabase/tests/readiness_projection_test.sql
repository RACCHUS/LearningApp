-- pgTAP: study-time estimates for the projected readiness date (migration 20261124090000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(12);

-- Fictional, transaction-local fixtures.
insert into public.learning_targets (id, target_type, title, slug, status, is_public, is_official)
values ('d6400000-0000-4000-8000-000000000011', 'standardized_exam',
  'Projection Fictional Target', 'projection-fixture', 'published', true, false);
insert into public.target_versions (id, target_id, version_code, status)
values ('d6400000-0000-4000-8000-000000000012', 'd6400000-0000-4000-8000-000000000011', 'pj-v1', 'published'),
       ('d6400000-0000-4000-8000-000000000013', 'd6400000-0000-4000-8000-000000000011', 'pj-v2', 'draft');
insert into public.curriculum_nodes (id, target_version_id, parent_id, node_type, code, title, sort_order) values
  ('d6400000-0000-4000-8000-000000000021', 'd6400000-0000-4000-8000-000000000012', null, 'domain', 'D1', 'Domain', 1),
  ('d6400000-0000-4000-8000-000000000031', 'd6400000-0000-4000-8000-000000000012', 'd6400000-0000-4000-8000-000000000021', 'objective', 'O1', 'With content', 1),
  ('d6400000-0000-4000-8000-000000000032', 'd6400000-0000-4000-8000-000000000012', 'd6400000-0000-4000-8000-000000000021', 'objective', 'O2', 'Tiny', 2),
  ('d6400000-0000-4000-8000-000000000033', 'd6400000-0000-4000-8000-000000000012', 'd6400000-0000-4000-8000-000000000021', 'objective', 'O3', 'No lessons', 3);
insert into public.lessons (id, title, visibility) values
  ('d6400000-0000-4000-8000-000000000051', 'Projection lesson', 'public'),
  ('d6400000-0000-4000-8000-000000000052', 'Projection tiny lesson', 'public');
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id) values
  ('d6400000-0000-4000-8000-000000000031', 'd6400000-0000-4000-8000-000000000051'),
  ('d6400000-0000-4000-8000-000000000032', 'd6400000-0000-4000-8000-000000000052');
-- O1: 1,800 words of reading, 2 practice prompts (4 words each), 1 task
-- (title, body and two criteria: 8 words), 3 graded items.
insert into public.lesson_blocks (lesson_id, sort_order, block_type, content) values
  ('d6400000-0000-4000-8000-000000000051', 1, 'markdown', jsonb_build_object('text', rtrim(repeat('word ', 1800)))),
  ('d6400000-0000-4000-8000-000000000051', 2, 'practice_prompt', '{"prompt": "Do this", "answer": "Like that"}'),
  ('d6400000-0000-4000-8000-000000000051', 3, 'practice_prompt', '{"prompt": "Do more", "answer": "Like so"}'),
  ('d6400000-0000-4000-8000-000000000051', 4, 'performance_task',
   '{"title": "Task", "body": "Build it", "verification": "self_check", "criteria": [{"text": "One"}, {"text": "Two"}]}'),
  ('d6400000-0000-4000-8000-000000000052', 1, 'markdown', '{"text": "Short"}');
insert into public.assessment_items (lesson_id, interaction_type, prompt, response_spec, scoring_spec)
select 'd6400000-0000-4000-8000-000000000051', 'numeric_entry', 'Item ' || g, '{}'::jsonb,
       jsonb_build_object('correct_value', g, 'tolerance', 0)
from generate_series(1, 3) g;

create temporary table pj (label text primary key, result jsonb) on commit drop;
grant all on pj to anon, authenticated;
create function pg_temp.snap(p_label text, p_role text, p_version text default 'd6400000-0000-4000-8000-000000000012')
returns void language plpgsql as $$
begin
  execute format('set local role %I', p_role);
  perform set_config('request.jwt.claim.sub', '', true);
  insert into pj values (p_label, public.get_target_study_estimates(p_version::uuid));
  reset role;
end $$;
create function pg_temp.obj(p_label text, p_code text) returns jsonb language sql as $$
  select o from pj, jsonb_array_elements(result->'objectives') o where label = p_label and o->>'code' = p_code;
$$;

-- 1. Activated by migration 20261124100000 (audited); while off nothing is computed.
select ok(exists(select 1 from private.site_feature_change_audit
                 where feature_key = 'learning.readiness_projection' and next_enabled
                   and reason like '%20261124100000%'),
  'the activation is recorded in the feature audit');
update private.site_feature_controls set enabled = false
  where feature_key = 'learning.readiness_projection';
select pg_temp.snap('off', 'anon');
select is((select result from pj where label = 'off'), '{"enabled": false}'::jsonb, 'while off it returns only enabled: false');

update private.site_feature_controls set enabled = true, release_ready = true
  where feature_key = 'learning.readiness_projection';
select pg_temp.snap('on', 'anon');

-- 2. The heuristic. Words: 1,800 + 8 (prompts) + 6 (task: Task, Build it, self_check, One, Two) = 1,814.
select is((pg_temp.obj('on', 'O1')->>'words')::int, 1814, 'every string in the lesson blocks is counted as reading');
select is((pg_temp.obj('on', 'O1')->>'practice_prompts')::int, 2, 'practice prompts are counted');
select is((pg_temp.obj('on', 'O1')->>'tasks')::int, 1, 'performance tasks are counted');
select is((pg_temp.obj('on', 'O1')->>'graded_questions')::int, 3, 'graded items are counted');
-- low: 1814/180 + 2*2 + 3*1 + 20 = 10.08 + 27 = 37; high: 1814/100 + 2*4 + 3*2 + 45 = 18.14 + 59 = 77.
select is((pg_temp.obj('on', 'O1')->>'minutes_low')::int, 37, 'low estimate follows the published rates');
select is((pg_temp.obj('on', 'O1')->>'minutes_high')::int, 77, 'high estimate follows the published rates');
select is((pg_temp.obj('on', 'O2')->>'minutes_low')::int, 5, 'an objective with lessons is never under 5 minutes');
select ok(pg_temp.obj('on', 'O3')->'minutes_low' = 'null'::jsonb,
  'an objective without lessons has no estimate (not yet available, not zero)');
select is((select result->>'method' from pj where label = 'on'), 'content-v1', 'the method is named');

-- 3. Guests cannot read drafts.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$ select public.get_target_study_estimates('d6400000-0000-4000-8000-000000000013') $$,
  '42501', null, 'a guest cannot read a draft version');
reset role;

select * from finish();
rollback;
