-- PR-H slice 5 (master plan v2.6 §6.8 M-14, §9.6, §12.0): the Wanted Board.
--
-- * New gate `content.wanted_board`, default OFF, not release-ready. Every
--   write and the board read check it on the server.
-- * Needs are concept-level topics, never learner data. A learner may
--   *propose* one; it stays private (proposer + moderators) until a
--   moderator approves it. Moderators may post needs directly.
-- * "I need this too" votes are stored per user but never exposed: the
--   board shows a count only from 3 votes up (small-cohort suppression).
-- * A contributor links their OWN lesson contribution to an open need.
--   A moderator marks a need fulfilled only with a linked PUBLISHED
--   contribution; fulfilment never publishes anything by itself.
-- * Rate limits; no direct writes from browsers. Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.wanted_board', 'Wanted Board', 'Content', 'release', false, 'experimental', false,
  'Moderated, concept-level lesson requests that contributors can fulfil through governed contributions')
ON CONFLICT (feature_key) DO NOTHING;

create table if not exists public.content_wanted_needs (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 5 and 120),
  details text check (details is null or char_length(details) <= 1000),
  subject_tag text check (subject_tag is null or subject_tag ~ '^[a-z0-9][a-z0-9-]{0,39}$'),
  status text not null default 'proposed'
    check (status in ('proposed', 'open', 'fulfilled', 'closed', 'rejected')),
  proposed_by uuid references auth.users(id) on delete set null,
  reviewed_by uuid references auth.users(id) on delete set null,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  fulfilled_by uuid references public.content_contributions(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists content_wanted_needs_status
  on public.content_wanted_needs (status, created_at desc);
create index if not exists content_wanted_needs_proposer
  on public.content_wanted_needs (proposed_by, created_at desc);

create table if not exists public.content_wanted_votes (
  need_id uuid not null references public.content_wanted_needs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (need_id, user_id)
);

create table if not exists public.content_wanted_links (
  need_id uuid not null references public.content_wanted_needs(id) on delete cascade,
  contribution_id uuid not null references public.content_contributions(id),
  linked_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (need_id, contribution_id)
);

alter table public.content_wanted_needs enable row level security;
alter table public.content_wanted_votes enable row level security;
alter table public.content_wanted_links enable row level security;

-- Proposals are private to their proposer and moderators. The public board
-- is read through wanted_board() so that votes stay aggregated.
create policy content_wanted_needs_select on public.content_wanted_needs
  for select to authenticated
  using (proposed_by = auth.uid() or private.is_moderator());

create policy content_wanted_votes_select on public.content_wanted_votes
  for select to authenticated
  using (user_id = auth.uid());

create policy content_wanted_links_select on public.content_wanted_links
  for select to authenticated
  using (linked_by = auth.uid() or private.is_moderator());

revoke all on table public.content_wanted_needs from public, anon;
revoke all on table public.content_wanted_votes from public, anon;
revoke all on table public.content_wanted_links from public, anon;
revoke insert, update, delete on table public.content_wanted_needs from authenticated;
revoke insert, update, delete on table public.content_wanted_votes from authenticated;
revoke insert, update, delete on table public.content_wanted_links from authenticated;
grant select on table public.content_wanted_needs to authenticated;
grant select on table public.content_wanted_votes to authenticated;
grant select on table public.content_wanted_links to authenticated;

-- Small-cohort suppression threshold for the public vote count.
create or replace function private.wanted_vote_floor()
returns integer language sql immutable set search_path = '' as $$ select 3 $$;
revoke all on function private.wanted_vote_floor() from public, anon, authenticated;

-- The public board: open needs only, with a suppressed vote count, whether
-- the caller voted, and how many contributions are linked.
create or replace function public.wanted_board()
returns table (
  id uuid,
  title text,
  details text,
  subject_tag text,
  votes integer,
  has_voted boolean,
  linked integer,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  return query
    select n.id, n.title, n.details, n.subject_tag,
           case when v.cnt >= private.wanted_vote_floor() then v.cnt::integer end,
           exists (select 1 from public.content_wanted_votes x
                    where x.need_id = n.id and x.user_id = auth.uid()),
           (select count(*)::integer from public.content_wanted_links l
             where l.need_id = n.id),
           n.created_at
      from public.content_wanted_needs n
      left join lateral (
        select count(*) as cnt from public.content_wanted_votes x
         where x.need_id = n.id
      ) v on true
     where n.status = 'open'
     order by coalesce(v.cnt, 0) desc, n.created_at desc
     limit 200;
end;
$$;

revoke all on function public.wanted_board() from public, anon;
grant execute on function public.wanted_board() to authenticated;

create or replace function public.propose_wanted_need(
  p_title text,
  p_details text default null,
  p_subject_tag text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_mod boolean := private.is_moderator();
  v_recent integer;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select count(*) into v_recent from public.content_wanted_needs
   where proposed_by = v_uid and created_at > now() - interval '24 hours';
  if v_recent >= 5 and not v_mod then
    raise exception 'rate_limited' using errcode = '54000';
  end if;
  begin
    insert into public.content_wanted_needs
      (title, details, subject_tag, status, proposed_by, reviewed_by)
    values
      (btrim(coalesce(p_title, '')), nullif(btrim(coalesce(p_details, '')), ''),
       nullif(btrim(coalesce(p_subject_tag, '')), ''),
       -- A moderator's own need is posted directly; a learner's waits.
       case when v_mod then 'open' else 'proposed' end,
       v_uid, case when v_mod then v_uid end)
    returning id into v_id;
  exception when check_violation then
    raise exception 'invalid_need' using errcode = '22023';
  end;
  return v_id;
end;
$$;

revoke all on function public.propose_wanted_need(text, text, text) from public, anon;
grant execute on function public.propose_wanted_need(text, text, text) to authenticated;

-- Moderator: approve (open) or reject a proposed need.
create or replace function public.review_wanted_need(
  p_id uuid,
  p_approve boolean,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.content_wanted_needs%rowtype;
  v_to text;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into v_row from public.content_wanted_needs where id = p_id for update;
  if not found then
    raise exception 'need_not_found' using errcode = 'P0002';
  end if;
  if v_row.status <> 'proposed' then
    raise exception 'invalid_state_transition' using errcode = '22000';
  end if;
  if v_row.proposed_by = v_uid then
    raise exception 'cannot_review_own_need' using errcode = '42501';
  end if;
  if p_approve is not true and btrim(coalesce(p_note, '')) = '' then
    raise exception 'rejection_reason_required' using errcode = '22023';
  end if;
  if p_note is not null and char_length(p_note) > 1000 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  v_to := case when p_approve then 'open' else 'rejected' end;
  update public.content_wanted_needs
     set status = v_to, reviewed_by = v_uid,
         review_note = nullif(btrim(coalesce(p_note, '')), ''),
         updated_at = now()
   where id = p_id;
  return v_to;
end;
$$;

revoke all on function public.review_wanted_need(uuid, boolean, text) from public, anon;
grant execute on function public.review_wanted_need(uuid, boolean, text) to authenticated;

-- "I need this too" (toggle). Returns whether the caller now votes for it.
create or replace function public.vote_wanted_need(p_id uuid, p_vote boolean)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.content_wanted_needs where id = p_id and status = 'open'
  ) then
    raise exception 'need_not_open' using errcode = 'P0002';
  end if;
  if p_vote then
    insert into public.content_wanted_votes (need_id, user_id)
    values (p_id, v_uid) on conflict do nothing;
  else
    delete from public.content_wanted_votes where need_id = p_id and user_id = v_uid;
  end if;
  return p_vote;
end;
$$;

revoke all on function public.vote_wanted_need(uuid, boolean) from public, anon;
grant execute on function public.vote_wanted_need(uuid, boolean) to authenticated;

-- A contributor links their own contribution to an open need.
create or replace function public.link_contribution_to_need(
  p_need_id uuid,
  p_contribution_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_recent integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.content_wanted_needs where id = p_need_id and status = 'open'
  ) then
    raise exception 'need_not_open' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.content_contributions
     where id = p_contribution_id and contributor_id = v_uid
       and status in ('submitted', 'checks_failed', 'ready_for_publication', 'published')
  ) then
    raise exception 'contribution_not_owned' using errcode = '42501';
  end if;
  select count(*) into v_recent from public.content_wanted_links
   where linked_by = v_uid and created_at > now() - interval '24 hours';
  if v_recent >= 10 then
    raise exception 'rate_limited' using errcode = '54000';
  end if;
  insert into public.content_wanted_links (need_id, contribution_id, linked_by)
  values (p_need_id, p_contribution_id, v_uid)
  on conflict do nothing;
  return true;
end;
$$;

revoke all on function public.link_contribution_to_need(uuid, uuid) from public, anon;
grant execute on function public.link_contribution_to_need(uuid, uuid) to authenticated;

-- Moderator: fulfil (with a linked, published contribution), close or
-- reopen an approved need. Never publishes or edits any contribution.
create or replace function public.set_wanted_need_status(
  p_id uuid,
  p_status text,
  p_contribution_id uuid default null,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_from text;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.wanted_board') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if p_status not in ('fulfilled', 'closed', 'open') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  if p_note is not null and char_length(p_note) > 1000 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  select status into v_from from public.content_wanted_needs where id = p_id for update;
  if not found then
    raise exception 'need_not_found' using errcode = 'P0002';
  end if;
  if v_from not in ('open', 'fulfilled', 'closed') or v_from = p_status then
    raise exception 'invalid_state_transition' using errcode = '22000';
  end if;
  if p_status = 'fulfilled' and not exists (
    select 1
      from public.content_wanted_links l
      join public.content_contributions c on c.id = l.contribution_id
     where l.need_id = p_id and l.contribution_id = p_contribution_id
       and c.status = 'published'
  ) then
    raise exception 'published_link_required' using errcode = '22023';
  end if;
  update public.content_wanted_needs
     set status = p_status,
         fulfilled_by = case when p_status = 'fulfilled' then p_contribution_id end,
         reviewed_by = v_uid,
         review_note = coalesce(nullif(btrim(coalesce(p_note, '')), ''), review_note),
         updated_at = now()
   where id = p_id;
  return p_status;
end;
$$;

revoke all on function public.set_wanted_need_status(uuid, text, uuid, text) from public, anon;
grant execute on function public.set_wanted_need_status(uuid, text, uuid, text) to authenticated;
