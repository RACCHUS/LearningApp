-- EXM-02B: server-private, independently reviewed R1-R4 scoring keys.
-- No live items or keys are seeded. This file is a LOCAL migration only until
-- owner approval through the guarded production deployment workflow.
--
-- This design deliberately keeps answer tokens and submitted responses out
-- of the client-readable event/grade tables. A client can obtain only its own
-- boolean correctness for one previously recorded step. It is not proof of
-- physical book lookup or an issuer pass prediction.

create function public.exam_reference_drill_tokens_valid(p_tokens jsonb)
returns boolean language plpgsql immutable security invoker
set search_path=pg_catalog
as $check$
declare
  step_name text;
  entry jsonb;
  candidate jsonb;
  token text;
  seen text[];
begin
  if jsonb_typeof(p_tokens) is distinct from 'object'
     or (select count(*) from jsonb_object_keys(p_tokens)) <> 4 then
    return false;
  end if;
  foreach step_name in array array[
    'resource_choice','section_location','interpretation','application'
  ] loop
    entry := p_tokens -> step_name;
    if jsonb_typeof(entry) is distinct from 'array'
       or jsonb_array_length(entry) < 1
       or jsonb_array_length(entry) > 6 then
      return false;
    end if;
    seen := array[]::text[];
    for candidate in select value from jsonb_array_elements(entry) as source(value)
    loop
      if jsonb_typeof(candidate) is distinct from 'string' then
        return false;
      end if;
      token := candidate #>> '{}';
      if token is null
         or length(token) > 80
         or token !~ '^[a-z0-9][a-z0-9 _./:-]*$'
         or token <> lower(btrim(token))
         or token = any(seen) then
        return false;
      end if;
      seen := array_append(seen,token);
    end loop;
  end loop;
  return true;
end
$check$;
revoke all on function public.exam_reference_drill_tokens_valid(jsonb)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_tokens_valid(jsonb)
  to service_role;

-- NEVER grant learner API read access to this table. Even learner-owned
-- scopes cannot read the private editorial key or review evidence.
create table public.exam_reference_drill_scoring_keys (
  id uuid primary key default gen_random_uuid(),
  approved_binding_id uuid not null
    references public.assessment_item_reference_validity(id)
      on update restrict on delete restrict,
  scoring_version integer not null check(scoring_version > 0),
  step_tokens jsonb not null
    check(public.exam_reference_drill_tokens_valid(step_tokens)),
  author_ref text not null check(length(btrim(author_ref)) between 3 and 150),
  ai_drafted boolean not null,
  reviewer_ref text,
  reviewer_qualification_evidence text,
  reviewer_edition_access_evidence text,
  rights_review_status text not null default 'pending'
    check(rights_review_status in ('pending','approved','rejected')),
  review_status text not null default 'pending'
    check(review_status in ('pending','approved','rejected')),
  publication_status text not null default 'draft'
    check(publication_status in ('draft','published','retired')),
  reviewed_at timestamptz,
  review_minutes integer check(review_minutes between 1 and 10000),
  created_at timestamptz not null default now(),
  unique(approved_binding_id,scoring_version),
  constraint exam_drill_scoring_independent_reviewer
    check(reviewer_ref is null or btrim(reviewer_ref) <> btrim(author_ref)),
  constraint exam_drill_scoring_approval
    check(publication_status <> 'published' or (
      review_status='approved' and rights_review_status='approved'
      and reviewer_ref is not null
      and length(btrim(reviewer_ref)) >= 3
      and reviewer_qualification_evidence is not null
      and length(btrim(reviewer_qualification_evidence)) >= 8
      and reviewer_edition_access_evidence is not null
      and length(btrim(reviewer_edition_access_evidence)) >= 8
      and reviewed_at is not null and review_minutes is not null
    ))
);
create unique index exam_one_published_scoring_key_per_binding
  on public.exam_reference_drill_scoring_keys(approved_binding_id)
  where publication_status='published';

create function public.guard_exam_reference_drill_scoring_key()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,public
as $guard$
declare
  binding public.assessment_item_reference_validity%rowtype;
begin
  if tg_op='DELETE' then
    if old.publication_status <> 'draft' then
      raise exception 'Reviewed scoring rubrics cannot be deleted';
    end if;
    return old;
  end if;

  if tg_op='UPDATE' and old.publication_status in ('published','retired') then
    if old.publication_status='published'
      and new.publication_status='retired'
      and (to_jsonb(new)-'publication_status')
          = (to_jsonb(old)-'publication_status') then
      return new;
    end if;
    raise exception 'Reviewed scoring keys are immutable';
  end if;

  if new.publication_status='published' then
    select * into binding from public.assessment_item_reference_validity
      where id=new.approved_binding_id;
    if not found or binding.publication_status <> 'published'
      or binding.review_status <> 'approved'
      or binding.rights_review_status <> 'approved'
      or binding.item_content_sha256 is distinct from
        public.exam_reference_item_fingerprint(binding.assessment_item_id) then
      raise exception 'No approved, unchanged edition-specific item binding';
    end if;
    -- R1 and R2 must at least agree with the already independently reviewed
    -- exact-edition book and one source-anchored section. The reviewer is
    -- responsible for the complete accepted-token/rule semantics.
    if not (new.step_tokens -> 'resource_choice'
          @> jsonb_build_array(lower(binding.reference_edition_key)))
       or not exists (
         select 1 from jsonb_array_elements(binding.expected_locations)
           as location(value)
         join jsonb_array_elements_text(
           new.step_tokens -> 'section_location'
         ) as accepted(token)
           on lower(btrim(location.value->>'section'))=accepted.token
       ) then
      raise exception 'Rubric resource and section must match approved location';
    end if;
    if new.review_status <> 'approved'
      or new.rights_review_status <> 'approved'
      or new.reviewer_ref is null
      or btrim(new.reviewer_ref)=btrim(new.author_ref)
      or new.reviewer_qualification_evidence is null
      or new.reviewer_edition_access_evidence is null
      or new.reviewed_at is null or new.reviewed_at > now()
      or new.review_minutes is null then
      raise exception 'Independent reviewed scoring rubric required';
    end if;
  end if;
  return new;
end
$guard$;
revoke all on function public.guard_exam_reference_drill_scoring_key()
  from public,anon,authenticated;
create trigger trg_guard_exam_reference_drill_scoring_key
before insert or update or delete on public.exam_reference_drill_scoring_keys
for each row execute function public.guard_exam_reference_drill_scoring_key();

alter table public.exam_reference_drill_scoring_keys enable row level security;
revoke all on public.exam_reference_drill_scoring_keys
  from public,anon,authenticated;
grant select,insert,update,delete
  on public.exam_reference_drill_scoring_keys to service_role;
comment on table public.exam_reference_drill_scoring_keys is
 'Private exact-binding R1-R4 reviewed token sets; no learner SELECT/INSERT/UPDATE/DELETE.';

-- Durable, *server-derived* grading is distinct from unverified timestamps and
-- claimed observations. A cascade from deleting the owning step deletes this
-- derived grade too. Submitted answers are neither saved nor hashed.
create table public.exam_reference_drill_grades (
  event_id uuid primary key
    references public.exam_reference_drill_events(id) on delete cascade,
  owner_auth_uid uuid not null references auth.users(id) on delete cascade,
  approved_binding_id uuid not null
    references public.assessment_item_reference_validity(id) on delete restrict,
  scoring_key_id uuid not null
    references public.exam_reference_drill_scoring_keys(id) on delete restrict,
  drill_step text not null check(drill_step in (
    'resource_choice','section_location','interpretation','application')),
  is_correct boolean not null,
  scoring_version integer not null check(scoring_version > 0),
  graded_at timestamptz not null default now()
);
create index exam_drill_grades_owner_binding_time
  on public.exam_reference_drill_grades
    (owner_auth_uid,approved_binding_id,graded_at desc);
alter table public.exam_reference_drill_grades enable row level security;
revoke all on public.exam_reference_drill_grades
  from public,anon,authenticated;
grant select on public.exam_reference_drill_grades to authenticated;
grant select,insert,delete on public.exam_reference_drill_grades to service_role;
create policy exm_drill_grade_owner_read
on public.exam_reference_drill_grades for select to authenticated
using (
  owner_auth_uid=(select auth.uid())
  and (select (auth.jwt()->>'is_anonymous')::boolean) is false
);
comment on table public.exam_reference_drill_grades is
 'Private, owner-only server-graded reference step; immutable to clients; no answer, key, or issuer score.';

-- Score a previously persisted step once. Own event first, exact published
-- binding and separately reviewed rubric next, then compare inside DB.
-- Repeated calls return the original grade regardless of the new candidate:
-- no repeated guesses can re-grade one event. Cap 20 per binding per owner in
-- any rolling 24-hour period to reduce answer-oracle abuse.
create function public.score_exam_reference_drill_step(
  p_event_id uuid, p_answer text
)
returns table (
  drill_step text,
  is_correct boolean,
  scoring_version integer,
  graded_at timestamptz
)
language plpgsql volatile security definer
set search_path=pg_catalog,public,pg_temp
as $score$
declare
  actor_uid uuid;
  event_row public.exam_reference_drill_events%rowtype;
  key_row public.exam_reference_drill_scoring_keys%rowtype;
  grade_row public.exam_reference_drill_grades%rowtype;
  normalized_answer text;
  match_found boolean;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
    or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent sign-in required for scoring'
      using errcode='42501';
  end if;

  select * into event_row from public.exam_reference_drill_events e
    where e.id=p_event_id and e.owner_auth_uid=actor_uid;
  if not found or event_row.responded is distinct from true then
    raise exception 'No scoreable reference step is available'
      using errcode='42501';
  end if;

  -- Serializes all attempts for the same owner/binding, including the rolling
  -- submission cap and duplicate-score race.
  perform pg_advisory_xact_lock(hashtextextended(
    actor_uid::text || ':' || event_row.approved_binding_id::text,0));

  select * into grade_row from public.exam_reference_drill_grades g
    where g.event_id=p_event_id and g.owner_auth_uid=actor_uid;
  if found then
    return query select grade_row.drill_step,grade_row.is_correct,
      grade_row.scoring_version,grade_row.graded_at;
    return;
  end if;

  normalized_answer := lower(btrim(p_answer));
  if normalized_answer is null or length(normalized_answer) < 1
    or length(normalized_answer) > 80
    or normalized_answer !~ '^[a-z0-9][a-z0-9 _./:-]*$' then
    raise exception 'Invalid reference response token' using errcode='22023';
  end if;

  select k.* into key_row from public.exam_reference_drill_scoring_keys k
    join public.assessment_item_reference_validity b
      on b.id=k.approved_binding_id
    join public.exam_reference_manifest_revisions m
      on m.id=b.manifest_revision_id
    where k.approved_binding_id=event_row.approved_binding_id
      and k.publication_status='published'
      and k.review_status='approved'
      and k.rights_review_status='approved'
      and b.publication_status='published'
      and b.review_status='approved'
      and b.rights_review_status='approved'
      and b.assessment_item_id=event_row.assessment_item_id
      and b.manifest_revision_id=event_row.manifest_revision_id
      and b.item_content_revision=event_row.item_content_revision
      and b.answer_location_revision=event_row.answer_location_revision
      and b.item_content_sha256=
        public.exam_reference_item_fingerprint(b.assessment_item_id)
      and m.publication_status='published'
      and m.exam_part_key=event_row.exam_part_key
      and event_row.administration_date >= m.effective_from
      and (m.effective_until is null
        or event_row.administration_date <= m.effective_until);
  if not found then
    raise exception 'No approved scoring revision for this step'
      using errcode='42501';
  end if;

  if (select count(*) from public.exam_reference_drill_grades g
       where g.owner_auth_uid=actor_uid
         and g.approved_binding_id=event_row.approved_binding_id
         and g.graded_at > now()-interval '24 hours') >= 20 then
    raise exception 'Reference grading limit reached'
      using errcode='42501';
  end if;

  select exists(
    select 1
      from jsonb_array_elements_text(
        key_row.step_tokens -> event_row.drill_step
      ) as candidate(token)
      where candidate.token=normalized_answer
  ) into match_found;

  insert into public.exam_reference_drill_grades (
    event_id,owner_auth_uid,approved_binding_id,scoring_key_id,
    drill_step,is_correct,scoring_version
  ) values (
    event_row.id,actor_uid,event_row.approved_binding_id,key_row.id,
    event_row.drill_step,match_found,key_row.scoring_version
  ) returning * into grade_row;

  return query select grade_row.drill_step,grade_row.is_correct,
    grade_row.scoring_version,grade_row.graded_at;
end
$score$;

revoke all on function public.score_exam_reference_drill_step(uuid,text)
  from public,anon,authenticated;
grant execute on function public.score_exam_reference_drill_step(uuid,text)
  to authenticated;
