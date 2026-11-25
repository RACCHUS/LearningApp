-- pgTAP: a learner's own outside resources (migration 20261125030000,
-- companion plan v1.0 EX-1). Owner-only rows, gated writes, validated
-- objective keys, and self-report that no readiness function can read.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(27);

insert into auth.users (id, email) values
  ('ce000000-0000-4000-8000-000000000001', 'lr-a@example.invalid'),
  ('ce000000-0000-4000-8000-000000000002', 'lr-b@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like 'ce000000-%' on conflict (id) do nothing;

-- A's private target with one coded objective and one node without a code.
insert into public.learning_targets (id, target_type, title, slug, created_by) values
  ('ce000000-0000-4000-8000-000000000010', 'curriculum_standard', 'LR Goal', 'test-lr-goal',
   'ce000000-0000-4000-8000-000000000001');
insert into public.target_versions (id, target_id, version_code, status) values
  ('ce000000-0000-4000-8000-000000000011', 'ce000000-0000-4000-8000-000000000010', 'A', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code) values
  ('ce000000-0000-4000-8000-000000000021', 'ce000000-0000-4000-8000-000000000011', 'objective', 'Exponents', '1.1'),
  ('ce000000-0000-4000-8000-000000000022', 'ce000000-0000-4000-8000-000000000011', 'objective', 'Radicals', '1.2'),
  ('ce000000-0000-4000-8000-000000000023', 'ce000000-0000-4000-8000-000000000011', 'objective', 'Uncoded topic', null);

-- Structure and privileges.
select ok((select relrowsecurity from pg_class where oid = 'public.learner_external_resources'::regclass),
  'resources table has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.learner_resource_objectives'::regclass),
  'objectives table has RLS');
select ok(not has_table_privilege('anon', 'public.learner_external_resources', 'select'),
  'anon cannot read resources');
select ok(not has_table_privilege('authenticated', 'public.learner_external_resources', 'insert'),
  'no direct inserts into resources');
select ok(not has_table_privilege('authenticated', 'public.learner_resource_objectives', 'update'),
  'no direct updates of objectives (studied marks go through the RPC)');
select ok(not has_function_privilege('anon', 'public.save_learner_external_resource(uuid, text, text, text, text, text, uuid)', 'execute'),
  'anon cannot call save');
select ok(not has_function_privilege('authenticated', 'private.learner_resources_writer()', 'execute'),
  'the guard is not callable directly');

-- Self-report isolation: only the companion's own functions may mention
-- these tables. A readiness or coverage function that read them would turn
-- "I studied this" into evidence.
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and (p.prosrc ilike '%learner_resource_objectives%' or p.prosrc ilike '%learner_external_resources%')
        and p.proname not in ('save_learner_external_resource', 'set_learner_resource_objectives',
                              'set_learner_resource_objective_studied', 'delete_learner_external_resource',
                              'set_learner_resource_sections') $$,
  'no other function reads self-reported outside study');

-- Gate OFF (it was seeded OFF and later activated by 20261125040000).
update private.site_feature_controls set enabled = false where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ce000000-0000-4000-8000-000000000001', true);

select throws_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'My course') $$,
  '42501', 'feature_disabled', 'writes are refused while the switch is off');

reset role;
update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ce000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', '  My course  ',
       'course', 'https://example.org/course?x=1', 'paid') $$,
  'the owner adds a resource to their goal');
select is((select title from public.learner_external_resources), 'My course', 'the title is trimmed');
select throws_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'Bad', 'course', 'http://example.org') $$,
  '23514', null, 'a link must be https');
select throws_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'Bad', 'course', 'https://user:pw@example.org/') $$,
  '23514', null, 'a link may not carry credentials');
select throws_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'Bad', 'mooc') $$,
  '23514', null, 'an unknown kind is refused');
select lives_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'A printed book', 'book') $$,
  'a resource needs no link');

select is(
  (select public.set_learner_resource_objectives(
     (select id from public.learner_external_resources where title = 'My course'), array['1.1', ' 1.2 ', '1.1', 'Uncoded topic'])),
  3, 'covered objectives are saved once each, by code or by title where there is no code');
select throws_ok(
  $$ select public.set_learner_resource_objectives(
       (select id from public.learner_external_resources where title = 'My course'), array['9.9']) $$,
  'P0001', 'unknown_objective', 'a key that is not a node of the goal is refused');

select isnt(
  (select public.set_learner_resource_objective_studied(
     (select id from public.learner_external_resources where title = 'My course'), '1.1', true)),
  null, 'marking studied returns when');
select is(
  (select public.set_learner_resource_objectives(
     (select id from public.learner_external_resources where title = 'My course'), array['1.1'])),
  1, 'the covered set can shrink');
select ok(
  (select studied_at is not null from public.learner_resource_objectives where objective_key = '1.1'),
  'a kept objective keeps its studied mark');
select throws_ok(
  $$ select public.set_learner_resource_objective_studied(
       (select id from public.learner_external_resources where title = 'My course'), '1.2', true) $$,
  'P0002', 'objective_not_covered', 'only a covered objective can be marked studied');

-- Another learner sees and changes nothing.
reset role;
select set_config('test.lr_course', (select id::text from public.learner_external_resources where title = 'My course'), true);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ce000000-0000-4000-8000-000000000002', true);
select is_empty($$ select 1 from public.learner_external_resources $$, 'another learner reads no resources');
select is_empty($$ select 1 from public.learner_resource_objectives $$, 'another learner reads no objectives');
select throws_ok(
  $$ select public.set_learner_resource_objectives(current_setting('test.lr_course')::uuid, array['1.1']) $$,
  'P0002', 'resource_not_found', 'another learner cannot change it');
select throws_ok(
  $$ select public.save_learner_external_resource('ce000000-0000-4000-8000-000000000010', 'Mine now') $$,
  'P0002', 'target_not_found', 'a resource cannot be attached to a goal the caller cannot read');
select is(public.delete_learner_external_resource(current_setting('test.lr_course')::uuid), false,
  'another learner cannot delete it');

-- Gate OFF again: the owner can still remove their data.
reset role;
update private.site_feature_controls set enabled = false where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'ce000000-0000-4000-8000-000000000001', true);
select is(public.delete_learner_external_resource(current_setting('test.lr_course')::uuid), true,
  'the owner can delete with the switch off');

select * from finish();
rollback;
