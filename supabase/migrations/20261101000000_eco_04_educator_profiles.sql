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
  status text not null default 'unverified' check (status in ('unverified', 'pending', 'verified', 'rejected', 'expired')),
  verified_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.educator_verifications enable row level security;

create index if not exists idx_educator_verifications_educator
  on public.educator_verifications (educator_id, status);

-- Trigger to protect verified status tampering: only moderators can mark status='verified'
create or replace function private.guard_educator_verification_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_jwt_sub text;
begin
  v_jwt_sub := nullif(current_setting('request.jwt.claim.sub', true), '');
  -- If updating status to verified or setting verified_at, must be moderator
  if (new.status = 'verified' or new.verified_at is not null) and
     (old.status is distinct from 'verified' or old.verified_at is distinct from new.verified_at) then
    if (v_jwt_sub is not null or coalesce(auth.jwt()->>'role', '') = 'authenticated') and
       not private.is_moderator() and
       coalesce(auth.jwt()->>'role', '') <> 'service_role' then
      raise exception 'Access denied: only moderators can verify credentials'
        using errcode = '42501';
    end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_guard_educator_verification on public.educator_verifications;
create trigger trg_guard_educator_verification
  before insert or update on public.educator_verifications
  for each row
  execute function private.guard_educator_verification_status();

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
create or replace function public.verify_educator_credential(
  p_verification_id uuid,
  p_status text,
  p_expires_at timestamptz default null
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

  if p_status not in ('verified', 'rejected', 'expired') then
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

  update public.educator_verifications
     set status = p_status,
         verified_at = case when p_status = 'verified' then now() else null end,
         expires_at = p_expires_at,
         updated_at = now()
   where id = p_verification_id;

  return jsonb_build_object(
    'success', true,
    'verification_id', p_verification_id,
    'status', p_status,
    'verified_at', case when p_status = 'verified' then now() else null end,
    'expires_at', p_expires_at
  );
end;
$$;

revoke all on function public.verify_educator_credential(uuid, text, timestamptz) from public, anon;
grant execute on function public.verify_educator_credential(uuid, text, timestamptz) to authenticated, service_role;
