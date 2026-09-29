-- ============================================================================
-- Migration: 20260929000004_v2_stabilization_fix.sql
-- Description:
-- 1. Fix lesson_concepts_read RLS policy through course_lessons junction.
-- 2. Add owner write/modify policies for curriculum junction tables
--    (curriculum_node_courses, curriculum_node_modules, curriculum_node_lessons, curriculum_node_concepts)
--    with published-version immutability protection.
-- 3. Fix taxonomy source release lookups (source_system, 2018, onet_31_0).
-- 4. Establish full 5-tier SOC parentage (15-0000 -> 15-1200 -> 15-1250 -> 15-1252 -> 15-1252.00).
-- 5. Seed exam-gre Learning Target and TargetVersion.
-- 6. Deduplicate & consolidate the 6 overlapping broad fields into canonical CIP series.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. RLS Policy Hardening: lesson_concepts_read (via course_lessons)
-- ----------------------------------------------------------------------------
alter table public.lesson_concepts enable row level security;
drop policy if exists "lesson_concepts_read" on public.lesson_concepts;
create policy "lesson_concepts_read" on public.lesson_concepts
  for select using (
    exists (
      select 1 from public.lessons l
      where l.id = lesson_concepts.lesson_id
        and (
          l.user_id = auth.uid()
          or l.user_id is null
          or exists (
            select 1 from public.course_lessons cl
            join public.courses c on c.id = cl.course_id
            where cl.lesson_id = l.id
              and (c.is_public = true or c.user_id = auth.uid())
          )
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Curriculum Junctions Owner Write Policies & Immutability Invariant
-- ----------------------------------------------------------------------------

-- A. curriculum_node_courses
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
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_courses.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );

-- B. curriculum_node_modules
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
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_modules.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );

-- C. curriculum_node_lessons
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
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_lessons.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );

-- D. curriculum_node_concepts
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
        and v.status <> 'published'
    )
  )
  with check (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_concepts.curriculum_node_id
        and t.created_by = auth.uid()
        and v.status <> 'published'
    )
  );

-- ----------------------------------------------------------------------------
-- 3. Execute SOC 5-Tier Parentage & Seed exam-gre
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_soc_rel_id uuid;
  v_onet_rel_id uuid;
  v_major_id uuid;
  v_minor_id uuid;
  v_broad_id uuid;
  v_detailed_id uuid;
  v_f_uuid uuid;
  v_t_uuid uuid;
BEGIN
  -- Look up using canonical columns and values
  SELECT id INTO v_soc_rel_id FROM public.taxonomy_source_releases
  WHERE source_system = 'bls_soc' AND release_version = '2018' LIMIT 1;

  SELECT id INTO v_onet_rel_id FROM public.taxonomy_source_releases
  WHERE source_system = 'onet' AND release_version = 'onet_31_0' LIMIT 1;

  -- 1. Minor Group 15-1200
  SELECT id INTO v_major_id FROM public.occupation_nodes
  WHERE code = '15-0000' AND taxonomy_system = 'bls_soc' LIMIT 1;

  IF v_major_id IS NOT NULL THEN
    INSERT INTO public.occupation_nodes (
      code, title, description, level, taxonomy_system, taxonomy_version, source_release_id, is_active, parent_id
    ) VALUES (
      '15-1200', 'Computer Occupations', 'Computer and software systems, database administrators, and network analysts.',
      'minor_group', 'bls_soc', 'soc_2018', v_soc_rel_id, true, v_major_id
    ) ON CONFLICT (taxonomy_system, taxonomy_version, code) DO UPDATE SET
      title = EXCLUDED.title,
      parent_id = EXCLUDED.parent_id
    RETURNING id INTO v_minor_id;

    -- 2. Broad Occupation 15-1250
    INSERT INTO public.occupation_nodes (
      code, title, description, level, taxonomy_system, taxonomy_version, source_release_id, is_active, parent_id
    ) VALUES (
      '15-1250', 'Software and Web Developers, Programmers, and Testers',
      'Design, write, test, and maintain computer software, programs, and websites.',
      'broad_occupation', 'bls_soc', 'soc_2018', v_soc_rel_id, true, v_minor_id
    ) ON CONFLICT (taxonomy_system, taxonomy_version, code) DO UPDATE SET
      title = EXCLUDED.title,
      parent_id = EXCLUDED.parent_id
    RETURNING id INTO v_broad_id;

    -- 3. Connect Detailed Occupations to Broad/Minor parent_ids
    UPDATE public.occupation_nodes
    SET parent_id = v_broad_id
    WHERE code IN ('15-1252', '15-1254') AND taxonomy_system = 'bls_soc';

    UPDATE public.occupation_nodes
    SET parent_id = v_minor_id
    WHERE code = '15-1211' AND taxonomy_system = 'bls_soc';
  END IF;

  -- 4. Connect O*NET Extensions to parent detailed occupations
  SELECT id INTO v_detailed_id FROM public.occupation_nodes WHERE code = '15-1252' AND taxonomy_system = 'bls_soc' LIMIT 1;
  IF v_detailed_id IS NOT NULL THEN
    UPDATE public.occupation_nodes SET parent_id = v_detailed_id WHERE code = '15-1252.00' AND taxonomy_system = 'onet_soc';
  END IF;

  SELECT id INTO v_detailed_id FROM public.occupation_nodes WHERE code = '15-1211' AND taxonomy_system = 'bls_soc' LIMIT 1;
  IF v_detailed_id IS NOT NULL THEN
    UPDATE public.occupation_nodes SET parent_id = v_detailed_id WHERE code = '15-1211.00' AND taxonomy_system = 'onet_soc';
  END IF;

  SELECT id INTO v_detailed_id FROM public.occupation_nodes WHERE code = '15-2051' AND taxonomy_system = 'bls_soc' LIMIT 1;
  IF v_detailed_id IS NOT NULL THEN
    UPDATE public.occupation_nodes SET parent_id = v_detailed_id WHERE code = '15-2051.00' AND taxonomy_system = 'onet_soc';
  END IF;

  SELECT id INTO v_detailed_id FROM public.occupation_nodes WHERE code = '29-1141' AND taxonomy_system = 'bls_soc' LIMIT 1;
  IF v_detailed_id IS NOT NULL THEN
    UPDATE public.occupation_nodes SET parent_id = v_detailed_id WHERE code = '29-1141.00' AND taxonomy_system = 'onet_soc';
  END IF;

  -- 5. Seed exam-gre Learning Target
  SELECT id INTO v_f_uuid FROM public.fields WHERE slug = 'mathematics-statistics-series' LIMIT 1;

  INSERT INTO public.learning_targets (
    slug, title, target_type, description, field_id, is_public, status
  ) VALUES (
    'exam-gre',
    'GRE General Test',
    'standardized_exam',
    'Graduate Record Examinations assessing verbal reasoning, quantitative reasoning, and analytical writing skills for graduate admissions.',
    v_f_uuid,
    true,
    'published'
  ) ON CONFLICT (slug) DO UPDATE SET
    title = EXCLUDED.title,
    target_type = EXCLUDED.target_type,
    description = EXCLUDED.description,
    field_id = EXCLUDED.field_id
  RETURNING id INTO v_t_uuid;

  INSERT INTO public.target_versions (
    target_id, version_code, title, status
  ) VALUES (
    v_t_uuid,
    '2026.1',
    '2026 Initial Edition',
    'published'
  ) ON CONFLICT (target_id, version_code) DO NOTHING;

  IF v_f_uuid IS NOT NULL THEN
    INSERT INTO public.learning_target_fields (
      target_id, field_id, role, display_order
    ) VALUES (
      v_t_uuid, v_f_uuid, 'primary', 1
    ) ON CONFLICT (target_id, field_id) DO NOTHING;
  END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 4. Taxonomy Field Deduplication / Consolidation
-- Merge the 6 early duplicate broad fields into their canonical CIP series fields
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  rec record;
  v_old_id uuid;
  v_new_id uuid;
BEGIN
  -- Mapping of old overlapping slug to canonical CIP series slug
  FOR rec IN (
    VALUES
      ('computer-science', 'computer-sciences'),
      ('health-professions', 'health-professions-series'),
      ('engineering', 'engineering-disciplines'),
      ('business-management', 'business-management-series'),
      ('mathematics-statistics', 'mathematics-statistics-series'),
      ('biological-sciences', 'biological-biomedical-sciences')
  ) LOOP
    SELECT id INTO v_old_id FROM public.fields WHERE slug = rec.column1 LIMIT 1;
    SELECT id INTO v_new_id FROM public.fields WHERE slug = rec.column2 LIMIT 1;

    IF v_old_id IS NOT NULL AND v_new_id IS NOT NULL AND v_old_id <> v_new_id THEN
      -- Re-point learning targets
      UPDATE public.learning_targets SET field_id = v_new_id WHERE field_id = v_old_id;

      -- Re-point learning_target_fields
      UPDATE public.learning_target_fields SET field_id = v_new_id WHERE field_id = v_old_id
      AND NOT EXISTS (
        SELECT 1 FROM public.learning_target_fields ltf2
        WHERE ltf2.target_id = learning_target_fields.target_id AND ltf2.field_id = v_new_id
      );
      DELETE FROM public.learning_target_fields WHERE field_id = v_old_id;

      -- Re-point knowledge concepts
      UPDATE public.knowledge_concepts SET field_id = v_new_id WHERE field_id = v_old_id;

      -- Re-point catalog_cluster_fields
      DELETE FROM public.catalog_cluster_fields WHERE field_id = v_old_id;

      -- Delete the obsolete duplicate field
      DELETE FROM public.fields WHERE id = v_old_id;
    END IF;
  END LOOP;
END $$;
