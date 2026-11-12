-- PR-H slice 1: governed public contribution (migration 20261112070000).
-- Synthetic users and data; the feature gate is enabled only inside this
-- rolled-back transaction.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(35);

insert into auth.users (id, email, is_anonymous) values
  ('c0700000-0000-4000-8000-00000000000a', 'contrib-a@example.invalid', false),
  ('c0700000-0000-4000-8000-00000000000b', 'contrib-b@example.invalid', false),
  ('c0700000-0000-4000-8000-00000000000c', 'contrib-mod@example.invalid', false),
  ('c0700000-0000-4000-8000-00000000000d', 'contrib-admin@example.invalid', false)
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('c0700000-0000-4000-8000-00000000000a', 'contrib-a@example.invalid'),
  ('c0700000-0000-4000-8000-00000000000b', 'contrib-b@example.invalid')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('c0700000-0000-4000-8000-00000000000c', 'moderator'),
  ('c0700000-0000-4000-8000-00000000000d', 'admin')
on conflict (user_id) do nothing;

-- A's good lesson, A's broken lesson, B's lesson.
insert into public.lessons (id, title, user_id, visibility) values
  ('c0700000-0000-4000-8000-000000000101', 'Good lesson', 'c0700000-0000-4000-8000-00000000000a', 'private'),
  ('c0700000-0000-4000-8000-000000000102', 'Broken lesson', 'c0700000-0000-4000-8000-00000000000a', 'private'),
  ('c0700000-0000-4000-8000-000000000103', 'B lesson', 'c0700000-0000-4000-8000-00000000000b', 'private');
insert into public.questions (lesson_id, question_text, options, correct_answer, type) values
  ('c0700000-0000-4000-8000-000000000101', 'Q1', '["a","b","c"]', 2, 'mcq'),
  ('c0700000-0000-4000-8000-000000000102', 'Q2', '["a","A "]', 0, 'mcq'),
  ('c0700000-0000-4000-8000-000000000102', 'Q3', '["a","b"]', 5, 'mcq'),
  ('c0700000-0000-4000-8000-000000000103', 'Q4', '["a","b"]', 1, 'mcq');
insert into public.terms (lesson_id, term, definition) values
  ('c0700000-0000-4000-8000-000000000101', 'Term', 'Meaning');

-- Grants and privileges --------------------------------------------------
select ok(not has_table_privilege('authenticated', 'public.content_contributions', 'INSERT'),
  'browser roles cannot insert contributions directly');
select ok(not has_table_privilege('authenticated', 'public.content_contributions', 'UPDATE'),
  'browser roles cannot update contributions directly');
select ok(not has_table_privilege('authenticated', 'public.content_contribution_events', 'INSERT'),
  'browser roles cannot forge audit events');
select ok(not has_function_privilege('anon',
  'public.submit_lesson_contribution(uuid,text,boolean,boolean)', 'EXECUTE'),
  'anonymous callers cannot submit');
select ok(not has_function_privilege('authenticated',
  'private.contribution_apply(uuid,text,text,text)', 'EXECUTE'),
  'transition helper is not callable by browsers');
select is((select enabled or release_ready from private.site_feature_controls
            where feature_key = 'content.public_contribution'), false,
  'gate is seeded OFF and not release-ready');

-- Gate OFF -------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000101', 'CC-BY-4.0', true, false) $$,
  '42501', 'feature_disabled', 'submission refused while the gate is OFF');
reset role;

update private.site_feature_controls
   set enabled = true, release_ready = true
 where feature_key = 'content.public_contribution';

-- Contributor rules -------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000a', true);
select throws_ok($$ select public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000101', 'CC-BY-4.0', false, false) $$,
  '22023', 'rights_attestation_required', 'rights attestation is mandatory');
select throws_ok($$ select public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000101', 'All rights reserved', true, false) $$,
  '22023', 'unsupported_license', 'only open licences are accepted');
select throws_ok($$ select public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000103', 'CC-BY-4.0', true, false) $$,
  '42501', 'lesson_not_owned', 'cannot contribute another user''s lesson');

select is((public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000101', 'CC-BY-4.0', true, true))->>'status',
  'submitted', 'valid lesson is submitted');
select throws_ok($$ select public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000101', 'CC-BY-4.0', true, true) $$,
  '23505', 'contribution_already_open', 'one open contribution per lesson');

select is((public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000102', 'CC0-1.0', true, false))->>'status',
  'checks_failed', 'broken lesson fails automated checks');
select is((select jsonb_array_length(check_issues) from public.content_contributions
            where lesson_id = 'c0700000-0000-4000-8000-000000000102'), 2,
  'duplicate options and an out-of-range key are both reported');
select is((public.submit_lesson_contribution(
  'c0700000-0000-4000-8000-000000000102', 'CC0-1.0', true, false))->>'version',
  '2', 'resubmitting after failed checks creates version 2');
select is((select status from public.content_contributions
            where lesson_id = 'c0700000-0000-4000-8000-000000000102' and version = 1),
  'withdrawn', 'the failed attempt is closed with an audit trail');

select is((select visibility from public.lessons
            where id = 'c0700000-0000-4000-8000-000000000101'),
  'private', 'submitting never changes the lesson''s visibility (A35)');
select is((select snapshot->'questions'->0->>'correct_answer' from public.content_contributions
            where lesson_id = 'c0700000-0000-4000-8000-000000000101'), '2',
  'the snapshot captures the validated answer key');
select is((select length(snapshot_sha256) from public.content_contributions
            where lesson_id = 'c0700000-0000-4000-8000-000000000101'), 64,
  'the snapshot is hashed');

-- B cannot see A's contributions.
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000b', true);
select is((select count(*)::int from public.content_contributions), 0,
  'other learners cannot read contributions');
select throws_ok($$ select public.review_lesson_contribution(
  (select id from public.content_contributions limit 1), 'approve', null) $$,
  '42501', 'moderator_required', 'learners cannot review');

-- Moderator review ---------------------------------------------------------
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000c', true);
select is((select count(*)::int from public.content_contributions), 3,
  'moderators can read the queue');
select throws_ok(format($$ select public.review_lesson_contribution(%L, 'reject', '  ') $$,
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101')),
  '22023', 'rejection_reason_required', 'a rejection needs a reason');
select is(public.review_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101'), 'approve', 'Looks fine'),
  'ready_for_publication', 'moderator approves');
select throws_ok(format($$ select public.publish_lesson_contribution(%L) $$,
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101')),
  '42501', 'admin_required', 'moderators cannot publish');

-- Admin publishes ------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000d', true);
select is(public.publish_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101')),
  'published', 'admin publishes the approved version');
select is((select trust_tier from public.list_published_contributions(10) limit 1),
  'community_unreviewed', 'published copies are labelled community_unreviewed (A93)');
-- Read as the table owner: row-level security rightly hides A's private
-- lesson from the admin's own session.
reset role;
select is((select visibility from public.lessons
            where id = 'c0700000-0000-4000-8000-000000000101'),
  'private', 'publishing does not change the source lesson');
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000d', true);

-- Anonymous readers see only the published snapshot, and only while ON.
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is((select count(*)::int from public.list_published_contributions(10)), 1,
  'anyone can read published community copies while the gate is ON');
reset role;

-- Takedown and withdrawal --------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000c', true);
select throws_ok(format($$ select public.takedown_lesson_contribution(%L, '') $$,
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101')),
  '22023', 'takedown_reason_required', 'a takedown needs a reason');
select is(public.takedown_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101'), 'copyright report'),
  'withdrawn', 'moderator takedown');
select is((select count(*)::int from public.content_contribution_events e
             join public.content_contributions c on c.id = e.contribution_id
            where c.lesson_id = 'c0700000-0000-4000-8000-000000000101'), 4,
  'submitted, approved, published and taken_down are all audited');

select set_config('request.jwt.claim.sub', 'c0700000-0000-4000-8000-00000000000a', true);
select is(public.withdraw_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000102' and version = 2), 'changed my mind'),
  'withdrawn', 'contributors can withdraw their own submission');
select throws_ok(format($$ select public.withdraw_lesson_contribution(%L) $$,
  (select id from public.content_contributions
    where lesson_id = 'c0700000-0000-4000-8000-000000000101')),
  '22000', null, 'withdrawn is terminal');
reset role;

-- Gate OFF again: nothing is listed.
update private.site_feature_controls
   set enabled = false
 where feature_key = 'content.public_contribution';
select is((select count(*)::int from public.list_published_contributions(10)), 0,
  'turning the gate OFF hides community copies');

select * from finish();
rollback;
