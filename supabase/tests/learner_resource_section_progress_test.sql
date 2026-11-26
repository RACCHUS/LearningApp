-- pgTAP: self-reported progress through the parts of an outside resource
-- (migration 20261125060000, companion plan v1.0 EX-4). Gated writes, owner
-- only, and marks that no readiness function can read.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(20);

insert into auth.users (id, email) values
  ('d0000000-0000-4000-8000-000000000001', 'lp-a@example.invalid'),
  ('d0000000-0000-4000-8000-000000000002', 'lp-b@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like 'd0000000-%' on conflict (id) do nothing;

insert into public.learning_targets (id, target_type, title, slug, created_by) values
  ('d0000000-0000-4000-8000-000000000010', 'curriculum_standard', 'LP Goal', 'test-lp-goal',
   'd0000000-0000-4000-8000-000000000001');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d0000000-0000-4000-8000-000000000011', 'd0000000-0000-4000-8000-000000000010', 'A', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code) values
  ('d0000000-0000-4000-8000-000000000021', 'd0000000-0000-4000-8000-000000000011', 'objective', 'Exponents', '1.1'),
  ('d0000000-0000-4000-8000-000000000022', 'd0000000-0000-4000-8000-000000000011', 'objective', 'Radicals', '1.2');

select ok(not has_function_privilege('anon', 'public.set_learner_resource_section_studied(uuid, integer, boolean)', 'execute'),
  'anon cannot mark a part studied');
select ok(not has_table_privilege('authenticated', 'public.learner_resource_sections', 'update'),
  'no direct updates of sections (studied marks go through the RPC)');

-- Self-report isolation, restated for the new function and columns.
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and p.prosrc ilike '%learner_resource_sections%'
        and p.proname not in ('set_learner_resource_sections', 'set_learner_resource_section_studied',
                              'get_companion_outcome_report') $$,
  'no other function reads self-reported progress through a resource');

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);
select public.save_learner_external_resource('d0000000-0000-4000-8000-000000000010', 'My course', 'course');
reset role;
select set_config('test.lp_course', (select id::text from public.learner_external_resources where title = 'My course'), true);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);

-- 1.1 is in parts 1 and 2; 1.2 only in part 2.
select is(
  public.set_learner_resource_sections(current_setting('test.lp_course')::uuid,
    '[{"title": "Part 1", "objective_keys": ["1.1"], "minutes": 25},
      {"title": "Part 2", "objective_keys": ["1.1", "1.2"], "minutes": 12.4},
      {"title": "Part 3", "minutes": null}]'::jsonb),
  3, 'an outline is saved with time estimates');
select is(
  (select array_agg(est_minutes order by position) from public.learner_resource_sections),
  array[25, 12, null]::integer[], 'estimates are whole minutes and optional');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.lp_course')::uuid,
       '[{"title": "x", "minutes": 0}]'::jsonb) $$,
  '23514', null, 'an estimate must be at least a minute');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.lp_course')::uuid,
       '[{"title": "x", "minutes": "25"}]'::jsonb) $$,
  'P0001', 'invalid_outline', 'an estimate must be a number');

select isnt(
  public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 1, true),
  null, 'marking a part studied returns when');
select is(
  (select count(*)::integer from public.learner_resource_objectives where studied_at is not null),
  0, 'an objective that another unstudied part also covers is not marked yet');
select public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 2, true);
select is(
  (select count(*)::integer from public.learner_resource_objectives where studied_at is not null),
  2, 'once every part covering an objective is studied, the objective is marked studied');
select is(
  public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 2, false),
  null, 'a part can be unmarked');
select is(
  (select count(*)::integer from public.learner_resource_objectives where studied_at is not null),
  2, 'unmarking a part does not unmark an objective');
select throws_ok(
  $$ select public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 9, true) $$,
  'P0002', 'section_not_found', 'a part that does not exist cannot be marked');

-- Replacing the outline keeps the mark of a part whose title is unchanged.
select public.set_learner_resource_sections(current_setting('test.lp_course')::uuid,
  '[{"title": "Intro"}, {"title": "Part 1", "objective_keys": ["1.1"]}, {"title": "Part 2"}]'::jsonb);
select is(
  (select array_agg(studied_at is not null order by position) from public.learner_resource_sections),
  array[false, true, false], 'a kept part keeps its studied mark; new and unmarked parts have none');

-- Another learner changes nothing.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000002', true);
select throws_ok(
  $$ select public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 2, true) $$,
  'P0002', 'section_not_found', 'another learner cannot mark it');

-- Gate OFF: marks are refused, reading your own rows still works.
reset role;
update private.site_feature_controls set enabled = false where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd0000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.set_learner_resource_section_studied(current_setting('test.lp_course')::uuid, 1, true) $$,
  '42501', 'feature_disabled', 'a part cannot be marked while the switch is off');
select is((select count(*)::integer from public.learner_resource_sections), 3,
  'the owner still reads their outline with the switch off');

-- Readiness never moves from a studied mark: the readiness function's result
-- for this learner and goal is the same before and after marking.
reset role;
update private.site_feature_controls set enabled = true where feature_key = 'content.learner_resources';
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public', 'private')
       and p.proname ilike '%readiness%'
       and (p.prosrc ilike '%learner_resource%' or p.prosrc ilike '%learner_external%')),
  'no readiness function mentions any outside-resource table');
select ok(
  not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public', 'private')
       and p.proname ilike '%coverage%'
       and (p.prosrc ilike '%learner_resource%' or p.prosrc ilike '%learner_external%')),
  'no coverage function mentions any outside-resource table');
select is(
  (select count(*)::integer from pg_attribute
    where attrelid = 'public.learner_resource_sections'::regclass and attname in ('est_minutes', 'studied_at')),
  2, 'the two progress columns exist');

select * from finish();
rollback;
