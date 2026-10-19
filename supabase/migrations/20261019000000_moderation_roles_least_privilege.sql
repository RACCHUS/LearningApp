-- ECO-00B: Moderation Roles Least Privilege & View Security
-- Migration Version: 20261019000000

-- -----------------------------------------------------------------------------
-- 1. Moderation Roles Least-Privilege Hardening (pg_graphql Defense in Depth)
-- -----------------------------------------------------------------------------
-- Revoke all table-level privileges from public and anon so pg_graphql does not
-- expose moderation_roles in the unauthenticated GraphQL schema.
revoke all on table public.moderation_roles from public, anon;
grant select, insert, update, delete on table public.moderation_roles to authenticated;

-- -----------------------------------------------------------------------------
-- 2. View Security Hardening (security_invoker)
-- -----------------------------------------------------------------------------
-- Enforce that queries against v_field_relations_bidirectional execute using the
-- querying user's RLS permissions rather than security definer semantics.
alter view public.v_field_relations_bidirectional set (security_invoker = true);

-- -----------------------------------------------------------------------------
-- 3. Initial Administrator Provisioning
-- -----------------------------------------------------------------------------
-- Idempotently bootstrap trusted administrator role for project owner if account exists.
insert into public.moderation_roles (user_id, role, granted_by)
select id, 'admin', id
  from auth.users
 where lower(email) = 'richardgurudeo@gmail.com'
on conflict (user_id) do update set role = 'admin';
