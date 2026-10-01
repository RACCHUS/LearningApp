-- ============================================================================
-- Migration: 20260929000006_v2_system_targets_rls_hardening.sql
-- Description:
-- Harden target_versions and curriculum_nodes RLS policies so client writes
-- strictly require t.created_by = auth.uid().
-- Official/system targets with created_by IS NULL can only be modified via service_role.
-- ============================================================================

-- 1. target_versions write policies
alter table public.target_versions enable row level security;
drop policy if exists "versions_insert" on public.target_versions;
drop policy if exists "versions_update" on public.target_versions;
drop policy if exists "versions_delete" on public.target_versions;

create policy "versions_insert" on public.target_versions
  for insert with check (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

create policy "versions_update" on public.target_versions
  for update using (
    target_versions.status <> 'published'
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

create policy "versions_delete" on public.target_versions
  for delete using (
    target_versions.status <> 'published'
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

-- 2. curriculum_nodes write policies
alter table public.curriculum_nodes enable row level security;
drop policy if exists "nodes_write" on public.curriculum_nodes;
create policy "nodes_write" on public.curriculum_nodes
  for all using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );
