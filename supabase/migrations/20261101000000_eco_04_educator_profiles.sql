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
    'status_transition'
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
  v_actor_id uuid;
  v_reviewer_id uuid;
begin
  v_jwt_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  v_is_moderator := private.is_moderator();
  v_actor_id := auth.uid();

  -- If non-moderator (or ordinary authenticated user) is modifying:
  if (v_jwt_sub is not null or coalesce(auth.jwt()->>'role', '') = 'authenticated') and
     not v_is_moderator and
     coalesce(auth.jwt()->>'role', '') <> 'service_role' then

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

    -- 2. Non-moderators can only set status to 'unverified' or 'pending', and can never set verified_at / verified_by
    if (new.status not in ('unverified', 'pending') or new.verified_at is not null or new.verified_by is not null) and
       (old is null or old.status is distinct from new.status or old.verified_at is distinct from new.verified_at or old.verified_by is distinct from new.verified_by) then
      raise exception 'Access denied: only moderators can make moderation decisions (verified, rejected, expired, revoked)'
        using errcode = '42501';
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

    -- 5. Non-moderators can never delete verified, rejected, or revoked credentials
    if tg_op = 'DELETE' and old.status in ('verified', 'rejected', 'revoked') then
      raise exception 'Access denied: verified, rejected, or revoked credentials cannot be deleted by non-moderators'
        using errcode = '42501';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  -- 6. Trigger-enforced audit recording on any status change:
  -- Guarantees that EVERY authorized status transition (whether executed through RPC
  -- or direct moderator/user UPDATE) writes an immutable audit record.
  -- Attribution: The authenticated actor (v_actor_id = auth.uid()) performing the transition
  -- is recorded as reviewer_id. If a previous verifier exists (e.g. on revocation),
  -- the original verifier and verified timestamp are preserved in audit metadata.
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_reviewer_id := coalesce(v_actor_id, new.verified_by);

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
      new.status,
      old.status,
      new.status,
      nullif(current_setting('educator_verifications.audit_notes', true), ''),
      nullif(current_setting('educator_verifications.audit_internal_notes', true), ''),
      case
        when new.expires_at is not null or old.verified_by is not null then
          jsonb_strip_nulls(jsonb_build_object(
            'expires_at', new.expires_at,
            'original_verified_by', old.verified_by,
            'original_verified_at', old.verified_at
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
drop policy if exists educator_verifications_select on public.educator_verifications;
drop policy if exists educator_verifications_public_select on public.educator_verifications;
drop policy if exists educator_verifications_auth_select on public.educator_verifications;
drop policy if exists educator_verifications_insert on public.educator_verifications;
drop policy if exists educator_verifications_update on public.educator_verifications;
drop policy if exists educator_verifications_delete on public.educator_verifications;

create policy educator_verifications_public_select on public.educator_verifications
  for select
  to anon, authenticated, service_role
  using (
    private.is_educator_profiles_public_enabled()
    and status = 'verified'
    and exists (
      select 1 from public.educator_profiles ep
      where ep.id = educator_verifications.educator_id
        and ep.status = 'active'
    )
  );

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
    follower_id = auth.uid()
    or educator_id = auth.uid()
    or private.is_moderator()
  );

create policy educator_follows_insert on public.educator_follows
  for insert
  to authenticated
  with check (
    follower_id = auth.uid()
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
         expires_at = p_expires_at,
         updated_at = now()
   where id = p_verification_id;

  return jsonb_build_object(
    'success', true,
    'verification_id', p_verification_id,
    'status', p_status,
    'verified_at', case when p_status = 'verified' then now() else null end,
    'verified_by', case when p_status = 'verified' then v_caller_id else null end,
    'expires_at', p_expires_at,
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

