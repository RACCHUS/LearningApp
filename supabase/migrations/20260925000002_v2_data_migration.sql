-- Learning Architecture v2 — Phase 2: Additive Data Migration
-- Safe, idempotent backfill from legacy tables into v2 structures:
--   1. career_paths -> learning_targets, target_versions, curriculum_nodes, curriculum_node_courses
--   2. legacy concepts -> knowledge_concepts, lesson_concepts
--   3. course_lessons section_titles -> modules

do $$
declare
  cp record;
  cp_json jsonb;
  new_target_id uuid;
  new_version_id uuid;
  new_node_id uuid;
  c_rec record;
  c_json jsonb;
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
      cp_json := to_jsonb(cp);
      -- Check if already mapped in v2_migration_map
      select v2_id into new_target_id
      from public.v2_migration_map
      where legacy_type = 'career_path'
        and legacy_id = cp_json->>'id'
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
          coalesce(cp_json->>'title', 'Untitled Career'),
          coalesce(cp_json->>'slug', 'career-' || substr(md5(gen_random_uuid()::text), 1, 8)),
          cp_json->>'description',
          cp_json->>'image_url',
          coalesce((cp_json->>'is_public')::boolean, true),
          coalesce((cp_json->>'is_official')::boolean, false),
          'published',
          case
            when (cp_json->>'created_by') is not null and (cp_json->>'created_by') ~ '^[0-9a-fA-F-]{36}$'
              then (cp_json->>'created_by')::uuid
            when (cp_json->>'user_id') is not null and (cp_json->>'user_id') ~ '^[0-9a-fA-F-]{36}$'
              then (cp_json->>'user_id')::uuid
            else null
          end,
          coalesce((cp_json->>'created_at')::timestamptz, now()),
          coalesce((cp_json->>'updated_at')::timestamptz, (cp_json->>'created_at')::timestamptz, now())
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
          cp_json->>'id',
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
          coalesce((cp_json->>'created_at')::timestamptz, now()),
          coalesce((cp_json->>'updated_at')::timestamptz, (cp_json->>'created_at')::timestamptz, now())
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
          cp_json->>'id',
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
          coalesce(cp_json->>'title', 'Untitled Career'),
          0,
          'core',
          coalesce((cp_json->>'created_at')::timestamptz, now()),
          coalesce((cp_json->>'updated_at')::timestamptz, (cp_json->>'created_at')::timestamptz, now())
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
          where cpc.career_path_id = (cp_json->>'id')::uuid
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
      c_json := to_jsonb(c_rec);
      select v2_id into new_concept_id
      from public.v2_migration_map
      where legacy_type = 'legacy_concept'
        and legacy_id = c_json->>'id'
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
          coalesce(c_json->>'concept_text', c_json->>'name', 'Untitled Concept'),
          c_json->>'example_text',
          c_json->>'emoji',
          'active',
          case
            when (c_json->>'created_by') is not null and (c_json->>'created_by') ~ '^[0-9a-fA-F-]{36}$'
              then (c_json->>'created_by')::uuid
            when (c_json->>'user_id') is not null and (c_json->>'user_id') ~ '^[0-9a-fA-F-]{36}$'
              then (c_json->>'user_id')::uuid
            else null
          end,
          'legacy_concept',
          c_json->>'id',
          coalesce((c_json->>'created_at')::timestamptz, now()),
          coalesce((c_json->>'updated_at')::timestamptz, (c_json->>'created_at')::timestamptz, now())
        );

        insert into public.v2_migration_map (
          legacy_type,
          legacy_id,
          v2_type,
          v2_id
        ) values (
          'legacy_concept',
          c_json->>'id',
          'knowledge_concept',
          new_concept_id
        )
        on conflict do nothing;

        -- Bind to lesson in lesson_concepts if lesson exists
        if (c_json->>'lesson_id') is not null and (c_json->>'lesson_id') ~ '^[0-9a-fA-F-]{36}$' then
          insert into public.lesson_concepts (
            lesson_id,
            concept_id,
            role,
            weight,
            sort_order
          )
          select
            l.id,
            new_concept_id,
            'primary',
            1.0,
            0
          from public.lessons l
          where l.id = (c_json->>'lesson_id')::uuid
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
