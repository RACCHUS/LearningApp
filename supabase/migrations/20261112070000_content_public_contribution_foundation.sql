-- PR-H slice 1 (master plan v2.6 §5.2 AssetPublicationStatus, §8.6, §14,
-- P5.1, Gate G5): governed public contribution of personal lessons.
--
-- * New gate `content.public_contribution`, default OFF and not
--   release-ready. Every write RPC and the public reader check it on the
--   server; a client flag is never authorization.
-- * A contribution is an IMMUTABLE, VERSIONED SNAPSHOT of a lesson the
--   contributor owns, taken with explicit consent, a recorded licence and a
--   rights attestation. Submitting never changes the lesson's visibility:
--   the private lesson stays private (A35).
-- * Automated deterministic checks run at submission (answer keys in range,
--   distinct options, short-answer accepted answers, size bounds).
-- * Moderators approve or reject; only admins publish. Published copies are
--   labelled `community_unreviewed` and never confer verified mastery (A93).
-- * Contributors can withdraw; moderators can take down. Every transition is
--   written to an append-only event log (P5.1 acceptance).
-- Additive only: no existing table, row, policy or function is changed.

-- ---------------------------------------------------------------------------
-- 1. Feature gate (default OFF, not release-ready)
-- ---------------------------------------------------------------------------
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.public_contribution', 'Community lesson contributions', 'Content', 'release', false, 'experimental', false,
  'Consent + licence + checks + moderator review + admin publish; private lessons stay private when OFF')
ON CONFLICT (feature_key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. Tables
-- ---------------------------------------------------------------------------
create table if not exists public.content_contributions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete set null,
  contributor_id uuid references auth.users(id) on delete set null,
  version integer not null check (version >= 1),
  status text not null check (status in (
    'submitted', 'checks_failed', 'ready_for_publication',
    'rejected', 'published', 'withdrawn', 'superseded')),
  license text not null check (license in ('CC-BY-4.0', 'CC-BY-SA-4.0', 'CC0-1.0')),
  rights_attested_at timestamptz not null,
  ai_assisted boolean not null,
  trust_tier text not null default 'community_unreviewed'
    check (trust_tier in ('community_unreviewed')),
  snapshot jsonb not null,
  snapshot_sha256 text not null,
  check_issues jsonb not null default '[]'::jsonb,
  reviewer_id uuid references auth.users(id) on delete set null,
  review_note text check (review_note is null or char_length(review_note) <= 1000),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- At most one open contribution per lesson.
create unique index if not exists content_contributions_one_open_per_lesson
  on public.content_contributions (lesson_id)
  where status in ('submitted', 'checks_failed', 'ready_for_publication');

-- At most one live published version per lesson.
create unique index if not exists content_contributions_one_published_per_lesson
  on public.content_contributions (lesson_id)
  where status = 'published';

create index if not exists content_contributions_status_created
  on public.content_contributions (status, created_at desc);
create index if not exists content_contributions_contributor_created
  on public.content_contributions (contributor_id, created_at desc);

create table if not exists public.content_contribution_events (
  id uuid primary key default gen_random_uuid(),
  contribution_id uuid not null references public.content_contributions(id),
  actor_id uuid references auth.users(id) on delete set null,
  event text not null check (event in (
    'submitted', 'checks_failed', 'approved', 'rejected', 'published',
    'withdrawn', 'taken_down', 'superseded')),
  from_status text,
  to_status text not null,
  note text check (note is null or char_length(note) <= 1000),
  created_at timestamptz not null default now()
);

create index if not exists content_contribution_events_contribution
  on public.content_contribution_events (contribution_id, created_at);

alter table public.content_contributions enable row level security;
alter table public.content_contribution_events enable row level security;

-- Reads: own contributions, or moderators. All writes go through RPCs.
create policy content_contributions_select on public.content_contributions
  for select to authenticated
  using (contributor_id = auth.uid() or private.is_moderator());

create policy content_contribution_events_select on public.content_contribution_events
  for select to authenticated
  using (
    private.is_moderator()
    or exists (
      select 1 from public.content_contributions c
       where c.id = contribution_id and c.contributor_id = auth.uid()
    )
  );

revoke all on table public.content_contributions from public, anon;
revoke all on table public.content_contribution_events from public, anon;
revoke insert, update, delete on table public.content_contributions from authenticated;
revoke insert, update, delete on table public.content_contribution_events from authenticated;
grant select on table public.content_contributions to authenticated;
grant select on table public.content_contribution_events to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Private helpers
-- ---------------------------------------------------------------------------

-- Allowed status transitions (AssetPublicationStatus, plan §5.2).
create or replace function private.contribution_transition_allowed(
  p_from text,
  p_to text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select (p_from, p_to) in (
    ('submitted', 'ready_for_publication'),
    ('submitted', 'rejected'),
    ('submitted', 'withdrawn'),
    ('checks_failed', 'withdrawn'),
    ('ready_for_publication', 'published'),
    ('ready_for_publication', 'rejected'),
    ('ready_for_publication', 'withdrawn'),
    ('published', 'withdrawn'),
    ('published', 'superseded')
  );
$$;

revoke all on function private.contribution_transition_allowed(text, text)
  from public, anon, authenticated;

-- Applies one audited transition. Caller authorization is checked by the
-- public RPCs before this runs.
create or replace function private.contribution_apply(
  p_id uuid,
  p_to text,
  p_event text,
  p_note text
)
returns public.content_contributions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.content_contributions;
  v_from text;
begin
  select * into v_row from public.content_contributions where id = p_id for update;
  if not found then
    raise exception 'contribution_not_found' using errcode = 'P0002';
  end if;
  v_from := v_row.status;
  if not private.contribution_transition_allowed(v_row.status, p_to) then
    raise exception 'invalid_state_transition: % -> %', v_row.status, p_to
      using errcode = '22000';
  end if;
  update public.content_contributions
     set status = p_to,
         updated_at = now(),
         published_at = case when p_to = 'published' then now() else published_at end
   where id = p_id
   returning * into v_row;
  insert into public.content_contribution_events
    (contribution_id, actor_id, event, from_status, to_status, note)
  values (p_id, auth.uid(), p_event, v_from, p_to,
          nullif(btrim(coalesce(p_note, '')), ''));
  return v_row;
end;
$$;

revoke all on function private.contribution_apply(uuid, text, text, text)
  from public, anon, authenticated;

-- Deterministic checks on a snapshot. Returns a list of issue objects.
create or replace function private.contribution_check_snapshot(p_snapshot jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_issues jsonb := '[]'::jsonb;
  v_q jsonb;
  v_i integer := 0;
  v_type text;
  v_n integer;
  v_key integer;
  v_items integer;
begin
  if btrim(coalesce(p_snapshot->>'title', '')) = '' then
    v_issues := v_issues || jsonb_build_object('path', 'title', 'code', 'missing_title');
  end if;
  v_items := jsonb_array_length(p_snapshot->'terms')
           + jsonb_array_length(p_snapshot->'concepts')
           + jsonb_array_length(p_snapshot->'questions');
  if v_items = 0 then
    v_issues := v_issues || jsonb_build_object('path', 'lesson', 'code', 'empty_lesson');
  end if;
  if octet_length(p_snapshot::text) > 262144 then
    v_issues := v_issues || jsonb_build_object('path', 'lesson', 'code', 'too_large');
  end if;

  for v_q in select * from jsonb_array_elements(p_snapshot->'questions')
  loop
    v_type := coalesce(v_q->>'type', 'mcq');
    if v_type = 'short_answer' then
      if coalesce(jsonb_array_length(v_q->'accepted_answers'), 0) = 0 then
        v_issues := v_issues || jsonb_build_object(
          'path', format('questions[%s]', v_i), 'code', 'missing_accepted_answers');
      end if;
    else
      v_n := case when jsonb_typeof(v_q->'options') = 'array'
                  then jsonb_array_length(v_q->'options') else 0 end;
      v_key := (v_q->>'correct_answer')::integer;
      if v_n < 2 or v_n > 8 then
        v_issues := v_issues || jsonb_build_object(
          'path', format('questions[%s]', v_i), 'code', 'option_count');
      elsif v_key is null or v_key < 0 or v_key >= v_n then
        v_issues := v_issues || jsonb_build_object(
          'path', format('questions[%s]', v_i), 'code', 'answer_key_out_of_range');
      elsif (select count(distinct lower(regexp_replace(btrim(o), '\s+', ' ', 'g')))
               from jsonb_array_elements_text(v_q->'options') o) <> v_n then
        v_issues := v_issues || jsonb_build_object(
          'path', format('questions[%s]', v_i), 'code', 'duplicate_options');
      end if;
    end if;
    v_i := v_i + 1;
  end loop;
  return v_issues;
end;
$$;

revoke all on function private.contribution_check_snapshot(jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Contributor RPCs
-- ---------------------------------------------------------------------------

-- Submits a versioned snapshot of a lesson the caller owns. Never changes
-- the lesson itself.
create or replace function public.submit_lesson_contribution(
  p_lesson_id uuid,
  p_license text,
  p_rights_attested boolean,
  p_ai_assisted boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_lesson record;
  v_snapshot jsonb;
  v_issues jsonb;
  v_version integer;
  v_open public.content_contributions;
  v_row public.content_contributions;
  v_recent integer;
begin
  if v_uid is null then
    raise exception 'authentication_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.public_contribution') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  if p_rights_attested is not true then
    raise exception 'rights_attestation_required' using errcode = '22023';
  end if;
  if p_license is null or p_license not in ('CC-BY-4.0', 'CC-BY-SA-4.0', 'CC0-1.0') then
    raise exception 'unsupported_license' using errcode = '22023';
  end if;
  if p_ai_assisted is null then
    raise exception 'ai_assisted_required' using errcode = '22023';
  end if;

  select l.id, l.title, l.description, l.tags, l.user_id, l.origin_target_version_id
    into v_lesson
    from public.lessons l
   where l.id = p_lesson_id
     for update;
  if not found or v_lesson.user_id is distinct from v_uid then
    raise exception 'lesson_not_owned' using errcode = '42501';
  end if;
  if v_lesson.origin_target_version_id is not null then
    raise exception 'curriculum_lessons_not_contributable' using errcode = '42501';
  end if;

  select count(*) into v_recent
    from public.content_contributions
   where contributor_id = v_uid
     and created_at > now() - interval '24 hours';
  if v_recent >= 5 then
    raise exception 'rate_limited' using errcode = '54000';
  end if;

  select * into v_open
    from public.content_contributions
   where lesson_id = p_lesson_id
     and status in ('submitted', 'checks_failed', 'ready_for_publication')
     for update;
  if found then
    if v_open.status = 'checks_failed' then
      -- Explicit repair path: the failed attempt is closed, a new version
      -- is checked from the lesson as it is now.
      perform private.contribution_apply(
        v_open.id, 'withdrawn', 'withdrawn', 'replaced by a repaired resubmission');
    else
      raise exception 'contribution_already_open' using errcode = '23505';
    end if;
  end if;

  v_snapshot := jsonb_build_object(
    'title', v_lesson.title,
    'description', v_lesson.description,
    'tags', to_jsonb(coalesce(v_lesson.tags, '{}'::text[])),
    'terms', coalesce((
      select jsonb_agg(jsonb_build_object(
               'term', t.term, 'definition', t.definition, 'example', t.example)
             order by t.created_at, t.id)
        from public.terms t where t.lesson_id = p_lesson_id), '[]'::jsonb),
    'concepts', coalesce((
      select jsonb_agg(jsonb_build_object(
               'concept_text', c.concept_text, 'example_text', c.example_text,
               'key_points', to_jsonb(c.key_points))
             order by c.created_at, c.id)
        from public.concepts c where c.lesson_id = p_lesson_id), '[]'::jsonb),
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'question_text', q.question_text, 'options', q.options,
               'correct_answer', q.correct_answer, 'type', q.type,
               'explanation', q.explanation,
               'accepted_answers', to_jsonb(q.accepted_answers),
               'grading_method', q.grading_method,
               'numeric_tolerance', q.numeric_tolerance)
             order by q.created_at, q.id)
        from public.questions q where q.lesson_id = p_lesson_id), '[]'::jsonb)
  );
  v_issues := private.contribution_check_snapshot(v_snapshot);

  select coalesce(max(version), 0) + 1 into v_version
    from public.content_contributions where lesson_id = p_lesson_id;

  insert into public.content_contributions (
    lesson_id, contributor_id, version, status, license, rights_attested_at,
    ai_assisted, snapshot, snapshot_sha256, check_issues
  ) values (
    p_lesson_id, v_uid, v_version,
    case when jsonb_array_length(v_issues) = 0 then 'submitted' else 'checks_failed' end,
    p_license, now(), p_ai_assisted, v_snapshot,
    encode(extensions.digest(convert_to(v_snapshot::text, 'UTF8'), 'sha256'), 'hex'),
    v_issues
  ) returning * into v_row;

  insert into public.content_contribution_events
    (contribution_id, actor_id, event, from_status, to_status, note)
  values (v_row.id, v_uid,
          case when v_row.status = 'submitted' then 'submitted' else 'checks_failed' end,
          null, v_row.status, null);

  return jsonb_build_object(
    'id', v_row.id, 'version', v_row.version, 'status', v_row.status,
    'issues', v_row.check_issues);
end;
$$;

revoke all on function public.submit_lesson_contribution(uuid, text, boolean, boolean)
  from public, anon;
grant execute on function public.submit_lesson_contribution(uuid, text, boolean, boolean)
  to authenticated;

-- The contributor withdraws their own contribution at any open or
-- published stage. Withdrawal is allowed even when the gate is OFF.
create or replace function public.withdraw_lesson_contribution(
  p_id uuid,
  p_note text default null
)
returns text
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
  if not exists (
    select 1 from public.content_contributions
     where id = p_id and contributor_id = v_uid
  ) then
    raise exception 'contribution_not_owned' using errcode = '42501';
  end if;
  return (private.contribution_apply(p_id, 'withdrawn', 'withdrawn', p_note)).status;
end;
$$;

revoke all on function public.withdraw_lesson_contribution(uuid, text) from public, anon;
grant execute on function public.withdraw_lesson_contribution(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Moderator / admin RPCs
-- ---------------------------------------------------------------------------

-- Moderator decision on a submitted or ready contribution. A moderator
-- cannot review their own contribution.
create or replace function public.review_lesson_contribution(
  p_id uuid,
  p_decision text,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.content_contributions;
begin
  if v_uid is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.public_contribution') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into v_row from public.content_contributions where id = p_id;
  if not found then
    raise exception 'contribution_not_found' using errcode = 'P0002';
  end if;
  if v_row.contributor_id = v_uid then
    raise exception 'cannot_review_own_contribution' using errcode = '42501';
  end if;
  if p_decision = 'approve' then
    v_row := private.contribution_apply(p_id, 'ready_for_publication', 'approved', p_note);
  elsif p_decision = 'reject' then
    if btrim(coalesce(p_note, '')) = '' then
      raise exception 'rejection_reason_required' using errcode = '22023';
    end if;
    v_row := private.contribution_apply(p_id, 'rejected', 'rejected', p_note);
  else
    raise exception 'invalid_decision' using errcode = '22023';
  end if;
  update public.content_contributions
     set reviewer_id = v_uid, review_note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;
  return v_row.status;
end;
$$;

revoke all on function public.review_lesson_contribution(uuid, text, text) from public, anon;
grant execute on function public.review_lesson_contribution(uuid, text, text) to authenticated;

-- Admin-only publication of an approved contribution. Any earlier published
-- version of the same lesson is superseded. The source lesson's own
-- visibility is not changed.
create or replace function public.publish_lesson_contribution(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.content_contributions;
  v_prev uuid;
begin
  if v_uid is null or not private.is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if not private.site_feature_enabled('content.public_contribution') then
    raise exception 'feature_disabled' using errcode = '42501';
  end if;
  select * into v_row from public.content_contributions where id = p_id for update;
  if not found then
    raise exception 'contribution_not_found' using errcode = 'P0002';
  end if;
  if v_row.contributor_id = v_uid then
    raise exception 'cannot_publish_own_contribution' using errcode = '42501';
  end if;
  if v_row.status <> 'ready_for_publication' then
    raise exception 'invalid_state_transition: % -> published', v_row.status
      using errcode = '22000';
  end if;
  select id into v_prev from public.content_contributions
   where lesson_id = v_row.lesson_id and status = 'published' and id <> p_id;
  if v_prev is not null then
    perform private.contribution_apply(v_prev, 'superseded', 'superseded',
      format('superseded by version %s', v_row.version));
  end if;
  return (private.contribution_apply(p_id, 'published', 'published', null)).status;
end;
$$;

revoke all on function public.publish_lesson_contribution(uuid) from public, anon;
grant execute on function public.publish_lesson_contribution(uuid) to authenticated;

-- Moderator takedown of a published contribution, with a mandatory reason.
-- Allowed even when the gate is OFF, so harmful content can always be removed.
create or replace function public.takedown_lesson_contribution(
  p_id uuid,
  p_reason text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not private.is_moderator() then
    raise exception 'moderator_required' using errcode = '42501';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'takedown_reason_required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.content_contributions where id = p_id and status = 'published'
  ) then
    raise exception 'not_published' using errcode = '22000';
  end if;
  return (private.contribution_apply(p_id, 'withdrawn', 'taken_down', p_reason)).status;
end;
$$;

revoke all on function public.takedown_lesson_contribution(uuid, text) from public, anon;
grant execute on function public.takedown_lesson_contribution(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Public reader (gated): published community copies only
-- ---------------------------------------------------------------------------
create or replace function public.list_published_contributions(
  p_limit integer default 50
)
returns table (
  id uuid,
  version integer,
  license text,
  ai_assisted boolean,
  trust_tier text,
  title text,
  snapshot jsonb,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id, c.version, c.license, c.ai_assisted, c.trust_tier,
         c.snapshot->>'title', c.snapshot, c.published_at
    from public.content_contributions c
   where c.status = 'published'
     and private.site_feature_enabled('content.public_contribution')
   order by c.published_at desc
   limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.list_published_contributions(integer) from public;
grant execute on function public.list_published_contributions(integer) to anon, authenticated;
