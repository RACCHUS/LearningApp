-- pgTAP: where a part of an outline begins in a video (migration
-- 20261125090000, companion plan v1.0 EX-7). The outline write carries it
-- and everything the earlier outline tests assert still holds.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into auth.users (id, email) values
  ('d1000000-0000-4000-8000-000000000001', 'st-a@example.invalid')
on conflict (id) do nothing;
insert into public.users (id) select id from auth.users where id::text like 'd1000000-%' on conflict (id) do nothing;

insert into public.learning_targets (id, target_type, title, slug, created_by) values
  ('d1000000-0000-4000-8000-000000000010', 'curriculum_standard', 'ST Goal', 'test-st-goal',
   'd1000000-0000-4000-8000-000000000001');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d1000000-0000-4000-8000-000000000011', 'd1000000-0000-4000-8000-000000000010', 'A', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title, code) values
  ('d1000000-0000-4000-8000-000000000021', 'd1000000-0000-4000-8000-000000000011', 'objective', 'Exponents', '1.1');

-- Only the companion's own writers may mention the table (restated, since
-- this migration replaced one of them).
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('public', 'private')
        and p.prosrc ilike '%learner_resource_sections%'
        and p.proname not in ('set_learner_resource_sections', 'set_learner_resource_section_studied') $$,
  'no other function reads the outline, its progress or its start times');
select ok(not has_function_privilege('anon', 'public.set_learner_resource_sections(uuid, jsonb)', 'execute'),
  'anon still cannot save an outline after the function was replaced');

update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000001', true);
select public.save_learner_external_resource('d1000000-0000-4000-8000-000000000010', 'My video', 'video');
reset role;
select set_config('test.st_video', (select id::text from public.learner_external_resources where title = 'My video'), true);
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000001', true);

select is(
  public.set_learner_resource_sections(current_setting('test.st_video')::uuid,
    '[{"title": "Intro", "start": 0, "minutes": 2},
      {"title": "Exponents", "objective_keys": ["1.1"], "start": 135.4},
      {"title": "No time", "start": null},
      {"title": "Also no time"}]'::jsonb),
  4, 'an outline is saved with start times');
select is(
  (select array_agg(start_seconds order by position) from public.learner_resource_sections),
  array[0, 135, null, null]::integer[], 'start times are whole seconds and optional');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.st_video')::uuid,
       '[{"title": "x", "start": -5}]'::jsonb) $$,
  '23514', null, 'a start time cannot be negative');
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.st_video')::uuid,
       '[{"title": "x", "start": "2:15"}]'::jsonb) $$,
  'P0001', 'invalid_outline', 'a start time must be a number of seconds');

-- The replaced function still keeps a studied mark and still refuses when off.
select public.set_learner_resource_section_studied(current_setting('test.st_video')::uuid, 2, true);
select public.set_learner_resource_sections(current_setting('test.st_video')::uuid,
  '[{"title": "Exponents", "start": 140}]'::jsonb);
select ok(
  (select studied_at is not null and start_seconds = 140 from public.learner_resource_sections),
  'replacing the outline keeps the studied mark and takes the new start time');

reset role;
update private.site_feature_controls set enabled = false where feature_key = 'content.learner_resources';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'd1000000-0000-4000-8000-000000000001', true);
select throws_ok(
  $$ select public.set_learner_resource_sections(current_setting('test.st_video')::uuid, '[]'::jsonb) $$,
  '42501', 'feature_disabled', 'the replaced function still refuses while the switch is off');

select * from finish();
rollback;
