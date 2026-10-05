begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

-- Setup test users
insert into auth.users (id, is_anonymous)
values
  ('11111111-1111-4111-8111-111111111111', false),
  ('22222222-2222-4222-8222-222222222222', false);

insert into public.users (id)
values
  ('11111111-1111-4111-8111-111111111111'),
  ('22222222-2222-4222-8222-222222222222');

-- Setup target owned by user 1
insert into public.learning_targets
  (id, target_type, title, slug, created_by, is_official, status)
values (
  'aaaaaaaa-1111-4aaa-8aaa-aaaaaaaaaaaa',
  'certification',
  'Immutability Test Target',
  'immutability-test-target',
  '11111111-1111-4111-8111-111111111111',
  false,
  'draft'
);

-- Insert 3 target versions: draft, published, retired
insert into public.target_versions (id, target_id, version_code, title, status)
values
  ('bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-1111-4aaa-8aaa-aaaaaaaaaaaa', 'v1', 'Draft Version', 'draft'),
  ('bbbbbbbb-2222-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-1111-4aaa-8aaa-aaaaaaaaaaaa', 'v2', 'Published Version', 'published'),
  ('bbbbbbbb-3333-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-1111-4aaa-8aaa-aaaaaaaaaaaa', 'v3', 'Retired Version', 'retired');

-- Pre-seed an existing node in the retired version for testing update/delete rejection
insert into public.curriculum_nodes (id, target_version_id, node_type, title)
values ('cccccccc-3333-4ccc-8ccc-cccccccccccc', 'bbbbbbbb-3333-4bbb-8bbb-bbbbbbbbbbbb', 'topic', 'Old Historical Topic');

-- Pre-seed a lesson
insert into public.lessons (id, title, user_id)
values ('dddddddd-1111-4ddd-8ddd-dddddddddddd', 'Test Lesson', '11111111-1111-4111-8111-111111111111');

-- Switch to authenticated owner User 1
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);

-- 1. Draft version permits node insertion
select lives_ok(
  $$
    insert into public.curriculum_nodes (id, target_version_id, node_type, title)
    values ('cccccccc-1111-4ccc-8ccc-cccccccccccc', 'bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb', 'topic', 'Draft Topic')
  $$,
  'Owner can insert curriculum nodes in draft target version'
);

-- 2. Draft version permits node lesson binding
select lives_ok(
  $$
    insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id)
    values ('cccccccc-1111-4ccc-8ccc-cccccccccccc', 'dddddddd-1111-4ddd-8ddd-dddddddddddd')
  $$,
  'Owner can bind lessons to nodes in draft target version'
);

-- 3. Draft version permits updating version metadata
select results_eq(
  $$
    update public.target_versions
    set title = 'Updated Draft Title'
    where id = 'bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb'
    returning title
  $$,
  $$ values ('Updated Draft Title'::text) $$,
  'Owner can update draft target version'
);

-- 4. Published version rejects node insertion
select throws_ok(
  $$
    insert into public.curriculum_nodes (id, target_version_id, node_type, title)
    values ('cccccccc-2222-4ccc-8ccc-cccccccccccc', 'bbbbbbbb-2222-4bbb-8bbb-bbbbbbbbbbbb', 'topic', 'Forbidden Topic')
  $$,
  '42501',
  null,
  'Owner cannot insert curriculum nodes in published target version'
);

-- 5. Published version rejects updates
select is_empty(
  $$
    update public.target_versions
    set title = 'Hacked Published Title'
    where id = 'bbbbbbbb-2222-4bbb-8bbb-bbbbbbbbbbbb'
    returning id
  $$,
  'Owner cannot update published target version (0 rows updated)'
);

-- 6. Published version rejects delete
select is_empty(
  $$
    delete from public.target_versions
    where id = 'bbbbbbbb-2222-4bbb-8bbb-bbbbbbbbbbbb'
    returning id
  $$,
  'Owner cannot delete published target version (0 rows deleted)'
);

-- 7. Retired version rejects node insertion
select throws_ok(
  $$
    insert into public.curriculum_nodes (id, target_version_id, node_type, title)
    values ('cccccccc-4444-4ccc-8ccc-cccccccccccc', 'bbbbbbbb-3333-4bbb-8bbb-bbbbbbbbbbbb', 'topic', 'Forbidden Retired Topic')
  $$,
  '42501',
  null,
  'Owner cannot insert curriculum nodes in retired target version'
);

-- 8. Retired version rejects updates
select is_empty(
  $$
    update public.target_versions
    set title = 'Hacked Retired Title'
    where id = 'bbbbbbbb-3333-4bbb-8bbb-bbbbbbbbbbbb'
    returning id
  $$,
  'Owner cannot update retired target version (0 rows updated)'
);

-- 9. Retired version rejects delete
select is_empty(
  $$
    delete from public.target_versions
    where id = 'bbbbbbbb-3333-4bbb-8bbb-bbbbbbbbbbbb'
    returning id
  $$,
  'Owner cannot delete retired target version (0 rows deleted)'
);

-- 10. Retired version rejects node modification
select is_empty(
  $$
    update public.curriculum_nodes
    set title = 'Modified Historical Topic'
    where id = 'cccccccc-3333-4ccc-8ccc-cccccccccccc'
    returning id
  $$,
  'Owner cannot update curriculum nodes in retired target version (0 rows updated)'
);

-- 11. Retired version rejects node deletion
select is_empty(
  $$
    delete from public.curriculum_nodes
    where id = 'cccccccc-3333-4ccc-8ccc-cccccccccccc'
    returning id
  $$,
  'Owner cannot delete curriculum nodes in retired target version (0 rows deleted)'
);

-- 12. Retired version rejects lesson binding
select throws_ok(
  $$
    insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id)
    values ('cccccccc-3333-4ccc-8ccc-cccccccccccc', 'dddddddd-1111-4ddd-8ddd-dddddddddddd')
  $$,
  '42501',
  null,
  'Owner cannot bind lessons to nodes in retired target version'
);

-- 13. Owner can promote draft version to review_ready
select lives_ok(
  $$
    update public.target_versions
    set status = 'review_ready'
    where id = 'bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  'Owner can promote draft version to review_ready status'
);

-- 14. In review_ready, attempting to update valid_until or source_url is rejected
select throws_ok(
  $$
    update public.target_versions
    set valid_until = '2030-01-01'::date
    where id = 'bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  'TargetVersion is frozen in "review_ready" status. Revert status to "draft" before making edits.',
  'review_ready rejects modifying valid_until or other metadata columns'
);

-- 15. publish_target_version RPC atomically publishes review_ready and retires previous published version
select is(
  (select public.publish_target_version('bbbbbbbb-1111-4bbb-8bbb-bbbbbbbbbbbb'::uuid, true)->>'status'),
  'published',
  'publish_target_version atomically promotes review_ready version to published'
);

-- 16. Previous published version was atomically retired
select is(
  (select status from public.target_versions where id = 'bbbbbbbb-2222-4bbb-8bbb-bbbbbbbbbbbb'),
  'retired',
  'publish_target_version atomically retired previous published version'
);

-- 17. Attempting to update valid_until or source_url when retiring a published version is rejected
-- Reset to administrative role so UPDATE targets the published row without RLS filtering it out,
-- allowing trg_target_versions_lifecycle to enforce published-to-retired attribute immutability.
reset role;

insert into public.target_versions (id, target_id, version_code, title, status)
values ('bbbbbbbb-4444-4bbb-8bbb-bbbbbbbbbbbb', 'aaaaaaaa-1111-4aaa-8aaa-aaaaaaaaaaaa', 'v4', 'Test Published', 'published');

select throws_ok(
  $$
    update public.target_versions
    set status = 'retired',
        valid_until = '2030-01-01'::date
    where id = 'bbbbbbbb-4444-4bbb-8bbb-bbbbbbbbbbbb'
  $$,
  'Cannot modify TargetVersion attributes when retiring a published version. It must be a status-only transition.',
  'Retiring published version rejects modifying valid_until'
);

select * from finish();
rollback;
