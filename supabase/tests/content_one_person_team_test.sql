-- One-person team (20261119050000): the sole admin may review, publish and
-- decide their own community items, labelled in the audit trail. Plain
-- moderators keep the two-person rule.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

insert into auth.users (id, email, is_anonymous) values
  ('c0760000-0000-4000-8000-00000000000a', 'opt-admin@example.invalid', false),
  ('c0760000-0000-4000-8000-00000000000b', 'opt-mod@example.invalid', false)
on conflict (id) do nothing;
insert into public.users (id, email) values
  ('c0760000-0000-4000-8000-00000000000a', 'opt-admin@example.invalid'),
  ('c0760000-0000-4000-8000-00000000000b', 'opt-mod@example.invalid')
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('c0760000-0000-4000-8000-00000000000a', 'admin'),
  ('c0760000-0000-4000-8000-00000000000b', 'moderator')
on conflict (user_id) do nothing;
insert into public.lessons (id, title, user_id, visibility) values
  ('c0760000-0000-4000-8000-000000000101', 'Admin lesson', 'c0760000-0000-4000-8000-00000000000a', 'private'),
  ('c0760000-0000-4000-8000-000000000102', 'Mod lesson', 'c0760000-0000-4000-8000-00000000000b', 'private');
insert into public.questions (lesson_id, question_text, options, correct_answer, type) values
  ('c0760000-0000-4000-8000-000000000101', 'Q1', '["a","b","c"]', 1, 'mcq'),
  ('c0760000-0000-4000-8000-000000000102', 'Q2', '["a","b","c"]', 2, 'mcq');
insert into public.terms (lesson_id, term, definition) values
  ('c0760000-0000-4000-8000-000000000101', 'Term', 'Meaning'),
  ('c0760000-0000-4000-8000-000000000102', 'Term', 'Meaning');

select is((select count(*)::int from private.site_feature_controls
            where feature_key in ('content.public_contribution',
              'content.refresh_proposals', 'content.wanted_board')
              and enabled and release_ready), 3,
  'the three public user-content switches are on');

-- The admin shares, reviews and publishes their own lesson.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0760000-0000-4000-8000-00000000000a', true);
select is((public.submit_lesson_contribution(
  'c0760000-0000-4000-8000-000000000101', 'CC-BY-4.0', true, false)->>'status'),
  'submitted', 'the admin submits their own lesson');
select is(public.review_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0760000-0000-4000-8000-000000000101'), 'approve', 'Checked'),
  'ready_for_publication', 'the admin may approve their own contribution');
select is(public.publish_lesson_contribution(
  (select id from public.content_contributions
    where lesson_id = 'c0760000-0000-4000-8000-000000000101')),
  'published', 'the admin may publish their own contribution');
reset role;

select ok((select review_note from public.content_contributions
            where lesson_id = 'c0760000-0000-4000-8000-000000000101')
          like '[self-reviewed by admin]%', 'the self-review is labelled');
select is((select count(*)::int from public.content_contribution_events e
             join public.content_contributions c on c.id = e.contribution_id
            where c.lesson_id = 'c0760000-0000-4000-8000-000000000101'
              and e.note like '[self-%by admin]%'), 2,
  'approval and publication are both labelled in the audit trail');

-- A plain moderator still cannot approve their own.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c0760000-0000-4000-8000-00000000000b', true);
select is((public.submit_lesson_contribution(
  'c0760000-0000-4000-8000-000000000102', 'CC-BY-4.0', true, false)->>'status'),
  'submitted', 'the moderator submits their own lesson');
select throws_ok(format($$ select public.review_lesson_contribution(%L, 'approve', null) $$,
  (select id from public.content_contributions
    where lesson_id = 'c0760000-0000-4000-8000-000000000102')),
  '42501', 'cannot_review_own_contribution', 'a moderator cannot approve their own');

-- Refresh proposals: same rule.
select ok(public.propose_contribution_refresh(
  (select id from public.content_contributions
    where lesson_id = 'c0760000-0000-4000-8000-000000000101'),
  'correction', 'Q1 needs a clearer wording for beginners.') is not null,
  'the moderator proposes an update');
select throws_ok(format($$ select public.decide_refresh_proposal(%L, true, null) $$,
  (select id from public.content_refresh_proposals limit 1)),
  '42501', 'cannot_decide_own_proposal', 'a moderator cannot decide their own proposal');
reset role;

select * from finish();
rollback;
