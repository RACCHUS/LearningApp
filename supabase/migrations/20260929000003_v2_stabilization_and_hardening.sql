-- Migration: 20260929000003_v2_stabilization_and_hardening.sql
-- Description:
-- 1. Fix lesson_concepts_read RLS policy (remove "or true" backdoor).
-- 2. Complete 5-tier SOC hierarchy (Minor group 15-1200, Broad group 15-1250, and parent linkages for O*NET extensions).
-- 3. Seed missing exam-gre standardized exam learning target and version.

-- ----------------------------------------------------------------------------
-- 1. RLS Policy Hardening: lesson_concepts_read
-- ----------------------------------------------------------------------------
alter table public.lesson_concepts enable row level security;
drop policy if exists "lesson_concepts_read" on public.lesson_concepts;
create policy "lesson_concepts_read" on public.lesson_concepts
  for select using (
    exists (
      select 1 from public.lessons l
      left join public.courses c on c.id = l.course_id
      where l.id = lesson_concepts.lesson_id
        and (
          l.user_id = auth.uid()
          or l.user_id is null
          or c.is_public = true
          or c.user_id = auth.uid()
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 2. SOC 5-Tier Hierarchy Completion & O*NET Extension Parentage
-- 3. Seed exam-gre Learning Target
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
  SELECT id INTO v_soc_rel_id FROM public.taxonomy_source_releases WHERE source_name = 'bls_soc' AND release_version = 'soc_2018' LIMIT 1;
  SELECT id INTO v_onet_rel_id FROM public.taxonomy_source_releases WHERE source_name = 'onet_soc' AND release_version = '2019' LIMIT 1;

  -- 1. Minor Group 15-1200
  SELECT id INTO v_major_id FROM public.occupation_nodes WHERE code = '15-0000' AND taxonomy_system = 'bls_soc' LIMIT 1;

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
