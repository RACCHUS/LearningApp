-- PR-H slice 3: reporting published community lessons (20261113010000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(9);

insert into auth.users (id, email, is_anonymous) values
  ('c0710000-0000-4000-8000-00000000000a', 'rep-owner@example.invalid', false),
  ('c0710000-0000-4000-8000-00000000000b', 'rep-reader@example.invalid', false)
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('c0710000-0000-4000-8000-00000000000a', 'rep-owner@example.invalid')
on conflict (id) do nothing;
insert into public.lessons (id, title, user_id, visibility) values
  ('c0710000-0000-4000-8000-000000000101', 'Shared', 'c0710000-0000-4000-8000-00000000000a', 'private');

-- One published and one merely submitted contribution (direct rows as the
-- table owner; the workflow itself is covered by its own suite).
insert into public.content_contributions
  (id, lesson_id, contributor_id, version, status, license, rights_attested_at,
   ai_assisted, snapshot, snapshot_sha256)
values
  ('c0710000-0000-4000-8000-000000000201', 'c0710000-0000-4000-8000-000000000101',
   'c0710000-0000-4000-8000-00000000000a', 1, 'published', 'CC-BY-4.0', now(),
   false, '{"title":"Shared"}', repeat('a', 64)),
  ('c0710000-0000-4000-8000-000000000202', null,
   'c0710000-0000-4000-8000-00000000000a', 1, 'submitted', 'CC-BY-4.0', now(),
   false, '{"title":"Pending"}', repeat('b', 64));

select ok(not has_function_privilege('anon',
  'public.report_lesson_contribution(uuid,text,text)', 'EXECUTE'),
  'anonymous users cannot report');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0710000-0000-4000-8000-00000000000b', true);

select throws_ok($$ select public.report_lesson_contribution(
  'c0710000-0000-4000-8000-000000000201', 'not-a-reason', null) $$,
  '22023', 'invalid_reason', 'reason must be one of the known values');
select throws_ok($$ select public.report_lesson_contribution(
  'c0710000-0000-4000-8000-000000000202', 'spam', null) $$,
  'P0002', 'not_published', 'only published copies can be reported');
select ok(public.report_lesson_contribution(
  'c0710000-0000-4000-8000-000000000201', 'misinformation', 'Q2 is wrong')
  is not null, 'a reader can report a published copy');
select throws_ok($$ select public.report_lesson_contribution(
  'c0710000-0000-4000-8000-000000000201', 'spam', null) $$,
  '23505', 'already_reported', 'one pending report per reader and copy');
select is((select count(*)::int from public.moderation_reports
            where target_type = 'lesson_contribution'
              and reporter_id = 'c0710000-0000-4000-8000-00000000000b'), 1,
  'the reader can see their own report');
reset role;

select is((select target_id from public.moderation_reports
            where target_type = 'lesson_contribution'),
  'c0710000-0000-4000-8000-000000000201'::uuid,
  'the report targets the contribution');
select ok(exists (
  select 1 from pg_constraint
   where conname = 'moderation_reports_target_type_check'
     and pg_get_constraintdef(oid) like '%community_answer%'),
  'existing target types are kept');

-- Reporting still works when the feature is OFF (the gate is seeded OFF).
select is((select enabled from private.site_feature_controls
            where feature_key = 'content.public_contribution'), false,
  'report succeeded with the feature OFF');

select * from finish();
rollback;
