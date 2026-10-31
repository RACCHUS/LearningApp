-- EXM-03: verified 50k per-store inventory and private keyset page for
-- issued assignments.  This forward migration does not change prior files.
-- Combined export across separate requests must compare pre/post inventory
-- digests and reject partial collections.  50k remains an explicit hard cap.
create or replace function public.exm03_account_practice_inventory()
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,pg_temp
as $inventory$
declare
  v_owner uuid := public.exm03_portability_owner();
  v_events bigint;
  v_grades bigint;
  v_assignments bigint;
  v_attempts bigint;
  v_reference_digest text;
  v_part_digest text;
begin
  select count(*),count(g.event_id),
    md5(coalesce(string_agg(
      e.id::text||':'||coalesce(g.is_correct::text,'ungraded')||':'||
      coalesce(g.scoring_version::text,'none')||':'||
      coalesce(g.graded_at::text,'none'),
      ',' order by e.id),'')) into v_events,v_grades,v_reference_digest
  from public.exam_reference_drill_events e
  left join public.exam_reference_drill_grades g
    on g.event_id=e.id and g.owner_auth_uid=e.owner_auth_uid
    and g.approved_binding_id=e.approved_binding_id
    and g.drill_step=e.drill_step
  where e.owner_auth_uid=v_owner;

  select count(*),count(t.id),
    md5(coalesce(string_agg(
      a.id::text||':'||coalesce(t.id::text,'unscored')||':'||
      coalesce(t.response_sha256,'none')||':'||
      coalesce(t.practice_score::text,'none'),
      ',' order by a.id),'')) into v_assignments,v_attempts,v_part_digest
  from public.exam_part_practice_assignments a
  left join public.exam_part_practice_attempts t
    on t.assignment_id=a.id and t.owner_id=a.owner_id
  where a.owner_id=v_owner;

  if v_events>50000 or v_assignments>50000 then
    raise exception 'Combined export/erasure size exceeds reviewed bound'
      using errcode='54000';
  end if;
  return jsonb_build_object(
    'scope','exm-educational-practice-all-editions-v1',
    'owner_id',v_owner,
    'reference_events',v_events,
    'reference_grades',v_grades,
    'part_assignments',v_assignments,
    'part_attempts',v_attempts,
    'snapshot_fingerprint',md5(
      v_owner::text||':'||v_reference_digest||':'||v_part_digest),
    'bound_per_store',50000
  );
end
$inventory$;
comment on function public.exm03_account_practice_inventory() is
 'Authenticated, live-session owner inventory across graded R1-R4 and assigned EXM-03 practice; 50k per store bound, stable fingerprint.';

create index if not exists exm03_assignment_owner_page_idx
  on public.exam_part_practice_assignments(owner_id,issued_at desc,id desc);

create function public.exm03_account_part_export_page(
  p_limit integer default 250,
  p_before_issued_at timestamptz default null,
  p_before_assignment_id uuid default null
)
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,pg_temp
as $page$
declare
  v_owner uuid := public.exm03_portability_owner();
  v_rows jsonb;
  v_count integer;
begin
  if p_limit is null or p_limit<1 or p_limit>250
     or (p_before_issued_at is null) <> (p_before_assignment_id is null) then
    raise exception 'Invalid EXM assignment export page cursor'
      using errcode='22023';
  end if;

  select count(*)::integer,coalesce(jsonb_agg(jsonb_build_object(
    'assignment_id',a.id,
    'target_id',a.target_id,
    'target_version_id',a.target_version_id,
    'exam_part_key',a.exam_part_key,
    'curriculum_root_node_id',a.curriculum_root_node_id,
    'manifest_revision_id',a.manifest_revision_id,
    'practice_kind',a.practice_kind,
    'issued_at',a.issued_at,
    'expires_at',a.expires_at,
    'attempt',case when t.id is null then null else jsonb_build_object(
      'attempt_id',t.id,
      'completed_at',t.completed_at,
      'question_count',t.question_count,
      'fully_correct_count',t.fully_correct_count,
      'partial_count',t.partial_count,
      'practice_score',t.practice_score,
      'question_edition_fingerprint',t.question_edition_fingerprint,
      'official_exam_result',false
    ) end
  ) order by a.issued_at desc,a.id desc),'[]'::jsonb)
  into v_count,v_rows
  from (
    select *
    from public.exam_part_practice_assignments x
    where x.owner_id=v_owner
      and (p_before_issued_at is null
        or (x.issued_at,x.id)<(p_before_issued_at,p_before_assignment_id))
    order by x.issued_at desc,x.id desc
    limit p_limit
  ) a
  left join public.exam_part_practice_attempts t
    on t.assignment_id=a.id and t.owner_id=a.owner_id;

  perform public.exm03_portability_owner();
  return jsonb_build_object(
    'scope','exm-educational-practice-all-editions-v1',
    'owner_id',v_owner,
    'row_count',v_count,
    'rows',v_rows
  );
end
$page$;
revoke all on function public.exm03_account_part_export_page(integer,timestamptz,uuid)
  from public,anon,authenticated;
grant execute on function public.exm03_account_part_export_page(integer,timestamptz,uuid)
  to authenticated;
comment on function public.exm03_account_part_export_page(integer,timestamptz,uuid) is
 'Private, permanent live-session owner-scoped EXM-03 assignment + scored summary page (<=250); no answers, item lists, session data or scoring tokens.';
