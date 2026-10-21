-- EXM-02B: verified bounded multi-request export for >5,000 saved events.
-- Existing single-statement export stays untouched. No answer keys, client
-- response tokens, new persistence tables, retention rules or service roles.
-- A double inventory digest detects changed event IDs and newly scored grades
-- across cursor-page requests; it is NOT one MVCC snapshot across requests.
-- All functions are SECURITY INVOKER with pre-existing owner SELECT RLS.
create function public.exam_reference_drill_export_inventory()
returns jsonb
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $inventory$
declare
  actor_uid uuid;
  n bigint;
  fingerprint text;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  select count(*),
     md5(coalesce(string_agg(
       e.id::text || ':' ||
       coalesce(g.is_correct::text, 'unscored') || ':' ||
       coalesce(g.scoring_version::text, 'none') || ':' ||
       coalesce(extract(epoch from g.graded_at)::text, 'none'),
       ',' order by e.recorded_at desc,e.id desc
     ),''))
    into n,fingerprint
    from public.exam_reference_drill_events e
    left join public.exam_reference_drill_grades g
      on g.event_id=e.id
     and g.owner_auth_uid=e.owner_auth_uid
     and g.approved_binding_id=e.approved_binding_id
     and g.drill_step=e.drill_step
   where e.owner_auth_uid=actor_uid;

  -- This is a product/client-size bound, not a retention deletion trigger.
  if n > 50000 then
    raise exception 'Reference history exceeds current verified export bound'
      using errcode='54000';
  end if;
  return jsonb_build_object(
    'scope','reference-practice-all-editions',
    'owner_auth_uid',actor_uid,
    'record_count',n,
    'record_fingerprint',fingerprint,
    'verification','pre-and-post-inventory-digest-v1'
  );
end
$inventory$;

create function public.exam_reference_drill_export_page(
  p_limit integer default 250,
  p_before_recorded_at timestamptz default null,
  p_before_event_id uuid default null
)
returns jsonb
language plpgsql stable security invoker
set search_path=pg_catalog,public,pg_temp
as $page$
declare
  actor_uid uuid;
  records jsonb;
  row_count integer;
begin
  actor_uid := (select auth.uid());
  if actor_uid is null
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false then
    raise exception 'Permanent owner sign-in required'
      using errcode='42501';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 250 or
     (p_before_recorded_at is null) <> (p_before_event_id is null) then
    raise exception 'Invalid exact export cursor/limit'
      using errcode='22023';
  end if;

  select count(*)::integer,coalesce(jsonb_agg(
       jsonb_build_object(
         'event_id',e.id,'owner_auth_uid',e.owner_auth_uid,
         'client_attempt_id',e.client_attempt_id,
         'assessment_item_id',e.assessment_item_id,
         'approved_binding_id',e.approved_binding_id,
         'manifest_revision_id',e.manifest_revision_id,
         'exam_part_key',e.exam_part_key,
         'administration_date',e.administration_date,
         'item_content_revision',e.item_content_revision,
         'answer_location_revision',e.answer_location_revision,
         'drill_step',e.drill_step,'responded',e.responded,
         'app_elapsed_ms',e.app_elapsed_ms,
         'self_reported_book_ms',e.self_reported_book_ms,
         'started_at',e.started_at,'completed_at',e.completed_at,
         'recorded_at',e.recorded_at,
         'verification_state',e.verification_state,
         'is_correct',g.is_correct,
         'scoring_version',g.scoring_version,
         'graded_at',g.graded_at
       ) order by e.recorded_at desc,e.id desc),'[]'::jsonb)
   into row_count,records
   from (
     select *
     from public.exam_reference_drill_events x
     where x.owner_auth_uid=actor_uid
       and (p_before_recorded_at is null or
         (x.recorded_at,x.id) < (p_before_recorded_at,p_before_event_id))
     order by x.recorded_at desc,x.id desc
     limit p_limit
   ) e
   left join public.exam_reference_drill_grades g
     on g.event_id=e.id
    and g.owner_auth_uid=e.owner_auth_uid
    and g.approved_binding_id=e.approved_binding_id
    and g.drill_step=e.drill_step;
  return jsonb_build_object(
    'scope','reference-practice-all-editions',
    'owner_auth_uid',actor_uid,
    'row_count',row_count,
    'rows',records
  );
end
$page$;

revoke all on function public.exam_reference_drill_export_inventory()
  from public,anon,authenticated;
revoke all on function public.exam_reference_drill_export_page(integer,timestamptz,uuid)
  from public,anon,authenticated;
grant execute on function public.exam_reference_drill_export_inventory()
  to authenticated;
grant execute on function public.exam_reference_drill_export_page(integer,timestamptz,uuid)
  to authenticated;
comment on function public.exam_reference_drill_export_inventory() is
 'Owner-RLS bounded 50k all-edition step inventory and grade-state fingerprint for pre/post verified export.';
comment on function public.exam_reference_drill_export_page(integer,timestamptz,uuid) is
 'Owner-RLS 250-row keyset page of public EXM event+server grade fields; no scoring keys/reviewer data.';
