-- =============================================================================
-- Migration 63: ECO-04 Educator Profiles, Subject Associations & Verification Claims
--
-- Implements Phase 2 (W2) Educator Architecture Foundation:
-- 1. Introduces public.educator_profiles for lightweight contributor identities.
-- 2. Introduces public.educator_subjects for subject affiliation without course ownership.
-- 3. Introduces public.educator_verifications separating self-declared claims from
--    platform-vetted and licensed regulatory credentials.
-- 4. Introduces public.educator_follows for bookmarking and following educators.
-- 5. Implements Gate 2 private launch gate (educator_profiles_public_enabled = false).
-- 6. Enforces least-privilege RLS policies separating anon from authenticated evaluation.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Phase 2 Gate 2 Launch Configuration
-- -----------------------------------------------------------------------------
insert into public.community_config (key, value, description)
values (
  'educator_profiles_public_enabled',
  'false',
  'Gate 2 launch gate: when false, educator profiles are private to owners and moderators'
)
on conflict (key) do nothing;

create or replace function private.is_educator_profiles_public_enabled()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select value::boolean from public.community_config where key = 'educator_profiles_public_enabled'),
    false
  );
$$;

revoke all on function private.is_educator_profiles_public_enabled() from public;
grant execute on function private.is_educator_profiles_public_enabled() to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 2. Educator Profiles Table
-- -----------------------------------------------------------------------------
create table if not exists public.educator_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) between 2 and 100),
  headline text check (headline is null or length(trim(headline)) between 2 and 150),
  bio text check (bio is null or length(trim(bio)) <= 2000),
  avatar_url text check (avatar_url is null or length(trim(avatar_url)) <= 1000),
  languages text[] not null default array['en']::text[],
  is_accepting_questions boolean not null default true,
  status text not null default 'draft' check (status in ('draft', 'active', 'paused', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.educator_profiles enable row level security;

-- Updated_at trigger for educator_profiles
create or replace function private.handle_educator_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_educator_profiles_updated_at on public.educator_profiles;
create trigger trg_educator_profiles_updated_at
  before update on public.educator_profiles
  for each row
  execute function private.handle_educator_profile_updated_at();

-- Trusted tracking table for active educator profile deletions:
-- Stored in private schema with privileges revoked from public, anon, authenticated, and service_role.
-- Derived strictly from trusted database trigger execution context.
create table if not exists private.active_profile_deletions (
  profile_id uuid primary key
);

revoke all on table private.active_profile_deletions from public, anon, authenticated, service_role;

-- Profile deletion cascade tracking triggers:
-- Records profile ID in trusted private.active_profile_deletions table during delete so that
-- cascading foreign key deletes on educator_verifications know they are part of a verified profile deletion.
create or replace function private.handle_educator_profile_before_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.active_profile_deletions (profile_id)
  values (old.id)
  on conflict (profile_id) do nothing;
  return old;
end;
$$;

create or replace function private.handle_educator_profile_after_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.active_profile_deletions
   where profile_id = old.id;
  return old;
end;
$$;

drop trigger if exists trg_educator_profile_before_delete on public.educator_profiles;
create trigger trg_educator_profile_before_delete
  before delete on public.educator_profiles
  for each row
  execute function private.handle_educator_profile_before_delete();

drop trigger if exists trg_educator_profile_after_delete on public.educator_profiles;
create trigger trg_educator_profile_after_delete
  after delete on public.educator_profiles
  for each row
  execute function private.handle_educator_profile_after_delete();

revoke all on function private.handle_educator_profile_before_delete() from public, anon;
grant execute on function private.handle_educator_profile_before_delete() to authenticated, service_role;

revoke all on function private.handle_educator_profile_after_delete() from public, anon;
grant execute on function private.handle_educator_profile_after_delete() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Educator Subjects Association Table (Teacher doesn't own the subject)
-- -----------------------------------------------------------------------------
create table if not exists public.educator_subjects (
  id uuid primary key default gen_random_uuid(),
  educator_id uuid not null references public.educator_profiles(id) on delete cascade,
  subject_id text not null check (length(trim(subject_id)) > 0),
  subject_name text not null check (length(trim(subject_name)) > 0),
  experience_summary text check (experience_summary is null or length(trim(experience_summary)) <= 1000),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  unique (educator_id, subject_id)
);

alter table public.educator_subjects enable row level security;

create index if not exists idx_educator_subjects_subject_id
  on public.educator_subjects (subject_id);

-- -----------------------------------------------------------------------------
-- 4. Educator Verifications Table (Claims vs. Platform-Vetted vs. Regulated)
-- -----------------------------------------------------------------------------
create table if not exists public.educator_verifications (
  id uuid primary key default gen_random_uuid(),
  educator_id uuid not null references public.educator_profiles(id) on delete cascade,
  verification_type text not null check (verification_type in ('self_declared', 'platform_vetted', 'licensed_credential')),
  subject_id text check (subject_id is null or length(trim(subject_id)) > 0),
  jurisdiction text check (jurisdiction is null or length(trim(jurisdiction)) <= 50),
  issuer text check (issuer is null or length(trim(issuer)) <= 200),
  credential_reference text check (credential_reference is null or length(trim(credential_reference)) <= 200),
  status text not null default 'unverified' check (status in ('unverified', 'pending', 'verified', 'rejected', 'expired', 'revoked')),
  verified_at timestamptz,
  verified_by uuid,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.educator_verifications enable row level security;

create index if not exists idx_educator_verifications_educator
  on public.educator_verifications (educator_id, status);

-- -----------------------------------------------------------------------------
-- 4.1 Educator Verification Decision Audits (Immutable Governance Log)
-- Preserved independently of claim lifecycle (no cascading deletions)
-- -----------------------------------------------------------------------------
create table if not exists public.educator_verification_audits (
  id uuid primary key default gen_random_uuid(),
  verification_id uuid not null,
  educator_id uuid not null,
  reviewer_id uuid,
  action text not null check (action in (
    'unverified', 'pending', 'verified', 'rejected', 'expired', 'revoked',
    'submit', 'resubmit', 'verify', 'reject', 'expire', 'revoke', 'unverify',
    'status_transition', 'deleted', 'delete'
  )),
  previous_status text not null,
  new_status text not null,
  notes text,
  internal_notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.educator_verification_audits enable row level security;

create index if not exists idx_educator_verification_audits_verification
  on public.educator_verification_audits (verification_id);

create index if not exists idx_educator_verification_audits_educator
  on public.educator_verification_audits (educator_id);

create index if not exists idx_educator_verification_audits_reviewer
  on public.educator_verification_audits (reviewer_id);

drop policy if exists educator_verification_audits_select on public.educator_verification_audits;
create policy educator_verification_audits_select on public.educator_verification_audits
  for select
  to authenticated
  using (
    private.is_moderator()
  );

-- Strict append-only table privileges:
-- Revoke all modification privileges from anon, authenticated, and service_role.
-- Direct updates, deletions, and truncations are strictly forbidden at the engine level.
revoke all on table public.educator_verification_audits from public, anon;
revoke all on table public.educator_verification_audits from authenticated;
grant select on table public.educator_verification_audits to authenticated;
revoke all on table public.educator_verification_audits from service_role;
grant select on table public.educator_verification_audits to service_role;

-- Dedicated trigger function to strictly reject any UPDATE, DELETE, or TRUNCATE on educator_verification_audits
create or replace function private.guard_educator_verification_audits_append_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'Access denied: educator_verification_audits is strictly append-only'
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_guard_educator_verification_audits on public.educator_verification_audits;
create trigger trg_guard_educator_verification_audits
  before update or delete on public.educator_verification_audits
  for each row
  execute function private.guard_educator_verification_audits_append_only();

drop trigger if exists trg_guard_educator_verification_audits_truncate on public.educator_verification_audits;
create trigger trg_guard_educator_verification_audits_truncate
  before truncate on public.educator_verification_audits
  for each statement
  execute function private.guard_educator_verification_audits_append_only();

revoke all on function private.guard_educator_verification_audits_append_only() from public, anon;
grant execute on function private.guard_educator_verification_audits_append_only() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4.2 Public Verified Credentials View (Column-Shielded for Gate 2)
-- Shields internal moderation attribution (verified_by) and unredacted references (credential_reference).
-- Anonymous and third-party learners query this view rather than the raw base table.
-- -----------------------------------------------------------------------------
create or replace view public.public_educator_verifications with (security_invoker = false) as
select
  id,
  educator_id,
  verification_type,
  subject_id,
  jurisdiction,
  issuer,
  status,
  verified_at,
  expires_at,
  created_at
from public.educator_verifications
where private.is_educator_profiles_public_enabled()
  and status = 'verified'
  and (expires_at is null or expires_at > now())
  and exists (
    select 1 from public.educator_profiles ep
    where ep.id = educator_verifications.educator_id
      and ep.status = 'active'
  );

revoke all on public.public_educator_verifications from public;
grant select on public.public_educator_verifications to anon, authenticated, service_role;

-- Trigger to protect verified status tampering: only moderators can mark status='verified'
-- and verified credentials are fully IMMUTABLE to non-moderators
create or replace function private.guard_educator_verification_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jwt_sub text;
  v_is_moderator boolean;
  v_is_service_role boolean;
  v_is_admin_dba boolean;
  v_is_profile_cascade boolean;
  v_actor_id uuid;
  v_reviewer_id uuid;
  v_should_audit boolean := false;
  v_audit_action text;
  v_prev_status text;
begin
  v_jwt_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  v_is_moderator := private.is_moderator();
  -- Service-role trust boundary:
  -- In Supabase, ordinary client requests route through PostgREST via the authenticator connection role.
  -- PostgREST cryptographically verifies JWT signatures before executing SET LOCAL ROLE (anon, authenticated, service_role).
  -- This check evaluates the PostgreSQL engine session role rather than caller-mutable JWT claim GUCs
  -- (e.g. request.jwt.claim.role), ensuring REST callers cannot forge service-role exemptions via HTTP headers.
  -- (Note: PostgREST's JWT validation is the system boundary; direct arbitrary SQL execution by untrusted clients is out of scope).
  v_is_service_role := (coalesce(nullif(current_setting('role', true), 'none'), session_user) = 'service_role');
  v_is_admin_dba := (session_user = 'postgres' and coalesce(nullif(current_setting('role', true), 'none'), 'postgres') = 'postgres');
  -- Trusted cascade detection: requires nesting depth > 1 and parent profile deletion registered in trusted private table
  v_is_profile_cascade := (
    tg_op = 'DELETE' and
    pg_trigger_depth() > 1 and
    exists (
      select 1 from private.active_profile_deletions
      where profile_id = old.educator_id
    )
  );
  v_actor_id := auth.uid();
  if v_actor_id is null and v_jwt_sub is not null then
    begin
      v_actor_id := v_jwt_sub::uuid;
    exception when others then
      v_actor_id := null;
    end;
  end if;

  -- If non-moderator (or ordinary authenticated user) is modifying:
  if (v_jwt_sub is not null or coalesce(auth.jwt()->>'role', '') = 'authenticated' or coalesce(auth.role(), '') = 'authenticated') and
     not v_is_moderator and
     not v_is_service_role and
     not v_is_admin_dba then

    -- 1. If old status is 'verified', ALL trust-bearing fields are completely IMMUTABLE to non-moderators
    if tg_op = 'UPDATE' and old.status = 'verified' then
      if (new.verification_type is distinct from old.verification_type or
          new.subject_id is distinct from old.subject_id or
          new.jurisdiction is distinct from old.jurisdiction or
          new.issuer is distinct from old.issuer or
          new.credential_reference is distinct from old.credential_reference or
          new.status is distinct from old.status or
          new.verified_at is distinct from old.verified_at or
          new.verified_by is distinct from old.verified_by or
          new.expires_at is distinct from old.expires_at) then
        raise exception 'Access denied: verified credentials are immutable to non-moderators'
          using errcode = '42501';
      end if;
    end if;

    -- 2. Non-moderators can only set status to 'unverified' or 'pending'
    if tg_op in ('INSERT', 'UPDATE') then
      if new.status not in ('unverified', 'pending') and
         (old is null or old.status is distinct from new.status) then
        raise exception 'Access denied: only moderators can make moderation decisions (verified, rejected, expired, revoked)'
          using errcode = '42501';
      end if;

      -- Non-moderators can never set or alter verified_at / verified_by
      if (old is null and (new.verified_at is not null or new.verified_by is not null)) or
         (old is not null and (new.verified_at is distinct from old.verified_at or new.verified_by is distinct from old.verified_by)) then
        raise exception 'Access denied: only moderators can verify credentials'
          using errcode = '42501';
      end if;
    end if;

    -- 3. Non-moderators can never transition out of 'rejected' or 'revoked' back into verified or decision states
    if tg_op = 'UPDATE' and old.status in ('rejected', 'revoked') and new.status not in ('unverified', 'pending') then
      raise exception 'Access denied: cannot alter rejected or revoked credentials without re-submission'
        using errcode = '42501';
    end if;

    -- 4. Non-moderators can never reassign educator_id
    if tg_op = 'UPDATE' and new.educator_id is distinct from old.educator_id then
      raise exception 'Access denied: cannot reassign credential ownership'
        using errcode = '42501';
    end if;

    -- 5. Non-moderators can never delete verified, rejected, or revoked credentials directly,
    -- UNLESS the deletion is cascading from an authorized deletion of their own educator profile.
    if tg_op = 'DELETE' and old.status in ('verified', 'rejected', 'revoked') then
      if not v_is_profile_cascade then
        raise exception 'Access denied: verified, rejected, or revoked credentials cannot be deleted by non-moderators'
          using errcode = '42501';
      end if;
    end if;
  end if;

  -- ---------------------------------------------------------------------------
  -- Deletion Audit Tombstone:
  -- Any authorized deletion of a credential (by owner, moderator, or system cascade)
  -- records an immutable tombstone audit event capturing the actor and previous status.
  -- ---------------------------------------------------------------------------
  if tg_op = 'DELETE' then
    if v_is_service_role or v_is_admin_dba then
      v_reviewer_id := null;
    elsif v_is_moderator and (v_actor_id is distinct from old.educator_id) then
      v_reviewer_id := v_actor_id;
    else
      v_reviewer_id := null;
    end if;

    insert into public.educator_verification_audits (
      verification_id,
      educator_id,
      reviewer_id,
      action,
      previous_status,
      new_status,
      notes,
      internal_notes,
      metadata
    ) values (
      old.id,
      old.educator_id,
      v_reviewer_id,
      'deleted',
      old.status,
      'deleted',
      nullif(current_setting('educator_verifications.audit_notes', true), ''),
      nullif(current_setting('educator_verifications.audit_internal_notes', true), ''),
      jsonb_strip_nulls(jsonb_build_object(
        'deleted_at', now(),
        'deleted_by', v_actor_id,
        'deleted_by_role', case
          when v_is_service_role then 'service_role'
          when v_is_admin_dba then 'administrator'
          when v_is_moderator and (v_actor_id is distinct from old.educator_id) then 'moderator'
          when v_is_profile_cascade or (v_actor_id is not null and v_actor_id = old.educator_id) then 'owner'
          when v_is_moderator then 'moderator'
          else coalesce(nullif(nullif(session_user, 'postgres'), ''), 'system')
        end,
        'cascade_from_profile', v_is_profile_cascade,
        'previous_status', old.status,
        'verification_type', old.verification_type,
        'issuer', old.issuer,
        'subject_id', old.subject_id,
        'original_verified_by', old.verified_by,
        'original_verified_at', old.verified_at,
        'original_expires_at', old.expires_at
      ))
    );

    return old;
  end if;

  -- ---------------------------------------------------------------------------
  -- Moderator Invariant & Provenance Enforcement:
  -- When a credential is in 'verified' status (via direct INSERT, direct UPDATE, or RPC):
  -- 1. verified_at must be populated (auto-populates to now() if omitted).
  -- 2. verified_by must match the authenticated moderator actor (anti-forgery).
  -- ---------------------------------------------------------------------------
  if new.status = 'verified' then
    -- Auto-populate verified_at if omitted
    if new.verified_at is null then
      new.verified_at := now();
    end if;

    -- Auto-populate verified_by if omitted
    if new.verified_by is null and v_actor_id is not null then
      new.verified_by := v_actor_id;
    end if;

    -- Anti-forgery guard: caller cannot specify a different moderator as verified_by
    if v_actor_id is not null and
       not v_is_service_role and
       not v_is_admin_dba and
       new.verified_by is distinct from v_actor_id and
       (tg_op = 'INSERT' or old.status <> 'verified' or new.verified_by is distinct from old.verified_by) then
      raise exception 'Access denied: verified_by must match the authenticated moderator'
        using errcode = '42501';
    end if;

    -- Must have non-null verification timestamp and verifier
    if new.verified_at is null or new.verified_by is null then
      raise exception 'Invalid verification state: verified credentials require verified_at and verified_by'
        using errcode = '22023';
    end if;
  else
    -- If transitioning to any non-verified status, clear verified_at and verified_by
    new.verified_at := null;
    new.verified_by := null;
  end if;

  -- ---------------------------------------------------------------------------
  -- Audit Decision Determination:
  -- Evaluates if an audit record must be generated.
  -- Covers:
  --   a) Any status transition (UPDATE where status changed).
  --   b) Direct INSERT in decision state ('verified', 'rejected', 'expired', 'revoked').
  --   c) Material re-verification / review update where status remains 'verified'
  --      (verified_at changed, verified_by changed, expires_at changed, or review notes provided).
  -- ---------------------------------------------------------------------------
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_should_audit := true;
    v_audit_action := new.status;
    v_prev_status := old.status;
  elsif tg_op = 'INSERT' and new.status in ('verified', 'rejected', 'expired', 'revoked') then
    v_should_audit := true;
    v_audit_action := new.status;
    v_prev_status := 'unverified';
  elsif tg_op = 'UPDATE' and new.status = 'verified' and old.status = 'verified' and (
    new.verified_at is distinct from old.verified_at or
    new.verified_by is distinct from old.verified_by or
    new.expires_at is distinct from old.expires_at or
    nullif(current_setting('educator_verifications.audit_notes', true), '') is not null or
    nullif(current_setting('educator_verifications.audit_internal_notes', true), '') is not null
  ) then
    v_should_audit := true;
    v_audit_action := 'verify';
    v_prev_status := old.status;
  end if;

  if v_should_audit then
    if v_is_service_role or v_is_admin_dba then
      v_reviewer_id := null;
    elsif v_is_moderator then
      v_reviewer_id := v_actor_id;
    else
      v_reviewer_id := coalesce(v_actor_id, new.verified_by, case when tg_op = 'UPDATE' then old.verified_by else null end);
    end if;

    insert into public.educator_verification_audits (
      verification_id,
      educator_id,
      reviewer_id,
      action,
      previous_status,
      new_status,
      notes,
      internal_notes,
      metadata
    ) values (
      new.id,
      new.educator_id,
      v_reviewer_id,
      v_audit_action,
      v_prev_status,
      new.status,
      nullif(current_setting('educator_verifications.audit_notes', true), ''),
      nullif(current_setting('educator_verifications.audit_internal_notes', true), ''),
      case
        when new.expires_at is not null or
             (tg_op = 'UPDATE' and old.expires_at is not null) or
             (tg_op = 'UPDATE' and old.verified_by is not null) then
          jsonb_strip_nulls(jsonb_build_object(
            'expires_at', new.expires_at,
            'original_expires_at', case when tg_op = 'UPDATE' then old.expires_at else null end,
            'original_verified_by', case when tg_op = 'UPDATE' then old.verified_by else null end,
            'original_verified_at', case when tg_op = 'UPDATE' then old.verified_at else null end
          ))
        else '{}'::jsonb
      end
    );
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_guard_educator_verification on public.educator_verifications;
create trigger trg_guard_educator_verification
  before insert or update or delete on public.educator_verifications
  for each row
  execute function private.guard_educator_verification_status();

revoke all on function private.guard_educator_verification_status() from public, anon;
grant execute on function private.guard_educator_verification_status() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. Educator Follows Table
-- -----------------------------------------------------------------------------
create table if not exists public.educator_follows (
  id uuid primary key default gen_random_uuid(),
  follower_id uuid not null references auth.users(id) on delete cascade,
  educator_id uuid not null references public.educator_profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, educator_id),
  check (follower_id <> educator_id)
);

alter table public.educator_follows enable row level security;

create index if not exists idx_educator_follows_educator
  on public.educator_follows (educator_id);

-- -----------------------------------------------------------------------------
-- 6. Row-Level Security Policies (Separated Public / Authenticated Evaluation)
-- -----------------------------------------------------------------------------

-- 6.1 educator_profiles
drop policy if exists educator_profiles_select on public.educator_profiles;
drop policy if exists educator_profiles_public_select on public.educator_profiles;
drop policy if exists educator_profiles_auth_select on public.educator_profiles;
drop policy if exists educator_profiles_insert on public.educator_profiles;
drop policy if exists educator_profiles_update on public.educator_profiles;
drop policy if exists educator_profiles_delete on public.educator_profiles;

-- Public read: evaluates only when Gate 2 is open, avoiding is_moderator() calls for anon
create policy educator_profiles_public_select on public.educator_profiles
  for select
  to anon, authenticated, service_role
  using (
    private.is_educator_profiles_public_enabled()
    and status = 'active'
  );

-- Authenticated read: owner access to own profile (draft/active) and moderator supervision
create policy educator_profiles_auth_select on public.educator_profiles
  for select
  to authenticated
  using (
    id = auth.uid()
    or private.is_moderator()
  );

create policy educator_profiles_insert on public.educator_profiles
  for insert
  to authenticated
  with check (
    id = auth.uid()
  );

create policy educator_profiles_update on public.educator_profiles
  for update
  to authenticated
  using (
    id = auth.uid()
    or private.is_moderator()
  )
  with check (
    id = auth.uid()
    or private.is_moderator()
  );

create policy educator_profiles_delete on public.educator_profiles
  for delete
  to authenticated
  using (
    id = auth.uid()
    or private.is_moderator()
  );

-- 6.2 educator_subjects
drop policy if exists educator_subjects_select on public.educator_subjects;
drop policy if exists educator_subjects_public_select on public.educator_subjects;
drop policy if exists educator_subjects_auth_select on public.educator_subjects;
drop policy if exists educator_subjects_insert on public.educator_subjects;
drop policy if exists educator_subjects_update on public.educator_subjects;
drop policy if exists educator_subjects_delete on public.educator_subjects;

create policy educator_subjects_public_select on public.educator_subjects
  for select
  to anon, authenticated, service_role
  using (
    private.is_educator_profiles_public_enabled()
    and status = 'active'
    and exists (
      select 1 from public.educator_profiles ep
      where ep.id = educator_subjects.educator_id
        and ep.status = 'active'
    )
  );

create policy educator_subjects_auth_select on public.educator_subjects
  for select
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_subjects_insert on public.educator_subjects
  for insert
  to authenticated
  with check (
    educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_subjects_update on public.educator_subjects
  for update
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  )
  with check (
    educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_subjects_delete on public.educator_subjects
  for delete
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  );

-- 6.3 educator_verifications
-- Direct table SELECT access is strictly restricted to the credential owner and moderators.
-- Public reads of verified credentials are routed exclusively through public.public_educator_verifications
-- to prevent column leakage of verified_by or unredacted credential_reference.
drop policy if exists educator_verifications_select on public.educator_verifications;
drop policy if exists educator_verifications_public_select on public.educator_verifications;
drop policy if exists educator_verifications_auth_select on public.educator_verifications;
drop policy if exists educator_verifications_insert on public.educator_verifications;
drop policy if exists educator_verifications_update on public.educator_verifications;
drop policy if exists educator_verifications_delete on public.educator_verifications;

create policy educator_verifications_auth_select on public.educator_verifications
  for select
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_verifications_insert on public.educator_verifications
  for insert
  to authenticated
  with check (
    (educator_id = auth.uid() and status in ('unverified', 'pending'))
    or private.is_moderator()
  );

create policy educator_verifications_update on public.educator_verifications
  for update
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  )
  with check (
    educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_verifications_delete on public.educator_verifications
  for delete
  to authenticated
  using (
    educator_id = auth.uid()
    or private.is_moderator()
  );

-- 6.4 educator_follows
drop policy if exists educator_follows_select on public.educator_follows;
drop policy if exists educator_follows_insert on public.educator_follows;
drop policy if exists educator_follows_delete on public.educator_follows;

create policy educator_follows_select on public.educator_follows
  for select
  to authenticated
  using (
    (
      follower_id = auth.uid()
      or educator_id = auth.uid()
      or private.is_moderator()
    )
    and (
      private.is_moderator()
      or educator_id = auth.uid()
      or private.is_educator_profiles_public_enabled()
    )
  );

create policy educator_follows_insert on public.educator_follows
  for insert
  to authenticated
  with check (
    follower_id = auth.uid()
    and (
      private.is_moderator()
      or (
        private.is_educator_profiles_public_enabled()
        and exists (
          select 1 from public.educator_profiles ep
          where ep.id = educator_follows.educator_id
            and ep.status = 'active'
        )
      )
    )
  );

create policy educator_follows_delete on public.educator_follows
  for delete
  to authenticated
  using (
    follower_id = auth.uid()
    or private.is_moderator()
  );

-- -----------------------------------------------------------------------------
-- 7. High-Performance RPCs
-- -----------------------------------------------------------------------------

-- Upsert current user's educator profile
create or replace function public.upsert_my_educator_profile(
  p_display_name text,
  p_headline text default null,
  p_bio text default null,
  p_avatar_url text default null,
  p_languages text[] default array['en']::text[],
  p_is_accepting_questions boolean default true,
  p_status text default 'draft'
)
returns public.educator_profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_profile public.educator_profiles;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_status not in ('draft', 'active', 'paused', 'archived') then
    raise exception 'Invalid educator profile status: %', p_status using errcode = '22023';
  end if;

  insert into public.educator_profiles (
    id, display_name, headline, bio, avatar_url, languages, is_accepting_questions, status, updated_at
  ) values (
    v_user_id,
    trim(p_display_name),
    nullif(trim(p_headline), ''),
    nullif(trim(p_bio), ''),
    nullif(trim(p_avatar_url), ''),
    coalesce(p_languages, array['en']::text[]),
    coalesce(p_is_accepting_questions, true),
    coalesce(p_status, 'draft'),
    now()
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    headline = excluded.headline,
    bio = excluded.bio,
    avatar_url = excluded.avatar_url,
    languages = excluded.languages,
    is_accepting_questions = excluded.is_accepting_questions,
    status = excluded.status,
    updated_at = now()
  returning * into v_profile;

  return v_profile;
end;
$$;

revoke all on function public.upsert_my_educator_profile(text, text, text, text, text[], boolean, text) from public, anon;
grant execute on function public.upsert_my_educator_profile(text, text, text, text, text[], boolean, text) to authenticated, service_role;

-- Moderator verification RPC
drop function if exists public.verify_educator_credential(uuid, text, timestamptz);
drop function if exists public.verify_educator_credential(uuid, text, timestamptz, text);
drop function if exists public.verify_educator_credential(uuid, text, timestamptz, text, text);

create or replace function public.verify_educator_credential(
  p_verification_id uuid,
  p_status text,
  p_expires_at timestamptz default null,
  p_notes text default null,
  p_internal_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_final_expires_at timestamptz;
  v_final_verified_at timestamptz;
  v_final_verified_by uuid;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null or not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges'
      using errcode = '42501';
  end if;

  if p_status not in ('verified', 'rejected', 'revoked', 'expired') then
    raise exception 'Invalid verification decision: %', p_status
      using errcode = '22023';
  end if;

  perform 1
     from public.educator_verifications
    where id = p_verification_id
      for update;

  if not found then
    raise exception 'Verification record % not found', p_verification_id
      using errcode = 'P0002';
  end if;

  -- Set session configuration for trigger to pick up notes & internal_notes
  perform set_config('educator_verifications.audit_notes', coalesce(p_notes, ''), true);
  perform set_config('educator_verifications.audit_internal_notes', coalesce(p_internal_notes, ''), true);

  update public.educator_verifications
     set status = p_status,
         verified_at = case when p_status = 'verified' then now() else null end,
         verified_by = case when p_status = 'verified' then v_caller_id else null end,
         expires_at = case
           when p_expires_at is not null then p_expires_at
           else educator_verifications.expires_at
         end,
         updated_at = now()
   where id = p_verification_id
  returning verified_at, verified_by, expires_at
     into v_final_verified_at, v_final_verified_by, v_final_expires_at;

  return jsonb_build_object(
    'success', true,
    'verification_id', p_verification_id,
    'status', p_status,
    'verified_at', v_final_verified_at,
    'verified_by', v_final_verified_by,
    'expires_at', v_final_expires_at,
    'reviewer_id', v_caller_id,
    'notes', p_notes,
    'internal_notes', p_internal_notes
  );
end;
$$;

revoke all on function public.verify_educator_credential(uuid, text, timestamptz, text, text) from public, anon;
grant execute on function public.verify_educator_credential(uuid, text, timestamptz, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 7. Educator Feedback Query RPC (Separates Author Feedback from Internal Staff Notes)
-- -----------------------------------------------------------------------------
create or replace function public.fetch_my_credential_feedback(
  p_verification_id uuid default null
)
returns table (
  id uuid,
  verification_id uuid,
  action text,
  new_status text,
  feedback text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  return query
  select a.id,
         a.verification_id,
         a.action,
         a.new_status,
         a.notes as feedback,
         a.created_at
    from public.educator_verification_audits a
   where a.educator_id = v_caller_id
     and (p_verification_id is null or a.verification_id = p_verification_id)
   order by a.created_at desc;
end;
$$;

revoke all on function public.fetch_my_credential_feedback(uuid) from public, anon;
grant execute on function public.fetch_my_credential_feedback(uuid) to authenticated, service_role;

