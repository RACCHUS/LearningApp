-- EXM-02B: cross-edition *presentation* of owner-read-only graded evidence
-- inside the existing Progress Current Context view.
-- Append-only migration; no automatic retention/deletion policy is assumed.
-- This is not a generic account export or an official exam-readiness metric.

create index exam_drill_events_owner_manifest_step_idx
  on public.exam_reference_drill_events
  (owner_auth_uid,manifest_revision_id,drill_step);

create function public.exam_reference_drill_context_progress(
  p_target_version_id uuid
)
returns table (
  manifest_revision_id uuid,
  exam_part_key text,
  manifest_revision integer,
  drill_step text,
  recorded_steps integer,
  graded_correct integer,
  graded_incorrect integer,
  awaiting_grade integer,
  skipped_steps integer,
  last_recorded_at timestamptz
)
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $progress$
declare
  actor_id uuid;
  n_groups integer;
begin
  actor_id := (select auth.uid());
  if actor_id is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false
     or p_target_version_id is null then
    raise exception 'Permanent account and exact target version required'
      using errcode='42501';
  end if;

  -- Count groups from the same owner-only base relations. Do not silently
  -- claim completeness if this scoped dashboard exceeds its safe bound.
  select count(*)::integer into n_groups
  from (
    select e.manifest_revision_id,e.drill_step
    from public.exam_reference_drill_events e
    join public.exam_reference_manifest_revisions m
      on m.id=e.manifest_revision_id
    where e.owner_auth_uid=actor_id
      and m.target_version_id=p_target_version_id
      and m.publication_status='published'
      and m.review_status='approved'
      and e.exam_part_key=m.exam_part_key
    group by e.manifest_revision_id,e.drill_step
  ) groups;
  if n_groups > 100 then
    raise exception 'Too many reference progress groups; use edition detail'
      using errcode='54000';
  end if;

  return query
  select m.id, m.exam_part_key, m.revision,
    e.drill_step,
    count(*)::integer,
    count(*) filter (where g.is_correct is true)::integer,
    count(*) filter (where g.is_correct is false)::integer,
    count(*) filter (where e.responded is true
      and g.is_correct is null)::integer,
    count(*) filter (where e.responded is false
      and g.is_correct is null)::integer,
    max(e.recorded_at)
  from public.exam_reference_drill_events e
  join public.exam_reference_manifest_revisions m
    on m.id=e.manifest_revision_id
  left join public.exam_reference_drill_grades g
    on g.event_id=e.id
   and g.owner_auth_uid=e.owner_auth_uid
   and g.approved_binding_id=e.approved_binding_id
   and g.drill_step=e.drill_step
  where e.owner_auth_uid=actor_id
    and m.target_version_id=p_target_version_id
    and m.publication_status='published'
    and m.review_status='approved'
    and e.exam_part_key=m.exam_part_key
  group by m.id,m.exam_part_key,m.revision,e.drill_step
  order by m.exam_part_key,m.revision desc,e.drill_step;
end
$progress$;

revoke all on function public.exam_reference_drill_context_progress(uuid)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_context_progress(uuid)
  to authenticated;
comment on function public.exam_reference_drill_context_progress(uuid) is
  'Owner-RLS, current-published-manifest-only R1–R4 aggregates per exact version and edition. No grading side effects or mastery projection.';
