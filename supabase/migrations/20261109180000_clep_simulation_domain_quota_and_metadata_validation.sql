-- Migration: 20261109180000_clep_simulation_domain_quota_and_metadata_validation.sql
-- Description: Backfill target_versions.metadata.bank for blueprint authorities,
--              and enforce strict psychometric domain-code presence and four-domain quotas
--              prior to inserting attempts into clep_simulation_attempts.

-- ----------------------------------------------------------------------------
-- 1. Backfill target_versions.metadata with bank = 'simulation_exam' & Trigger Sync
-- ----------------------------------------------------------------------------
update public.target_versions tv
set metadata = jsonb_set(coalesce(tv.metadata, '{}'::jsonb), '{bank}', '"simulation_exam"')
where (
    tv.metadata->>'role' = 'blueprint_authority'
    or tv.metadata->>'bank' is null
    or tv.metadata->>'bank' <> 'simulation_exam'
  )
  and exists (
    select 1
    from public.assessment_items i
    where i.origin_target_version_id = tv.id
      and public.is_protected_simulation_item(i.metadata)
  );

create or replace function public.trg_fn_sync_target_version_simulation_bank()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.metadata->>'bank' = 'simulation_exam' and new.origin_target_version_id is not null then
    update public.target_versions
    set metadata = jsonb_set(coalesce(metadata, '{}'::jsonb), '{bank}', '"simulation_exam"')
    where id = new.origin_target_version_id
      and (metadata->>'bank' is null or metadata->>'bank' <> 'simulation_exam');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_target_version_simulation_bank on public.assessment_items;
create trigger trg_sync_target_version_simulation_bank
after insert or update on public.assessment_items
for each row
execute function public.trg_fn_sync_target_version_simulation_bank();

-- ----------------------------------------------------------------------------
-- 2. Function: clep_issue_simulation_exam (Strict Pre-Issuance Domain Quotas)
-- ----------------------------------------------------------------------------
create or replace function public.clep_issue_simulation_exam(
  p_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  v_target_id uuid;
  v_version_status text;
  v_target_status text;
  v_is_public boolean;
  v_version_meta jsonb;
  v_exam_code text;
  v_item_ids uuid[];
  v_count integer;
  v_missing_domain_count integer;
  v_invalid_domain_count integer;
  v_d1_count integer;
  v_d2_count integer;
  v_d3_count integer;
  v_d4_count integer;
  v_issued_at timestamptz;
  v_expires_at timestamptz;
  v_attempt_id uuid;
  v_questions jsonb;
  v_domains jsonb;
begin
  -- 1. Authentication check
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to issue simulation exam' using errcode = '42501';
  end if;

  -- 1b. Reject anonymous / guest accounts to prevent bypassing single-attempt restrictions
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is true then
    raise exception 'Official simulation exams require a verified, registered learner account: guest/anonymous accounts are not permitted' using errcode = '42501';
  end if;

  -- 2. Verify target version is published and public
  select v.target_id, v.status, t.status, t.is_public, v.metadata
  into v_target_id, v_version_status, v_target_status, v_is_public, v_version_meta
  from public.target_versions v
  join public.learning_targets t on t.id = v.target_id
  where v.id = p_target_version_id;

  if not found then
    raise exception 'Target version not found: %', p_target_version_id using errcode = 'P0002';
  end if;

  if v_version_status <> 'published' or v_target_status <> 'published' or v_is_public is not true then
    raise exception 'Cannot issue simulation exam for unpublished target version: %', p_target_version_id using errcode = '42501';
  end if;

  -- 3. Enforce single simulation attempt per learner per exam version (anti-harvesting guard)
  if exists (
    select 1
    from public.clep_simulation_attempts
    where user_id = v_user_id
      and target_version_id = p_target_version_id
  ) then
    raise exception 'Simulation attempt already exists for this exam version: only one official simulation attempt is permitted per learner' using errcode = '23505';
  end if;

  -- 4. Gather protected simulation item IDs
  select array_agg(i.id order by i.created_at, i.id), count(i.id)
  into v_item_ids, v_count
  from public.assessment_items i
  where i.origin_target_version_id = p_target_version_id
    and public.is_protected_simulation_item(i.metadata);

  if v_count = 0 or v_item_ids is null then
    raise exception 'No simulation items found for target version: %', p_target_version_id using errcode = 'P0002';
  end if;

  -- --------------------------------------------------------------------------
  -- 5. CRITICAL: Strict Psychometric Domain Validation BEFORE Attempt Insertion
  -- If any item lacks a valid domain code or violates quotas, fail BEFORE inserting
  -- into clep_simulation_attempts so the learner's one-time attempt is NOT consumed.
  -- --------------------------------------------------------------------------

  -- 5a. Verify every item has a valid, non-null, non-empty domain_code
  select count(*)
  into v_missing_domain_count
  from (
    select
      i.id,
      coalesce(
        nullif(i.metadata->>'domain_code', ''),
        (
          select dom.code
          from public.assessment_item_concepts aic
          left join public.curriculum_node_concepts cnc on cnc.concept_id = aic.concept_id
          left join public.curriculum_nodes n on n.id = cnc.curriculum_node_id
          left join public.curriculum_nodes dom on (
            (n.node_type = 'domain' and dom.id = n.id) or
            (n.node_type = 'objective' and dom.id = n.parent_id) or
            (n.node_type = 'concept' and dom.id = (
              select parent_id from public.curriculum_nodes where id = n.parent_id
            ))
          )
          where aic.assessment_item_id = i.id and dom.node_type = 'domain'
          limit 1
        )
      ) as resolved_domain
    from public.assessment_items i
    where i.origin_target_version_id = p_target_version_id
      and public.is_protected_simulation_item(i.metadata)
  ) item_check
  where item_check.resolved_domain is null or item_check.resolved_domain = '';

  if v_missing_domain_count > 0 then
    raise exception 'Simulation items violate psychometric contract: % item(s) lack required domain_code', v_missing_domain_count using errcode = '22023';
  end if;

  -- 5b. Verify all item domain codes match declared domains for this target version
  select count(*)
  into v_invalid_domain_count
  from (
    select
      coalesce(
        nullif(i.metadata->>'domain_code', ''),
        (
          select dom.code
          from public.assessment_item_concepts aic
          left join public.curriculum_node_concepts cnc on cnc.concept_id = aic.concept_id
          left join public.curriculum_nodes n on n.id = cnc.curriculum_node_id
          left join public.curriculum_nodes dom on (
            (n.node_type = 'domain' and dom.id = n.id) or
            (n.node_type = 'objective' and dom.id = n.parent_id) or
            (n.node_type = 'concept' and dom.id = (
              select parent_id from public.curriculum_nodes where id = n.parent_id
            ))
          )
          where aic.assessment_item_id = i.id and dom.node_type = 'domain'
          limit 1
        )
      ) as resolved_domain
    from public.assessment_items i
    where i.origin_target_version_id = p_target_version_id
      and public.is_protected_simulation_item(i.metadata)
  ) item_check
  where item_check.resolved_domain not in (
    select d.code
    from public.curriculum_nodes d
    where d.target_version_id = p_target_version_id
      and d.node_type = 'domain'
  );

  if v_invalid_domain_count > 0 then
    raise exception 'Simulation items contain domain_codes not declared in target_version blueprint: % item(s) invalid', v_invalid_domain_count using errcode = '22023';
  end if;

  -- 5c. Enforce Four-Domain Quotas for College Algebra (CLEP-ALG)
  v_exam_code := coalesce(v_version_meta->>'exam_code', '');
  if v_exam_code = 'CLEP-ALG' then
    if v_count <> 60 then
      raise exception 'CLEP College Algebra requires exactly 60 simulation items (found %)', v_count using errcode = '22023';
    end if;

    select
      count(*) filter (where resolved_domain = '1.0'),
      count(*) filter (where resolved_domain = '2.0'),
      count(*) filter (where resolved_domain = '3.0'),
      count(*) filter (where resolved_domain = '4.0')
    into v_d1_count, v_d2_count, v_d3_count, v_d4_count
    from (
      select
        coalesce(
          nullif(i.metadata->>'domain_code', ''),
          (
            select dom.code
            from public.assessment_item_concepts aic
            join public.curriculum_nodes c on c.id = aic.concept_id
            join public.curriculum_nodes obj on obj.id = c.parent_id
            join public.curriculum_nodes dom on dom.id = obj.parent_id
            where aic.assessment_item_id = i.id and dom.node_type = 'domain'
            limit 1
          )
        ) as resolved_domain
      from public.assessment_items i
      where i.origin_target_version_id = p_target_version_id
        and public.is_protected_simulation_item(i.metadata)
    ) q;

    if v_d1_count <> 15 or v_d2_count <> 15 or v_d3_count <> 18 or v_d4_count <> 12 then
      raise exception 'CLEP College Algebra item pool violates four-domain quotas: expected 15/15/18/12, got 1.0: %, 2.0: %, 3.0: %, 4.0: %',
        v_d1_count, v_d2_count, v_d3_count, v_d4_count using errcode = '22023';
    end if;
  end if;

  -- 6. Establish server-controlled timestamps (90-min test + 5-min network buffer)
  v_issued_at := clock_timestamp();
  v_expires_at := v_issued_at + interval '95 minutes';

  -- 7. Record attempt in database (ONLY after all psychometric validations pass)
  insert into public.clep_simulation_attempts (
    user_id,
    target_id,
    target_version_id,
    status,
    issued_item_ids,
    total_questions,
    issued_at,
    expires_at
  ) values (
    v_user_id,
    v_target_id,
    p_target_version_id,
    'in_progress',
    v_item_ids,
    v_count,
    v_issued_at,
    v_expires_at
  )
  returning id into v_attempt_id;

  -- 8. Gather official blueprint domains
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'code', d.code,
        'title', d.title,
        'weight', coalesce(d.weight, 0.25)
      )
      order by d.sort_order, d.code
    ),
    '[]'::jsonb
  )
  into v_domains
  from public.curriculum_nodes d
  where d.target_version_id = p_target_version_id
    and d.node_type = 'domain';

  -- 9. Project ONLY safe question fields with domain_code (ZERO scoring keys or explanations leaked)
  select jsonb_agg(
    jsonb_build_object(
      'id', i.id,
      'interaction_type', i.interaction_type,
      'prompt', i.prompt,
      'response_spec', jsonb_build_object('options', i.response_spec->'options'),
      'domain_code', coalesce(
        nullif(i.metadata->>'domain_code', ''),
        (
          select dom.code
          from public.assessment_item_concepts aic
          left join public.curriculum_node_concepts cnc on cnc.concept_id = aic.concept_id
          left join public.curriculum_nodes n on n.id = cnc.curriculum_node_id
          left join public.curriculum_nodes dom on (
            (n.node_type = 'domain' and dom.id = n.id) or
            (n.node_type = 'objective' and dom.id = n.parent_id) or
            (n.node_type = 'concept' and dom.id = (
              select parent_id from public.curriculum_nodes where id = n.parent_id
            ))
          )
          where aic.assessment_item_id = i.id and dom.node_type = 'domain'
          limit 1
        )
      ),
      'metadata', jsonb_build_object(
        'bank', i.metadata->>'bank',
        'item_role', i.metadata->>'item_role',
        'domain_code', coalesce(
          nullif(i.metadata->>'domain_code', ''),
          (
            select dom.code
            from public.assessment_item_concepts aic
            join public.curriculum_nodes c on c.id = aic.concept_id
            join public.curriculum_nodes obj on obj.id = c.parent_id
            join public.curriculum_nodes dom on dom.id = obj.parent_id
            where aic.assessment_item_id = i.id and dom.node_type = 'domain'
            limit 1
          )
        )
      ),
      'concept_ids', coalesce(
        (select jsonb_agg(c.concept_id) from public.assessment_item_concepts c where c.assessment_item_id = i.id),
        '[]'::jsonb
      )
    )
    order by i.created_at, i.id
  )
  into v_questions
  from public.assessment_items i
  where i.id = any(v_item_ids);

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'target_version_id', p_target_version_id,
    'total_questions', v_count,
    'time_limit_minutes', 90,
    'issued_at', v_issued_at,
    'expires_at', v_expires_at,
    'domains', v_domains,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.clep_issue_simulation_exam(uuid) from public, anon;
grant execute on function public.clep_issue_simulation_exam(uuid) to authenticated;
grant execute on function public.clep_issue_simulation_exam(uuid) to service_role;
comment on function public.clep_issue_simulation_exam(uuid) is
  'Issues a confidential, timed CLEP simulation exam with pre-flight psychometric domain and quota validation.';

