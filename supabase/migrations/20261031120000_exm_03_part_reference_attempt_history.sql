-- EXM-03: read-only, owner-scoped historical reference-drill attempts.
-- Reuses EXM-02B immutable step events and server-owned grades. Does NOT
-- create a parallel assessment store, implicit retention schedule, or copy
-- raw answers, private editorial rubrics, client response tokens or book use.
-- Existing EXM-02B whole-account export + explicit owner erasure already cover
-- every underlying R1-R4 event. No hosted migrations are run by this commit.

create index exam_drill_owner_part_attempt_history
on public.exam_reference_drill_events
  (owner_auth_uid,exam_part_key,client_attempt_id,recorded_at desc);

create function public.exam_reference_drill_part_attempt_history(
  p_target_version_id uuid,
  p_exam_part_key text,
  p_limit integer default 20,
  p_before_last_at timestamptz default null,
  p_before_attempt_id uuid default null
)
returns table (
  owner_auth_uid uuid,
  target_version_id uuid,
  exam_part_key text,
  client_attempt_id uuid,
  manifest_revision_id uuid,
  manifest_revision integer,
  assessment_item_id uuid,
  approved_binding_id uuid,
  administration_date date,
  recorded_steps integer,
  graded_correct integer,
  graded_incorrect integer,
  awaiting_grade integer,
  skipped_steps integer,
  first_recorded_at timestamptz,
  last_recorded_at timestamptz,
  completed_four_steps boolean
)
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $history$
declare
  actor_uid uuid;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false
  then
    raise exception 'Permanent owner sign-in required for practice history'
      using errcode='42501';
  end if;
  if p_target_version_id is null
     or p_exam_part_key is null
     or p_exam_part_key !~ '^[a-z][a-z0-9_]*$'
     or length(p_exam_part_key) > 128
     or p_limit is null or p_limit < 1 or p_limit > 50
     or (p_before_last_at is null) <> (p_before_attempt_id is null)
  then
    raise exception 'Exact version/part and bounded attempt cursor required'
      using errcode='22023';
  end if;

  -- Every row is derived from existing immutable owner RLS evidence. A
  -- recorded four-stage drill means exactly four accepted unique R1-R4
  -- observations, not four correct answers or an official exam attempt.
  -- Only currently published/reviewed reference editions are displayed.
  return query
  with attempts as (
    select e.owner_auth_uid as owner_id,
      m.target_version_id as version_id,
      e.exam_part_key as part_id,
      e.client_attempt_id as attempt_id,
      m.id as edition_id, m.revision as edition_revision,
      e.assessment_item_id as item_id,
      e.approved_binding_id as binding_id,
      e.administration_date as exam_date,
      count(*)::integer as step_count,
      count(*) filter (where g.is_correct is true)::integer as correct_count,
      count(*) filter (where g.is_correct is false)::integer as incorrect_count,
      count(*) filter (where e.responded is true
                       and g.is_correct is null)::integer as awaiting_count,
      count(*) filter (where e.responded is false
                       and g.is_correct is null)::integer as skipped_count,
      min(e.recorded_at) as first_at,
      max(e.recorded_at) as last_at
    from public.exam_reference_drill_events e
    join public.exam_reference_manifest_revisions m
      on m.id=e.manifest_revision_id
    left join public.exam_reference_drill_grades g
      on g.event_id=e.id
     and g.owner_auth_uid=e.owner_auth_uid
     and g.approved_binding_id=e.approved_binding_id
     and g.drill_step=e.drill_step
    where e.owner_auth_uid=actor_uid
      and m.target_version_id=p_target_version_id
      and e.exam_part_key=p_exam_part_key
      and m.exam_part_key=p_exam_part_key
      and m.publication_status='published'
      and m.review_status='approved'
    group by e.owner_auth_uid,m.target_version_id,e.exam_part_key,
      e.client_attempt_id,m.id,m.revision,e.assessment_item_id,
      e.approved_binding_id,e.administration_date
  )
  select a.owner_id,a.version_id,a.part_id,a.attempt_id,
    a.edition_id,a.edition_revision,a.item_id,a.binding_id,a.exam_date,
    a.step_count,a.correct_count,a.incorrect_count,a.awaiting_count,
    a.skipped_count,a.first_at,a.last_at,(a.step_count=4)
  from attempts a
  where (p_before_last_at is null
    or (a.last_at,a.attempt_id)<(p_before_last_at,p_before_attempt_id))
  order by a.last_at desc,a.attempt_id desc
  limit p_limit;
end
$history$;

revoke all on function public.exam_reference_drill_part_attempt_history(
  uuid,text,integer,timestamptz,uuid
) from public,anon,authenticated;
grant execute on function public.exam_reference_drill_part_attempt_history(
  uuid,text,integer,timestamptz,uuid
) to authenticated;
comment on function public.exam_reference_drill_part_attempt_history(
  uuid,text,integer,timestamptz,uuid
) is 'Owner-RLS, permanent account, bounded latest attempt summaries of currently reviewed EXM R1-R4 reference drills. Four recorded steps != official examination; no raw answers or private key access. Underlying events support existing export and erasure.';
