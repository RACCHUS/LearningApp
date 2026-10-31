-- EXM-02B: explicitly approved bounded erasure for large saved histories.
-- No automatic retention, background job, UPDATE privilege or scheduler.
-- The learner must re-preview and reconfirm EACH batch; 1,000 max per call.
-- This adds new RPCs without changing the previously reviewed ones.

create function public.exam_reference_drill_batch_erasure_preview(
  p_batch_limit integer default 1000
)
returns jsonb
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $preview$
declare
  actor_uid uuid;
  all_count bigint;
  selected_ids uuid[];
  batch_count integer;
  batch_editions integer;
  batch_grades integer;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  if p_batch_limit is null or p_batch_limit < 1 or p_batch_limit > 1000 then
    raise exception 'Batch size must be between 1 and 1000'
      using errcode='22023';
  end if;

  select count(*) into all_count
    from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid;

  select array_agg(batch.id order by batch.id),
      count(*)::integer,count(distinct batch.manifest_revision_id)::integer
    into selected_ids,batch_count,batch_editions
    from (
      select e.id,e.manifest_revision_id
      from public.exam_reference_drill_events e
      where e.owner_auth_uid=actor_uid
      order by e.id
      limit p_batch_limit
    ) batch;
  select count(*)::integer into batch_grades
    from public.exam_reference_drill_grades g
    where g.owner_auth_uid=actor_uid and g.event_id=any(selected_ids);

  return jsonb_build_object(
    'scope','reference-practice-next-batch',
    'owner_auth_uid',actor_uid,
    'total_events',all_count,
    'batch_events',batch_count,
    'batch_grades',batch_grades,
    'batch_editions',batch_editions,
    'batch_limit',p_batch_limit,
    'batch_fingerprint',md5(coalesce(array_to_string(selected_ids,','),''))
  );
end
$preview$;

create function public.exam_reference_drill_erase_batch(
  p_batch_limit integer,
  p_expected_count integer,
  p_expected_fingerprint text,
  p_confirmation text
)
returns jsonb
language plpgsql volatile security invoker
set search_path=pg_catalog,public,pg_temp
as $delete$
declare
  actor_uid uuid;
  selected_ids uuid[];
  selected_count integer;
  removed_count integer;
  remaining_count bigint;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  if p_confirmation is distinct from 'DELETE NEXT BATCH'
     or p_batch_limit is null or p_batch_limit < 1 or p_batch_limit > 1000
     or p_expected_count is null or p_expected_count < 1
     or p_expected_count > p_batch_limit
     or p_expected_fingerprint is null
     or p_expected_fingerprint !~ '^[a-f0-9]{32}$' then
    raise exception 'Exact batch preview and confirmation required'
      using errcode='22023';
  end if;

  -- Select a bounded, deterministic ID set with owner RLS (no FOR UPDATE,
  -- which would require forbidden client UPDATE privilege). New inserts are
  -- never swept into this ID set. DELETE row locks and a strict rowcount
  -- assertion enforce rollback on concurrent removals.
  select array_agg(batch.id order by batch.id),count(*)::integer
    into selected_ids,selected_count
    from (
      select e.id
      from public.exam_reference_drill_events e
      where e.owner_auth_uid=actor_uid
      order by e.id
      limit p_batch_limit
    ) batch;
  if selected_count <> p_expected_count
     or md5(coalesce(array_to_string(selected_ids,','),'')) <>
       p_expected_fingerprint then
    raise exception 'Batch changed; refresh the preview before deleting'
      using errcode='P0001';
  end if;

  delete from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid and e.id=any(selected_ids);
  get diagnostics removed_count = row_count;
  if removed_count <> selected_count then
    raise exception 'Incomplete batch deletion; transaction rolled back'
      using errcode='P0001';
  end if;
  select count(*) into remaining_count
    from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid;
  return jsonb_build_object(
    'scope','reference-practice-next-batch',
    'owner_auth_uid',actor_uid,
    'deleted_events',removed_count,
    'remaining_events',remaining_count
  );
end
$delete$;

revoke all on function public.exam_reference_drill_batch_erasure_preview(integer)
  from public,anon,authenticated;
revoke all on function public.exam_reference_drill_erase_batch(integer,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_batch_erasure_preview(integer)
  to authenticated;
grant execute on function public.exam_reference_drill_erase_batch(integer,integer,text,text)
  to authenticated;

comment on function public.exam_reference_drill_batch_erasure_preview(integer) is
 'RLS owner-only preview of next deterministic 1–1000 saved EXM steps, including retired editions. No automatic erasure.';
comment on function public.exam_reference_drill_erase_batch(integer,integer,text,text) is
 'Explicit RLS owner-only, fingerprint-checked deletion of exactly one previewed step batch. Re-preview and re-confirm every subsequent batch.';
