-- ============================================================================
-- Migration: 20261005000000_content_hardening.sql
-- Description:
-- 1. Tighten Assessment RLS (assessment_stimuli, assessment_items, assessment_item_concepts).
-- 2. Enforce strict draft-only writes for curriculum nodes and junctions (review_ready is frozen).
-- 3. Make target_version_concept_mappings.to_concept_id nullable for 'removed' mappings.
-- 4. Add clean_draft_target_version RPC for idempotent, repeatable ingestion.
-- 5. Harden and disambiguate resolve_canonical_concept RPC.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Assessment Stimuli Visibility Hardening
-- ----------------------------------------------------------------------------
-- User-created stimuli must not leak publicly unless attached to a public lesson.
-- System/official stimuli (created_by is null) remain readable to all.
drop policy if exists "assessment_stimuli_read" on public.assessment_stimuli;
create policy "assessment_stimuli_read" on public.assessment_stimuli
  for select to authenticated, anon
  using (
    created_by is null
    or created_by = auth.uid()
    or exists (
      select 1 from public.assessment_items i
      join public.lessons l on l.id = i.lesson_id
      where i.stimulus_id = assessment_stimuli.id
        and (l.visibility = 'public' or l.user_id = auth.uid())
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Assessment Items Visibility Hardening
-- ----------------------------------------------------------------------------
-- Standalone items (lesson_id is null) must NOT be public if user_id belongs to a private user.
drop policy if exists "assessment_items_read" on public.assessment_items;
create policy "assessment_items_read" on public.assessment_items
  for select to authenticated, anon
  using (
    (lesson_id is null and (user_id is null or user_id = auth.uid()))
    or (lesson_id is not null and exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and (l.visibility = 'public' or l.user_id = auth.uid())
    ))
  );

drop policy if exists "assessment_items_write" on public.assessment_items;
create policy "assessment_items_write" on public.assessment_items
  for all to authenticated
  using (
    (user_id is not null and user_id = auth.uid())
    or (lesson_id is not null and exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and l.user_id = auth.uid()
    ))
  )
  with check (
    (user_id is not null and user_id = auth.uid())
    or (lesson_id is not null and exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and l.user_id = auth.uid()
    ))
  );

-- ----------------------------------------------------------------------------
-- 3. Assessment Item Concept Junction Visibility Hardening
-- ----------------------------------------------------------------------------
-- Concepts attached to private items must not leak. Inherit item visibility.
drop policy if exists "assessment_item_concepts_read" on public.assessment_item_concepts;
create policy "assessment_item_concepts_read" on public.assessment_item_concepts
  for select to authenticated, anon
  using (exists (
    select 1 from public.assessment_items a
    where a.id = assessment_item_concepts.assessment_item_id
      and (
        (a.lesson_id is null and (a.user_id is null or a.user_id = auth.uid()))
        or (a.lesson_id is not null and exists (
          select 1 from public.lessons l
          where l.id = a.lesson_id
            and (l.visibility = 'public' or l.user_id = auth.uid())
        ))
      )
  ));

-- ----------------------------------------------------------------------------
-- 4. Coherent Frozen review_ready Staging State
-- ----------------------------------------------------------------------------
-- review_ready represents a frozen content snapshot for QA review.
-- Curriculum node edits require transitioning back to 'draft'.
drop policy if exists "nodes_write" on public.curriculum_nodes;
create policy "nodes_write" on public.curriculum_nodes
  for all using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  )
  with check (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  );

-- TargetVersion updates: editable when draft, OR transitioning between draft and review_ready.
drop policy if exists "versions_update" on public.target_versions;
create policy "versions_update" on public.target_versions
  for update using (
    target_versions.status not in ('published', 'retired')
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 5. Nullable to_concept_id for Removed Concept Mappings
-- ----------------------------------------------------------------------------
alter table public.target_version_concept_mappings
  alter column to_concept_id drop not null;

alter table public.target_version_concept_mappings
  drop constraint if exists tv_concept_mappings_removed_check;

alter table public.target_version_concept_mappings
  add constraint tv_concept_mappings_removed_check
  check ( (mapping_type = 'removed') or (to_concept_id is not null) );

-- Drop and recreate unique constraint with coalesce so removed mappings are unique per from_concept
alter table public.target_version_concept_mappings
  drop constraint if exists target_version_concept_mappings_from_target_version_id_fro_key;

drop index if exists tv_concept_mappings_unique_idx;
create unique index tv_concept_mappings_unique_idx
  on public.target_version_concept_mappings (
    from_target_version_id,
    from_concept_id,
    to_target_version_id,
    coalesce(to_concept_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

-- ----------------------------------------------------------------------------
-- 6. Idempotent Draft Cleanup RPC (clean_draft_target_version)
-- ----------------------------------------------------------------------------
create or replace function public.clean_draft_target_version(
  p_version_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
begin
  select status into v_status
  from public.target_versions
  where id = p_version_id;

  if v_status is null then
    raise exception 'TargetVersion % not found', p_version_id;
  end if;

  if v_status <> 'draft' then
    raise exception 'Cannot clean TargetVersion with status "%". Only draft versions may be reset.', v_status;
  end if;

  -- 1. Delete official flashcards linked to concepts of this draft
  delete from public.flashcards
  where user_id is null
    and id in (
      select fc.flashcard_id
      from public.flashcard_concepts fc
      join public.curriculum_node_concepts cnc on cnc.concept_id = fc.concept_id
      join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
      where cn.target_version_id = p_version_id
    );

  -- 2. Delete official lessons bound to curriculum nodes of this draft
  delete from public.lessons
  where user_id is null
    and id in (
      select l.id
      from public.lessons l
      join public.curriculum_node_lessons cnl on cnl.lesson_id = l.id
      join public.curriculum_nodes cn on cn.id = cnl.curriculum_node_id
      where cn.target_version_id = p_version_id
    );

  -- 3. Delete content source mappings pointing to curriculum nodes of this draft
  delete from public.content_source_mappings
  where entity_type = 'curriculum_node'
    and entity_id in (
      select cn.id
      from public.curriculum_nodes cn
      where cn.target_version_id = p_version_id
    );

  -- 4. Delete curriculum nodes (cascades to curriculum_node_concepts, cnl)
  delete from public.curriculum_nodes
  where target_version_id = p_version_id;

  -- 5. Delete concept mappings involving this draft version
  delete from public.target_version_concept_mappings
  where from_target_version_id = p_version_id
     or to_target_version_id = p_version_id;

  -- 6. Delete content source mappings pointing to this version
  delete from public.content_source_mappings
  where entity_type = 'target_version'
    and entity_id = p_version_id;
end;
$$;

revoke all on function public.clean_draft_target_version(uuid) from public;
grant execute on function public.clean_draft_target_version(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 7. Ambiguity-Safe & Hardened Canonical Concept Resolver
-- ----------------------------------------------------------------------------
drop function if exists public.resolve_canonical_concept(text, text);

create or replace function public.resolve_canonical_concept(
  p_slug text,
  p_name text default null,
  p_field_id uuid default null
)
returns table (
  id uuid,
  field_id uuid,
  slug text,
  name text,
  status text,
  match_type text,
  is_ambiguous boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
  v_id uuid;
  v_field_id uuid;
  v_slug text;
  v_name text;
  v_status text;
begin
  -- 1. Exact slug match (canonical unique identity)
  select c.id, c.field_id, c.slug, c.name, c.status
  into v_id, v_field_id, v_slug, v_name, v_status
  from public.knowledge_concepts c
  where c.slug = p_slug
  limit 1;

  if found then
    return query select v_id, v_field_id, v_slug, v_name, v_status, 'exact_slug'::text, false;
    return;
  end if;

  -- 2. Exact unique alias match
  select count(*) into v_count
  from public.knowledge_concepts c
  where p_slug = any(c.aliases);

  if v_count = 1 then
    select c.id, c.field_id, c.slug, c.name, c.status
    into v_id, v_field_id, v_slug, v_name, v_status
    from public.knowledge_concepts c
    where p_slug = any(c.aliases)
    limit 1;

    return query select v_id, v_field_id, v_slug, v_name, v_status, 'slug_alias'::text, false;
    return;
  elsif v_count > 1 then
    -- Multiple candidates share this alias: check if field disambiguates
    if p_field_id is not null then
      select count(*) into v_count
      from public.knowledge_concepts c
      where p_slug = any(c.aliases)
        and (c.field_id = p_field_id or exists (
          select 1 from public.concept_fields cf
          where cf.concept_id = c.id and cf.field_id = p_field_id
        ));

      if v_count = 1 then
        select c.id, c.field_id, c.slug, c.name, c.status
        into v_id, v_field_id, v_slug, v_name, v_status
        from public.knowledge_concepts c
        where p_slug = any(c.aliases)
          and (c.field_id = p_field_id or exists (
            select 1 from public.concept_fields cf
            where cf.concept_id = c.id and cf.field_id = p_field_id
          ))
        limit 1;

        return query select v_id, v_field_id, v_slug, v_name, v_status, 'field_slug_alias'::text, false;
        return;
      end if;
    end if;

    -- Ambiguous alias across multiple concepts
    return query select null::uuid, null::uuid, null::text, null::text, null::text, 'ambiguous_alias'::text, true;
    return;
  end if;

  -- 3. Case-insensitive Name Match
  if p_name is not null and trim(p_name) <> '' then
    select count(*) into v_count
    from public.knowledge_concepts c
    where lower(c.name) = lower(trim(p_name));

    if v_count = 1 then
      select c.id, c.field_id, c.slug, c.name, c.status
      into v_id, v_field_id, v_slug, v_name, v_status
      from public.knowledge_concepts c
      where lower(c.name) = lower(trim(p_name))
      limit 1;

      return query select v_id, v_field_id, v_slug, v_name, v_status, 'exact_name'::text, false;
      return;
    elsif v_count > 1 then
      if p_field_id is not null then
        select count(*) into v_count
        from public.knowledge_concepts c
        where lower(c.name) = lower(trim(p_name))
          and (c.field_id = p_field_id or exists (
            select 1 from public.concept_fields cf
            where cf.concept_id = c.id and cf.field_id = p_field_id
          ));

        if v_count = 1 then
          select c.id, c.field_id, c.slug, c.name, c.status
          into v_id, v_field_id, v_slug, v_name, v_status
          from public.knowledge_concepts c
          where lower(c.name) = lower(trim(p_name))
            and (c.field_id = p_field_id or exists (
              select 1 from public.concept_fields cf
              where cf.concept_id = c.id and cf.field_id = p_field_id
            ))
          limit 1;

          return query select v_id, v_field_id, v_slug, v_name, v_status, 'field_exact_name'::text, false;
          return;
        end if;
      end if;

      return query select null::uuid, null::uuid, null::text, null::text, null::text, 'ambiguous_name'::text, true;
      return;
    end if;

    -- 4. Name matches an alias
    select count(*) into v_count
    from public.knowledge_concepts c
    where lower(trim(p_name)) = any(select lower(a) from unnest(c.aliases) a);

    if v_count = 1 then
      select c.id, c.field_id, c.slug, c.name, c.status
      into v_id, v_field_id, v_slug, v_name, v_status
      from public.knowledge_concepts c
      where lower(trim(p_name)) = any(select lower(a) from unnest(c.aliases) a)
      limit 1;

      return query select v_id, v_field_id, v_slug, v_name, v_status, 'name_alias'::text, false;
      return;
    elsif v_count > 1 then
      if p_field_id is not null then
        select count(*) into v_count
        from public.knowledge_concepts c
        where lower(trim(p_name)) = any(select lower(a) from unnest(c.aliases) a)
          and (c.field_id = p_field_id or exists (
            select 1 from public.concept_fields cf
            where cf.concept_id = c.id and cf.field_id = p_field_id
          ));

        if v_count = 1 then
          select c.id, c.field_id, c.slug, c.name, c.status
          into v_id, v_field_id, v_slug, v_name, v_status
          from public.knowledge_concepts c
          where lower(trim(p_name)) = any(select lower(a) from unnest(c.aliases) a)
            and (c.field_id = p_field_id or exists (
              select 1 from public.concept_fields cf
              where cf.concept_id = c.id and cf.field_id = p_field_id
            ))
          limit 1;

          return query select v_id, v_field_id, v_slug, v_name, v_status, 'field_name_alias'::text, false;
          return;
        end if;
      end if;

      return query select null::uuid, null::uuid, null::text, null::text, null::text, 'ambiguous_name_alias'::text, true;
      return;
    end if;
  end if;

  return;
end;
$$;

revoke all on function public.resolve_canonical_concept(text, text, uuid) from public;
grant execute on function public.resolve_canonical_concept(text, text, uuid) to authenticated, anon, service_role;
