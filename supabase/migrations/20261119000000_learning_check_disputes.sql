-- PR-D follow-up (master plan v2.6 §10.0 wrong-answer triage, §14.0A):
-- a review queue for practice checks that learners say are wrong.
--
-- * New gate `learning.check_disputes`, default OFF, not release-ready.
--   It gates new disputes and decisions only.
-- * A signed-in learner disputes one check in a bundled Bridge, at the
--   Bridge's content version, with a triage reason and an optional note.
--   The learner's answer is never sent or stored.
-- * A moderator upholds or dismisses every open dispute for that check at
--   once. Dismissing needs a note. A moderator cannot decide a check they
--   disputed themselves.
-- * An upheld check is quarantined at that content version: apps stop
--   using it as evidence and show it as "being corrected". Shipping a
--   fixed Bridge with a new content version ends the quarantine on its
--   own, so no row has to be edited. The quarantine list is readable even
--   while the gate is OFF, because it is a safety signal.
-- * No direct writes from browsers. Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.check_disputes', 'Disputed practice checks', 'Learning', 'release', false, 'experimental', false,
  'Learners report practice checks that seem wrong; moderators uphold (quarantine) or dismiss')
ON CONFLICT (feature_key) DO NOTHING;

create table if not exists public.learning_check_disputes (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  content_kind text not null default 'bridge' check (content_kind in ('bridge')),
  content_id text not null
    check (content_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'),
  content_version text not null
    check (content_version ~ '^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}$'),
  item_id text not null
    check (item_id ~ '^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'),
  reason text not null check (reason in (
    'wrong_answer', 'unclear', 'input_problem', 'source_mismatch', 'other')),
  note text check (note is null or char_length(note) <= 500),
  status text not null default 'open'
    check (status in ('open', 'upheld', 'dismissed', 'withdrawn')),
  reviewer_id uuid references auth.users(id) on delete set null,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

-- One open dispute per learner per check version.
create unique index if not exists learning_check_disputes_one_open
  on public.learning_check_disputes
     (reporter_id, content_kind, content_id, content_version, item_id)
  where status = 'open';
create index if not exists learning_check_disputes_item
  on public.learning_check_disputes
     (content_kind, content_id, content_version, item_id, status);
create index if not exists learning_check_disputes_reporter
  on public.learning_check_disputes (reporter_id, created_at desc);

alter table public.learning_check_disputes enable row level security;

create policy learning_check_disputes_select on public.learning_check_disputes
  for select to authenticated
  using (reporter_id = auth.uid() or private.is_moderator());

revoke all on table public.learning_check_disputes from public, anon;
revoke insert, update, delete on table public.learning_check_disputes from authenticated;
grant select on table public.learning_check_disputes to authenticated;

create or replace function public.submit_check_dispute(
  p_content_id text,
  p_content_version text,
  p_item_id text,
  p_reason text,
  p_note text default null
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
  if not private.site_feature_enabled('learning.check_disputes') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select count(*) into v_recent
    from public.learning_check_disputes
   where reporter_id = v_uid and created_at > now() - interval '24 hours';
  if v_recent >= 20 then
    raise exception 'rate_limited' using errcode = '54000';
  end if;

  begin
    insert into public.learning_check_disputes
      (reporter_id, content_id, content_version, item_id, reason, note)
    values
      (v_uid, p_content_id, p_content_version, p_item_id, p_reason,
       nullif(btrim(coalesce(p_note, '')), ''))
    returning id into v_id;
  exception
    when unique_violation then
      raise exception 'already_disputed' using errcode = '23505';
    when check_violation or not_null_violation then
      raise exception 'invalid_dispute' using errcode = '22023';
  end;
  return v_id;
end;
$$;

revoke all on function public.submit_check_dispute(text, text, text, text, text)
  from public, anon;
grant execute on function public.submit_check_dispute(text, text, text, text, text)
  to authenticated;

-- Moderator decision for one check version: settles every open dispute.
create or replace function public.decide_check_disputes(
  p_content_id text,
  p_content_version text,
  p_item_id text,
  p_uphold boolean,
  p_note text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('learning.check_disputes') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if p_uphold is null then
    raise exception 'decision_required' using errcode = '22023';
  end if;
  if p_uphold is not true and btrim(coalesce(p_note, '')) = '' then
    raise exception 'dismiss_reason_required' using errcode = '22023';
  end if;
  if p_note is not null and char_length(p_note) > 1000 then
    raise exception 'note_too_long' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.learning_check_disputes
     where content_kind = 'bridge' and content_id = p_content_id
       and content_version = p_content_version and item_id = p_item_id
       and status = 'open' and reporter_id = v_uid
  ) then
    raise exception 'cannot_decide_own_dispute' using errcode = '42501';
  end if;

  update public.learning_check_disputes
     set status = case when p_uphold then 'upheld' else 'dismissed' end,
         reviewer_id = v_uid,
         review_note = nullif(btrim(coalesce(p_note, '')), ''),
         decided_at = now()
   where content_kind = 'bridge' and content_id = p_content_id
     and content_version = p_content_version and item_id = p_item_id
     and status = 'open';
  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'no_open_disputes' using errcode = 'P0002';
  end if;
  return v_count;
end;
$$;

revoke all on function public.decide_check_disputes(text, text, text, boolean, text)
  from public, anon;
grant execute on function public.decide_check_disputes(text, text, text, boolean, text)
  to authenticated;

-- The reporter withdraws their own open dispute (works when OFF).
create or replace function public.withdraw_check_dispute(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.learning_check_disputes
     set status = 'withdrawn', decided_at = now()
   where id = p_id and reporter_id = auth.uid() and status = 'open';
  if not found then
    raise exception 'dispute_not_open_or_not_owned' using errcode = '42501';
  end if;
  return 'withdrawn';
end;
$$;

revoke all on function public.withdraw_check_dispute(uuid) from public, anon;
grant execute on function public.withdraw_check_dispute(uuid) to authenticated;

-- Upheld checks, by content version. No reporter, note or count is exposed.
create or replace function public.quarantined_check_items()
returns table (content_kind text, content_id text, content_version text, item_id text)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct d.content_kind, d.content_id, d.content_version, d.item_id
    from public.learning_check_disputes d
   where d.status = 'upheld';
$$;

revoke all on function public.quarantined_check_items() from public;
grant execute on function public.quarantined_check_items() to anon, authenticated;
