-- Regression coverage for public.v_field_relations_bidirectional.
-- The relation catalog is intentionally public; the view must execute with
-- caller privileges and expose only SELECT to API roles.

begin;
create extension if not exists pgtap;

select plan(15);

select ok(
  coalesce(
    (select reloptions @> array['security_invoker=true']::text[]
       from pg_class
      where oid = 'public.v_field_relations_bidirectional'::regclass),
    false
  ),
  'bidirectional field-relations view runs with invoker privileges'
);

select ok(
  (select relrowsecurity
     from pg_class
    where oid = 'public.field_relations'::regclass),
  'underlying field_relations table has RLS enabled'
);

select ok(
  exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'field_relations'
       and policyname = 'public_read_field_relations'
       and cmd = 'SELECT'
       and 'public' = any (roles)
       and qual = 'true'
  ),
  'the intended public taxonomy read policy remains in place'
);

select ok(
  has_table_privilege('anon', 'public.v_field_relations_bidirectional', 'SELECT'),
  'anon retains SELECT on the bidirectional taxonomy view'
);

select ok(
  has_table_privilege('authenticated', 'public.v_field_relations_bidirectional', 'SELECT'),
  'authenticated retains SELECT on the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('anon', 'public.v_field_relations_bidirectional', 'INSERT'),
  'anon cannot INSERT through the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('anon', 'public.v_field_relations_bidirectional', 'UPDATE'),
  'anon cannot UPDATE through the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('anon', 'public.v_field_relations_bidirectional', 'DELETE'),
  'anon cannot DELETE through the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('authenticated', 'public.v_field_relations_bidirectional', 'INSERT'),
  'authenticated cannot INSERT through the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('authenticated', 'public.v_field_relations_bidirectional', 'UPDATE'),
  'authenticated cannot UPDATE through the bidirectional taxonomy view'
);

select ok(
  not has_table_privilege('authenticated', 'public.v_field_relations_bidirectional', 'DELETE'),
  'authenticated cannot DELETE through the bidirectional taxonomy view'
);

set local role anon;

select cmp_ok(
  (select count(*)::integer from public.v_field_relations_bidirectional),
  '=',
  (
    select (count(*) + count(*) filter (
      where relation_type in ('shares_foundations', 'cross_disciplinary_partner')
    ))::integer
    from public.field_relations
  ),
  'anon can read all intended forward and symmetric taxonomy relations through the view'
);

select ok(
  has_table_privilege(current_user, 'public.field_relations', 'SELECT'),
  'anon retains SELECT on the underlying public taxonomy relation table'
);

reset role;
set local role authenticated;

select cmp_ok(
  (select count(*)::integer from public.v_field_relations_bidirectional),
  '=',
  (
    select (count(*) + count(*) filter (
      where relation_type in ('shares_foundations', 'cross_disciplinary_partner')
    ))::integer
    from public.field_relations
  ),
  'authenticated can read all intended forward and symmetric taxonomy relations through the view'
);

select ok(
  has_table_privilege(current_user, 'public.field_relations', 'SELECT'),
  'authenticated retains SELECT on the underlying public taxonomy relation table'
);

select * from finish();
rollback;
