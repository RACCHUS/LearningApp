-- EXM-02B: one-statement, owner-only account-wide R1–R4 evidence export.
-- This covers saved reference-practice events across ALL original and retired
-- manifest revisions. It is NOT an export of the learner's entire LearningApp
-- account. No retention interval or automatic purging is instituted here.
-- Client answers, private correct tokens and reviewer records are never read.

create function public.exam_reference_drill_account_export(
  p_max_records integer default 5000
)
returns jsonb
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $export$
declare
  actor_uid uuid;
  record_count integer;
  clean_steps jsonb;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent sign-in required for private practice export'
      using errcode='42501';
  end if;
  if p_max_records is null or p_max_records < 1 or p_max_records > 5000 then
    raise exception 'Invalid reference-practice export bound'
      using errcode='22023';
  end if;

  -- A single bounded database statement makes deletion/grade reads share
  -- the same MVCC snapshot, unlike a sequence of cursor-page network RPCs.
  -- SECURITY INVOKER and ordinary SELECT+RLS on both relations are required.
  with bounded as materialized (
    select e.id,e.owner_auth_uid,e.client_attempt_id,
      e.assessment_item_id,e.approved_binding_id,e.manifest_revision_id,
      e.exam_part_key,e.administration_date,e.item_content_revision,
      e.answer_location_revision,e.drill_step,e.responded,e.app_elapsed_ms,
      e.self_reported_book_ms,e.started_at,e.completed_at,e.recorded_at,
      e.verification_state
    from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid
    order by e.recorded_at desc,e.id desc
    limit p_max_records + 1
  )
  select count(*)::integer,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_id',e.id,
          'owner_auth_uid',e.owner_auth_uid,
          'client_attempt_id',e.client_attempt_id,
          'assessment_item_id',e.assessment_item_id,
          'approved_binding_id',e.approved_binding_id,
          'manifest_revision_id',e.manifest_revision_id,
          'exam_part_key',e.exam_part_key,
          'administration_date',e.administration_date,
          'item_content_revision',e.item_content_revision,
          'answer_location_revision',e.answer_location_revision,
          'drill_step',e.drill_step,
          'responded',e.responded,
          'app_elapsed_ms',e.app_elapsed_ms,
          'self_reported_book_ms',e.self_reported_book_ms,
          'started_at',e.started_at,
          'completed_at',e.completed_at,
          'recorded_at',e.recorded_at,
          'verification_state',e.verification_state,
          'is_correct',g.is_correct,
          'scoring_version',g.scoring_version,
          'graded_at',g.graded_at
        ) order by e.recorded_at desc,e.id desc
      ),'[]'::jsonb
    )
  into record_count,clean_steps
  from bounded e
  left join public.exam_reference_drill_grades g
    on g.event_id=e.id
   and g.owner_auth_uid=e.owner_auth_uid
   and g.approved_binding_id=e.approved_binding_id
   and g.drill_step=e.drill_step;

  if record_count > p_max_records then
    raise exception 'Reference practice export exceeds the safe record bound'
      using errcode='54000';
  end if;

  return jsonb_build_object(
    'format','learningapp-exm-reference-practice-account-v1',
    'scope','reference-practice-all-editions',
    'owner_auth_uid',actor_uid,
    'record_count',record_count,
    'generated_at',now(),
    'snapshot_consistency','single-sql-statement',
    'steps',clean_steps
  );
end
$export$;

revoke all on function public.exam_reference_drill_account_export(integer)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_account_export(integer)
  to authenticated;
comment on function public.exam_reference_drill_account_export(integer) is
  'Owner-RLS one-statement reference-practice export, all saved manifest revisions, 5000-event cap. No submitted answers, private rubrics or reviewer material.';
