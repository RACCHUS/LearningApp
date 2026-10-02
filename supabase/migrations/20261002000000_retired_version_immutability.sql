-- ============================================================================
-- Migration: 20261002000000_retired_version_immutability.sql
-- Description: Enforce strict immutability for published and retired target versions.
--              Only versions with status = 'draft' are editable or deletable.
--              Both published and retired versions are immutable historical snapshots.
-- ============================================================================

-- 1. Target versions update & delete policies
alter table public.target_versions enable row level security;

drop policy if exists "versions_update" on public.target_versions;
create policy "versions_update" on public.target_versions
  for update using (
    target_versions.status = 'draft'
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

drop policy if exists "versions_delete" on public.target_versions;
create policy "versions_delete" on public.target_versions
  for delete using (
    target_versions.status = 'draft'
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

-- 2. Curriculum nodes write policy
alter table public.curriculum_nodes enable row level security;

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

-- 3. Curriculum node bindings (courses, modules, lessons, concepts)
alter table public.curriculum_node_courses enable row level security;
drop policy if exists "node_courses_owner_write" on public.curriculum_node_courses;
create policy "node_courses_owner_write" on public.curriculum_node_courses
  for all using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_courses.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_courses.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  );

alter table public.curriculum_node_modules enable row level security;
drop policy if exists "node_modules_owner_write" on public.curriculum_node_modules;
create policy "node_modules_owner_write" on public.curriculum_node_modules
  for all using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_modules.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_modules.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  );

alter table public.curriculum_node_lessons enable row level security;
drop policy if exists "node_lessons_owner_write" on public.curriculum_node_lessons;
create policy "node_lessons_owner_write" on public.curriculum_node_lessons
  for all using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_lessons.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_lessons.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  );

alter table public.curriculum_node_concepts enable row level security;
drop policy if exists "node_concepts_owner_write" on public.curriculum_node_concepts;
create policy "node_concepts_owner_write" on public.curriculum_node_concepts
  for all using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_concepts.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_concepts.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status = 'draft'
    )
  );
