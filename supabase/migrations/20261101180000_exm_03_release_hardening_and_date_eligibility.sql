-- =============================================================================
-- Migration 81: EXM-03 Release Hardening, Date-Specific Eligibility & RLS Defenses
--
-- Remediates release gates:
-- 1. Binds assigned practice issuance and canonical scoring to the learner's actual
--    exam administration date, replacing invalid current_date assumptions.
-- 2. Hardens public.exm03_has_protected_binding so retired approved items permanently
--    retain restrictive RLS answer-key protection against client SELECT('*').
-- 3. Revokes unauthenticated and authenticated execute privileges from the unconfirmed
--    exm03_erase_part_attempts RPC; user erasure must proceed via exm03_erase_account_practice.
-- 4. Introduces usage_role ('practice_pool', 'held_out_transfer', 'selection_probe')
--    on assessment_item_reference_validity and strictly excludes held-out items
--    from ordinary learner practice issuance.
-- 5. Includes administration_date in assignment records and export pages.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Add administration_date to exam_part_practice_assignments
-- -----------------------------------------------------------------------------
alter table public.exam_part_practice_assignments
  add column if not exists administration_date date;

update public.exam_part_practice_assignments
  set administration_date = coalesce(administration_date, (issued_at at time zone 'UTC')::date, current_date)
  where administration_date is null;

alter table public.exam_part_practice_assignments
  alter column administration_date set not null;

create index if not exists exm03_assignment_admin_date_idx
  on public.exam_part_practice_assignments (target_version_id, exam_part_key, administration_date);

-- -----------------------------------------------------------------------------
-- 2. Add usage_role to assessment_item_reference_validity
-- -----------------------------------------------------------------------------
alter table public.assessment_item_reference_validity
  add column if not exists usage_role text not null default 'practice_pool'
    check (usage_role in ('practice_pool', 'held_out_transfer', 'selection_probe'));

create index if not exists exm02a_validity_usage_role_idx
  on public.assessment_item_reference_validity (manifest_revision_id, publication_status, usage_role);

comment on column public.assessment_item_reference_validity.usage_role is
  'Differentiates practice pool items from held-out transfer probes and nonproduction selection probes.';

-- -----------------------------------------------------------------------------
-- 3. Harden exm03_has_protected_binding for Retired Items
-- -----------------------------------------------------------------------------
create or replace function public.exm03_has_protected_binding(p_item_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,pg_temp
as $private$
  select exists (
    select 1 from public.assessment_item_reference_validity b
    where b.assessment_item_id=p_item_id
      and b.publication_status in ('published', 'retired')
      and b.review_status='approved'
      and b.rights_review_status='approved'
  );
$private$;

revoke all on function public.exm03_has_protected_binding(uuid)
  from public,anon,authenticated;
grant execute on function public.exm03_has_protected_binding(uuid)
  to anon,authenticated;

comment on function public.exm03_has_protected_binding(uuid) is
  'Returns true if item has an approved published OR retired reference binding. Restrictive RLS uses this to permanently protect scoring_spec from direct client reads.';

-- -----------------------------------------------------------------------------
-- 4. Revoke Authenticated Execute from Unconfirmed exm03_erase_part_attempts
-- -----------------------------------------------------------------------------
revoke all on function public.exm03_erase_part_attempts(uuid,text)
  from public,anon,authenticated;
grant execute on function public.exm03_erase_part_attempts(uuid,text)
  to service_role;

comment on function public.exm03_erase_part_attempts(uuid,text) is
  'Service-role only internal or administrative erasure. Learner client erasure must proceed through exm03_erase_account_practice with session validation, advisory locking, confirmation phrase, and fingerprint verification.';

-- -----------------------------------------------------------------------------
-- 5. Replace exm03_issue_assigned_practice with Date-Specific Signature
-- -----------------------------------------------------------------------------
drop function if exists public.exm03_issue_assigned_practice(uuid,text);

create or replace function public.exm03_issue_assigned_practice(
  p_target_version_id uuid,
  p_exam_part_key text,
  p_administration_date date
)
returns jsonb
language plpgsql volatile security definer
set search_path=pg_catalog,public,pg_temp
as $issue$
declare
  actor_id uuid;
  session_id uuid;
  profile jsonb;
  v_target_id uuid;
  v_root uuid;
  v_manifest uuid;
  v_count integer;
  v_distinct_concepts integer;
  v_assigned jsonb;
  v_visible jsonb;
  v_assignment uuid;
  v_expiry timestamptz;
begin
  -- PostgREST validates the JWT signature; the issuer additionally checks
  -- permanent-account status and the exact still-live Auth session.
  actor_id := (select auth.uid());
  if actor_id is null
     or (select auth.jwt()->>'role') is distinct from 'authenticated'
     or (select (auth.jwt()->>'is_anonymous')::boolean) is distinct from false
     or nullif(auth.jwt()->>'session_id','') is null
     or (auth.jwt()->>'session_id') !~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     or p_target_version_id is null
     or p_exam_part_key is null
     or p_exam_part_key !~ '^[a-z][a-z0-9_]{0,127}$'
     or p_administration_date is null then
    raise exception 'Permanent authenticated session, exact part, and administration date required'
      using errcode='42501';
  end if;
  session_id := (auth.jwt()->>'session_id')::uuid;
  if not exists (
    select 1 from auth.sessions s
    where s.id=session_id and s.user_id=actor_id
      and (s.not_after is null or s.not_after > now())
  ) then
    raise exception 'Authentication session is no longer active'
      using errcode='42501';
  end if;

  select v.target_id,v.metadata into v_target_id,profile
  from public.target_versions v
  join public.learning_targets t on t.id=v.target_id
  where v.id=p_target_version_id
    and v.status='published'
    and t.status='published'
    and t.is_public=true;
  if v_target_id is null
     or jsonb_typeof(profile->'exam_preparation'->'exam_parts')
         is distinct from 'array' then
    raise exception 'Published version with configured parts required'
      using errcode='42501';
  end if;
  if (select count(*) from jsonb_array_elements(
        profile->'exam_preparation'->'exam_parts') as part(value)
      where part.value->>'key'=p_exam_part_key) <> 1 then
    raise exception 'Exactly one configured exam-part key required'
      using errcode='42501';
  end if;

  select cn.id into v_root
  from jsonb_array_elements(profile->'exam_preparation'->'exam_parts')
    as part(value)
  join public.curriculum_nodes cn
    on cn.id::text=part.value->>'curriculum_root_node_id'
   and cn.target_version_id=p_target_version_id
  where part.value->>'key'=p_exam_part_key;
  if v_root is null then
    raise exception 'Exam part root must belong to this version'
      using errcode='42501';
  end if;

  -- Select manifest effective on the learner's actual administration date, NOT current_date.
  select m.id into v_manifest
  from public.exam_reference_manifest_revisions m
  where m.target_version_id=p_target_version_id
    and m.exam_part_key=p_exam_part_key
    and m.publication_status='published'
    and m.review_status='approved'
    and p_administration_date >= m.effective_from
    and (m.effective_until is null or p_administration_date <= m.effective_until)
  order by m.revision desc
  limit 1;
  if v_manifest is null then
    raise exception 'No effective approved reference manifest for part on requested administration date'
      using errcode='42501';
  end if;

  -- Per-owner advisory lock prevents concurrent issuance from outrunning
  -- the quota. Failed issuance rolls everything back without leaking keys.
  perform pg_advisory_xact_lock(hashtextextended(actor_id::text, 61503));
  select count(*) into v_count
  from public.exam_part_practice_assignments a
  where a.owner_id=actor_id and a.issued_at>now()-interval '24 hours';
  if v_count>=12 then
    raise exception 'Practice issuance quota reached'
      using errcode='42501';
  end if;
  select count(*) into v_count
  from public.exam_part_practice_assignments a
  where a.owner_id=actor_id
    and a.expires_at>now()
    and not exists (
      select 1 from public.exam_part_practice_attempts t
      where t.assignment_id=a.id
    );
  if v_count>=2 then
    raise exception 'Finish or expire existing practice assignments first'
      using errcode='42501';
  end if;

  -- Bounded loop to assemble 6 single-choice items spanning >= 3 core concepts.
  -- Excludes held-out transfer probes and selection probes (usage_role must be 'practice_pool').
  for v_attempt in 1..20 loop
    with recursive part_nodes(id) as (
      select v_root
      union
      select n.id from public.curriculum_nodes n
      join part_nodes p on n.parent_id=p.id
      where n.target_version_id=p_target_version_id
    ),
    eligible as (
      select i.id, public.exam_reference_item_fingerprint(i.id) as sha
      from public.assessment_items i
      join public.assessment_item_reference_validity b
        on b.assessment_item_id=i.id
       and b.manifest_revision_id=v_manifest
       and b.publication_status='published'
       and b.review_status='approved'
       and b.rights_review_status='approved'
       and b.usage_role='practice_pool'
      where i.origin_target_version_id=p_target_version_id
        and i.interaction_type='single_choice'
        and i.response_spec ? 'options'
        and jsonb_typeof(i.response_spec->'options')='array'
        and jsonb_array_length(i.response_spec->'options') between 2 and 10
        and i.scoring_spec ? 'correct_index'
        and jsonb_typeof(i.scoring_spec->'correct_index')='number'
        and (i.scoring_spec->>'correct_index') ~ '^[0-9]+$'
        and (i.scoring_spec->>'correct_index')::integer
              < jsonb_array_length(i.response_spec->'options')
        and b.item_content_sha256 =
              public.exam_reference_item_fingerprint(i.id)
        and exists (
          select 1 from public.assessment_item_concepts ic
          where ic.assessment_item_id=i.id
            and exists (
              select 1 from public.curriculum_node_concepts nc
              where nc.concept_id=ic.concept_id and nc.relevance='core'
                and nc.curriculum_node_id in (select id from part_nodes)
            )
        )
        and not exists (
          select 1 from public.assessment_item_concepts ic
          where ic.assessment_item_id=i.id
            and (
              not exists (
                select 1 from public.curriculum_node_concepts nc
                where nc.concept_id=ic.concept_id and nc.relevance='core'
                  and nc.curriculum_node_id in (select id from part_nodes)
              ) or exists (
                select 1 from public.curriculum_node_concepts nc
                join public.curriculum_nodes outsider
                  on outsider.id=nc.curriculum_node_id
                where nc.concept_id=ic.concept_id
                  and outsider.target_version_id=p_target_version_id
                  and outsider.id not in (select id from part_nodes)
              )
            )
        )
      group by i.id
    ),
    selection as (
      select id,sha from eligible order by random() limit 6
    )
    select jsonb_agg(jsonb_build_object('id',id,'sha256',sha)
                     order by id),
           count(*) into v_assigned,v_count
    from selection;

    if v_count<>6 then
      raise exception 'Not enough verified part-specific questions'
        using errcode='42501';
    end if;
    select count(distinct ic.concept_id) into v_distinct_concepts
    from jsonb_array_elements(v_assigned) as chosen(value)
    join public.assessment_item_concepts ic
      on ic.assessment_item_id=(chosen.value->>'id')::uuid;
    exit when v_distinct_concepts>=3;
  end loop;
  if v_distinct_concepts<3 then
    raise exception 'Part practice requires three distinct core concepts'
      using errcode='42501';
  end if;

  v_expiry := now()+interval '90 minutes';
  insert into public.exam_part_practice_assignments (
    owner_id,target_id,target_version_id,exam_part_key,
    curriculum_root_node_id,manifest_revision_id,practice_kind,
    assigned_items,issued_at,expires_at,administration_date
  ) values (
    actor_id,v_target_id,p_target_version_id,p_exam_part_key,
    v_root,v_manifest,'diagnostic',
    v_assigned,now(),v_expiry,p_administration_date
  ) returning id into v_assignment;

  select jsonb_agg(jsonb_build_object(
    'id',i.id,
    'interaction_type',i.interaction_type,
    'prompt',i.prompt,
    'response_spec',jsonb_build_object('options',i.response_spec->'options')
  ) order by chosen.ordinality)
  into v_visible
  from jsonb_array_elements(v_assigned) with ordinality as chosen(value, ordinality)
  join public.assessment_items i
    on i.id=(chosen.value->>'id')::uuid;

  return jsonb_build_object(
    'assignment_id',v_assignment,
    'target_version_id',p_target_version_id,
    'exam_part_key',p_exam_part_key,
    'administration_date',p_administration_date::text,
    'expires_at',v_expiry,
    'practice_only',true,
    'question_count',6,
    'questions',v_visible
  );
end
$issue$;

revoke all on function public.exm03_issue_assigned_practice(uuid,text,date)
  from public,anon,authenticated;
grant execute on function public.exm03_issue_assigned_practice(uuid,text,date)
  to authenticated;

comment on function public.exm03_issue_assigned_practice(uuid,text,date) is
  'Permanent live-session owner-only, quota-bound server-assigned reviewed six-item part diagnostic for a specific exam administration date. Returns safe questions only. Excludes held-out items. Grading remains private; not an official exam.';

-- -----------------------------------------------------------------------------
-- 6. Update exm03_record_assigned_practice to Validate Assignment Administration Date
-- -----------------------------------------------------------------------------
create or replace function public.exm03_record_assigned_practice(
  p_assignment_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,pg_temp
as $record$
declare
  a public.exam_part_practice_assignments%rowtype;
  existing public.exam_part_practice_attempts%rowtype;
  v_version record;
  v_manifest public.exam_reference_manifest_revisions%rowtype;
  v_questions integer;
  v_correct integer := 0;
  v_response_hash text;
  v_entry jsonb;
  v_item_id uuid;
  v_ids uuid[] := array[]::uuid[];
  v_item public.assessment_items%rowtype;
  v_hash text;
  v_actual text;
  v_expected text;
  v_distinct_concepts integer;
  v_edition text;
begin
  if p_assignment_id is null
     or p_responses is null
     or jsonb_typeof(p_responses) is distinct from 'object' then
    raise exception 'Assignment ID and responses object required'
      using errcode='22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_assignment_id::text, 61501));

  select * into a from public.exam_part_practice_assignments
    where id=p_assignment_id;
  if not found then
    raise exception 'Practice assignment not found'
      using errcode='42501';
  end if;

  v_response_hash := encode(sha256(convert_to(p_responses::text,'UTF8')),'hex');

  select * into existing from public.exam_part_practice_attempts
    where assignment_id=a.id;
  if found then
    if existing.response_sha256 = v_response_hash then
      return jsonb_build_object(
        'attempt_id',existing.id,
        'target_version_id',existing.target_version_id,
        'exam_part_key',existing.exam_part_key,
        'question_count',existing.question_count,
        'fully_correct_count',existing.fully_correct_count,
        'partial_count',existing.partial_count,
        'practice_score',existing.practice_score,
        'already_recorded',true,
        'official_exam_result',false
      );
    end if;
    raise exception 'Assignment already scored with different responses'
      using errcode='23505';
  end if;

  if a.expires_at <= now() then
    raise exception 'Practice assignment expired'
      using errcode='42501';
  end if;

  select v.id,v.target_id,v.status,v.metadata into v_version
  from public.target_versions v
  join public.learning_targets t on t.id=v.target_id
  where v.id=a.target_version_id
    and v.target_id=a.target_id
    and v.status='published'
    and t.status='published'
    and t.is_public=true;
  if not found or not exists (
        select 1 from jsonb_array_elements(
          v_version.metadata->'exam_preparation'->'exam_parts'
        ) as part(value)
        where part.value->>'key'=a.exam_part_key
          and part.value->>'curriculum_root_node_id'
              =a.curriculum_root_node_id::text
      ) or not exists (
        select 1 from public.curriculum_nodes cn
        where cn.id=a.curriculum_root_node_id
          and cn.target_version_id=a.target_version_id
      ) then
    raise exception 'No published matching target/version/part curriculum'
      using errcode='42501';
  end if;

  -- Validate against manifest covering the assignment's actual administration date
  select * into v_manifest from public.exam_reference_manifest_revisions
    where id=a.manifest_revision_id;
  if not found or v_manifest.target_version_id <> a.target_version_id
     or v_manifest.exam_part_key <> a.exam_part_key
     or v_manifest.publication_status <> 'published'
     or v_manifest.review_status <> 'approved'
     or a.administration_date < v_manifest.effective_from
     or (v_manifest.effective_until is not null
         and a.administration_date > v_manifest.effective_until) then
    raise exception 'No current approved source manifest for this part on the administration date'
      using errcode='42501';
  end if;

  v_questions := jsonb_array_length(a.assigned_items);
  if v_questions not between 6 and 50 or
     (select count(*) from jsonb_object_keys(p_responses)) <> v_questions
     or pg_column_size(p_responses)>65536 then
    raise exception 'Complete bounded assigned responses required'
      using errcode='22023';
  end if;

  for v_entry in select value from jsonb_array_elements(a.assigned_items)
      as assigned(value)
  loop
    if jsonb_typeof(v_entry) is distinct from 'object'
       or (select count(*) from jsonb_object_keys(v_entry)) <> 2
       or coalesce(v_entry->>'id','') !~
          '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
       or coalesce(v_entry->>'sha256','') !~ '^[a-f0-9]{64}$' then
      raise exception 'Malformed immutable practice assignment'
        using errcode='22023';
    end if;
    v_item_id := (v_entry->>'id')::uuid;
    if v_item_id=any(v_ids) then
      raise exception 'Assigned questions may not repeat'
        using errcode='22023';
    end if;
    v_ids := array_append(v_ids,v_item_id);

    select * into v_item from public.assessment_items
      where id=v_item_id and origin_target_version_id=a.target_version_id;
    v_hash := public.exam_reference_item_fingerprint(v_item_id);
    if not found or v_hash is distinct from (v_entry->>'sha256')
       or v_item.interaction_type <> 'single_choice'
       or not exists (
         select 1 from public.assessment_item_reference_validity b
         where b.assessment_item_id=v_item_id
           and b.manifest_revision_id=a.manifest_revision_id
           and b.publication_status='published'
           and b.review_status='approved'
           and b.rights_review_status='approved'
           and b.usage_role='practice_pool'
           and b.item_content_sha256=v_hash
       ) then
      raise exception 'Assigned item was modified or lost valid approval'
        using errcode='42501';
    end if;

    v_actual := trim(coalesce(p_responses->>v_item_id::text,''));
    v_expected := trim(v_item.scoring_spec->>'correct_index');
    if v_actual !~ '^[0-9]+$' or
       v_actual::integer >= jsonb_array_length(v_item.response_spec->'options') then
      raise exception 'Response index out of range for question'
        using errcode='22023';
    end if;
    if v_actual=v_expected then
      v_correct := v_correct+1;
    end if;
  end loop;

  -- At least three separate core concepts, not six copies of one item.
  with recursive subtree(id) as (
    select id from public.curriculum_nodes
      where id=a.curriculum_root_node_id
        and target_version_id=a.target_version_id
    union
    select n.id from public.curriculum_nodes n
      join subtree p on n.parent_id=p.id
      where n.target_version_id=a.target_version_id
  )
  select count(distinct ic.concept_id) into v_distinct_concepts
  from public.assessment_item_concepts ic
    join public.curriculum_node_concepts nc
      on nc.concept_id=ic.concept_id and nc.relevance='core'
  where ic.assessment_item_id=any(v_ids)
    and nc.curriculum_node_id in (select id from subtree);
  if v_distinct_concepts < 3 then
    raise exception 'Practice requires three distinct reviewed concepts'
      using errcode='42501';
  end if;

  v_edition := encode(sha256(convert_to(
    a.manifest_revision_id::text || ':' || a.assigned_items::text,
    'UTF8')),'hex');

  insert into public.exam_part_practice_attempts (
    owner_id,target_id,target_version_id,exam_part_key,
    curriculum_root_node_id,practice_kind,
    question_count,fully_correct_count,partial_count,
    practice_score,question_edition_fingerprint,assignment_id,response_sha256
  ) values (
    a.owner_id,a.target_id,a.target_version_id,a.exam_part_key,
    a.curriculum_root_node_id,a.practice_kind,
    v_questions,v_correct,0,
    round(v_correct::numeric/v_questions,6),v_edition,a.id,v_response_hash
  ) returning * into existing;

  return jsonb_build_object(
    'attempt_id',existing.id,
    'target_version_id',existing.target_version_id,
    'exam_part_key',existing.exam_part_key,
    'question_count',existing.question_count,
    'fully_correct_count',existing.fully_correct_count,
    'partial_count',existing.partial_count,
    'practice_score',existing.practice_score,
    'already_recorded',false,
    'official_exam_result',false
  );
end
$record$;

revoke all on function public.exm03_record_assigned_practice(uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.exm03_record_assigned_practice(uuid,jsonb)
  to service_role;

-- -----------------------------------------------------------------------------
-- 7. Update exm03_account_part_export_page to Include administration_date
-- -----------------------------------------------------------------------------
create or replace function public.exm03_account_part_export_page(
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
    'administration_date',a.administration_date,
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
    'page_row_count',v_count,
    'has_more_rows',v_count=p_limit,
    'assignments',v_rows
  );
end
$page$;

-- -----------------------------------------------------------------------------
-- 8. Update exm03_account_practice_export to Include administration_date
-- -----------------------------------------------------------------------------
create or replace function public.exm03_account_practice_export()
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
    'administration_date',a.administration_date,
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
     or (v_reference->>'record_count')::integer<>(v_inventory->>'reference_events')::integer then
    raise exception 'EXM export read mismatch against verified inventory'
      using errcode='40001';
  end if;

  return jsonb_build_object(
    'scope','exm-educational-practice-all-editions-v1',
    'export_version',1,
    'exported_at',now(),
    'owner_id',v_owner,
    'snapshot_consistency','single-sql-statement',
    'record_count',(v_inventory->>'reference_events')::integer + (v_inventory->>'part_assignments')::integer,
    'inventory',v_inventory,
    'reference_practice',v_reference,
    'assigned_practice',v_parts
  );
end
$export$;

