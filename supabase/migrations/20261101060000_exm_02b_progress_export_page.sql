-- EXM-02B: durable version-scoped Progress and owner-only data export page.
-- The invoker's ordinary SELECT grants + RLS on BOTH underlying tables are
-- mandatory; this function never reads reviewer keys or submitted responses.
-- Newly introduced migration; nothing applied to hosted production.

create index exam_drill_events_owner_manifest_cursor
on public.exam_reference_drill_events
  (owner_auth_uid,manifest_revision_id,recorded_at desc,id desc);

create function public.exam_reference_drill_progress_page(
  p_manifest_revision_id uuid,
  p_limit integer default 100,
  p_before_recorded_at timestamptz default null,
  p_before_event_id uuid default null
)
returns table (
  event_id uuid,
  owner_auth_uid uuid,
  client_attempt_id uuid,
  assessment_item_id uuid,
  approved_binding_id uuid,
  manifest_revision_id uuid,
  exam_part_key text,
  administration_date date,
  item_content_revision integer,
  answer_location_revision integer,
  drill_step text,
  responded boolean,
  app_elapsed_ms integer,
  self_reported_book_ms integer,
  started_at timestamptz,
  completed_at timestamptz,
  recorded_at timestamptz,
  verification_state text,
  is_correct boolean,
  scoring_version integer,
  graded_at timestamptz
)
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $body$
begin
  if (select auth.uid()) is null
    or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false
    or p_manifest_revision_id is null then
    raise exception 'Permanent account and exact reference edition required'
      using errcode='42501';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 100
     or (p_before_recorded_at is null) <> (p_before_event_id is null) then
    raise exception 'Invalid reference progress pagination'
      using errcode='22023';
  end if;

  return query
  select e.id, e.owner_auth_uid, e.client_attempt_id,
    e.assessment_item_id, e.approved_binding_id, e.manifest_revision_id,
    e.exam_part_key, e.administration_date, e.item_content_revision,
    e.answer_location_revision, e.drill_step, e.responded, e.app_elapsed_ms,
    e.self_reported_book_ms, e.started_at, e.completed_at, e.recorded_at,
    e.verification_state, g.is_correct, g.scoring_version, g.graded_at
  from public.exam_reference_drill_events e
  left join public.exam_reference_drill_grades g
    on g.event_id=e.id
   and g.owner_auth_uid=e.owner_auth_uid
   and g.approved_binding_id=e.approved_binding_id
   and g.drill_step=e.drill_step
  where e.owner_auth_uid=(select auth.uid())
    and e.manifest_revision_id=p_manifest_revision_id
    and (p_before_recorded_at is null
      or (e.recorded_at,e.id) < (p_before_recorded_at,p_before_event_id))
  order by e.recorded_at desc,e.id desc
  limit p_limit;
end
$body$;

revoke all on function public.exam_reference_drill_progress_page(
  uuid,integer,timestamptz,uuid
) from public,anon,authenticated;
grant execute on function public.exam_reference_drill_progress_page(
  uuid,integer,timestamptz,uuid
) to authenticated;
comment on function public.exam_reference_drill_progress_page(
  uuid,integer,timestamptz,uuid
) is 'RLS-invoker, deterministic owner-only R1-R4 evidence page; no private keys, raw answers or issuer score.';
