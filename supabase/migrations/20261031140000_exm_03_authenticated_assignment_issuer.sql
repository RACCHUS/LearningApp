-- EXM-03: Authenticated, server-assigned educational practice questions.
-- Only the database chooses reviewed canonical items; clients specify solely
-- an exact published target version and exam part. No answer keys are returned.
-- Submission and scoring remain service-role-only pending privacy release gates.

create function public.exm03_issue_assigned_practice(
  p_target_version_id uuid,
  p_exam_part_key text
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
     or p_exam_part_key !~ '^[a-z][a-z0-9_]{0,127}$' then
    raise exception 'Permanent authenticated session and exact part required'
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

  select m.id into v_manifest
  from public.exam_reference_manifest_revisions m
  where m.target_version_id=p_target_version_id
    and m.exam_part_key=p_exam_part_key
    and m.publication_status='published'
    and m.review_status='approved'
    and current_date>=m.effective_from
    and (m.effective_until is null or current_date<=m.effective_until)
  order by m.revision desc
  limit 1;
  if v_manifest is null then
    raise exception 'No effective approved reference manifest for part'
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

  -- SQL owns question selection. Candidate qualification mirrors the
  -- protected grader: original independently approved published bindings,
  -- current unchanged item hash, supported canonical single choice, and all
  -- concepts exclusively core within the selected subtree (not shared).
  for v_pick in 1..12 loop
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
    assigned_items,issued_at,expires_at
  ) values (
    actor_id,v_target_id,p_target_version_id,p_exam_part_key,
    v_root,v_manifest,'diagnostic',
    v_assigned,now(),v_expiry
  ) returning id into v_assignment;

  -- Do not return scoring_spec, explanations, private source bindings, hashes
  -- or answers. Only safe visible options and exact question IDs are returned.
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
    'expires_at',v_expiry,
    'practice_only',true,
    'question_count',6,
    'questions',v_visible
  );
end
$issue$;

revoke all on function public.exm03_issue_assigned_practice(uuid,text)
  from public,anon,authenticated;
grant execute on function public.exm03_issue_assigned_practice(uuid,text)
  to authenticated;
comment on function public.exm03_issue_assigned_practice(uuid,text) is
  'Permanent live-session owner-only, quota-bound server-assigned reviewed six-item part diagnostic. Returns safe questions only. Grading remains private; not an official exam.';
