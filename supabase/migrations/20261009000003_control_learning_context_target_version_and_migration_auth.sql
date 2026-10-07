-- ============================================================================
-- Migration: 20261009000003_control_learning_context_target_version_and_migration_auth.sql
-- Description:
--   1. Architectural Split between Normal Visibility & Historical-Context Access:
--      - public.is_target_version_visible(uuid): Normal catalog visibility
--        (published public versions, target author, reviewer in review_ready, admin).
--      - public.has_historical_target_version_access(uuid, uuid): Historical access
--        strictly granted to learners who legitimately enrolled before retirement.
--   2. Target Versions Read RLS:
--      - Re-declare 'versions_read' using is_target_version_visible() and
--        has_historical_target_version_access().
--   3. Controlled Learning Context Target Version (Database Trigger):
--      - Add trigger on public.learning_contexts preventing users from arbitrarily
--        assigning target_version_id to draft, review_ready, or retired versions.
--      - On INSERT or whenever target_version_id changes, require caller to have
--        normal visibility (is_target_version_visible) or service_role privilege.
--      - For target-root contexts (root_type = 'target'), verify root_id matches
--        the target_versions.target_id.
--      - Prevent reassigning user_id on context rows for non-admin callers.
--   4. Harden evaluate_target_version_migration RPC:
--      - Require source target version to be normally visible OR accessible via
--        has_historical_target_version_access(p_from_target_version_id, p_user_id).
--      - Require destination target version to be normally visible.
--   5. Harden migrate_user_context_target_version RPC:
--      - Require current target version to be normally visible OR accessible via
--        has_historical_target_version_access(current_tv_id, p_user_id).
--      - Require destination target version to be normally visible.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Normal Visibility & Historical Access Helper Functions
-- ----------------------------------------------------------------------------

-- Normal (Catalog) Visibility:
-- Returns true if the target version is currently visible in the general catalog
-- (e.g., published version of a public published target, target owner, reviewer).
-- Deliberately excludes retired versions so they cannot be newly selected or browsed.
create or replace function public.is_target_version_visible(p_target_version_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.target_versions tv
    join public.learning_targets lt on lt.id = tv.target_id
    where tv.id = p_target_version_id
      and (
        coalesce(auth.role(), '') = 'service_role'
        or (lt.status = 'published' and lt.is_public = true and tv.status = 'published')
        or (auth.uid() is not null and lt.created_by = auth.uid())
        or (auth.uid() is not null and tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
      )
  );
$$;

revoke all on function public.is_target_version_visible(uuid) from public;
grant execute on function public.is_target_version_visible(uuid) to anon, authenticated, service_role;

-- Historical-Context Access:
-- Returns true ONLY if the target version is retired AND the specified user
-- has a legitimate learning context referencing it.
-- Bound to auth.uid() for ordinary callers to prevent enrollment oracle privacy leaks.
create or replace function public.has_historical_target_version_access(
  p_target_version_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_effective_user_id uuid;
begin
  if p_target_version_id is null then
    return false;
  end if;

  -- Prevent enrollment oracle: ordinary callers cannot query whether another user
  -- has an enrolled context. Non-service-role callers are strictly scoped to auth.uid().
  if coalesce(auth.role(), '') = 'service_role' then
    v_effective_user_id := coalesce(p_user_id, auth.uid());
  else
    if auth.uid() is null then
      return false;
    end if;
    -- If an explicit user_id was supplied and does not match caller auth.uid(), reject
    if p_user_id is not null and p_user_id <> auth.uid() then
      return false;
    end if;
    v_effective_user_id := auth.uid();
  end if;

  if v_effective_user_id is null then
    return false;
  end if;

  return exists (
    select 1
    from public.target_versions tv
    join public.learning_contexts lc
      on lc.target_version_id = tv.id
     and lc.user_id = v_effective_user_id
    where tv.id = p_target_version_id
      and tv.status = 'retired'
  );
end;
$$;

revoke all on function public.has_historical_target_version_access(uuid, uuid) from public;
grant execute on function public.has_historical_target_version_access(uuid, uuid) to anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. Target Versions Read Policy (Two-Tier Visibility)
-- ----------------------------------------------------------------------------
drop policy if exists "versions_read" on public.target_versions;
create policy "versions_read" on public.target_versions
  for select using (
    coalesce(auth.role(), '') = 'service_role'
    or public.is_target_version_visible(id)
    or public.has_historical_target_version_access(id, auth.uid())
  );

-- ----------------------------------------------------------------------------
-- 3. Controlled Learning Context Target Version Trigger
-- ----------------------------------------------------------------------------
create or replace function public.validate_learning_context_target_version()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_target_id uuid;
  v_is_admin boolean;
begin
  v_is_admin := coalesce(auth.role(), '') = 'service_role';

  -- Prevent non-admins from transferring context ownership to another user
  if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id and not v_is_admin then
    raise exception 'Unauthorized: cannot reassign learning context ownership.';
  end if;

  if new.target_version_id is not null then
    -- Verify target version exists and retrieve its learning target id
    select tv.target_id into v_target_id
    from public.target_versions tv
    where tv.id = new.target_version_id;

    if not found then
      raise exception 'Target version % does not exist.', new.target_version_id;
    end if;

    -- Verify target-root contexts match the target version's learning target id
    if new.root_type = 'target' then
      if new.root_id is null or lower(trim(new.root_id)) <> lower(v_target_id::text) then
        raise exception 'Learning context root_id does not match target version target_id.';
      end if;
    end if;

    -- Enforce normal visibility on INSERT or when target_version_id is modified.
    -- Existing unchanged references to versions that subsequently retired remain allowed.
    if tg_op = 'INSERT' or new.target_version_id is distinct from old.target_version_id then
      if not v_is_admin and not public.is_target_version_visible(new.target_version_id) then
        raise exception 'Unauthorized: target version % is not visible or accessible.', new.target_version_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_learning_context_target_version on public.learning_contexts;
create trigger trg_validate_learning_context_target_version
  before insert or update on public.learning_contexts
  for each row execute function public.validate_learning_context_target_version();

-- ----------------------------------------------------------------------------
-- 4. Harden evaluate_target_version_migration RPC
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

  -- Source target version must be normally visible OR accessible via historical context for p_user_id
  if not (
    public.is_target_version_visible(p_from_target_version_id)
    or public.has_historical_target_version_access(p_from_target_version_id, p_user_id)
  ) then
    raise exception 'Unauthorized: source target version is not accessible for this caller.';
  end if;

  -- Destination version must be normally visible
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

revoke all on function public.evaluate_target_version_migration(uuid, uuid, uuid) from public;
grant execute on function public.evaluate_target_version_migration(uuid, uuid, uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Harden migrate_user_context_target_version RPC
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

  -- Current target version must be normally visible OR accessible via historical context
  if not (
    public.is_target_version_visible(v_from_tv.id)
    or public.has_historical_target_version_access(v_from_tv.id, p_user_id)
  ) then
    raise exception 'Unauthorized: current target version is not accessible for this caller.';
  end if;

  -- Destination version must be normally visible
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
