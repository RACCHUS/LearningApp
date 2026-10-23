-- EXM-03: account-wide educational practice portability for bounded histories.
-- Never grants direct access to private assignments, scoring rubrics or responses.
-- This is a DRAFT migration only; no hosted SQL is changed by this commit.

-- Only an active permanent Supabase Auth session may export or erase.
create function public.exm03_portability_owner()
returns uuid language plpgsql stable security definer
set search_path=pg_catalog,public,pg_temp
as $owner$
declare
  v_owner uuid := (select auth.uid());
  v_session uuid;
begin
  if v_owner is null
     or (auth.jwt()->>'role') is distinct from 'authenticated'
     or (auth.jwt()->>'is_anonymous') is distinct from 'false'
     or coalesce(auth.jwt()->>'session_id','') !~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    raise exception 'A live permanent account session is required'
      using errcode='42501';
  end if;
  v_session := (auth.jwt()->>'session_id')::uuid;
  if not exists (select 1 from auth.sessions s
                 where s.id=v_session and s.user_id=v_owner
                 and (s.not_after is null or s.not_after>now())) then
    raise exception 'Practice portability session has ended'
      using errcode='42501';
  end if;
  return v_owner;
end
$owner$;
revoke all on function public.exm03_portability_owner()
  from public,anon,authenticated;

-- Existing R1-R4 events, newly graded receipts, pending assignments and
-- completed EXM-03 attempts all contribute to the same inventory token.
-- Fail closed beyond explicit bounds. Never call this a complete account
-- export of unrelated LearningApp data.
create function public.exm03_account_practice_inventory()
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

  if v_events>5000 or v_assignments>5000 then
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
    'bound_per_store',5000
  );
end
$inventory$;
revoke all on function public.exm03_account_practice_inventory()
  from public,anon,authenticated;
grant execute on function public.exm03_account_practice_inventory()
  to authenticated;

-- STABLE read: reference rows and EXM-03 rows come from the same statement
-- snapshot. The older EXM-02B archive alone does NOT include EXM-03.
create function public.exm03_account_practice_export()
returns jsonb language plpgsql stable security definer
set search_path=pg_catalog,public,pg_temp
as $export$
declare
  v_owner uuid := public.exm03_portability_owner();
  v_inventory jsonb;
  v_reference jsonb;
  v_parts jsonb;
begin
  v_inventory := public.exm03_account_practice_inventory();
  v_reference := public.exam_reference_drill_account_export(5000);
  select coalesce(jsonb_agg(jsonb_build_object(
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
  into v_parts
  from public.exam_part_practice_assignments a
  left join public.exam_part_practice_attempts t
    on t.assignment_id=a.id and t.owner_id=a.owner_id
  where a.owner_id=v_owner;

  if jsonb_array_length(v_parts)<>(v_inventory->>'part_assignments')::integer
     or (v_reference->>'record_count')::integer<>
         (v_inventory->>'reference_events')::integer then
    raise exception 'Practice export inventory changed during collection'
      using errcode='40001';
  end if;
  return jsonb_build_object(
    'format','learningapp-exm-combined-practice-v1',
    'scope','educational-practice-history-not-entire-account',
    'owner_id',v_owner,
    'generated_at',now(),
    'snapshot_consistency','single-stable-rpc-statement',
    'inventory',v_inventory,
    'reference_practice',v_reference,
    'part_practice',v_parts,
    'includes_unsubmitted_assignments',true,
    'official_exam_result',false
  );
end
$export$;
revoke all on function public.exm03_account_practice_export()
  from public,anon,authenticated;
grant execute on function public.exm03_account_practice_export()
  to authenticated;

-- Coordinate future R1-R4 inserts with this account's erasure lock.
-- Does not bypass existing RLS/validated-content trigger.
create function public.exm03_reference_insert_owner_lock()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,public,pg_temp
as $lock$
begin
  perform pg_advisory_xact_lock(
    hashtextextended(new.owner_auth_uid::text,61503));
  return new;
end
$lock$;
revoke all on function public.exm03_reference_insert_owner_lock()
  from public,anon,authenticated;
create trigger exm03_reference_insert_owner_lock
  before insert on public.exam_reference_drill_events
  for each row execute function public.exm03_reference_insert_owner_lock();

-- Caller must view a fresh inventory, review the counts and enter the
-- literal phrase. Entire SQL transaction rolls back if anything differs.
-- No automatic erasure, scheduling or retention TTL.
create function public.exm03_erase_account_practice(
  p_expected_events integer,
  p_expected_assignments integer,
  p_expected_attempts integer,
  p_expected_fingerprint text,
  p_confirmation text
)
returns jsonb language plpgsql volatile security definer
set search_path=pg_catalog,public,pg_temp
as $erase$
declare
  v_owner uuid := public.exm03_portability_owner();
  v_current jsonb;
  v_deleted_events integer;
  v_deleted_assignments integer;
  v_remaining_events bigint;
  v_remaining_assignments bigint;
  v_remaining_grades bigint;
  v_remaining_attempts bigint;
begin
  if p_confirmation is distinct from 'DELETE ALL EXAM PRACTICE'
     or p_expected_events is null or p_expected_events<0
     or p_expected_assignments is null or p_expected_assignments<0
     or p_expected_attempts is null or p_expected_attempts<0
     or coalesce(p_expected_fingerprint,'') !~ '^[a-f0-9]{32}$' then
    raise exception 'Preview and explicit practice-history confirmation required'
      using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_owner::text,61503));
  v_current := public.exm03_account_practice_inventory();
  if (v_current->>'reference_events')::integer<>p_expected_events
     or (v_current->>'part_assignments')::integer<>p_expected_assignments
     or (v_current->>'part_attempts')::integer<>p_expected_attempts
     or v_current->>'snapshot_fingerprint'<>p_expected_fingerprint then
    raise exception 'History changed; obtain and confirm a fresh inventory'
      using errcode='40001';
  end if;

  delete from public.exam_reference_drill_events e
    where e.owner_auth_uid=v_owner;
  get diagnostics v_deleted_events = row_count;
  delete from public.exam_part_practice_assignments a
    where a.owner_id=v_owner;
  get diagnostics v_deleted_assignments = row_count;
  if v_deleted_events<>p_expected_events
     or v_deleted_assignments<>p_expected_assignments then
    raise exception 'Incomplete practice deletion; all work rolled back'
      using errcode='40001';
  end if;

  select count(*) into v_remaining_events
    from public.exam_reference_drill_events where owner_auth_uid=v_owner;
  select count(*) into v_remaining_grades
    from public.exam_reference_drill_grades where owner_auth_uid=v_owner;
  select count(*) into v_remaining_assignments
    from public.exam_part_practice_assignments where owner_id=v_owner;
  select count(*) into v_remaining_attempts
    from public.exam_part_practice_attempts where owner_id=v_owner;
  if v_remaining_events<>0 or v_remaining_grades<>0
     or v_remaining_assignments<>0 or v_remaining_attempts<>0 then
    raise exception 'Dependent practice data remains; transaction rolled back'
      using errcode='40001';
  end if;
  perform public.exm03_portability_owner();
  return jsonb_build_object(
    'scope','exm-educational-practice-all-editions-v1',
    'owner_id',v_owner,
    'deleted_reference_events',v_deleted_events,
    'deleted_part_assignments',v_deleted_assignments,
    'remaining_reference_events',v_remaining_events,
    'remaining_reference_grades',v_remaining_grades,
    'remaining_part_assignments',v_remaining_assignments,
    'remaining_part_attempts',v_remaining_attempts,
    'irreversible',true
  );
end
$erase$;
revoke all on function public.exm03_erase_account_practice(integer,integer,integer,text,text)
  from public,anon,authenticated;
grant execute on function public.exm03_erase_account_practice(integer,integer,integer,text,text)
  to authenticated;

comment on function public.exm03_account_practice_export() is
 'Owner live-session, complete small-history archive of saved R1-R4 events/grades and EXM-03 assignments/attempts. 5000 per-store hard bound; private keys and responses excluded.';
comment on function public.exm03_erase_account_practice(integer,integer,integer,text,text) is
 'Explicit fingerprint-confirmed atomic erasure across R1-R4 reference events/grades and EXM-03 assignments/attempts. Disallows stale previews and oversized histories.';
