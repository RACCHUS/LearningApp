-- Companion to external resources, EX-1 (companion plan v1.0 §3.2-§3.4,
-- §7.2): a learner's own outside resources for a goal.
--
-- * New gate `content.learner_resources`, default OFF, not release-ready.
--   Every write checks it on the server. Reading and deleting your own rows
--   never depend on it, so switching it off keeps the data and the learner's
--   right to remove it.
-- * A resource is a title the learner typed, with an optional https link. The
--   server never fetches the link and stores nothing read from another site.
-- * `learner_resource_objectives`: the learner says which objectives of the
--   goal the resource covers (rung 1) and may mark one "studied". Objectives
--   are keyed by their code (or title where a node has no code), not by node
--   id, so the rows survive a new version of the target.
-- * "Studied" is SELF-REPORT. No readiness, coverage or evidence function
--   reads these tables; supabase/tests/learner_external_resources_test.sql
--   asserts that.
-- * Private to the owner (RLS), removed with the account (ON DELETE CASCADE).
--   No direct writes from browsers. Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.learner_resources', 'Learner outside resources', 'Content', 'release', false, 'experimental', false,
  'A learner adds a course, video or book they study outside LearningApp to a goal, ticks the objectives it covers and marks parts studied; self-report never counts toward readiness')
ON CONFLICT (feature_key) DO NOTHING;

create table if not exists public.learner_external_resources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 200),
  kind text not null default 'other'
    check (kind in ('video', 'video_series', 'course', 'book', 'article', 'podcast', 'class', 'other')),
  -- https only, no credentials in the host part, no whitespace.
  url text check (url is null or (char_length(url) <= 2000 and url ~ '^https://[^\s/?#@]+([/?#]\S*)?$')),
  access text check (access is null or access in ('free_no_login', 'free_with_login', 'paid')),
  -- Set when the learner picked a record from data/external_resources/.
  catalog_resource_id text check (
    catalog_resource_id is null
    or (char_length(catalog_resource_id) <= 120 and catalog_resource_id ~ '^[a-z0-9]+(-[a-z0-9]+)*$')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists learner_external_resources_owner
  on public.learner_external_resources (user_id, target_id, created_at);

create table if not exists public.learner_resource_objectives (
  resource_id uuid not null references public.learner_external_resources(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  objective_key text not null check (char_length(objective_key) between 1 and 200),
  -- Self-report: "I studied this outside LearningApp". Never evidence.
  studied_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (resource_id, objective_key)
);

create index if not exists learner_resource_objectives_owner
  on public.learner_resource_objectives (user_id);

alter table public.learner_external_resources enable row level security;
alter table public.learner_resource_objectives enable row level security;

create policy learner_external_resources_select on public.learner_external_resources
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy learner_resource_objectives_select on public.learner_resource_objectives
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.learner_external_resources from public, anon;
revoke all on table public.learner_resource_objectives from public, anon;
revoke insert, update, delete, truncate, references, trigger
  on table public.learner_external_resources from authenticated;
revoke insert, update, delete, truncate, references, trigger
  on table public.learner_resource_objectives from authenticated;
grant select on table public.learner_external_resources to authenticated;
grant select on table public.learner_resource_objectives to authenticated;

-- Signed-in caller with the gate on, or an exception. Returns the caller.
create or replace function private.learner_resources_writer()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.learner_resources') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;
revoke all on function private.learner_resources_writer() from public, anon, authenticated;

-- Create (p_resource_id null) or edit one of the caller's resources.
create or replace function public.save_learner_external_resource(
  p_target_id uuid,
  p_title text,
  p_kind text default 'other',
  p_url text default null,
  p_access text default null,
  p_catalog_resource_id text default null,
  p_resource_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_per_user constant integer := 100;
  v_uid uuid := private.learner_resources_writer();
  v_id uuid;
begin
  if p_resource_id is not null then
    update public.learner_external_resources r
       set title = btrim(p_title),
           kind = coalesce(p_kind, 'other'),
           url = nullif(btrim(p_url), ''),
           access = p_access,
           catalog_resource_id = p_catalog_resource_id,
           updated_at = now()
     where r.id = p_resource_id and r.user_id = v_uid
     returning r.id into v_id;
    if v_id is null then
      raise exception 'resource_not_found' using errcode = 'P0002';
    end if;
    return v_id;
  end if;

  -- Same visibility as the targets_read policy: your own target, or a
  -- published public one.
  if not exists (
    select 1 from public.learning_targets lt
     where lt.id = p_target_id
       and (lt.created_by = v_uid
            or (lt.status = 'published' and lt.is_public
                and (lt.is_official or lt.review_status = 'approved')))
  ) then
    raise exception 'target_not_found' using errcode = 'P0002';
  end if;
  if (select count(*) from public.learner_external_resources r where r.user_id = v_uid) >= c_max_per_user then
    raise exception 'resource_limit' using errcode = 'P0001';
  end if;

  insert into public.learner_external_resources
    (user_id, target_id, title, kind, url, access, catalog_resource_id)
  values
    (v_uid, p_target_id, btrim(p_title), coalesce(p_kind, 'other'),
     nullif(btrim(p_url), ''), p_access, p_catalog_resource_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- Replace the set of objectives the caller says a resource covers. Keys
-- already covered keep their "studied" mark. Returns how many are covered.
create or replace function public.set_learner_resource_objectives(
  p_resource_id uuid,
  p_objective_keys text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_keys constant integer := 300;
  v_uid uuid := private.learner_resources_writer();
  v_target uuid;
  v_keys text[];
begin
  select r.target_id into v_target
    from public.learner_external_resources r
   where r.id = p_resource_id and r.user_id = v_uid
     for update;
  if v_target is null then
    raise exception 'resource_not_found' using errcode = 'P0002';
  end if;

  select coalesce(array_agg(distinct btrim(k)), '{}') into v_keys
    from unnest(coalesce(p_objective_keys, '{}')) as k
   where btrim(k) <> '';
  if cardinality(v_keys) > c_max_keys then
    raise exception 'too_many_objectives' using errcode = 'P0001';
  end if;
  -- Every key must be a node of some version of this target.
  if exists (
    select 1 from unnest(v_keys) as k
     where not exists (
       select 1
         from public.curriculum_nodes n
         join public.target_versions tv on tv.id = n.target_version_id
        where tv.target_id = v_target
          and (n.code = k or (coalesce(n.code, '') = '' and n.title = k)))
  ) then
    raise exception 'unknown_objective' using errcode = 'P0001';
  end if;

  delete from public.learner_resource_objectives o
   where o.resource_id = p_resource_id and o.objective_key <> all (v_keys);
  insert into public.learner_resource_objectives (resource_id, user_id, objective_key)
  select p_resource_id, v_uid, k from unnest(v_keys) as k
  on conflict (resource_id, objective_key) do nothing;
  update public.learner_external_resources r set updated_at = now() where r.id = p_resource_id;
  return cardinality(v_keys);
end;
$$;

-- Mark or unmark one covered objective as studied (self-report only).
create or replace function public.set_learner_resource_objective_studied(
  p_resource_id uuid,
  p_objective_key text,
  p_studied boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.learner_resources_writer();
  v_at timestamptz;
begin
  update public.learner_resource_objectives o
     set studied_at = case when coalesce(p_studied, false) then coalesce(o.studied_at, now()) end
   where o.resource_id = p_resource_id
     and o.user_id = v_uid
     and o.objective_key = btrim(p_objective_key)
  returning o.studied_at into v_at;
  if not found then
    raise exception 'objective_not_covered' using errcode = 'P0002';
  end if;
  return v_at;
end;
$$;

-- Removing your own resource never depends on the gate.
create or replace function public.delete_learner_external_resource(p_resource_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  delete from public.learner_external_resources r
   where r.id = p_resource_id and r.user_id = v_uid
  returning r.id into v_id;
  return v_id is not null;
end;
$$;

revoke all on function public.save_learner_external_resource(uuid, text, text, text, text, text, uuid) from public, anon;
revoke all on function public.set_learner_resource_objectives(uuid, text[]) from public, anon;
revoke all on function public.set_learner_resource_objective_studied(uuid, text, boolean) from public, anon;
revoke all on function public.delete_learner_external_resource(uuid) from public, anon;
grant execute on function public.save_learner_external_resource(uuid, text, text, text, text, text, uuid) to authenticated;
grant execute on function public.set_learner_resource_objectives(uuid, text[]) to authenticated;
grant execute on function public.set_learner_resource_objective_studied(uuid, text, boolean) to authenticated;
grant execute on function public.delete_learner_external_resource(uuid) to authenticated;
