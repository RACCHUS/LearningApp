begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

select has_column(
  'public', 'lessons', 'visibility',
  'lesson rows expose a visibility state'
);

insert into auth.users (id, is_anonymous)
values
  ('11111111-1111-4111-8111-111111111111', true),
  ('22222222-2222-4222-8222-222222222222', true);
insert into public.users (id)
values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');
insert into public.lessons (id, title, user_id)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'A guest private lesson',
  '11111111-1111-4111-8111-111111111111'
);
insert into public.terms (id, lesson_id, term, definition)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Secret term', 'Only the owner reads this'
);
insert into public.questions (id, lesson_id, question_text, options, correct_answer)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Secret question?', '["Yes", "No"]'::jsonb, 0
);
insert into public.concepts (id, lesson_id, concept_text)
values (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Secret legacy concept'
);
insert into public.knowledge_concepts (id, name)
values ('ffffffff-ffff-4fff-8fff-ffffffffffff', 'Mapped topic');
insert into public.lesson_concepts (lesson_id, concept_id)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'ffffffff-ffff-4fff-8fff-ffffffffffff'
);
insert into public.question_concepts (question_id, concept_id)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'ffffffff-ffff-4fff-8fff-ffffffffffff'
);
insert into public.term_concepts (term_id, concept_id)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'ffffffff-ffff-4fff-8fff-ffffffffffff'
);
insert into public.courses (id, user_id, title, is_public, visibility, status)
values (
  '99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111',
  'Public course with private material', true, 'public', 'published'
);
insert into public.course_lessons (course_id, lesson_id)
values (
  '99999999-9999-4999-8999-999999999999',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);
insert into public.lessons (id, title, visibility)
values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'System lesson', 'public');
insert into public.terms (id, lesson_id, term, definition)
values (
  '77777777-7777-4777-8777-777777777777',
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  'Public term', 'Anyone can read this'
);

-- Model a private lesson bound while a version was draft, then published.
-- The fixture bypasses only the immutability trigger; all reads below use RLS.
set local session_replication_role = replica;
insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id)
select n.id, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
from public.curriculum_nodes n
join public.target_versions v on v.id = n.target_version_id
join public.learning_targets t on t.id = v.target_id
where t.is_official and t.status = 'published' and t.is_public
  and v.status = 'published'
limit 1;
set local session_replication_role = origin;

select is(
  (select visibility from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'private',
  'new guest lessons default to private'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select is(
  (select count(*) from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'the guest owner can read their private lesson'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is(
  (select count(*) from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'another guest cannot read the lesson row'
);
select is(
  (select count(*) from public.terms where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'another guest cannot read its terms'
);
select is(
  (select count(*) from public.questions where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'another guest cannot read its questions'
);
select is(
  (select count(*) from public.concepts where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'another guest cannot read its legacy concepts'
);
select is(
  (select count(*) from public.lesson_concepts where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'another guest cannot read lesson-to-concept mappings'
);
select is(
  (select count(*) from public.question_concepts where question_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
  0::bigint,
  'another guest cannot read question-to-concept mappings'
);
select is(
  (select count(*) from public.term_concepts where term_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
  0::bigint,
  'another guest cannot read term-to-concept mappings'
);
select is(
  (select count(*) from public.course_lessons where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'public course membership cannot expose a private lesson ID'
);
select is(
  (select count(*) from public.curriculum_node_lessons where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'published curriculum membership cannot expose a private lesson ID'
);
update public.lessons
set visibility = 'public'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
select is(
  (select visibility from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'private',
  'another guest cannot publish the owner lesson'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'an unauthenticated visitor cannot read a private lesson'
);
select is(
  (select count(*) from public.lessons where id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  1::bigint,
  'an unauthenticated visitor can read an explicitly public system lesson'
);
select is(
  (select count(*) from public.terms where lesson_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'),
  1::bigint,
  'public lesson terms remain readable before sign-in'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
update public.lessons
set visibility = 'public'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select visibility from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'public',
  'the owner can explicitly publish their lesson'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'an explicitly published user lesson is readable without sign-in'
);
select is(
  (select count(*) from public.terms where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'publishing also makes lesson content readable'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
update public.lessons
set visibility = 'unlisted'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select visibility from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  'unlisted',
  'the owner can reserve unlisted visibility'
);

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select is(
  (select count(*) from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'unlisted is owner-only until explicit link-sharing exists'
);

reset role;
select throws_ok(
  $$insert into public.lessons (id, title, visibility)
    values ('88888888-8888-4888-8888-888888888888', 'Invalid system lesson', 'private')$$,
  '23514',
  'new row for relation "lessons" violates check constraint "lessons_ownerless_public_check"',
  'an ownerless lesson cannot remain private'
);

select * from finish();
rollback;
