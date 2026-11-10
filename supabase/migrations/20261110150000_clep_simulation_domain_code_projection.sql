-- ============================================================================
-- Migration: 20261110150000_clep_simulation_domain_code_projection.sql
-- Description: Project domain_code and official domains in simulation exam RPCs
--              to ensure psychometrically accurate four-domain diagnostic reporting.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Replace clep_issue_simulation_exam to include domain_code and domains list
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
        'code', coalesce(d.code, '1.0'),
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
        i.metadata->>'domain_code',
        (
          select dom.code
          from public.assessment_item_concepts aic
          join public.curriculum_nodes c on c.id = aic.concept_id
          join public.curriculum_nodes obj on obj.id = c.parent_id
          join public.curriculum_nodes dom on dom.id = obj.parent_id
          where aic.assessment_item_id = i.id and dom.node_type = 'domain'
          limit 1
        ),
        '1.0'
      ),
      'metadata', jsonb_build_object(
        'bank', i.metadata->>'bank',
        'item_role', i.metadata->>'item_role',
        'domain_code', coalesce(
          i.metadata->>'domain_code',
          (
            select dom.code
            from public.assessment_item_concepts aic
            join public.curriculum_nodes c on c.id = aic.concept_id
            join public.curriculum_nodes obj on obj.id = c.parent_id
            join public.curriculum_nodes dom on dom.id = obj.parent_id
            where aic.assessment_item_id = i.id and dom.node_type = 'domain'
            limit 1
          ),
          '1.0'
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
  'Issues a single-attempt, authenticated CLEP simulation exam with sanitized options and psychometric domain_code annotations. Answer keys and item explanations are withheld.';

-- ----------------------------------------------------------------------------
-- 2. Replace clep_submit_simulation_exam preserving all security guards and adding domain_code
-- ----------------------------------------------------------------------------
create or replace function public.clep_submit_simulation_exam(
  p_attempt_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  a public.clep_simulation_attempts%rowtype;
  v_version_status text;
  v_target_status text;
  v_is_public boolean;
  v_answered_count integer;
  v_key text;
  v_item_uuid uuid;
  v_item record;
  v_user_answer integer;
  v_correct_answer integer;
  v_is_correct boolean;
  v_correct_count integer := 0;
  v_percentage numeric;
  v_results jsonb := '[]'::jsonb;
  v_readiness text;
  v_time_spent_seconds integer;
  v_response_hash text;
begin
  -- 1. Authentication check
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to submit simulation exam' using errcode = '42501';
  end if;

  -- 2. Input validation
  if p_attempt_id is null or p_responses is null or jsonb_typeof(p_responses) <> 'object' then
    raise exception 'Valid attempt_id and response object required' using errcode = '22023';
  end if;

  -- 3. Lock attempt row and verify ownership
  select * into a
  from public.clep_simulation_attempts
  where id = p_attempt_id
  for update;

  if not found then
    raise exception 'Simulation attempt not found: %', p_attempt_id using errcode = 'P0002';
  end if;

  if a.user_id <> v_user_id then
    raise exception 'Unauthorized: caller does not own this simulation attempt' using errcode = '42501';
  end if;

  -- 4. Replay protection: attempt must be in_progress
  if a.status <> 'in_progress' then
    raise exception 'Simulation attempt has already been submitted or closed (status: %)', a.status using errcode = '23505';
  end if;

  -- 5. Server-enforced deadline check
  if clock_timestamp() > a.expires_at then
    update public.clep_simulation_attempts
    set status = 'expired', updated_at = clock_timestamp()
    where id = a.id;
    raise exception 'Simulation attempt has expired (deadline: %)', a.expires_at using errcode = '42501';
  end if;

  -- 6. Target version must still be published and public
  select v.status, t.status, t.is_public
  into v_version_status, v_target_status, v_is_public
  from public.target_versions v
  join public.learning_targets t on t.id = v.target_id
  where v.id = a.target_version_id;

  if v_version_status <> 'published' or v_target_status <> 'published' or v_is_public is not true then
    raise exception 'Target version is no longer published' using errcode = '42501';
  end if;

  -- 7. Reject empty response object (cannot scrape answers without answering)
  select count(*) into v_answered_count
  from jsonb_object_keys(p_responses);

  if v_answered_count = 0 then
    raise exception 'Cannot submit empty responses: at least one answered question is required' using errcode = '22023';
  end if;

  -- 8. Validate that all submitted keys are valid UUIDs and belong to the issued items
  for v_key in select jsonb_object_keys(p_responses)
  loop
    begin
      v_item_uuid := v_key::uuid;
    exception when others then
      raise exception 'Invalid question ID format in responses: %', v_key using errcode = '22023';
    end;

    if not (v_item_uuid = any(a.issued_item_ids)) then
      raise exception 'Submitted question does not belong to this exam attempt: %', v_key using errcode = '22023';
    end if;
  end loop;

  -- 9. Server-calculated elapsed time (does not trust client-reported time)
  v_time_spent_seconds := round(extract(epoch from (clock_timestamp() - a.issued_at)))::integer;
  if v_time_spent_seconds < 0 then
    v_time_spent_seconds := 0;
  end if;

  -- 10. Grade answers and apply selective review policy with domain_code annotations
  for v_item in
    select
      i.id,
      i.prompt,
      i.response_spec,
      i.scoring_spec,
      i.explanation,
      i.metadata
    from public.assessment_items i
    where i.id = any(a.issued_item_ids)
    order by i.created_at, i.id
  loop
    v_correct_answer := (v_item.scoring_spec->>'correct_index')::integer;

    if p_responses ? (v_item.id::text) then
      v_user_answer := (p_responses->>(v_item.id::text))::integer;
      v_is_correct := (v_user_answer = v_correct_answer);
      if v_is_correct then
        v_correct_count := v_correct_count + 1;
      end if;

      -- Confidential bank policy: post-simulation feedback returns score, correctness,
      -- user's selected choice, and concept remediation references.
      -- Protected answer keys and item explanations remain permanently server-side
      -- and are NEVER returned to the client or persisted in attempt results.
      v_results := v_results || jsonb_build_object(
        'id', v_item.id,
        'answered', true,
        'is_correct', v_is_correct,
        'user_answer', v_user_answer,
        'domain_code', coalesce(
          v_item.metadata->>'domain_code',
          (
            select dom.code
            from public.assessment_item_concepts aic
            join public.curriculum_nodes c on c.id = aic.concept_id
            join public.curriculum_nodes obj on obj.id = c.parent_id
            join public.curriculum_nodes dom on dom.id = obj.parent_id
            where aic.assessment_item_id = v_item.id and dom.node_type = 'domain'
            limit 1
          ),
          '1.0'
        ),
        'concept_ids', coalesce(
          (select jsonb_agg(c.concept_id) from public.assessment_item_concepts c where c.assessment_item_id = v_item.id),
          '[]'::jsonb
        )
      );
    else
      -- Unanswered question: marked unattempted, not correct
      v_results := v_results || jsonb_build_object(
        'id', v_item.id,
        'answered', false,
        'is_correct', false,
        'user_answer', null,
        'domain_code', coalesce(
          v_item.metadata->>'domain_code',
          (
            select dom.code
            from public.assessment_item_concepts aic
            join public.curriculum_nodes c on c.id = aic.concept_id
            join public.curriculum_nodes obj on obj.id = c.parent_id
            join public.curriculum_nodes dom on dom.id = obj.parent_id
            where aic.assessment_item_id = v_item.id and dom.node_type = 'domain'
            limit 1
          ),
          '1.0'
        ),
        'concept_ids', coalesce(
          (select jsonb_agg(c.concept_id) from public.assessment_item_concepts c where c.assessment_item_id = v_item.id),
          '[]'::jsonb
        )
      );
    end if;
  end loop;

  v_percentage := round((v_correct_count::numeric / a.total_questions::numeric) * 100, 1);

  if v_percentage >= 70.0 then
    v_readiness := 'Competitive Diagnostic Standing';
  elsif v_percentage >= 50.0 then
    v_readiness := 'Approaching Foundation';
  else
    v_readiness := 'Needs Reinforcement';
  end if;

  v_response_hash := encode(sha256(convert_to(p_responses::text, 'UTF8')), 'hex');

  -- 11. Atomic state transition: mark attempt completed with grading results
  update public.clep_simulation_attempts
  set status = 'completed',
      submitted_at = clock_timestamp(),
      time_spent_seconds = v_time_spent_seconds,
      raw_score = v_correct_count,
      accuracy_percentage = v_percentage,
      response_sha256 = v_response_hash,
      responses = p_responses,
      results = v_results,
      updated_at = clock_timestamp()
  where id = a.id;

  return jsonb_build_object(
    'attempt_id', a.id,
    'target_version_id', a.target_version_id,
    'raw_score', v_correct_count,
    'total_questions', a.total_questions,
    'accuracy_percentage', v_percentage,
    'time_spent_seconds', v_time_spent_seconds,
    'readiness_indicator', v_readiness,
    'is_calibrated_clep_score', false,
    'scoring_disclaimer', 'Diagnostic score estimate only. Official College Board scaled scores require statistical equating and proprietary form calibration.',
    'results', v_results
  );
end;
$$;

revoke all on function public.clep_submit_simulation_exam(uuid, jsonb) from public, anon;
grant execute on function public.clep_submit_simulation_exam(uuid, jsonb) to authenticated;
grant execute on function public.clep_submit_simulation_exam(uuid, jsonb) to service_role;
comment on function public.clep_submit_simulation_exam(uuid, jsonb) is
  'Grades simulation exam attempts server-side. Returns accuracy percentage, raw score, readiness indicator, and item correctness annotated with domain_code without exposing correct answer keys.';
