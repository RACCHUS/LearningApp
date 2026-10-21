-- EXM-02B: opt-in owner-only preview and erasure of SAVED reference
-- practice events across current and retired manifest editions.
-- No automatic retention timer or irreversible action is executed by migration.
-- Existing grade FK ON DELETE CASCADE removes derived grades automatically.

create function public.exam_reference_drill_erasure_preview()
returns jsonb
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $preview$
declare
  actor_uid uuid;
  ids uuid[];
  total integer;
  editions integer;
  graded integer;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  select array_agg(e.id order by e.id),count(*)::integer,
    count(distinct e.manifest_revision_id)::integer
    into ids,total,editions
    from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid;
  -- Explicitly cap new erasure workflow until large-account policy is
  -- approved; do not pretend a preview or action is complete above bound.
  if total > 5000 then
    raise exception 'Saved practice exceeds safe erasure limit'
      using errcode='54000';
  end if;
  select count(*)::integer into graded
    from public.exam_reference_drill_grades g
    join public.exam_reference_drill_events e on e.id=g.event_id
    where e.owner_auth_uid=actor_uid
      and g.owner_auth_uid=actor_uid;
  return jsonb_build_object(
    'scope','reference-practice-all-editions',
    'owner_auth_uid',actor_uid,
    'event_count',total,
    'graded_count',graded,
    'edition_count',editions,
    'snapshot_fingerprint',md5(coalesce(array_to_string(ids,','),''))
  );
end
$preview$;

create function public.exam_reference_drill_erase_owned(
  p_expected_count integer,
  p_expected_fingerprint text,
  p_confirmation text
)
returns jsonb
language plpgsql volatile security invoker
set search_path=pg_catalog,public,pg_temp
as $erase$
declare
  actor_uid uuid;
  selected_ids uuid[];
  selected_count integer;
  fingerprint text;
  removed_count integer;
  remaining_count integer;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  if p_confirmation is distinct from 'DELETE REFERENCE PRACTICE'
     or p_expected_count is null or p_expected_count < 1
     or p_expected_count > 5000
     or p_expected_fingerprint is null
     or p_expected_fingerprint !~ '^[a-f0-9]{32}$' then
    raise exception 'Explicit preview and exact deletion confirmation required'
      using errcode='22023';
  end if;

  -- SELECT ... FOR UPDATE freezes the *selected* owner rows. Only those exact
  -- IDs may be deleted; no new rows inserted during the request are swept up.
  -- Cross-request changes are checked against the preview's row fingerprint.
  select array_agg(selected.id order by selected.id),count(*)::integer
    into selected_ids,selected_count
    from (
      select e.id from public.exam_reference_drill_events e
      where e.owner_auth_uid=actor_uid
      order by e.id for update
    ) selected;
  if selected_count > 5000 then
    raise exception 'Saved practice exceeds safe erasure limit'
      using errcode='54000';
  end if;
  fingerprint := md5(coalesce(array_to_string(selected_ids,','),''));
  if selected_count <> p_expected_count
     or fingerprint <> p_expected_fingerprint then
    raise exception 'Saved practice changed; prepare a fresh preview'
      using errcode='P0001';
  end if;

  delete from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid and e.id=any(selected_ids);
  get diagnostics removed_count = row_count;
  if removed_count <> selected_count then
    raise exception 'Incomplete owner-practice erasure; transaction rolled back';
  end if;

  select count(*)::integer into remaining_count
    from public.exam_reference_drill_events e
    where e.owner_auth_uid=actor_uid;
  return jsonb_build_object(
    'scope','reference-practice-all-editions',
    'owner_auth_uid',actor_uid,
    'deleted_events',removed_count,
    'remaining_events',remaining_count
  );
end
$erase$;

revoke all on function public.exam_reference_drill_erasure_preview()
  from public,anon,authenticated;
revoke all on function public.exam_reference_drill_erase_owned(integer,text,text)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_erasure_preview()
  to authenticated;
grant execute on function public.exam_reference_drill_erase_owned(integer,text,text)
  to authenticated;

comment on function public.exam_reference_drill_erasure_preview() is
  'Owner-RLS saved event/grade inventory only. Fingerprint tracks the exact observed event ID set; no answer material.';
comment on function public.exam_reference_drill_erase_owned(integer,text,text) is
  'Explicit confirmed, owner-RLS deletion of exact previewed EXM step IDs; dependent grades cascade. Not whole account erasure or automated retention.';
