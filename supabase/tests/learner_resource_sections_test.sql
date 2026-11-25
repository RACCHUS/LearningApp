-- pgTAP: the outline of a learner's outside resource (migration
-- 20261125050000, companion plan v1.0 EX-3). Owner-only rows, one gated
-- write, validated objective keys, and a map no readiness function can read.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(22);

insert into auth.users (id, email) values
  ('cf000000-0000-4000-8000-000000000001', 'ls-a@example.invalid'),
  ('cf000000-0000-4000-8000-000000000002', 'ls-b@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like 'cf000000-%' on conflict (id) do nothing;

insert into public.learning_targets (id, target_type, title, slug, created_by) values
  ('cf000000-0000-4000-8000-000000000010', 'curriculum_standard', 'LS Goal', 'test-ls-goal',
   'cf000000-0000-4000-8000-000000000001');
insert into public.target_versions (id, target_id, version_code, status) values
  ('cf000000-0000-4000-8000-000000000011', 'cf000000-0000-4000-8000-000000000010', 'A', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code) values
  ('cf000000-0000-4000-8000-000000000021', 'cf000000-0000-4000-8000-000000000011', 'objective', 'Exponents', '1.1'),
  ('cf000000-0000-4000-8000-000000000022', 'cf000000-0000-4000-8000-000000000011', 'objective', 'Radicals', '1.2'),
  ('cf000000-0000-4000-8000-000000000023', 'cf000000-0000-4000-8000-000000000011', 'objective', 'Uncoded topic', null);

-- Structure and privileges.
select ok((select relrowsecurity from pg_class where oid = 'public.learner_resource_sections'::regclass),
  'sections table has RLS');
select ok(not has_table_privilege('anon', 'public.learner_resource_sections', 'select'),
  'anon cannot read sections');
select ok(not has_table_privilege('authenticated', 'public.learner_resource_sections', 'insert'),
  'no direct inserts into sections');
select ok(not has_table_privilege('authenticated', 'public.learner_resource_sections', 'delete'),
  'no direct deletes of sections');
select ok(not has_function_privilege('anon', 'public.set_learner_resource_sections(uuid, jsonb)', 'execute'),
  'anon cannot save an outline');

-- A learner's own map is not evidence: only its own writer may mention it.
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and p.prosrc ilike '%learner_resource_sections%'
        and p.proname <> 'set_learner_resource_sections' $$,
  'no other function reads a learner''s outline map');

-- A resource to hang the outline on (gate ON for the set-up).
update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);
select public.save_learner_external_resource('cf000000-0000-4000-8000-000000000010', 'My course', 'course');
reset role;
select set_config('test.ls_course', (select id::text from public.learner_external_resources where title = 'My course'), true);

-- Gate OFF: the write is refused.
update private.site_feature_controls set enabled = false where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
       '[{"title": "Unit 1", "objective_keys": ["1.1"]}]'::jsonb) $$,
  '42501', 'feature_disabled', 'an outline cannot be saved while the switch is off');

reset role;
update private.site_feature_controls set enabled = true where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);

select is(
  public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
    '[{"title": "  Unit 1: Powers ", "objective_keys": ["1.1", " 1.1 ", "Uncoded topic"], "source": "outline_match"},
      {"title": "Unit 2: Roots", "objective_keys": ["1.2"], "source": "own_ai"},
      {"title": "Unit 3: Review"}]'::jsonb),
  3, 'the owner saves an outline in order');
select is(
  (select array_agg(title order by position) from public.learner_resource_sections),
  array['Unit 1: Powers', 'Unit 2: Roots', 'Unit 3: Review'], 'titles are trimmed and keep their order');
select is(
  (select objective_keys from public.learner_resource_sections where position = 1),
  array['1.1', 'Uncoded topic'], 'keys are trimmed and saved once each');
select is(
  (select array_agg(map_source order by position) from public.learner_resource_sections),
  array['outline_match', 'own_ai', 'learner'], 'how each proposal was made is recorded');
select is(
  (select count(*)::integer from public.learner_resource_objectives where studied_at is null),
  3, 'confirmed objectives are ticked as covered and none is marked studied');

select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
       '[{"title": "Unit 1", "objective_keys": ["9.9"]}]'::jsonb) $$,
  'P0001', 'unknown_objective', 'a key that is not a node of the goal is refused');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid, '{"title": "x"}'::jsonb) $$,
  'P0001', 'invalid_outline', 'the outline must be a list');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
       '[{"title": "x", "objective_keys": "1.1"}]'::jsonb) $$,
  'P0001', 'invalid_outline', 'keys must be a list');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
       '[{"title": "x", "source": "reviewed"}]'::jsonb) $$,
  '23514', null, 'an unknown source is refused, so a map can never claim review');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
       (select jsonb_agg(jsonb_build_object('title', 'S' || g)) from generate_series(1, 201) g)) $$,
  'P0001', 'too_many_sections', 'an outline is capped at 200 parts');
select is(
  (select count(*)::integer from public.learner_resource_sections), 3,
  'a refused save leaves the saved outline as it was');

-- Another learner sees and changes nothing.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000002', true);
select is_empty($$ select 1 from public.learner_resource_sections $$, 'another learner reads no outline');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid, '[]'::jsonb) $$,
  'P0002', 'resource_not_found', 'another learner cannot change it');

-- Clearing keeps the ticks; removing the resource removes the outline.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'cf000000-0000-4000-8000-000000000001', true);
select public.set_learner_resource_sections(current_setting('test.ls_course')::uuid,
  '[{"title": "Only part", "objective_keys": ["1.1"]}]'::jsonb);
select is(
  (select count(*)::integer from public.learner_resource_objectives), 3,
  'replacing the outline does not untick objectives');
select public.delete_learner_external_resource(current_setting('test.ls_course')::uuid);
select is_empty($$ select 1 from public.learner_resource_sections $$,
  'removing the resource removes its outline');

select * from finish();
rollback;
