-- ECO-00B: Trust, Safety, Legal & Moderation Architecture Foundation
-- Migration Version: 20261017000000

-- -----------------------------------------------------------------------------
-- 1. Private Schema & Zero-Argument Authorization Helpers
-- -----------------------------------------------------------------------------

create schema if not exists private;
grant usage on schema private to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Moderation Roles Table (Decoupled Platform-Wide Authority)
-- -----------------------------------------------------------------------------

create table if not exists public.moderation_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  role text not null check (role in ('moderator', 'admin')),
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.moderation_roles enable row level security;

-- -----------------------------------------------------------------------------
-- 3. Authorization Functions (Zero-Argument Caller Checks)
-- -----------------------------------------------------------------------------

create or replace function private.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.moderation_roles
     where user_id = auth.uid()
       and role in ('moderator', 'admin')
  );
$$;

revoke all on function private.is_moderator() from public, anon;
grant execute on function private.is_moderator() to authenticated, service_role;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.moderation_roles
     where user_id = auth.uid()
       and role = 'admin'
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated, service_role;

-- Public zero-argument RPC wrappers for authenticated client calls
create or replace function public.is_moderator()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_moderator();
$$;

revoke all on function public.is_moderator() from public, anon;
grant execute on function public.is_moderator() to authenticated, service_role;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin();
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;

-- RLS on moderation_roles
create policy moderation_roles_select_policy on public.moderation_roles
  for select
  to authenticated
  using (private.is_moderator());

create policy moderation_roles_insert_policy on public.moderation_roles
  for insert
  to authenticated
  with check (private.is_admin());

create policy moderation_roles_update_policy on public.moderation_roles
  for update
  to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy moderation_roles_delete_policy on public.moderation_roles
  for delete
  to authenticated
  using (private.is_admin());

-- -----------------------------------------------------------------------------
-- 4. Moderation Reports Table
-- -----------------------------------------------------------------------------

create table if not exists public.moderation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check (target_type in ('course', 'lesson', 'study_set', 'word_list', 'curriculum', 'resource', 'question', 'profile')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'harassment', 'misinformation', 'copyright', 'minor_safety', 'inappropriate', 'other')),
  description text,
  status text not null default 'pending' check (status in ('pending', 'under_review', 'actioned', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.moderation_reports enable row level security;

create index if not exists idx_moderation_reports_status_created
  on public.moderation_reports(status, created_at desc);

-- Partial unique index prevents duplicate pending/under_review reports on the same target by the same reporter
create unique index if not exists idx_moderation_reports_dedup
  on public.moderation_reports (reporter_id, target_type, target_id)
  where status in ('pending', 'under_review');

-- RLS on moderation_reports
-- Direct client inserts, updates, and deletes are denied to enforce rate-limits, target checks, and atomic actions.
create policy moderation_reports_select_policy on public.moderation_reports
  for select
  to authenticated
  using (reporter_id = auth.uid() or private.is_moderator());

revoke all on table public.moderation_reports from public, anon;
revoke insert, update, delete on table public.moderation_reports from authenticated;
grant select on table public.moderation_reports to authenticated;

-- -----------------------------------------------------------------------------
-- 5. Moderation Actions Table (Immutable Audit Log, Nullable on Delete)
-- -----------------------------------------------------------------------------

create table if not exists public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.moderation_reports(id) on delete set null,
  moderator_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('dismiss', 'warn', 'hide', 'delete', 'suspend_user', 'rate_limit')),
  reason text not null,
  notes text,
  target_type text not null,
  target_id uuid not null,
  created_at timestamptz not null default now()
);

alter table public.moderation_actions enable row level security;

create index if not exists idx_moderation_actions_report
  on public.moderation_actions(report_id);

create index if not exists idx_moderation_actions_created
  on public.moderation_actions(created_at desc);

-- RLS on moderation_actions
-- Direct client inserts, updates, and deletes are denied to ensure actions are only logged via apply_moderation_action RPC.
create policy moderation_actions_select_policy on public.moderation_actions
  for select
  to authenticated
  using (private.is_moderator());

revoke all on table public.moderation_actions from public, anon;
revoke insert, update, delete on table public.moderation_actions from authenticated;
grant select on table public.moderation_actions to authenticated;

-- -----------------------------------------------------------------------------
-- 6. Transactional Atomic Moderation Workflow RPC
-- -----------------------------------------------------------------------------

create or replace function public.apply_moderation_action(
  p_report_id uuid,
  p_action text,
  p_reason text,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_report record;
  v_action_id uuid;
  v_new_status text;
begin
  if not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges' using errcode = '42501';
  end if;

  if p_action not in ('dismiss', 'warn', 'hide', 'delete', 'suspend_user', 'rate_limit') then
    raise exception 'Invalid moderation action: %', p_action using errcode = '22023';
  end if;

  if p_reason is null or trim(p_reason) = '' then
    raise exception 'Moderation action reason is mandatory' using errcode = '22023';
  end if;

  -- Lock report row FOR UPDATE to prevent race conditions from concurrent actions
  select * into v_report
    from public.moderation_reports
   where id = p_report_id
     for update;

  if not found then
    raise exception 'Report % not found', p_report_id using errcode = 'P0002';
  end if;

  -- Validate permitted status transitions: cannot re-resolve an already resolved report
  if v_report.status not in ('pending', 'under_review') then
    raise exception 'Report % has already been resolved with status %', p_report_id, v_report.status using errcode = '22000';
  end if;

  v_new_status := case when p_action = 'dismiss' then 'dismissed' else 'actioned' end;

  insert into public.moderation_actions (
    report_id, moderator_id, action, reason, notes, target_type, target_id
  ) values (
    p_report_id, auth.uid(), p_action, p_reason, p_notes, v_report.target_type, v_report.target_id
  ) returning id into v_action_id;

  update public.moderation_reports
     set status = v_new_status,
         updated_at = now()
   where id = p_report_id;

  return v_action_id;
end;
$$;

revoke all on function public.apply_moderation_action(uuid, text, text, text) from public, anon;
grant execute on function public.apply_moderation_action(uuid, text, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Moderation Report Submission RPC with Rate Limiting & Target Validation
-- -----------------------------------------------------------------------------

create or replace function public.submit_moderation_report(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_report_id uuid;
  v_recent_reports_count integer;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'Authentication required to submit moderation reports' using errcode = '42501';
  end if;

  if p_reason not in ('spam', 'harassment', 'misinformation', 'copyright', 'minor_safety', 'inappropriate', 'other') then
    raise exception 'Invalid report reason: %', p_reason using errcode = '22023';
  end if;

  -- Validate target type and verify actual target existence in database
  case p_target_type
    when 'course' then
      if not exists (select 1 from public.courses where id = p_target_id) then
        raise exception 'Target course % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'lesson' then
      if not exists (select 1 from public.lessons where id = p_target_id) then
        raise exception 'Target lesson % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'study_set' then
      if not exists (select 1 from public.study_sets where id = p_target_id) then
        raise exception 'Target study_set % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'word_list' then
      if not exists (select 1 from public.word_lists where id = p_target_id) then
        raise exception 'Target word_list % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'curriculum' then
      if not exists (select 1 from public.curriculum_nodes where id = p_target_id) then
        raise exception 'Target curriculum % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'resource' then
      if not exists (select 1 from public.user_curriculum_resources where id = p_target_id) then
        raise exception 'Target resource % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'question' then
      if not exists (select 1 from public.questions where id = p_target_id) then
        raise exception 'Target question % does not exist', p_target_id using errcode = 'P0002';
      end if;
    when 'profile' then
      if not exists (select 1 from auth.users where id = p_target_id) then
        raise exception 'Target user profile % does not exist', p_target_id using errcode = 'P0002';
      end if;
    else
      raise exception 'Invalid target_type: %', p_target_type using errcode = '22023';
  end case;

  -- Rate limit check: maximum 10 reports per hour per user
  select count(*)::integer into v_recent_reports_count
    from public.moderation_reports
   where reporter_id = v_caller_id
     and created_at > now() - interval '1 hour';

  if v_recent_reports_count >= 10 then
    raise exception 'Rate limit exceeded: too many moderation reports submitted. Please wait before submitting additional reports.' using errcode = 'P0004';
  end if;

  -- Deduplication check for active report on the same target
  if exists (
    select 1
      from public.moderation_reports
     where reporter_id = v_caller_id
       and target_type = p_target_type
       and target_id = p_target_id
       and status in ('pending', 'under_review')
  ) then
    raise exception 'Duplicate report: you already have an active report for this content.' using errcode = '23505';
  end if;

  insert into public.moderation_reports (
    reporter_id, target_type, target_id, reason, description, status
  ) values (
    v_caller_id, p_target_type, p_target_id, p_reason, p_description, 'pending'
  ) returning id into v_report_id;

  return v_report_id;
end;
$$;

revoke all on function public.submit_moderation_report(text, uuid, text, text) from public, anon;
grant execute on function public.submit_moderation_report(text, uuid, text, text) to authenticated, service_role;
