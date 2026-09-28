-- Learning Architecture v2 — Phase 2: Additive Data Migration
-- Safe, idempotent backfill from legacy tables into v2 structures:
--   1. career_paths -> learning_targets, target_versions, curriculum_nodes, curriculum_node_courses
--   2. legacy concepts -> knowledge_concepts, lesson_concepts
--   3. course_lessons section_titles -> modules

do $$
declare
  cp record;
  new_target_id uuid;
  new_version_id uuid;
  new_node_id uuid;
  c_rec record;
  new_concept_id uuid;
  sec_rec record;
  new_module_id uuid;
begin

  -- ==========================================================================
  -- 1. MIGRATE CAREER PATHS -> LEARNING TARGETS
  -- ==========================================================================
  if to_regclass('public.career_paths') is not null then
    for cp in
      select * from public.career_paths
    loop
      -- Check if already mapped in v2_migration_map
      select v2_id into new_target_id
      from public.v2_migration_map
      where legacy_type = 'career_path'
        and legacy_id = cp.id::text
        and v2_type = 'learning_target';

      if new_target_id is null then
        new_target_id := gen_random_uuid();

        insert into public.learning_targets (
          id,
          target_type,
          title,
          slug,
          description,
          image_url,
          is_public,
          is_official,
          status,
          created_by,
          created_at,
          updated_at
        ) values (
          new_target_id,
          'career',
          cp.title,
          cp.slug,
          cp.description,
          cp.image_url,
          coalesce(cp.is_public, true),
          coalesce(cp.is_official, false),
          'published',
          cp.created_by,
          cp.created_at,
          cp.updated_at
        )
        on conflict (slug) do update
          set title = excluded.title
        returning id into new_target_id;

        insert into public.v2_migration_map (
          legacy_type,
          legacy_id,
          v2_type,
          v2_id
        ) values (
          'career_path',
          cp.id::text,
          'learning_target',
          new_target_id
        )
        on conflict do nothing;

        -- Create default TargetVersion
        new_version_id := gen_random_uuid();
        insert into public.target_versions (
          id,
          target_id,
          version_code,
          title,
          status,
          created_at,
          updated_at
        ) values (
          new_version_id,
          new_target_id,
          'v1',
          'Initial Curriculum',
          'published',
          cp.created_at,
          cp.updated_at
        )
        on conflict (target_id, version_code) do update
          set title = excluded.title
        returning id into new_version_id;

        insert into public.v2_migration_map (
          legacy_type,
          legacy_id,
          v2_type,
          v2_id
        ) values (
          'career_path_version',
          cp.id::text,
          'target_version',
          new_version_id
        )
        on conflict do nothing;

        -- Create root CurriculumNode
        new_node_id := gen_random_uuid();
        insert into public.curriculum_nodes (
          id,
          target_version_id,
          node_type,
          title,
          sort_order,
          importance,
          created_at,
          updated_at
        ) values (
          new_node_id,
          new_version_id,
          'track',
          cp.title,
          0,
          'core',
          cp.created_at,
          cp.updated_at
        );

        -- Attach courses from career_path_courses if table exists
        if to_regclass('public.career_path_courses') is not null then
          insert into public.curriculum_node_courses (
            curriculum_node_id,
            course_id,
            sort_order,
            is_required
          )
          select
            new_node_id,
            cpc.course_id,
            coalesce(cpc.order_index, 0),
            coalesce(cpc.is_required, true)
          from public.career_path_courses cpc
          where cpc.career_path_id = cp.id
          on conflict do nothing;
        end if;

      end if;
    end loop;
  end if;

  -- ==========================================================================
  -- 2. MIGRATE LEGACY CONCEPTS -> KNOWLEDGE CONCEPTS & LESSON CONCEPTS
  -- ==========================================================================
  if to_regclass('public.concepts') is not null then
    for c_rec in
      select * from public.concepts
    loop
      select v2_id into new_concept_id
      from public.v2_migration_map
      where legacy_type = 'legacy_concept'
        and legacy_id = c_rec.id::text
        and v2_type = 'knowledge_concept';

      if new_concept_id is null then
        new_concept_id := gen_random_uuid();

        insert into public.knowledge_concepts (
          id,
          name,
          short_definition,
          emoji,
          status,
          created_by,
          source_type,
          source_id,
          created_at,
          updated_at
        ) values (
          new_concept_id,
          c_rec.concept_text,
          c_rec.example_text,
          c_rec.emoji,
          'active',
          c_rec.created_by,
          'legacy_concept',
          c_rec.id::text,
          coalesce(c_rec.created_at, now()),
          coalesce(c_rec.created_at, now())
        );

        insert into public.v2_migration_map (
          legacy_type,
          legacy_id,
          v2_type,
          v2_id
        ) values (
          'legacy_concept',
          c_rec.id::text,
          'knowledge_concept',
          new_concept_id
        )
        on conflict do nothing;

        -- Bind to lesson in lesson_concepts
        if c_rec.lesson_id is not null then
          insert into public.lesson_concepts (
            lesson_id,
            concept_id,
            role,
            weight,
            sort_order
          ) values (
            c_rec.lesson_id,
            new_concept_id,
            'primary',
            1.0,
            0
          )
          on conflict do nothing;
        end if;

      end if;
    end loop;
  end if;

  -- ==========================================================================
  -- 3. MIGRATE SECTION TITLES -> MODULES
  -- ==========================================================================
  if to_regclass('public.course_lessons') is not null then
    for sec_rec in
      select distinct course_id, section_title
      from public.course_lessons
      where section_title is not null
        and trim(section_title) <> ''
    loop
      -- Check if module already exists for this course and section
      select id into new_module_id
      from public.modules
      where course_id = sec_rec.course_id
        and title = trim(sec_rec.section_title);

      if new_module_id is null then
        new_module_id := gen_random_uuid();
        insert into public.modules (
          id,
          course_id,
          title,
          sort_order,
          is_required
        ) values (
          new_module_id,
          sec_rec.course_id,
          trim(sec_rec.section_title),
          0,
          true
        );
      end if;

      -- Update course_lessons with module_id
      update public.course_lessons
      set module_id = new_module_id
      where course_id = sec_rec.course_id
        and section_title = sec_rec.section_title
        and module_id is null;

    end loop;
  end if;

end $$;
