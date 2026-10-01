begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

select has_table(
  'public', 'user_curriculum_resources',
  'personal curriculum attachments have their own table'
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
values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Owner lesson', '11111111-1111-4111-8111-111111111111'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'Other lesson', '22222222-2222-4222-8222-222222222222');
insert into public.learning_targets
  (id, target_type, title, slug, status, is_public, is_official, created_by)
values
  ('33333333-3333-4333-8333-333333333333', 'certification',
   'Private draft target', 'private-overlay-test-target', 'draft', false, false,
   '22222222-2222-4222-8222-222222222222');
insert into public.target_versions (id, target_id, version_code, status)
values
  ('44444444-4444-4444-8444-444444444444',
   '33333333-3333-4333-8333-333333333333', 'draft-1', 'draft');
insert into public.curriculum_nodes (id, target_version_id, node_type, title)
values
  ('55555555-5555-4555-8555-555555555555',
   '44444444-4444-4444-8444-444444444444', 'topic', 'Private topic');

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select lives_ok(
  $$insert into public.user_curriculum_resources (curriculum_node_id, lesson_id)
    values ('c1000000-0000-0000-0000-000000000001',
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,
  'authenticated guest can attach their own lesson to a published official node'
);
select is(
  (select count(*) from public.user_curriculum_resources
   where curriculum_node_id = 'c1000000-0000-0000-0000-000000000001'),
  1::bigint,
  'owner reads the attachment'
);
select lives_ok(
  $$insert into public.user_curriculum_resources (curriculum_node_id, lesson_id)
    values ('c1000000-0000-0000-0000-000000000001',
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')
    on conflict (user_id, curriculum_node_id, lesson_id, relationship)
    do update set sort_order = excluded.sort_order$$,
  'retrying the same attachment is idempotent'
);
select is(
  (select count(*) from public.user_curriculum_resources
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'duplicate retry leaves one overlay row'
);
select throws_ok(
  $$insert into public.user_curriculum_resources (curriculum_node_id, lesson_id)
    values ('c1000000-0000-0000-0000-000000000001',
            'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb')$$,
  '42501',
  'new row violates row-level security policy for table "user_curriculum_resources"',
  'owner cannot attach another account lesson'
);
select throws_ok(
  $$insert into public.user_curriculum_resources (curriculum_node_id, lesson_id)
    values ('55555555-5555-4555-8555-555555555555',
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,
  '42501',
  'new row violates row-level security policy for table "user_curriculum_resources"',
  'a draft private topic is not an official attachment destination'
);
select throws_ok(
  $$insert into public.user_curriculum_resources (user_id, curriculum_node_id, lesson_id)
    values ('22222222-2222-4222-8222-222222222222',
            'c1000000-0000-0000-0000-000000000001',
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,
  '42501',
  'new row violates row-level security policy for table "user_curriculum_resources"',
  'client cannot spoof attachment ownership'
);
select is(
  (select count(*) from public.curriculum_node_lessons
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'personal attach does not change official curriculum bindings'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select is(
  (select count(*) from public.user_curriculum_resources
   where curriculum_node_id = 'c1000000-0000-0000-0000-000000000001'),
  0::bigint,
  'a different guest cannot read the attachment'
);
update public.user_curriculum_resources
set sort_order = 9
where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
delete from public.user_curriculum_resources
where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
reset role;
select is(
  (select count(*) from public.user_curriculum_resources
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'another guest cannot delete the owner attachment'
);
select is(
  (select sort_order from public.user_curriculum_resources
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0,
  'another guest cannot reorder the owner attachment'
);

set local role anon;
select throws_ok(
  $$select * from public.user_curriculum_resources$$,
  '42501',
  'permission denied for table user_curriculum_resources',
  'an unauthenticated visitor cannot query attachments'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
delete from public.user_curriculum_resources
where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select count(*) from public.user_curriculum_resources
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'unlink removes only the owner overlay row'
);
select is(
  (select count(*) from public.lessons
   where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  1::bigint,
  'unlink preserves the lesson in Library'
);
select lives_ok(
  $$insert into public.user_curriculum_resources (curriculum_node_id, lesson_id)
    values ('c1000000-0000-0000-0000-000000000001',
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')$$,
  'owner may attach the same lesson again after unlinking'
);
delete from public.lessons where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
select is(
  (select count(*) from public.user_curriculum_resources
   where lesson_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'),
  0::bigint,
  'deleting the personal lesson cascades away its attachment'
);

select * from finish();
rollback;
