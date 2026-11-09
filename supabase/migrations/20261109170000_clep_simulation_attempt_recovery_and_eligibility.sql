-- Migration: 20261109170000_clep_simulation_attempt_recovery_and_eligibility.sql
-- Description: Adds authenticated attempt recovery, active session polling, guest-account rejection,
--              and strict domain mapping validation (zero silent 1.0 fallbacks).

-- ----------------------------------------------------------------------------
-- 1. Function: clep_get_active_simulation_attempt
-- ----------------------------------------------------------------------------
create or replace function public.clep_get_active_simulation_attempt(
  p_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  v_attempt record;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return jsonb_build_object('has_active_attempt', false, 'reason', 'unauthenticated');
  end if;

  select id, issued_at, expires_at, status, total_questions
  into v_attempt
  from public.clep_simulation_attempts
  where user_id = v_user_id
    and target_version_id = p_target_version_id
    and status = 'in_progress'
    and expires_at > clock_timestamp();

  if not found then
    return jsonb_build_object('has_active_attempt', false);
  end if;

  return jsonb_build_object(
    'has_active_attempt', true,
    'attempt_id', v_attempt.id,
    'issued_at', v_attempt.issued_at,
    'expires_at', v_attempt.expires_at,
    'seconds_remaining', greatest(0, extract(epoch from (v_attempt.expires_at - clock_timestamp()))::integer),
    'total_questions', v_attempt.total_questions
  );
end;
$$;

revoke all on function public.clep_get_active_simulation_attempt(uuid) from public, anon;
grant execute on function public.clep_get_active_simulation_attempt(uuid) to authenticated;
grant execute on function public.clep_get_active_simulation_attempt(uuid) to service_role;
comment on function public.clep_get_active_simulation_attempt(uuid) is
  'Checks if the authenticated learner has an active unexpired in-progress simulation attempt for an exam version.';

-- ----------------------------------------------------------------------------
-- 2. Function: clep_recover_simulation_exam
-- ----------------------------------------------------------------------------
create or replace function public.clep_recover_simulation_exam(
  p_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  v_attempt record;
  v_questions jsonb;
  v_domains jsonb;
begin
  -- 1. Authentication check
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to recover simulation exam' using errcode = '42501';
  end if;

  -- 2. Guest/Anonymous accounts cannot recover or hold official attempts
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) is true then
    raise exception 'Official simulation exams require a verified, registered learner account: guest/anonymous accounts are not permitted' using errcode = '42501';
  end if;

  -- 3. Find active in-progress attempt
  select id, issued_at, expires_at, issued_item_ids, total_questions
  into v_attempt
  from public.clep_simulation_attempts
  where user_id = v_user_id
    and target_version_id = p_target_version_id
    and status = 'in_progress'
    and expires_at > clock_timestamp();

  if not found then
    raise exception 'No active in-progress simulation attempt found to recover for target version: %', p_target_version_id using errcode = 'P0002';
  end if;

  -- 4. Gather official blueprint domains
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

  -- 5. Project safe questions for the issued item IDs (ZERO keys or explanations leaked)
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
          join public.curriculum_nodes c on c.id = aic.concept_id
          join public.curriculum_nodes obj on obj.id = c.parent_id
          join public.curriculum_nodes dom on dom.id = obj.parent_id
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
  where i.id = any(v_attempt.issued_item_ids);

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'target_version_id', p_target_version_id,
    'total_questions', v_attempt.total_questions,
    'time_limit_minutes', 90,
    'issued_at', v_attempt.issued_at,
    'expires_at', v_attempt.expires_at,
    'seconds_remaining', greatest(0, extract(epoch from (v_attempt.expires_at - clock_timestamp()))::integer),
    'is_resumed', true,
    'domains', v_domains,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.clep_recover_simulation_exam(uuid) from public, anon;
grant execute on function public.clep_recover_simulation_exam(uuid) to authenticated;
grant execute on function public.clep_recover_simulation_exam(uuid) to service_role;
comment on function public.clep_recover_simulation_exam(uuid) is
  'Allows an authenticated learner to resume an active, unexpired in-progress simulation attempt if connection was lost.';

-- ----------------------------------------------------------------------------
-- 3. Function: clep_issue_simulation_exam (Updated with guest guard and strict domain projection)
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
  v_item_ids uuid[];
  v_count integer;
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
  select v.target_id, v.status, t.status, t.is_public
  into v_target_id, v_version_status, v_target_status, v_is_public
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

  -- 5. Establish server-controlled timestamps (90-min test + 5-min network buffer)
  v_issued_at := clock_timestamp();
  v_expires_at := v_issued_at + interval '95 minutes';

  -- 6. Record attempt in database
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

  -- 7. Gather official blueprint domains
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

  -- 8. Project ONLY safe question fields with domain_code (ZERO scoring keys or explanations leaked)
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
          join public.curriculum_nodes c on c.id = aic.concept_id
          join public.curriculum_nodes obj on obj.id = c.parent_id
          join public.curriculum_nodes dom on dom.id = obj.parent_id
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
    'seconds_remaining', greatest(0, extract(epoch from (v_expires_at - clock_timestamp()))::integer),
    'is_resumed', false,
    'domains', v_domains,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.clep_issue_simulation_exam(uuid) from public, anon;
grant execute on function public.clep_issue_simulation_exam(uuid) to authenticated;
grant execute on function public.clep_issue_simulation_exam(uuid) to service_role;
comment on function public.clep_issue_simulation_exam(uuid) is
  'Issues a single-attempt, authenticated CLEP simulation exam with sanitized options and psychometric domain_code annotations. Answer keys and item explanations are withheld.';
