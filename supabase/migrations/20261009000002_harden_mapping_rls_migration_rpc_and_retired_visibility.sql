-- ============================================================================
-- Migration: 20261009000002_harden_mapping_rls_migration_rpc_and_retired_visibility.sql
-- Description:
--   1. Harden target_version_concept_mappings read RLS:
--      Replace open 'using (true)' policy with one requiring that both the source
--      and destination target versions are visible to the caller (via
--      is_target_version_visible), or caller is service_role.
--   2. Allow learners to read retired target versions they are enrolled in:
--      Update target_versions RLS policy 'versions_read' so that learners whose
--      learning_contexts reference a retired version can read that target_version row.
--      This fixes v_target_version_updates (security_invoker = true) when detecting
--      retired or outdated versions for active learner contexts.
--   3. Harden evaluate_target_version_migration RPC:
--      Enforce that caller may only evaluate from a source target version that is
--      normally visible OR referenced by caller's own learning_context.
--      Enforce that destination target version is normally visible (via
--      is_target_version_visible).
--   4. Harden migrate_user_context_target_version RPC:
--      Enforce that destination target version is normally visible (via
--      is_target_version_visible).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Harden target_version_concept_mappings Read Policy
-- ----------------------------------------------------------------------------
drop policy if exists "tv_concept_mappings_read" on public.target_version_concept_mappings;
create policy "tv_concept_mappings_read" on public.target_version_concept_mappings
  for select using (
    coalesce(auth.role(), '') = 'service_role'
    or (
      public.is_target_version_visible(from_target_version_id)
      and public.is_target_version_visible(to_target_version_id)
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Update target_versions Read Policy for Retired Enrolled Versions
-- ----------------------------------------------------------------------------
drop policy if exists "versions_read" on public.target_versions;
create policy "versions_read" on public.target_versions
  for select using (
    coalesce(auth.role(), '') = 'service_role'
    or exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and (
          (t.status = 'published' and t.is_public = true and target_versions.status = 'published')
          or (t.created_by = auth.uid())
          or (target_versions.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
    or (
      target_versions.status = 'retired'
      and exists (
        select 1 from public.learning_contexts lc
        where lc.target_version_id = target_versions.id
          and lc.user_id = auth.uid()
      )
    )
  );

-- ----------------------------------------------------------------------------
-- 3. Harden evaluate_target_version_migration RPC
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
  v_from_tv record;
  v_to_tv record;
begin
  if coalesce(auth.role(), '') <> 'service_role'
     and (auth.uid() is null or p_user_id is null or auth.uid() <> p_user_id) then
    raise exception 'Unauthorized: cannot evaluate migration evidence for another user.';
  end if;

  select * into v_from_tv
  from public.target_versions
  where id = p_from_target_version_id;

  if not found then
    raise exception 'Source target version not found.';
  end if;

  select tv.*, lt.created_by as target_owner
  into v_to_tv
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_to_target_version_id;

  if not found then
    raise exception 'Destination target version not found.';
  end if;

  if v_from_tv.target_id <> v_to_tv.target_id then
    raise exception 'Cannot evaluate migration across different learning targets.';
  end if;

  if not (
    public.is_target_version_visible(p_from_target_version_id)
    or exists (
      select 1 from public.learning_contexts lc
      where lc.user_id = p_user_id
        and lc.target_version_id = p_from_target_version_id
    )
  ) then
    raise exception 'Unauthorized: source target version is not accessible for this caller.';
  end if;

  if not public.is_target_version_visible(p_to_target_version_id) then
    raise exception 'Unauthorized: destination target version is not published for this caller.';
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
    'source_concepts_count', v_source_concepts_count,
    'target_concepts_count', v_target_concepts_count,
    'mapped_count', v_mapped_count,
    'retained_count', v_retained_count,
    'removed_count', v_removed_count,
    'new_concepts_count', v_new_concepts_count,
    'transfer_retention_pct', v_avg_weight,
    'user_assessed_count', v_user_assessed_count,
    'projected_retained_assessed', v_projected_retained_assessed,
    'mappings', v_mappings_json
  );
end;
$$;

revoke all on function public.evaluate_target_version_migration(uuid, uuid, uuid) from public;
grant execute on function public.evaluate_target_version_migration(uuid, uuid, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 4. Harden migrate_user_context_target_version RPC
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

  if not public.is_target_version_visible(p_to_target_version_id) then
    raise exception 'Unauthorized: destination target version is not published for this caller.';
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

  -- Resume pointers are disposable breadcrumbs and carry activity IDs rather
  -- than curriculum-node foreign keys. A target-version migration can make the
  -- saved lesson/study-set position stale, so clear the pointer atomically.
  delete from public.resume_pointers
  where context_id = p_context_id;

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

revoke all on function public.migrate_user_context_target_version(uuid, uuid, uuid) from public;
grant execute on function public.migrate_user_context_target_version(uuid, uuid, uuid) to authenticated, service_role;
