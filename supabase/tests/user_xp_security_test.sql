-- pgTAP test for user_xp security and increment_user_xp RPC hardening
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

-- 1. Create synthetic test users in auth.users
insert into auth.users (id, email) values
 ('ee111111-0000-4000-8000-000000000001', 'user1@example.invalid'),
 ('ee111111-0000-4000-8000-000000000002', 'user2@example.invalid')
on conflict (id) do nothing;

-- 2. Test unauthenticated call to increment_user_xp fails
set local role anon;
select throws_ok(
  $$ select increment_user_xp(10) $$,
  '42501',
  null,
  'Anon role cannot execute increment_user_xp'
);

-- 3. Switch to authenticated User 1
set local role authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

-- 4. Valid XP increment succeeds for own user
select lives_ok(
  $$ select increment_user_xp(50) $$,
  'Authenticated user can increment own XP'
);

select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  50,
  'User 1 total XP is 50'
);

-- 5. User 1 cannot increment User 2's XP
select throws_ok(
  $$ select increment_user_xp(50, 'ee111111-0000-4000-8000-000000000002'::uuid) $$,
  'P0001',
  'Cannot modify XP for another user',
  'User cannot modify another user XP'
);

-- 6. Negative or out of bounds XP amount fails
select throws_ok(
  $$ select increment_user_xp(-10) $$,
  'P0001',
  'Invalid XP increment amount (must be 1..1000)',
  'Negative XP amount throws exception'
);

select throws_ok(
  $$ select increment_user_xp(1001) $$,
  'P0001',
  'Invalid XP increment amount (must be 1..1000)',
  'XP amount > 1000 throws exception'
);

-- 7. Direct client update on user_xp is blocked
update public.user_xp set total_xp = 999999 where user_id = 'ee111111-0000-4000-8000-000000000001';
select is(
  (select total_xp from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000001'),
  50,
  'Direct client UPDATE on user_xp is blocked by RLS'
);

-- 8. User 1 cannot see User 2's XP row
do $$ begin
  -- create row for User 2 via service_role
  set local role service_role;
  insert into public.user_xp (user_id, total_xp) values ('ee111111-0000-4000-8000-000000000002', 100)
  on conflict (user_id) do update set total_xp = 100;
  
  -- switch back to User 1
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', 'ee111111-0000-4000-8000-000000000001', true);
end $$;

select is(
  (select count(*)::integer from public.user_xp where user_id = 'ee111111-0000-4000-8000-000000000002'),
  0,
  'User 1 cannot view User 2 XP'
);

select * from finish();
rollback;

