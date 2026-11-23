-- pgTAP: evidence for champion/challenger decisions (migration 20261123040000).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(10);

insert into auth.users (id, email)
select ('d5000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid, 'vde' || i || '@example.invalid'
from generate_series(1, 9) i on conflict (id) do nothing;
insert into public.users (id)
select ('d5000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid from generate_series(1, 9) i
on conflict (id) do nothing;
insert into public.moderation_roles (user_id, role) values
  ('d5000000-0000-4000-8000-000000000001', 'admin'),
  ('d5000000-0000-4000-8000-000000000002', 'moderator')
on conflict (user_id) do nothing;

-- A catalog book with a published R1 and a review-ready R2.
insert into public.learning_targets (id, target_type, title, slug) values
  ('d5000000-0000-4000-8000-000000000100', 'curriculum_standard', 'Evidence Book', 'test-vde-book');
insert into public.target_versions (id, target_id, version_code, status) values
  ('d5000000-0000-4000-8000-000000000101', 'd5000000-0000-4000-8000-000000000100', 'R1', 'draft'),
  ('d5000000-0000-4000-8000-000000000102', 'd5000000-0000-4000-8000-000000000100', 'R2', 'draft');
insert into public.lessons (id, title, visibility, origin_target_version_id) values
  ('d5000000-0000-4000-8000-000000000201', 'R1 lesson', 'public', 'd5000000-0000-4000-8000-000000000101'),
  ('d5000000-0000-4000-8000-000000000202', 'R2 lesson', 'public', 'd5000000-0000-4000-8000-000000000102');
insert into public.lesson_blocks (lesson_id, block_type, sort_order, content) values
  ('d5000000-0000-4000-8000-000000000201', 'markdown', 1, '{"text":"Read."}'),
  ('d5000000-0000-4000-8000-000000000202', 'markdown', 1, '{"text":"Read."}'),
  ('d5000000-0000-4000-8000-000000000202', 'markdown', 2, '{"text":"**Example 1**"}'),
  ('d5000000-0000-4000-8000-000000000202', 'practice_prompt', 3, '{"prompt":"Try"}');
update public.target_versions set status = 'review_ready' where target_id = 'd5000000-0000-4000-8000-000000000100';
update public.target_versions set status = 'published' where id = 'd5000000-0000-4000-8000-000000000101';

-- Six learners answered R1's checks: 6 x (4 answered, 3 correct).
insert into public.user_progress (user_id, lesson_id, questions_answered, correct_count)
select ('d5000000-0000-4000-8000-0000000000' || lpad(i::text, 2, '0'))::uuid,
       'd5000000-0000-4000-8000-000000000201', 4, 3
from generate_series(3, 8) i;
-- A volunteer accuracy concern on R1.
insert into private.content_review_evidence (lesson_id, aspect, outcome, reviewer_kind)
values ('d5000000-0000-4000-8000-000000000201', 'accuracy', 'concern', 'volunteer');

set local role authenticated;
select set_config('request.jwt.claim.sub', 'd5000000-0000-4000-8000-000000000002', true);
select throws_ok($$ select public.get_version_decision_candidates() $$, '42501', null, 'moderators cannot list candidates');
select throws_ok($$ select public.get_version_comparison('d5000000-0000-4000-8000-000000000101','d5000000-0000-4000-8000-000000000102') $$,
  '42501', null, 'moderators cannot compare');

select set_config('request.jwt.claim.sub', 'd5000000-0000-4000-8000-000000000001', true);
select is((select c->>'champion_code' from jsonb_array_elements(public.get_version_decision_candidates()) c
           where c->>'target_slug' = 'test-vde-book'), 'R1', 'the published version is the champion');
select is((select c->'challengers'->0->>'code' from jsonb_array_elements(public.get_version_decision_candidates()) c
           where c->>'target_slug' = 'test-vde-book'), 'R2', 'review-ready versions are challengers');

create temp table cmp as select public.get_version_comparison(
  'd5000000-0000-4000-8000-000000000101', 'd5000000-0000-4000-8000-000000000102') as v;
select is((select v->'challenger'->>'example_blocks' from cmp), '1', 'contents are counted per version');
select is((select v->'champion'->'review'->'accuracy'->>'concern' from cmp), '1', 'review evidence per version');
select is((select v->'champion'->>'learner_accounts' from cmp), '6', 'learners counted at five or more');
select is((select v->'champion'->>'check_accuracy' from cmp), '0.750', 'how their checks went');
select is((select v->'challenger'->>'learner_evidence' from cmp), 'not_published',
  'an unpublished challenger has no learner evidence, shown as such');
select throws_ok($$ select public.get_version_comparison('d5000000-0000-4000-8000-000000000101','d5000000-0000-4000-8000-000000000101') $$,
  '22023', null, 'two different versions of one target are required');
reset role;

select * from finish();
rollback;
