-- PR-H slice 4 (master plan v2.6 §8.7, §15.0 `content.refresh_proposals`):
-- source-change and correction proposals for published community lessons.
--
-- * New gate `content.refresh_proposals`, default OFF, not release-ready.
-- * A signed-in reader proposes an update to a PUBLISHED community copy
--   (source changed, correction, outdated), optionally with an https source
--   link. A moderator accepts or declines with a note.
-- * NOT auto-publication: accepting changes nothing in the copy or the
--   lesson. The contributor sees accepted proposals and may edit and
--   resubmit, which goes through the normal check -> review -> publish
--   workflow and supersedes the old version.
-- * Append-only event log; no direct writes from browsers.
-- Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.refresh_proposals', 'Community update proposals', 'Content', 'release', false, 'experimental', false,
  'Reviewed change proposals for published community lessons; never auto-published')
ON CONFLICT (feature_key) DO NOTHING;

create table if not exists public.content_refresh_proposals (
  id uuid primary key default gen_random_uuid(),
  contribution_id uuid not null references public.content_contributions(id),
  proposer_id uuid references auth.users(id) on delete set null,
  kind text not null check (kind in ('source_changed', 'correction', 'outdated')),
  item_ref text check (item_ref is null or item_ref ~ '^(lesson|terms|concepts|questions)(\[[0-9]{1,4}\])?$'),
  description text not null check (char_length(btrim(description)) between 10 and 2000),
  source_url text check (source_url is null or (source_url ~ '^https://[^\s]+$' and char_length(source_url) <= 500)),
  status text not null default 'open' check (status in ('open', 'accepted', 'declined', 'withdrawn')),
  reviewer_id uuid references auth.users(id) on delete set null,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists content_refresh_proposals_contribution
  on public.content_refresh_proposals (contribution_id, created_at desc);
create index if not exists content_refresh_proposals_status
  on public.content_refresh_proposals (status, created_at desc);
create index if not exists content_refresh_proposals_proposer
  on public.content_refresh_proposals (proposer_id, created_at desc);

create table if not exists public.content_refresh_proposal_events (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.content_refresh_proposals(id),
  actor_id uuid references auth.users(id) on delete set null,
  from_status text,
  to_status text not null,
  note text check (note is null or char_length(note) <= 1000),
  created_at timestamptz not null default now()
);

alter table public.content_refresh_proposals enable row level security;
alter table public.content_refresh_proposal_events enable row level security;

-- Proposer, the contribution's contributor, or moderators may read.
create policy content_refresh_proposals_select on public.content_refresh_proposals
  for select to authenticated
  using (
    proposer_id = auth.uid()
    or private.is_moderator()
    or exists (
      select 1 from public.content_contributions c
       where c.id = contribution_id and c.contributor_id = auth.uid()
    )
  );

create policy content_refresh_proposal_events_select on public.content_refresh_proposal_events
  for select to authenticated
  using (private.is_moderator());

revoke all on table public.content_refresh_proposals from public, anon;
revoke all on table public.content_refresh_proposal_events from public, anon;
revoke insert, update, delete on table public.content_refresh_proposals from authenticated;
revoke insert, update, delete on table public.content_refresh_proposal_events from authenticated;
grant select on table public.content_refresh_proposals to authenticated;
grant select on table public.content_refresh_proposal_events to authenticated;

create or replace function private.refresh_proposal_apply(
  p_id uuid,
  p_to text,
  p_note text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_from text;
begin
  select status into v_from from public.content_refresh_proposals
   where id = p_id for update;
  if not found then
    raise exception 'proposal_not_found' using errcode = 'P0002';
  end if;
  if v_from <> 'open' then
    raise exception 'invalid_state_transition: % -> %', v_from, p_to
      using errcode = '22000';
  end if;
  update public.content_refresh_proposals
     set status = p_to, updated_at = now()
   where id = p_id;
  insert into public.content_refresh_proposal_events
    (proposal_id, actor_id, from_status, to_status, note)
  values (p_id, auth.uid(), v_from, p_to, nullif(btrim(coalesce(p_note, '')), ''));
  return p_to;
end;
$$;

revoke all on function private.refresh_proposal_apply(uuid, text, text)
  from public, anon, authenticated;

create or replace function public.propose_contribution_refresh(
  p_contribution_id uuid,
  p_kind text,
  p_description text,
  p_item_ref text default null,
  p_source_url text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_recent integer;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.refresh_proposals') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.content_contributions
     where id = p_contribution_id and status = 'published'
  ) then
    raise exception 'not_published' using errcode = 'P0002';
  end if;
  select count(*) into v_recent
    from public.content_refresh_proposals
   where proposer_id = v_uid and created_at > now() - interval '24 hours';
  if v_recent >= 5 then
    raise exception 'rate_limited' using errcode = '54000';
  end if;

  begin
    insert into public.content_refresh_proposals
      (contribution_id, proposer_id, kind, item_ref, description, source_url)
    values
      (p_contribution_id, v_uid, p_kind, nullif(btrim(coalesce(p_item_ref, '')), ''),
       btrim(coalesce(p_description, '')), nullif(btrim(coalesce(p_source_url, '')), ''))
    returning id into v_id;
  exception when check_violation then
    raise exception 'invalid_proposal' using errcode = '22023';
  end;

  insert into public.content_refresh_proposal_events
    (proposal_id, actor_id, from_status, to_status, note)
  values (v_id, v_uid, null, 'open', null);
  return v_id;
end;
$$;

revoke all on function public.propose_contribution_refresh(uuid, text, text, text, text)
  from public, anon;
grant execute on function public.propose_contribution_refresh(uuid, text, text, text, text)
  to authenticated;

-- Moderator decision. Never edits the copy or the lesson.
create or replace function public.decide_refresh_proposal(
  p_id uuid,
  p_accept boolean,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_proposer uuid;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.refresh_proposals') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select proposer_id into v_proposer from public.content_refresh_proposals where id = p_id;
  if not found then
    raise exception 'proposal_not_found' using errcode = 'P0002';
  end if;
  if v_proposer = v_uid then
    raise exception 'cannot_decide_own_proposal' using errcode = '42501';
  end if;
  if p_accept is not true and btrim(coalesce(p_note, '')) = '' then
    raise exception 'decline_reason_required' using errcode = '22023';
  end if;
  perform private.refresh_proposal_apply(
    p_id, case when p_accept then 'accepted' else 'declined' end, p_note);
  update public.content_refresh_proposals
     set reviewer_id = v_uid, review_note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;
  return case when p_accept then 'accepted' else 'declined' end;
end;
$$;

revoke all on function public.decide_refresh_proposal(uuid, boolean, text) from public, anon;
grant execute on function public.decide_refresh_proposal(uuid, boolean, text) to authenticated;

-- The proposer withdraws their own open proposal (works when OFF).
create or replace function public.withdraw_refresh_proposal(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.content_refresh_proposals
     where id = p_id and proposer_id = auth.uid()
  ) then
    raise exception 'proposal_not_owned' using errcode = '42501';
  end if;
  return private.refresh_proposal_apply(p_id, 'withdrawn', null);
end;
$$;

revoke all on function public.withdraw_refresh_proposal(uuid) from public, anon;
grant execute on function public.withdraw_refresh_proposal(uuid) to authenticated;
