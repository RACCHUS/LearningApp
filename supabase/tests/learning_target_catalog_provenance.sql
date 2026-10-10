begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

select has_column('public', 'learning_targets', 'review_status',
  'learning targets record moderation status');

insert into auth.users (id, is_anonymous)
values
  ('99000000-0000-4000-8000-000000000001', true),
  ('99000000-0000-4000-8000-000000000002', true)
on conflict (id) do nothing;

-- System ingestion and trusted review take place without an end-user JWT.
insert into public.learning_targets
  (id, target_type, title, slug, status, is_public, is_official,
   created_by, review_status)
values
  ('99000000-0000-4000-8000-000000000010', 'career',
   'Official Test Career', 'official-test-career-990', 'published',
   true, true, null, 'approved'),
  ('99000000-0000-4000-8000-000000000011', 'career',
   'Reviewed Community Career', 'community-career-990', 'published',
   true, false, '99000000-0000-4000-8000-000000000002', 'approved');

set local role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select is(
  (select count(*) from public.learning_targets
   where slug in ('official-test-career-990', 'community-career-990')),
  2::bigint,
  'anonymous catalog visitors can see approved and official entries'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub',
  '99000000-0000-4000-8000-000000000001', true);

select lives_ok(
  $$insert into public.learning_targets
    (id, target_type, title, slug, created_by, status, is_public)
    values ('99000000-0000-4000-8000-000000000012', 'career',
      'My Private Learning Goal', 'private-goal-990',
      '99000000-0000-4000-8000-000000000001', 'draft', false)$$,
  'learner can create a private draft'
);

select throws_ok(
  $$insert into public.learning_targets
    (target_type, title, slug, created_by, status, is_public, is_official)
    values ('career', 'Spoofed Official', 'spoof-990',
      '99000000-0000-4000-8000-000000000001', 'draft', false, true)$$,
  '42501',
  'User goals must begin as private, unreviewed drafts.',
  'clients cannot mark a new goal official'
);

select throws_ok(
  $$insert into public.learning_targets
    (target_type, title, slug, created_by, status, is_public)
    values ('career', 'Spoofed Public', 'public-spoof-990',
      '99000000-0000-4000-8000-000000000001', 'published', true)$$,
  '42501',
  'User goals must begin as private, unreviewed drafts.',
  'clients cannot self-publish into public catalog'
);

select lives_ok(
  $$update public.learning_targets
    set review_status = 'pending'
    where slug = 'private-goal-990'$$,
  'owner may submit draft for review'
);

select throws_ok(
  $$update public.learning_targets
    set review_status = 'approved'
    where slug = 'private-goal-990'$$,
  '42501',
  'Only trusted reviewers may publish or verify goals.',
  'owner cannot approve own review request'
);

select is(
  (select review_status from public.learning_targets
    where slug = 'private-goal-990'),
  'pending',
  'review request leaves custom goal private'
);

select set_config('request.jwt.claim.sub',
  '99000000-0000-4000-8000-000000000002', true);
select is(
  (select count(*) from public.learning_targets
   where slug = 'private-goal-990'),
  0::bigint,
  'another account cannot see an unreviewed private goal'
);

select throws_ok(
  $$delete from public.learning_targets
    where slug = 'community-career-990'$$,
  '42501',
  'Only trusted reviewers may delete verified goals.',
  'approved public community entries cannot be silently deleted by owner'
);

reset role;
select * from finish();
rollback;
