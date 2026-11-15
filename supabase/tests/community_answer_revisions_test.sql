-- pgTAP: learning.answer_revisions gate, author/moderator-only history,
-- linking a resubmission to its rejected versions, learner-facing feedback
-- only (never internal notes), and no direct table access.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(25);

-- Users: A (author), B (another learner), M (admin, so also a moderator).
insert into auth.users (id, email) values
 ('a7e00000-0000-4000-8000-00000000000a', 'rev-a@example.invalid'),
 ('a7e00000-0000-4000-8000-00000000000b', 'rev-b@example.invalid'),
 ('a7e00000-0000-4000-8000-00000000000c', 'rev-m@example.invalid')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role, granted_by)
values ('a7e00000-0000-4000-8000-00000000000c', 'admin', 'a7e00000-0000-4000-8000-00000000000c')
on conflict (user_id) do update set role = 'admin';

-- Seeded fixtures need an admin session (tamper triggers check auth.uid()).
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000c', true);

-- Fixtures as owner: two questions; A's rejected answer v1, pending v2
-- (rejected later, after it is linked to v1), and pending v3; B's own
-- rejected answer.
insert into public.community_questions (id, author_id, title, body_markdown, status, is_seeded, concept_id) values
 ('a7e00000-0000-4000-8000-000000000101', 'a7e00000-0000-4000-8000-00000000000c',
  'Revision test question one', 'A seeded question used by the revision tests.', 'published', true, 'test.revisions.one'),
 ('a7e00000-0000-4000-8000-000000000102', 'a7e00000-0000-4000-8000-00000000000c',
  'Revision test question two', 'Another seeded question for the revision tests.', 'published', true, 'test.revisions.two');

insert into public.community_answers (id, question_id, author_id, body_markdown, status, created_at) values
 ('a7e00000-0000-4000-8000-000000000201', 'a7e00000-0000-4000-8000-000000000101',
  'a7e00000-0000-4000-8000-00000000000a', 'First attempt at the answer text.', 'archived', '2026-11-01 10:00+00'),
 ('a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-000000000101',
  'a7e00000-0000-4000-8000-00000000000a', 'Second attempt at the answer text.', 'under_review', '2026-11-02 10:00+00'),
 ('a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000101',
  'a7e00000-0000-4000-8000-00000000000a', 'Third attempt, now under review.', 'under_review', '2026-11-03 10:00+00'),
 ('a7e00000-0000-4000-8000-000000000204', 'a7e00000-0000-4000-8000-000000000102',
  'a7e00000-0000-4000-8000-00000000000a', 'An answer to a different question.', 'under_review', '2026-11-03 11:00+00'),
 ('a7e00000-0000-4000-8000-000000000205', 'a7e00000-0000-4000-8000-000000000101',
  'a7e00000-0000-4000-8000-00000000000b', 'Learner B answer that was rejected.', 'archived', '2026-11-01 12:00+00');

insert into public.community_review_audit
  (target_type, target_id, reviewer_id, action, previous_status, new_status, notes, internal_notes, created_at) values
 ('answer', 'a7e00000-0000-4000-8000-000000000201', 'a7e00000-0000-4000-8000-00000000000c',
  'reject', 'under_review', 'archived', 'Please add an example.', 'CONFIDENTIAL-1', '2026-11-01 11:00+00'),
 ('answer', 'a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-00000000000c',
  'reject', 'under_review', 'archived', 'Older note.', 'CONFIDENTIAL-2', '2026-11-02 11:00+00'),
 ('answer', 'a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-00000000000c',
  'reject', 'under_review', 'archived', 'The example is wrong.', 'CONFIDENTIAL-3', '2026-11-02 12:00+00');

select is(
  (select enabled or release_ready from private.site_feature_controls
    where feature_key = 'learning.answer_revisions'),
  false, 'learning.answer_revisions is seeded OFF');

-- Gate OFF: both RPCs refuse and nothing is written.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000a', true);
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-000000000201') $$,
  '42501', 'feature_disabled', 'linking is refused while the gate is OFF');
select throws_ok(
  $$ select * from public.list_community_answer_revisions(
       array['a7e00000-0000-4000-8000-000000000202']::uuid[]) $$,
  '42501', 'feature_disabled', 'reading history is refused while the gate is OFF');
select throws_ok(
  $$ select * from public.community_answer_revisions $$,
  '42501', null, 'no direct reads of the revisions table');
select throws_ok(
  $$ insert into public.community_answer_revisions (answer_id, revision_number, body_markdown, editor_id)
     values ('a7e00000-0000-4000-8000-000000000203', 1, 'forged history text',
             'a7e00000-0000-4000-8000-00000000000a') $$,
  '42501', null, 'no direct writes to the revisions table');

set local role anon;
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-000000000201') $$,
  '42501', null, 'anon cannot call the link RPC');

reset role;
select is((select count(*)::int from public.community_answer_revisions), 0, 'OFF path wrote nothing');
update private.site_feature_controls set enabled = true, release_ready = true
 where feature_key = 'learning.answer_revisions';

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000a', true);

-- v2 revises v1.
select is(
  public.link_community_answer_resubmission(
    'a7e00000-0000-4000-8000-000000000202', 'a7e00000-0000-4000-8000-000000000201'),
  1, 'v2 now has one earlier version');

-- v2 is then rejected too.
reset role;
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000c', true);
update public.community_answers set status = 'archived'
 where id = 'a7e00000-0000-4000-8000-000000000202';
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000a', true);

-- Refusals.
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000204', 'a7e00000-0000-4000-8000-000000000202') $$,
  '22023', 'invalid_revision_link', 'cannot link answers to different questions');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000201', 'a7e00000-0000-4000-8000-000000000203') $$,
  '22023', 'invalid_revision_link', 'the earlier answer must be a rejected one');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000205') $$,
  'P0002', 'answer_not_found', 'cannot claim another learner''s answer as an earlier version');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000203') $$,
  '22023', 'invalid_revision_link', 'an answer cannot revise itself');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000201') $$,
  '23505', 'already_revised', 'a rejected answer can only be revised once');

-- v3 revises v2 and inherits v1.
select is(
  public.link_community_answer_resubmission(
    'a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000202'),
  2, 'v3 has two earlier versions (v1 carried over from v2)');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000202') $$,
  '23505', 'already_linked', 'linking twice is refused');

select results_eq(
  $$ select revision_number, body_markdown, edit_reason
       from public.list_community_answer_revisions(array['a7e00000-0000-4000-8000-000000000203']::uuid[]) $$,
  $$ values (2, 'Second attempt at the answer text.'::text, 'The example is wrong.'::text),
            (1, 'First attempt at the answer text.'::text, 'Please add an example.'::text) $$,
  'author sees earlier versions newest first, each with the latest learner-facing feedback');
select is(
  (select count(*)::int from public.list_community_answer_revisions(
     array['a7e00000-0000-4000-8000-000000000203']::uuid[])
    where edit_reason like '%CONFIDENTIAL%'),
  0, 'internal moderation notes never appear in history');
select is(
  (select created_at from public.list_community_answer_revisions(
     array['a7e00000-0000-4000-8000-000000000203']::uuid[]) where revision_number = 1),
  '2026-11-01 10:00+00'::timestamptz, 'each version keeps the time it was written');
select is(
  (select source_answer_id from public.list_community_answer_revisions(
     array['a7e00000-0000-4000-8000-000000000203']::uuid[]) where revision_number = 2),
  'a7e00000-0000-4000-8000-000000000202'::uuid, 'each version points at the rejected answer it came from');

-- Another learner sees nothing; a moderator sees everything.
select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000b', true);
select is(
  (select count(*)::int from public.list_community_answer_revisions(
     array['a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000202']::uuid[])),
  0, 'other learners cannot read someone else''s history');
select throws_ok(
  $$ select public.link_community_answer_resubmission(
       'a7e00000-0000-4000-8000-000000000204', 'a7e00000-0000-4000-8000-000000000201') $$,
  'P0002', 'answer_not_found', 'other learners cannot link someone else''s answers');

select set_config('request.jwt.claim.sub', 'a7e00000-0000-4000-8000-00000000000c', true);
select is(
  (select count(*)::int from public.list_community_answer_revisions(
     array['a7e00000-0000-4000-8000-000000000203', 'a7e00000-0000-4000-8000-000000000202']::uuid[])),
  3, 'moderators see history for the answers they review');
select throws_ok(
  $$ select * from public.list_community_answer_revisions(
       (select array_agg(gen_random_uuid()) from generate_series(1, 101))) $$,
  '22023', 'too_many_answers', 'at most 100 answers per request');

-- Deleting the answer removes its history.
reset role;
delete from public.community_answers where id = 'a7e00000-0000-4000-8000-000000000203';
select is(
  (select count(*)::int from public.community_answer_revisions
    where answer_id = 'a7e00000-0000-4000-8000-000000000203'),
  0, 'history is deleted with its answer');
select is(
  (select count(*)::int from public.community_answer_revisions
    where answer_id = 'a7e00000-0000-4000-8000-000000000202'),
  1, 'other answers keep their history');

select * from finish();
rollback;
