-- ============================================================================
-- Phase G.5: Version Governance Security & Integrity Hardening
-- Migration: 20261008000001_phase_g_security_hardening.sql
--
-- Restores the authorization invariants established during Phase C.5 and
-- makes governance functions fail closed. This follow-up migration is
-- intentionally additive so already-migrated environments receive the fix.
-- ============================================================================

-- Governance audit rows are written only by the SECURITY DEFINER migration RPC.
drop policy if exists "user_migration_logs_insert" on public.user_version_migration_logs;
grant select on table public.user_version_migration_logs to authenticated;

-- The view must honor the RLS policies of learning_contexts/target_versions.
alter view public.v_target_version_updates set (security_invoker = true);
grant select on public.v_target_version_updates to authenticated;

-- ----------------------------------------------------------------------------
-- 1. Migration evaluation: authenticated users may inspect only their own
-- learner evidence. service_role may evaluate any user.
-- ----------------------------------------------------------------------------
create or replace function public.evaluate_target_version_migration(
  p_user_id uuid,
  p_from_target_version_id uuid,
  p_to_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_source_concepts_count integer;
  v_target_concepts_count integer;
  v_mapped_count integer;
  v_retained_count integer;
  v_removed_count integer;
  v_new_concepts_count integer;
  v_avg_weight numeric(5,2);
  v_user_assessed_count integer;
  v_projected_retained_assessed numeric(5,2);
  v_mappings_json jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or p_user_id is null or auth.uid() <> p_user_id) then
    raise exception 'Unauthorized: cannot evaluate migration evidence for another user.';
  end if;

  select count(distinct cnc.concept_id)
  into v_source_concepts_count
  from public.curriculum_node_concepts cnc
  join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
  where cn.target_version_id = p_from_target_version_id;

  select count(distinct cnc.concept_id)
  into v_target_concepts_count
  from public.curriculum_node_concepts cnc
  join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
  where cn.target_version_id = p_to_target_version_id;

  select
    count(*),
    count(*) filter (where m.transfer_weight > 0 and m.to_concept_id is not null),
    count(*) filter (
      where m.mapping_type = 'removed'
         or m.to_concept_id is null
         or m.transfer_weight = 0
    ),
    coalesce(round(avg(m.transfer_weight) * 100, 2), 100.00)
  into
    v_mapped_count,
    v_retained_count,
    v_removed_count,
    v_avg_weight
  from public.target_version_concept_mappings m
  where m.from_target_version_id = p_from_target_version_id
    and m.to_target_version_id = p_to_target_version_id;

  if v_mapped_count = 0 and v_source_concepts_count > 0 then
    select count(distinct s.concept_id)
    into v_retained_count
    from (
      select distinct cnc.concept_id
      from public.curriculum_node_concepts cnc
      join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
      where cn.target_version_id = p_from_target_version_id
    ) s
    where s.concept_id in (
      select distinct cnc2.concept_id
      from public.curriculum_node_concepts cnc2
      join public.curriculum_nodes cn2 on cn2.id = cnc2.curriculum_node_id
      where cn2.target_version_id = p_to_target_version_id
    );

    v_mapped_count := v_retained_count;
    v_removed_count := greatest(0, v_source_concepts_count - v_retained_count);
    v_avg_weight := round(
      (v_retained_count::numeric / v_source_concepts_count::numeric) * 100,
      2
    );
  end if;

  v_new_concepts_count := greatest(0, v_target_concepts_count - v_retained_count);

  select count(distinct ucs.concept_id)
  into v_user_assessed_count
  from public.user_concept_state ucs
  where ucs.user_id = p_user_id
    and ucs.evidence_count > 0
    and ucs.concept_id in (
      select distinct cnc.concept_id
      from public.curriculum_node_concepts cnc
      join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
      where cn.target_version_id = p_from_target_version_id
    );

  v_projected_retained_assessed :=
    round((v_user_assessed_count::numeric * (v_avg_weight / 100.0)), 1);

  select coalesce(jsonb_agg(jsonb_build_object(
    'from_concept_id', m.from_concept_id,
    'to_concept_id', m.to_concept_id,
    'mapping_type', m.mapping_type,
    'transfer_weight', m.transfer_weight,
    'from_concept_name', fc.name,
    'to_concept_name', tc.name
  )), '[]'::jsonb)
  into v_mappings_json
  from public.target_version_concept_mappings m
  left join public.knowledge_concepts fc on fc.id = m.from_concept_id
  left join public.knowledge_concepts tc on tc.id = m.to_concept_id
  where m.from_target_version_id = p_from_target_version_id
    and m.to_target_version_id = p_to_target_version_id;

  return jsonb_build_object(
    'from_target_version_id', p_from_target_version_id,
    'to_target_version_id', p_to_target_version_id,
    'total_source_concepts', v_source_concepts_count,
    'total_target_concepts', v_target_concepts_count,
    'mapped_concepts_count', v_mapped_count,
    'retained_concepts_count', v_retained_count,
    'removed_concepts_count', v_removed_count,
    'new_concepts_count', v_new_concepts_count,
    'transfer_retention_pct', v_avg_weight,
    'user_assessed_concepts_count', v_user_assessed_count,
    'projected_retained_assessed_count', v_projected_retained_assessed,
    'concept_mappings', v_mappings_json
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 2. User-context migration: self only (or service_role). Review-ready
-- destinations are restricted to target owners/reviewers.
-- ----------------------------------------------------------------------------
create or replace function public.migrate_user_context_target_version(
  p_user_id uuid,
  p_context_id uuid,
  p_to_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_context record;
  v_from_tv record;
  v_to_tv record;
  v_mapping record;
  v_transferred_count integer := 0;
  v_evaluation jsonb;
  v_retention_pct numeric(5,2) := 100.00;
  v_is_privileged_editor boolean := false;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or auth.uid() <> p_user_id) then
    raise exception 'Unauthorized: cannot migrate context for another user.';
  end if;

  select * into v_context
  from public.learning_contexts
  where id = p_context_id and user_id = p_user_id;

  if not found then
    raise exception 'Learning context not found or does not belong to user.';
  end if;

  select * into v_from_tv
  from public.target_versions
  where id = v_context.target_version_id;

  if not found then
    raise exception 'Current target version not found.';
  end if;

  select * into v_to_tv
  from public.target_versions
  where id = p_to_target_version_id;

  if not found then
    raise exception 'Destination target version not found.';
  end if;

  if v_from_tv.target_id <> v_to_tv.target_id then
    raise exception 'Cannot migrate context across different learning targets.';
  end if;

  if coalesce(auth.role(), '') = 'service_role' then
    v_is_privileged_editor := true;
  elsif auth.uid() is not null then
    select exists (
      select 1
      from public.learning_targets lt
      where lt.id = v_to_tv.target_id
        and lt.created_by = auth.uid()
    ) or public.is_target_reviewer(v_to_tv.target_id)
    into v_is_privileged_editor;
  end if;

  if v_to_tv.status = 'published' then
    null;
  elsif v_to_tv.status = 'review_ready' and v_is_privileged_editor then
    null;
  else
    raise exception 'Cannot migrate to target version with status "%" for this caller.', v_to_tv.status;
  end if;

  v_evaluation := public.evaluate_target_version_migration(
    p_user_id,
    v_from_tv.id,
    v_to_tv.id
  );
  v_retention_pct :=
    coalesce((v_evaluation->>'transfer_retention_pct')::numeric, 100.00);

  for v_mapping in
    select
      m.from_concept_id,
      m.to_concept_id,
      m.transfer_weight
    from public.target_version_concept_mappings m
    where m.from_target_version_id = v_from_tv.id
      and m.to_target_version_id = v_to_tv.id
      and m.to_concept_id is not null
      and m.transfer_weight > 0
  loop
    if v_mapping.from_concept_id <> v_mapping.to_concept_id then
      insert into public.user_concept_state (
        user_id,
        concept_id,
        retrieval_band,
        confidence,
        evidence_count,
        weighted_correct,
        weighted_total,
        last_evidence_at,
        updated_at
      )
      select
        p_user_id,
        v_mapping.to_concept_id,
        ucs.retrieval_band,
        ucs.confidence,
        round(ucs.evidence_count * v_mapping.transfer_weight)::integer,
        ucs.weighted_correct * v_mapping.transfer_weight,
        ucs.weighted_total * v_mapping.transfer_weight,
        ucs.last_evidence_at,
        now()
      from public.user_concept_state ucs
      where ucs.user_id = p_user_id
        and ucs.concept_id = v_mapping.from_concept_id
        and ucs.evidence_count > 0
      on conflict (user_id, concept_id) do update set
        evidence_count = greatest(
          public.user_concept_state.evidence_count,
          excluded.evidence_count
        ),
        weighted_correct = greatest(
          public.user_concept_state.weighted_correct,
          excluded.weighted_correct
        ),
        weighted_total = greatest(
          public.user_concept_state.weighted_total,
          excluded.weighted_total
        ),
        last_evidence_at = coalesce(
          excluded.last_evidence_at,
          public.user_concept_state.last_evidence_at
        ),
        updated_at = now();
    end if;

    v_transferred_count := v_transferred_count + 1;
  end loop;

  update public.learning_contexts
  set
    target_version_id = v_to_tv.id,
    updated_at = now()
  where id = p_context_id;

  update public.resume_pointers
  set
    curriculum_node_id = null,
    updated_at = now()
  where context_id = p_context_id
    and curriculum_node_id is not null
    and not exists (
      select 1 from public.curriculum_nodes cn
      where cn.id = resume_pointers.curriculum_node_id
        and cn.target_version_id = v_to_tv.id
    );

  insert into public.user_version_migration_logs (
    user_id,
    context_id,
    from_target_version_id,
    to_target_version_id,
    transferred_concepts_count,
    retained_mastery_pct,
    migration_metadata
  )
  values (
    p_user_id,
    p_context_id,
    v_from_tv.id,
    v_to_tv.id,
    v_transferred_count,
    v_retention_pct,
    jsonb_build_object(
      'from_version_code', v_from_tv.version_code,
      'to_version_code', v_to_tv.version_code,
      'evaluation', v_evaluation
    )
  );

  return jsonb_build_object(
    'success', true,
    'context_id', p_context_id,
    'from_version_code', v_from_tv.version_code,
    'to_version_code', v_to_tv.version_code,
    'transferred_concepts_count', v_transferred_count,
    'retained_mastery_pct', v_retention_pct
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 3. Audit: draft/review governance data is available only to the target owner,
-- assigned reviewers, or service_role.
-- ----------------------------------------------------------------------------
create or replace function public.audit_target_version_readiness(
  p_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tv record;
  v_domain_count integer := 0;
  v_objective_count integer := 0;
  v_leaf_objective_count integer := 0;
  v_domain_weight_sum numeric(7,3) := 0.0;
  v_is_weight_balanced boolean := false;
  v_lesson_count integer := 0;
  v_lesson_block_count integer := 0;
  v_stimulus_count integer := 0;
  v_assessment_item_count integer := 0;
  v_empty_objectives_count integer := 0;
  v_concept_count integer := 0;
  v_unassessed_concept_count integer := 0;
  v_provenance_citations_count integer := 0;
  v_missing_provenance_count integer := 0;
  v_cross_version_mappings_count integer := 0;
  v_can_stage_review boolean := false;
  v_can_publish boolean := false;
  v_blockers text[] := '{}';
  v_warnings text[] := '{}';
begin
  select tv.*, lt.title as target_title, lt.created_by as target_owner
  into v_tv
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_target_version_id;

  if not found then
    raise exception 'Target version not found: %', p_target_version_id;
  end if;

  if coalesce(auth.role(), '') <> 'service_role'
     and (
       auth.uid() is null
       or (
         v_tv.target_owner is distinct from auth.uid()
         and not public.is_target_reviewer(v_tv.target_id)
       )
     ) then
    raise exception 'Unauthorized: only service_role, target owner, or assigned reviewer may audit a target version.';
  end if;

  select
    count(*) filter (where cn.parent_id is null),
    count(*),
    coalesce(sum(cn.weight) filter (where cn.parent_id is null), 0.0)
  into
    v_domain_count,
    v_objective_count,
    v_domain_weight_sum
  from public.curriculum_nodes cn
  where cn.target_version_id = p_target_version_id;

  select count(*)
  into v_leaf_objective_count
  from public.curriculum_nodes cn
  where cn.target_version_id = p_target_version_id
    and not exists (
      select 1 from public.curriculum_nodes child
      where child.parent_id = cn.id
    );

  if v_domain_weight_sum = 0.0 then
    v_is_weight_balanced := true;
    v_warnings := array_append(v_warnings, 'Domains are unweighted (sum is 0.0).');
  elsif abs(v_domain_weight_sum - 100.0) < 0.1
     or abs(v_domain_weight_sum - 1.0) < 0.01 then
    v_is_weight_balanced := true;
  else
    v_is_weight_balanced := false;
    v_blockers := array_append(
      v_blockers,
      format('Domain weights sum to %s%% (expected 100.0%%).', v_domain_weight_sum)
    );
  end if;

  select count(distinct cnl.lesson_id)
  into v_lesson_count
  from public.curriculum_node_lessons cnl
  join public.curriculum_nodes cn on cn.id = cnl.curriculum_node_id
  where cn.target_version_id = p_target_version_id;

  select count(*)
  into v_lesson_block_count
  from public.lesson_blocks lb
  where lb.lesson_id in (
    select distinct cnl.lesson_id
    from public.curriculum_node_lessons cnl
    join public.curriculum_nodes cn on cn.id = cnl.curriculum_node_id
    where cn.target_version_id = p_target_version_id
  );

  select count(*)
  into v_stimulus_count
  from public.assessment_stimuli
  where origin_target_version_id = p_target_version_id;

  select count(*)
  into v_assessment_item_count
  from public.assessment_items ai
  where ai.origin_target_version_id = p_target_version_id
     or ai.lesson_id in (
       select distinct cnl.lesson_id
       from public.curriculum_node_lessons cnl
       join public.curriculum_nodes cn on cn.id = cnl.curriculum_node_id
       where cn.target_version_id = p_target_version_id
     );

  select count(*)
  into v_empty_objectives_count
  from public.curriculum_nodes cn
  where cn.target_version_id = p_target_version_id
    and not exists (
      select 1 from public.curriculum_nodes child where child.parent_id = cn.id
    )
    and not exists (
      select 1 from public.curriculum_node_lessons cnl
      where cnl.curriculum_node_id = cn.id
    )
    and not exists (
      select 1
      from public.curriculum_node_concepts cnc
      join public.assessment_item_concepts aic
        on aic.concept_id = cnc.concept_id
      where cnc.curriculum_node_id = cn.id
    );

  if v_empty_objectives_count > 0 then
    v_warnings := array_append(
      v_warnings,
      format(
        '%s leaf objective(s) have no lessons or assessment items bound.',
        v_empty_objectives_count
      )
    );
  end if;

  select count(distinct cnc.concept_id)
  into v_concept_count
  from public.curriculum_node_concepts cnc
  join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
  where cn.target_version_id = p_target_version_id;

  select count(distinct cnc.concept_id)
  into v_unassessed_concept_count
  from public.curriculum_node_concepts cnc
  join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
  where cn.target_version_id = p_target_version_id
    and not exists (
      select 1 from public.assessment_item_concepts aic
      where aic.concept_id = cnc.concept_id
    );

  if v_unassessed_concept_count > 0 then
    v_warnings := array_append(
      v_warnings,
      format('%s concept(s) have no direct assessment items.', v_unassessed_concept_count)
    );
  end if;

  select count(*)
  into v_provenance_citations_count
  from public.content_source_mappings
  where target_version_id = p_target_version_id;

  select count(*)
  into v_missing_provenance_count
  from public.curriculum_nodes cn
  where cn.target_version_id = p_target_version_id
    and not exists (
      select 1 from public.content_source_mappings csm
      where csm.curriculum_node_id = cn.id
    );

  if v_missing_provenance_count > 0 then
    v_warnings := array_append(
      v_warnings,
      format(
        '%s curriculum node(s) have no official source citation.',
        v_missing_provenance_count
      )
    );
  end if;

  select count(*)
  into v_cross_version_mappings_count
  from public.target_version_concept_mappings
  where from_target_version_id = p_target_version_id
     or to_target_version_id = p_target_version_id;

  if v_domain_count = 0 then
    v_blockers := array_append(
      v_blockers,
      'Target version has no domains (root curriculum nodes).'
    );
  end if;

  if v_objective_count = 0 then
    v_blockers := array_append(v_blockers, 'Target version has no objectives.');
  end if;

  v_can_stage_review :=
    (v_domain_count > 0 and v_objective_count > 0
      and (v_lesson_count > 0 or v_assessment_item_count > 0));
  v_can_publish :=
    (v_tv.status = 'review_ready'
      and v_is_weight_balanced
      and array_length(v_blockers, 1) is null);

  return jsonb_build_object(
    'target_version_id', v_tv.id,
    'version_code', v_tv.version_code,
    'status', v_tv.status,
    'target_title', v_tv.target_title,
    'domain_count', v_domain_count,
    'objective_count', v_objective_count,
    'leaf_objective_count', v_leaf_objective_count,
    'domain_weight_sum', v_domain_weight_sum,
    'is_domain_weight_balanced', v_is_weight_balanced,
    'lesson_count', v_lesson_count,
    'lesson_block_count', v_lesson_block_count,
    'stimulus_count', v_stimulus_count,
    'assessment_item_count', v_assessment_item_count,
    'empty_objectives_count', v_empty_objectives_count,
    'concept_coverage_count', v_concept_count,
    'unassessed_concepts_count', v_unassessed_concept_count,
    'provenance_citations_count', v_provenance_citations_count,
    'missing_provenance_count', v_missing_provenance_count,
    'cross_version_mappings_count', v_cross_version_mappings_count,
    'can_stage_review', v_can_stage_review,
    'can_publish', v_can_publish,
    'blocking_issues', to_jsonb(v_blockers),
    'warnings', to_jsonb(v_warnings)
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 4. Publication and retirement: service_role or target owner only.
-- Publishing requires review_ready; draft -> published shortcuts are forbidden.
-- ----------------------------------------------------------------------------
create or replace function public.publish_target_version(
  p_version_id uuid,
  p_retire_previous boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tv record;
  v_target_owner uuid;
  v_retired_ids uuid[] := '{}';
  v_ret record;
begin
  select tv.*, lt.created_by
  into v_tv
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_version_id;

  if not found then
    raise exception 'Target version not found: %', p_version_id;
  end if;

  v_target_owner := v_tv.created_by;

  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or v_target_owner is distinct from auth.uid()) then
    raise exception 'Unauthorized: only service_role or the target owner can publish a target version';
  end if;

  if v_tv.status = 'published' then
    return jsonb_build_object(
      'success', true,
      'target_version_id', p_version_id,
      'status', 'published',
      'already_published', true,
      'retired_version_ids', '[]'::jsonb,
      'retired_previous_count', 0
    );
  end if;

  if v_tv.status <> 'review_ready' then
    raise exception 'Cannot publish TargetVersion with status "%". Publication strictly requires "review_ready" staging status.', v_tv.status;
  end if;

  if p_retire_previous then
    for v_ret in
      select id
      from public.target_versions
      where target_id = v_tv.target_id
        and status = 'published'
        and id <> p_version_id
    loop
      update public.target_versions
      set status = 'retired', updated_at = now()
      where id = v_ret.id;
      v_retired_ids := array_append(v_retired_ids, v_ret.id);
    end loop;
  end if;

  update public.target_versions
  set status = 'published', updated_at = now()
  where id = p_version_id;

  update public.learning_targets
  set status = 'published', is_public = true, updated_at = now()
  where id = v_tv.target_id;

  return jsonb_build_object(
    'success', true,
    'target_version_id', p_version_id,
    'status', 'published',
    'already_published', false,
    'retired_version_ids', to_jsonb(v_retired_ids),
    'retired_previous_count', coalesce(array_length(v_retired_ids, 1), 0)
  );
end;
$$;

create or replace function public.retire_target_version(
  p_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tv record;
  v_target_owner uuid;
begin
  select tv.*, lt.created_by
  into v_tv
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_version_id;

  if not found then
    raise exception 'Target version not found: %', p_version_id;
  end if;

  v_target_owner := v_tv.created_by;

  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or v_target_owner is distinct from auth.uid()) then
    raise exception 'Unauthorized: only service_role or the target owner can retire a target version';
  end if;

  if v_tv.status = 'retired' then
    return jsonb_build_object(
      'success', true,
      'target_version_id', p_version_id,
      'status', 'retired',
      'already_retired', true
    );
  end if;

  if v_tv.status <> 'published' then
    raise exception 'Cannot retire target version in status "%". Only published versions can be retired.', v_tv.status;
  end if;

  update public.target_versions
  set status = 'retired', updated_at = now()
  where id = p_version_id;

  return jsonb_build_object(
    'success', true,
    'target_version_id', p_version_id,
    'status', 'retired',
    'already_retired', false
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 5. Explicit EXECUTE surface. SECURITY DEFINER functions are never left with
-- PostgreSQL's default PUBLIC execute privilege.
-- ----------------------------------------------------------------------------
revoke all on function public.evaluate_target_version_migration(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.evaluate_target_version_migration(uuid, uuid, uuid)
  to authenticated, service_role;

revoke all on function public.migrate_user_context_target_version(uuid, uuid, uuid)
  from public, anon;
grant execute on function public.migrate_user_context_target_version(uuid, uuid, uuid)
  to authenticated, service_role;

revoke all on function public.audit_target_version_readiness(uuid)
  from public, anon;
grant execute on function public.audit_target_version_readiness(uuid)
  to authenticated, service_role;

revoke all on function public.publish_target_version(uuid, boolean)
  from public, anon;
grant execute on function public.publish_target_version(uuid, boolean)
  to authenticated, service_role;

revoke all on function public.retire_target_version(uuid)
  from public, anon;
grant execute on function public.retire_target_version(uuid)
  to authenticated, service_role;
