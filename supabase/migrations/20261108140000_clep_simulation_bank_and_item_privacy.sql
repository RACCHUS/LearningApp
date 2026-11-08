-- Migration: 20261107140000_clep_simulation_bank_and_item_privacy.sql
-- Description: Enforce database-level question-bank separation, metadata persistence in ingest_curriculum_manifest,
--              restrictive RLS privacy for simulation items, and secure CLEP simulation issuance and server-side grading RPCs.

-- 1. Helper function for simulation item identification
create or replace function public.is_protected_simulation_item(p_metadata jsonb)
returns boolean language sql immutable
as $$
  select coalesce((p_metadata->>'is_protected')::boolean, false) = true
      or coalesce(p_metadata->>'bank', '') = 'simulation_exam'
      or coalesce(p_metadata->>'exposure', '') = 'timed_exam_only';
$$;

revoke all on function public.is_protected_simulation_item(jsonb) from public, anon;
grant execute on function public.is_protected_simulation_item(jsonb) to authenticated, anon, service_role;

-- 2. Restrictive RLS policy protecting simulation items from direct learner reads
drop policy if exists assessment_items_no_direct_read_of_simulation_items on public.assessment_items;
create policy assessment_items_no_direct_read_of_simulation_items
  on public.assessment_items
  as restrictive for select to anon, authenticated
  using (not public.is_protected_simulation_item(metadata));

comment on policy assessment_items_no_direct_read_of_simulation_items on public.assessment_items is
  'Enforces database-level question-bank separation. Directly blocks anon and authenticated roles from reading protected simulation items and their scoring keys.';

-- 3. Updated ingest_curriculum_manifest RPC preserving item metadata
create or replace function public.ingest_curriculum_manifest(
  payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_field_id uuid;
  v_field_slug text;
  v_target_id uuid;
  v_target_slug text;
  v_version_id uuid;
  v_version_code text;
  v_version_status text;

  -- Counters
  v_concepts_count int := 0;
  v_stimuli_count int := 0;
  v_domains_count int := 0;
  v_objectives_count int := 0;
  v_lessons_count int := 0;
  v_blocks_count int := 0;
  v_items_count int := 0;
  v_flashcards_count int := 0;
  v_questions_count int := 0;
  v_mappings_count int := 0;

  -- Lookup Maps
  v_stimuli_map jsonb := '{}'::jsonb;         -- stimulus_key -> uuid
  v_concepts_map jsonb := '{}'::jsonb;        -- slug -> uuid
  v_source_releases_map jsonb := '{}'::jsonb; -- source_id or index -> uuid
  v_default_rel_id uuid := null;

  -- Concept processing variables
  v_concept jsonb;
  v_concept_id uuid;
  v_concept_slug text;
  v_concept_name text;
  v_explicit_canon text;
  v_matched_id uuid;
  v_matched_is_ambig boolean;
  v_concept_rel_id uuid;

  -- Content processing variables
  v_stim jsonb;
  v_stim_key text;
  v_stim_id uuid;
  v_domain jsonb;
  v_domain_id uuid;
  v_obj jsonb;
  v_obj_id uuid;
  v_lesson jsonb;
  v_lesson_id uuid;
  v_block jsonb;
  v_block_id uuid;
  v_item jsonb;
  v_item_id uuid;
  v_fc jsonb;
  v_fc_id uuid;
  v_term jsonb;
  v_question jsonb;
  v_mapping jsonb;
  v_source_rel jsonb;
  v_source_rel_idx int := 0;
  v_rel_id uuid;
  v_source_artifact jsonb;
  v_mapping_id uuid;
  v_source_mapping jsonb;
  v_from_concept_id uuid;
  v_to_concept_id uuid;

  v_entity_rel_id uuid;
  v_lesson_rel_id uuid;
  v_obj_rel_id uuid;
  v_raw_concept_ref text;
  v_resolved_cid uuid;

  -- Concept mapping resolution variables
  v_from_version_code text;
  v_from_concept_slug text;
  v_to_concept_slug text;
  v_mapping_type text;
  v_from_tv_id uuid;
  v_to_tv_id uuid;
  v_transfer_weight numeric;
  v_concept_mappings_count int := 0;
begin

  -- 1. Security Check: Service-role only
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and auth.role() <> 'service_role' then
    raise exception 'Unauthorized: ingest_curriculum_manifest requires service_role privilege';
  end if;

  -- 2. Extract / Upsert Field
  v_field_slug := payload->'field'->>'slug';
  if v_field_slug is not null and v_field_slug <> '' then
    select id into v_field_id from public.fields where slug = v_field_slug;
    if v_field_id is null then
      insert into public.fields (slug, name, description, field_kind)
      values (
        v_field_slug,
        coalesce(payload->'field'->>'name', v_field_slug),
        payload->'field'->>'description',
        'native_field'
      )
      returning id into v_field_id;
    end if;
  end if;

  -- 3. Extract / Upsert LearningTarget
  v_target_slug := payload->'target'->>'slug';
  if v_target_slug is null or v_target_slug = '' then
    raise exception 'Missing target.slug in manifest payload';
  end if;

  select id into v_target_id from public.learning_targets where slug = v_target_slug;
  if v_target_id is null then
    insert into public.learning_targets (
      slug, title, target_type, description, field_id, status, is_public
    ) values (
      v_target_slug,
      coalesce(payload->'target'->>'title', v_target_slug),
      coalesce(payload->'target'->>'target_type', coalesce(payload->'target'->>'target_kind', 'certification')),
      payload->'target'->>'description',
      v_field_id,
      'published',
      true
    )
    returning id into v_target_id;
  end if;

  -- 4. Extract / Upsert TargetVersion
  v_version_code := payload->'target_version'->>'version_code';
  if v_version_code is null or v_version_code = '' then
    raise exception 'Missing target_version.version_code in manifest payload';
  end if;

  select id, status into v_version_id, v_version_status
  from public.target_versions
  where target_id = v_target_id and version_code = v_version_code;

  if v_version_id is null then
    insert into public.target_versions (
      target_id, version_code, title, description, valid_from, status, metadata
    ) values (
      v_target_id,
      v_version_code,
      coalesce(payload->'target_version'->>'title', payload->'target'->>'version_title', v_version_code),
      coalesce(payload->'target_version'->>'description', payload->'target'->>'version_description'),
      case when coalesce(payload->'target_version'->>'valid_from', payload->'target'->>'valid_from') is not null
           then (coalesce(payload->'target_version'->>'valid_from', payload->'target'->>'valid_from'))::date
           else null end,
      'draft',
      coalesce(payload->'target_version'->'metadata', '{}'::jsonb)
    )
    returning id, status into v_version_id, v_version_status;
  else
    if v_version_status <> 'draft' then
      raise exception 'Cannot ingest into TargetVersion "%" with status "%". Only draft versions may be replaced.', v_version_code, v_version_status;
    end if;

    update public.target_versions
    set title = coalesce(payload->'target_version'->>'title', payload->'target'->>'version_title', title),
        description = coalesce(payload->'target_version'->>'description', payload->'target'->>'version_description', description),
        valid_from = case when coalesce(payload->'target_version'->>'valid_from', payload->'target'->>'valid_from') is not null
                          then (coalesce(payload->'target_version'->>'valid_from', payload->'target'->>'valid_from'))::date
                          else valid_from end,
        metadata = coalesce(payload->'target_version'->'metadata', metadata),
        updated_at = now()
    where id = v_version_id;
  end if;

  -- 5. Atomically Clean Previous Draft Content for this TargetVersion
  perform public.clean_draft_target_version(v_version_id);

  -- 6. Ingest Source Releases
  if jsonb_typeof(coalesce(payload->'source_releases', payload->'sources')) = 'array' then
    for v_source_rel in select * from jsonb_array_elements(coalesce(payload->'source_releases', payload->'sources'))
    loop
      insert into public.content_source_releases (
        publisher, title, version, source_url, license, retrieved_at, sha256, metadata
      ) values (
        coalesce(v_source_rel->>'publisher', 'Authoritative Source'),
        coalesce(v_source_rel->>'title', 'Official Blueprint'),
        coalesce(v_source_rel->>'version', 'v1'),
        v_source_rel->>'source_url',
        coalesce(v_source_rel->>'license', v_source_rel->>'license_name'),
        case when v_source_rel->>'retrieved_at' is not null
             then (v_source_rel->>'retrieved_at')::timestamptz
             else now() end,
        v_source_rel->>'sha256',
        coalesce(v_source_rel->'metadata', '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
          'system', v_source_rel->>'system',
          'rights_note', v_source_rel->>'rights_note'
        ))
      )
      on conflict (publisher, title, version) do update
      set source_url = excluded.source_url,
          license = excluded.license,
          retrieved_at = excluded.retrieved_at,
          sha256 = excluded.sha256,
          metadata = excluded.metadata
      returning id into v_rel_id;

      v_source_rel_idx := v_source_rel_idx + 1;
      if v_default_rel_id is null then
        v_default_rel_id := v_rel_id;
      end if;

      if v_source_rel ? 'id' then
        v_source_releases_map := v_source_releases_map || jsonb_build_object(v_source_rel->>'id', v_rel_id::text);
      end if;
      if v_source_rel ? 'source_id' then
        v_source_releases_map := v_source_releases_map || jsonb_build_object(v_source_rel->>'source_id', v_rel_id::text);
      end if;
      v_source_releases_map := v_source_releases_map || jsonb_build_object(
        coalesce(v_source_rel->>'publisher', '') || '/' || coalesce(v_source_rel->>'version', ''), v_rel_id::text
      );
      v_source_releases_map := v_source_releases_map || jsonb_build_object(
        (v_source_rel_idx - 1)::text, v_rel_id::text
      );

      -- Link root target_version to this source release
      insert into public.content_source_mappings (
        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
      ) values (
        v_rel_id,
        'target_version',
        v_version_id,
        'official_blueprint',
        coalesce(payload->'target_version'->>'citation', 'Root Blueprint'),
        'Root target version mapping to authoritative source release',
        '{}'::jsonb
      )
      on conflict (source_release_id, entity_type, entity_id, relationship) do update
      set citation_location = excluded.citation_location,
          notes = excluded.notes,
          metadata = excluded.metadata
      returning id into v_mapping_id;

      v_mappings_count := v_mappings_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'content_source_mapping', v_mapping_id)
      on conflict do nothing;

      -- Source Artifacts
      if jsonb_typeof(v_source_rel->'artifacts') = 'array' then
        for v_source_artifact in select * from jsonb_array_elements(v_source_rel->'artifacts')
        loop
          insert into public.content_source_artifacts (
            source_release_id, artifact_name, source_url, sha256, file_size_bytes, retrieved_at, metadata
          ) values (
            v_rel_id,
            coalesce(v_source_artifact->>'artifact_name', 'blueprint.pdf'),
            v_source_artifact->>'source_url',
            v_source_artifact->>'sha256',
            case when v_source_artifact->>'file_size_bytes' is not null
                 then (v_source_artifact->>'file_size_bytes')::bigint
                 else null end,
            case when v_source_artifact->>'retrieved_at' is not null
                 then (v_source_artifact->>'retrieved_at')::timestamptz
                 else now() end,
            coalesce(v_source_artifact->'metadata', '{}'::jsonb)
          )
          on conflict (source_release_id, artifact_name) do update
          set source_url = excluded.source_url,
              sha256 = excluded.sha256,
              file_size_bytes = excluded.file_size_bytes,
              retrieved_at = excluded.retrieved_at,
              metadata = excluded.metadata;
        end loop;
      end if;
    end loop;
  end if;

  -- 7. Fully Transactional Canonical Concepts Resolution & Ingestion (Option A)
  if jsonb_typeof(payload->'concepts') = 'array' then
    for v_concept in select * from jsonb_array_elements(payload->'concepts')
    loop
      v_concept_slug := v_concept->>'slug';
      v_concept_name := coalesce(v_concept->>'name', v_concept_slug);
      v_explicit_canon := v_concept->>'canonical_concept';
      v_concept_id := null;

      if v_explicit_canon is not null and trim(v_explicit_canon) <> '' then
        select id into v_concept_id
        from public.knowledge_concepts
        where slug = trim(v_explicit_canon);

        if v_concept_id is null then
          raise exception 'Explicit canonical_concept "%" declared for concept "%" (%) does not exist in knowledge_concepts. Overrides must fail closed.', v_explicit_canon, v_concept_name, v_concept_slug;
        end if;

        if v_field_id is not null then
          insert into public.concept_fields (concept_id, field_id, relationship)
          values (v_concept_id, v_field_id, 'core_concept')
          on conflict (concept_id, field_id) do nothing;
        end if;
      else
        -- Ambiguity-safe resolution RPC
        select r.id, r.is_ambiguous into v_matched_id, v_matched_is_ambig
        from public.resolve_canonical_concept(v_concept_slug, v_concept_name, v_field_id) r
        limit 1;

        if v_matched_is_ambig then
          raise exception 'Ambiguous canonical concept match for "%" (%). Multiple concepts share this name across fields and target field does not disambiguate. Declare "canonical_concept: <existing-slug>" explicitly in the manifest to resolve the ambiguity, or make the concept name specific.', v_concept_name, v_concept_slug;
        end if;

        if v_matched_id is not null then
          v_concept_id := v_matched_id;
          if v_field_id is not null then
            insert into public.concept_fields (concept_id, field_id, relationship)
            values (v_concept_id, v_field_id, 'core_concept')
            on conflict (concept_id, field_id) do nothing;
          end if;
        else
          -- Insert new canonical knowledge concept
          insert into public.knowledge_concepts (
            field_id, slug, name, short_definition, description, emoji, aliases, status
          ) values (
            v_field_id,
            v_concept_slug,
            v_concept_name,
            v_concept->>'short_definition',
            v_concept->>'description',
            coalesce(v_concept->>'emoji', '💡'),
            case when jsonb_typeof(v_concept->'aliases') = 'array'
                 then array(select jsonb_array_elements_text(v_concept->'aliases'))
                 else array[]::text[] end,
            'active'
          )
          returning id into v_concept_id;

          if v_field_id is not null then
            insert into public.concept_fields (concept_id, field_id, relationship)
            values (v_concept_id, v_field_id, 'core_concept')
            on conflict (concept_id, field_id) do nothing;
          end if;
        end if;
      end if;

      v_concepts_count := v_concepts_count + 1;
      v_concepts_map := v_concepts_map || jsonb_build_object(v_concept_slug, v_concept_id::text);

      -- Canonical Concept Provenance Mapping
      if v_default_rel_id is not null then
        v_concept_rel_id := null;
        if v_concept ? 'source_release_id' and v_source_releases_map ? (v_concept->>'source_release_id') then
          v_concept_rel_id := (v_source_releases_map->>(v_concept->>'source_release_id'))::uuid;
        elsif v_concept ? 'source_id' and v_source_releases_map ? (v_concept->>'source_id') then
          v_concept_rel_id := (v_source_releases_map->>(v_concept->>'source_id'))::uuid;
        else
          v_concept_rel_id := v_default_rel_id;
        end if;

        if v_concept_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_concept_rel_id,
            'knowledge_concept',
            v_concept_id,
            coalesce(v_concept->>'relationship', 'official_blueprint'),
            coalesce(v_concept->>'citation', coalesce(v_concept->>'citation_location', 'Concept ' || v_concept_slug)),
            coalesce(v_concept->>'notes', coalesce(v_concept->>'citation_notes', 'Authoritative concept definition from blueprint')),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata;

          v_mappings_count := v_mappings_count + 1;
        end if;
      end if;
    end loop;
  end if;

  -- 8. Ingest Shared Stimuli (root-level & objective-level)
  if jsonb_typeof(payload->'stimuli') = 'array' then
    for v_stim in select * from jsonb_array_elements(payload->'stimuli')
    loop
      v_stim_key := v_stim->>'stimulus_key';
      insert into public.assessment_stimuli (
        title, body, stimulus_type, metadata, origin_target_version_id
      ) values (
        coalesce(v_stim->>'title', 'Exhibit'),
        coalesce(v_stim->>'body', coalesce(v_stim->>'body_markdown', '')),
        coalesce(v_stim->>'stimulus_type', 'scenario'),
        jsonb_build_object(
          'media_url', v_stim->>'media_url',
          'credit', v_stim->>'credit',
          'attribution', v_stim->>'attribution'
        ),
        v_version_id
      )
      returning id into v_stim_id;

      v_stimuli_count := v_stimuli_count + 1;
      v_stimuli_map := v_stimuli_map || jsonb_build_object(v_stim_key, v_stim_id::text);

      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id, manifest_key)
      values (v_version_id, 'assessment_stimulus', v_stim_id, v_stim_key);

      -- Stimulus Source Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_stim ? 'source_release_id' and v_source_releases_map ? (v_stim->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_stim->>'source_release_id'))::uuid;
        elsif v_stim ? 'source_id' and v_source_releases_map ? (v_stim->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_stim->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'assessment_stimulus',
            v_stim_id,
            'official_blueprint',
            coalesce(v_stim->>'citation', coalesce(v_stim->>'citation_location', 'Official Blueprint Stimulus')),
            coalesce(v_stim->>'notes', 'Assessment stimulus mapping'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- 9. Ingest Standalone Target-level Flashcards
  if jsonb_typeof(payload->'flashcards') = 'array' then
    for v_fc in select * from jsonb_array_elements(payload->'flashcards')
    loop
      insert into public.flashcards (
        front, back, explanation, origin_target_version_id
      ) values (
        v_fc->>'front',
        v_fc->>'back',
        v_fc->>'explanation',
        v_version_id
      )
      returning id into v_fc_id;

      v_flashcards_count := v_flashcards_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'flashcard', v_fc_id);

      -- Link concepts by UUID or slug lookup
      if jsonb_typeof(v_fc->'concept_ids') = 'array' then
        for v_concept_id in select (jsonb_array_elements_text(v_fc->'concept_ids'))::uuid
        loop
          insert into public.flashcard_concepts (flashcard_id, concept_id)
          values (v_fc_id, v_concept_id)
          on conflict do nothing;
        end loop;
      end if;

      if jsonb_typeof(v_fc->'concept_slugs') = 'array' then
        for v_raw_concept_ref in select jsonb_array_elements_text(v_fc->'concept_slugs')
        loop
          if v_concepts_map ? v_raw_concept_ref then
            v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
            insert into public.flashcard_concepts (flashcard_id, concept_id)
            values (v_fc_id, v_resolved_cid)
            on conflict do nothing;
          end if;
        end loop;
      end if;

      -- Flashcard Provenance Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_fc ? 'source_release_id' and v_source_releases_map ? (v_fc->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_release_id'))::uuid;
        elsif v_fc ? 'source_id' and v_source_releases_map ? (v_fc->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'flashcard',
            v_fc_id,
            'derived_from',
            coalesce(v_fc->>'citation', coalesce(v_fc->>'citation_location', coalesce(v_fc->>'front', 'Flashcard'))),
            coalesce(v_fc->>'notes', 'Flashcard derived from authoritative blueprint'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- 10. Ingest Domains, Objectives, Lessons, Blocks, Assessment Items
  if jsonb_typeof(payload->'domains') = 'array' then
    for v_domain in select * from jsonb_array_elements(payload->'domains')
    loop
      insert into public.curriculum_nodes (
        target_version_id, node_type, code, title, description, sort_order, weight, metadata
      ) values (
        v_version_id,
        'domain',
        v_domain->>'code',
        coalesce(v_domain->>'title', 'Domain'),
        v_domain->>'description',
        coalesce((v_domain->>'sort_order')::int, 0),
        case when v_domain->>'weight_percentage' is not null
             then (v_domain->>'weight_percentage')::numeric
             when v_domain->>'weight' is not null
             then (v_domain->>'weight')::numeric
             else null end,
        coalesce(v_domain->'metadata', '{}'::jsonb)
      )
      returning id into v_domain_id;

      v_domains_count := v_domains_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'curriculum_node', v_domain_id);

      -- Domain Source Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_domain ? 'source_release_id' and v_source_releases_map ? (v_domain->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid;
        elsif v_domain ? 'source_id' and v_source_releases_map ? (v_domain->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_domain->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'curriculum_node',
            v_domain_id,
            'official_blueprint',
            coalesce(v_domain->>'citation', coalesce(v_domain->>'citation_location', 'Domain ' || coalesce(v_domain->>'code', ''))),
            coalesce(v_domain->>'notes', 'Curriculum domain node citation'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;

      -- Objectives
      if jsonb_typeof(v_domain->'objectives') = 'array' then
        for v_obj in select * from jsonb_array_elements(v_domain->'objectives')
        loop
          insert into public.curriculum_nodes (
            target_version_id, parent_id, node_type, code, title, description, sort_order, metadata
          ) values (
            v_version_id,
            v_domain_id,
            'objective',
            v_obj->>'code',
            coalesce(v_obj->>'title', 'Objective'),
            v_obj->>'description',
            coalesce((v_obj->>'sort_order')::int, 0),
            jsonb_build_object('bloom_level', coalesce(v_obj->>'bloom_level', 'understand'))
          )
          returning id into v_obj_id;

          v_objectives_count := v_objectives_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'curriculum_node', v_obj_id);

          -- Objective Source Mapping
          if v_default_rel_id is not null then
            v_entity_rel_id := null;
            if v_obj ? 'source_release_id' and v_source_releases_map ? (v_obj->>'source_release_id') then
              v_entity_rel_id := (v_source_releases_map->>(v_obj->>'source_release_id'))::uuid;
            elsif v_obj ? 'source_id' and v_source_releases_map ? (v_obj->>'source_id') then
              v_entity_rel_id := (v_source_releases_map->>(v_obj->>'source_id'))::uuid;
            else
              v_entity_rel_id := coalesce(
                (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid,
                (v_source_releases_map->>(v_domain->>'source_id'))::uuid,
                v_default_rel_id
              );
            end if;

            v_obj_rel_id := v_entity_rel_id;

            if v_entity_rel_id is not null then
              insert into public.content_source_mappings (
                source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
              ) values (
                v_entity_rel_id,
                'curriculum_node',
                v_obj_id,
                'official_blueprint',
                coalesce(v_obj->>'citation', coalesce(v_obj->>'citation_location', 'Objective ' || coalesce(v_obj->>'code', ''))),
                coalesce(v_obj->>'notes', 'Curriculum objective node citation'),
                '{}'::jsonb
              )
              on conflict (source_release_id, entity_type, entity_id, relationship) do update
              set citation_location = excluded.citation_location,
                  notes = excluded.notes,
                  metadata = excluded.metadata
              returning id into v_mapping_id;

              v_mappings_count := v_mappings_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'content_source_mapping', v_mapping_id)
              on conflict do nothing;
            end if;
          end if;

          -- Link objective concepts by UUID or slug
          if jsonb_typeof(v_obj->'concept_ids') = 'array' then
            for v_concept_id in select (jsonb_array_elements_text(v_obj->'concept_ids'))::uuid
            loop
              insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
              values (v_obj_id, v_concept_id)
              on conflict do nothing;
            end loop;
          end if;

          if jsonb_typeof(v_obj->'concept_slugs') = 'array' then
            for v_raw_concept_ref in select jsonb_array_elements_text(v_obj->'concept_slugs')
            loop
              if v_concepts_map ? v_raw_concept_ref then
                v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
                values (v_obj_id, v_resolved_cid)
                on conflict do nothing;
              end if;
            end loop;
          end if;

          -- Objective Flashcards
          if jsonb_typeof(v_obj->'flashcards') = 'array' then
            for v_fc in select * from jsonb_array_elements(v_obj->'flashcards')
            loop
              insert into public.flashcards (
                front, back, explanation, origin_target_version_id
              ) values (
                v_fc->>'front',
                v_fc->>'back',
                v_fc->>'explanation',
                v_version_id
              )
              returning id into v_fc_id;

              v_flashcards_count := v_flashcards_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'flashcard', v_fc_id);

              if jsonb_typeof(v_fc->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_fc->'concept_ids'))::uuid
                loop
                  insert into public.flashcard_concepts (flashcard_id, concept_id)
                  values (v_fc_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_fc->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_fc->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.flashcard_concepts (flashcard_id, concept_id)
                    values (v_fc_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Objective Flashcard Provenance Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_fc ? 'source_release_id' and v_source_releases_map ? (v_fc->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_release_id'))::uuid;
                elsif v_fc ? 'source_id' and v_source_releases_map ? (v_fc->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(v_obj_rel_id, v_default_rel_id);
                end if;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'flashcard',
                    v_fc_id,
                    'derived_from',
                    coalesce(v_fc->>'citation', coalesce(v_fc->>'citation_location', coalesce(v_fc->>'front', 'Objective Flashcard'))),
                    coalesce(v_fc->>'notes', 'Flashcard derived from authoritative objective blueprint'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;
            end loop;
          end if;

          -- Objective Assessment Items
          if jsonb_typeof(v_obj->'assessment_items') = 'array' then
            for v_item in select * from jsonb_array_elements(v_obj->'assessment_items')
            loop
              v_stim_key := v_item->>'stimulus_key';
              v_stim_id := null;
              if v_stim_key is not null and v_stimuli_map ? v_stim_key then
                v_stim_id := (v_stimuli_map->>v_stim_key)::uuid;
              end if;

              insert into public.assessment_items (
                stimulus_id, prompt, interaction_type, response_spec, scoring_spec, explanation, origin_target_version_id, metadata
              ) values (
                v_stim_id,
                v_item->>'prompt',
                coalesce(v_item->>'interaction_type', 'single_choice'),
                coalesce(v_item->'response_spec', '{}'::jsonb),
                coalesce(v_item->'scoring_spec', '{}'::jsonb),
                v_item->>'explanation',
                v_version_id,
                coalesce(v_item->'metadata', '{}'::jsonb)
              )
              returning id into v_item_id;

              v_items_count := v_items_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'assessment_item', v_item_id);

              if jsonb_typeof(v_item->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_item->'concept_ids'))::uuid
                loop
                  insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                  values (v_item_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_item->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_item->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                    values (v_item_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Objective Assessment Item Provenance Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_item ? 'source_release_id' and v_source_releases_map ? (v_item->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_release_id'))::uuid;
                elsif v_item ? 'source_id' and v_source_releases_map ? (v_item->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(v_obj_rel_id, v_default_rel_id);
                end if;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'assessment_item',
                    v_item_id,
                    'derived_from',
                    coalesce(v_item->>'citation', coalesce(v_item->>'citation_location', substring(coalesce(v_item->>'prompt', 'Assessment Item') from 1 for 100))),
                    coalesce(v_item->>'notes', 'Assessment item derived from authoritative blueprint'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;
            end loop;
          end if;

          -- Lessons
          if jsonb_typeof(v_obj->'lessons') = 'array' then
            for v_lesson in select * from jsonb_array_elements(v_obj->'lessons')
            loop
              insert into public.lessons (
                title, description, visibility, origin_target_version_id
              ) values (
                v_lesson->>'title',
                coalesce(v_lesson->>'description', v_lesson->>'summary'),
                'public',
                v_version_id
              )
              returning id into v_lesson_id;

              v_lessons_count := v_lessons_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'lesson', v_lesson_id);

              -- Lesson Source Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_lesson ? 'source_release_id' and v_source_releases_map ? (v_lesson->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_lesson->>'source_release_id'))::uuid;
                elsif v_lesson ? 'source_id' and v_source_releases_map ? (v_lesson->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_lesson->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(
                    (v_source_releases_map->>(v_obj->>'source_release_id'))::uuid,
                    (v_source_releases_map->>(v_obj->>'source_id'))::uuid,
                    coalesce(
                      (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid,
                      (v_source_releases_map->>(v_domain->>'source_id'))::uuid,
                      v_default_rel_id
                    )
                  );
                end if;

                v_lesson_rel_id := v_entity_rel_id;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'lesson',
                    v_lesson_id,
                    'derived_from',
                    coalesce(v_lesson->>'citation', coalesce(v_lesson->>'citation_location', coalesce(v_lesson->>'title', 'Lesson'))),
                    coalesce(v_lesson->>'notes', 'Lesson derived from authoritative source'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;

              -- Bind lesson to objective
              insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
              values (v_obj_id, v_lesson_id, coalesce((v_lesson->>'order_index')::int, 0))
              on conflict do nothing;

              -- Scoped lesson concept linking
              if jsonb_typeof(v_lesson->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_lesson->'concept_ids'))::uuid
                loop
                  insert into public.lesson_concepts (lesson_id, concept_id)
                  values (v_lesson_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_lesson->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_lesson->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.lesson_concepts (lesson_id, concept_id)
                    values (v_lesson_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Lesson Blocks
              if jsonb_typeof(v_lesson->'blocks') = 'array' then
                for v_block in select * from jsonb_array_elements(v_lesson->'blocks')
                loop
                  insert into public.lesson_blocks (
                    lesson_id, block_type, content, sort_order
                  ) values (
                    v_lesson_id,
                    coalesce(v_block->>'block_type', 'markdown'),
                    coalesce(v_block->'content', '{}'::jsonb),
                    coalesce((v_block->>'sort_order')::int, 0)
                  )
                  returning id into v_block_id;

                  v_blocks_count := v_blocks_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'lesson_block', v_block_id);

                  -- Lesson Block Provenance Mapping
                  if v_default_rel_id is not null then
                    v_entity_rel_id := null;
                    if v_block ? 'source_release_id' and v_source_releases_map ? (v_block->>'source_release_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_block->>'source_release_id'))::uuid;
                    elsif v_block ? 'source_id' and v_source_releases_map ? (v_block->>'source_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_block->>'source_id'))::uuid;
                    else
                      v_entity_rel_id := coalesce(v_lesson_rel_id, v_default_rel_id);
                    end if;

                    if v_entity_rel_id is not null then
                      insert into public.content_source_mappings (
                        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                      ) values (
                        v_entity_rel_id,
                        'lesson_block',
                        v_block_id,
                        'derived_from',
                        coalesce(v_block->>'citation', coalesce(v_block->>'citation_location', coalesce(v_lesson->>'title', 'Lesson Block'))),
                        coalesce(v_block->>'notes', 'Lesson content block citation'),
                        '{}'::jsonb
                      )
                      on conflict (source_release_id, entity_type, entity_id, relationship) do update
                      set citation_location = excluded.citation_location,
                          notes = excluded.notes,
                          metadata = excluded.metadata
                      returning id into v_mapping_id;

                      v_mappings_count := v_mappings_count + 1;
                      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                      values (v_version_id, 'content_source_mapping', v_mapping_id)
                      on conflict do nothing;
                    end if;
                  end if;
                end loop;
              end if;

              -- Lesson Terms
              if jsonb_typeof(v_lesson->'terms') = 'array' then
                for v_term in select * from jsonb_array_elements(v_lesson->'terms')
                loop
                  insert into public.terms (lesson_id, term, definition)
                  values (v_lesson_id, v_term->>'term', v_term->>'definition');
                end loop;
              end if;

              -- Lesson Questions
              if jsonb_typeof(v_lesson->'questions') = 'array' then
                for v_question in select * from jsonb_array_elements(v_lesson->'questions')
                loop
                  insert into public.questions (
                    lesson_id, question_text, options, correct_answer, type, explanation,
                    accepted_answers, grading_method, numeric_tolerance
                  ) values (
                    v_lesson_id,
                    coalesce(v_question->>'question_text', v_question->>'question'),
                    coalesce(v_question->'options', '[]'::jsonb),
                    coalesce((coalesce(v_question->>'correct_answer', v_question->>'correct_index'))::int, 0),
                    coalesce(v_question->>'type', 'mcq'),
                    v_question->>'explanation',
                    array(select jsonb_array_elements_text(coalesce(v_question->'accepted_answers', '[]'::jsonb))),
                    coalesce(v_question->>'grading_method', 'normalized_text'),
                    case when v_question->>'numeric_tolerance' is not null
                      then (v_question->>'numeric_tolerance')::numeric
                      else null end
                  );
                  v_questions_count := v_questions_count + 1;
                end loop;
              end if;

              -- Lesson Assessment Items
              if jsonb_typeof(v_lesson->'assessment_items') = 'array' then
                for v_item in select * from jsonb_array_elements(v_lesson->'assessment_items')
                loop
                  v_stim_key := v_item->>'stimulus_key';
                  v_stim_id := null;
                  if v_stim_key is not null and v_stimuli_map ? v_stim_key then
                    v_stim_id := (v_stimuli_map->>v_stim_key)::uuid;
                  end if;

                  insert into public.assessment_items (
                    lesson_id, stimulus_id, prompt, interaction_type, response_spec, scoring_spec, explanation, origin_target_version_id, metadata
                  ) values (
                    v_lesson_id,
                    v_stim_id,
                    v_item->>'prompt',
                    coalesce(v_item->>'interaction_type', 'single_choice'),
                    coalesce(v_item->'response_spec', '{}'::jsonb),
                    coalesce(v_item->'scoring_spec', '{}'::jsonb),
                    v_item->>'explanation',
                    v_version_id,
                    coalesce(v_item->'metadata', '{}'::jsonb)
                  )
                  returning id into v_item_id;

                  v_items_count := v_items_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'assessment_item', v_item_id);

                  if jsonb_typeof(v_item->'concept_ids') = 'array' then
                    for v_concept_id in select (jsonb_array_elements_text(v_item->'concept_ids'))::uuid
                    loop
                      insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                      values (v_item_id, v_concept_id)
                      on conflict do nothing;
                    end loop;
                  end if;

                  if jsonb_typeof(v_item->'concept_slugs') = 'array' then
                    for v_raw_concept_ref in select jsonb_array_elements_text(v_item->'concept_slugs')
                    loop
                      if v_concepts_map ? v_raw_concept_ref then
                        v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                        insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                        values (v_item_id, v_resolved_cid)
                        on conflict do nothing;
                      end if;
                    end loop;
                  end if;

                  -- Lesson Assessment Item Provenance Mapping
                  if v_default_rel_id is not null then
                    v_entity_rel_id := null;
                    if v_item ? 'source_release_id' and v_source_releases_map ? (v_item->>'source_release_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_release_id'))::uuid;
                    elsif v_item ? 'source_id' and v_source_releases_map ? (v_item->>'source_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_id'))::uuid;
                    else
                      v_entity_rel_id := coalesce(v_lesson_rel_id, v_default_rel_id);
                    end if;

                    if v_entity_rel_id is not null then
                      insert into public.content_source_mappings (
                        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                      ) values (
                        v_entity_rel_id,
                        'assessment_item',
                        v_item_id,
                        'derived_from',
                        coalesce(v_item->>'citation', coalesce(v_item->>'citation_location', substring(coalesce(v_item->>'prompt', 'Lesson Assessment Item') from 1 for 100))),
                        coalesce(v_item->>'notes', 'Lesson assessment item derived from authoritative blueprint'),
                        '{}'::jsonb
                      )
                      on conflict (source_release_id, entity_type, entity_id, relationship) do update
                      set citation_location = excluded.citation_location,
                          notes = excluded.notes,
                          metadata = excluded.metadata
                      returning id into v_mapping_id;

                      v_mappings_count := v_mappings_count + 1;
                      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                      values (v_version_id, 'content_source_mapping', v_mapping_id)
                      on conflict do nothing;
                    end if;
                  end if;
                end loop;
              end if;

            end loop;
          end if; -- lessons

        end loop;
      end if; -- objectives

    end loop;
  end if; -- domains

  -- 11. Ingest Explicit Custom Source Mappings
  if jsonb_typeof(payload->'source_mappings') = 'array' then
    for v_source_mapping in select * from jsonb_array_elements(payload->'source_mappings')
    loop
      insert into public.content_source_mappings (
        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
      ) values (
        (v_source_mapping->>'source_release_id')::uuid,
        v_source_mapping->>'entity_type',
        (v_source_mapping->>'entity_id')::uuid,
        coalesce(v_source_mapping->>'relationship', 'derived_from'),
        coalesce(v_source_mapping->>'citation_location', v_source_mapping->>'section_reference'),
        coalesce(v_source_mapping->>'notes', v_source_mapping->>'citation_text'),
        coalesce(v_source_mapping->'metadata', '{}'::jsonb)
      )
      on conflict (source_release_id, entity_type, entity_id, relationship) do update
      set citation_location = excluded.citation_location,
          notes = excluded.notes,
          metadata = excluded.metadata
      returning id into v_mapping_id;

      v_mappings_count := v_mappings_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'content_source_mapping', v_mapping_id)
      on conflict do nothing;
    end loop;
  end if;

  -- 12. Ingest Concept Version Mappings
  if jsonb_typeof(coalesce(payload->'concept_mappings', payload->'target_version_concept_mappings')) = 'array' then
    for v_mapping in select * from jsonb_array_elements(coalesce(payload->'concept_mappings', payload->'target_version_concept_mappings'))
    loop
      -- Check if standard manifest format (from_version_code, from_concept_slug, etc.)
      if v_mapping ? 'from_version_code' or v_mapping ? 'from_concept_slug' then
        v_from_version_code := v_mapping->>'from_version_code';
        v_from_concept_slug := v_mapping->>'from_concept_slug';
        v_to_concept_slug := v_mapping->>'to_concept_slug';
        v_mapping_type := coalesce(v_mapping->>'mapping_type', 'unchanged');

        if v_mapping_type = 'equivalent' then
          v_mapping_type := 'unchanged';
        end if;

        if v_mapping_type not in ('unchanged', 'renamed', 'expanded', 'narrowed', 'replaced', 'removed') then
          raise exception 'Invalid mapping_type "%" for concept mapping. Must be one of unchanged, renamed, expanded, narrowed, replaced, removed.', v_mapping_type;
        end if;

        -- Resolve source version ID
        select id into v_from_tv_id
        from public.target_versions
        where target_id = v_target_id and version_code = v_from_version_code
        limit 1;

        if v_from_tv_id is null then
          raise exception 'Target version with version_code "%" not found for target "%".', v_from_version_code, v_target_id;
        end if;

        -- Resolve source concept ID
        v_from_concept_id := null;
        if v_concepts_map ? v_from_concept_slug then
          v_from_concept_id := (v_concepts_map->>v_from_concept_slug)::uuid;
        else
          select id into v_from_concept_id
          from public.knowledge_concepts
          where slug = v_from_concept_slug
          limit 1;
        end if;

        if v_from_concept_id is null then
          raise exception 'Source concept with slug "%" not found for concept mapping.', v_from_concept_slug;
        end if;

        -- Validate source concept is attached to source version through curriculum_node_concepts
        if not exists (
          select 1
          from public.curriculum_node_concepts cnc
          join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
          where cn.target_version_id = v_from_tv_id
            and cnc.concept_id = v_from_concept_id
        ) then
          raise exception 'Source concept "%" (id: %) is not associated with source target version "%" (version_code: %).',
            v_from_concept_slug, v_from_concept_id, v_from_tv_id, v_from_version_code;
        end if;

        -- Validate destination concept and mapping invariant
        v_to_concept_id := null;
        if v_mapping_type = 'removed' then
          if v_to_concept_slug is not null and trim(v_to_concept_slug) <> '' then
            raise exception 'Removed concept mapping for source concept "%" cannot specify a destination concept (got "%").',
              v_from_concept_slug, v_to_concept_slug;
          end if;

          if v_mapping ? 'transfer_weight' and v_mapping->>'transfer_weight' is not null and (v_mapping->>'transfer_weight')::numeric <> 0.0 then
            raise exception 'Removed concept mapping for source concept "%" must have transfer_weight = 0 (got %).',
              v_from_concept_slug, (v_mapping->>'transfer_weight')::numeric;
          end if;
          v_transfer_weight := 0.0;
        else
          if v_to_concept_slug is null or trim(v_to_concept_slug) = '' then
            raise exception 'Destination concept slug must be specified for mapping_type "%".', v_mapping_type;
          end if;

          if v_concepts_map ? v_to_concept_slug then
            v_to_concept_id := (v_concepts_map->>v_to_concept_slug)::uuid;
          else
            select id into v_to_concept_id
            from public.knowledge_concepts
            where slug = v_to_concept_slug
            limit 1;
          end if;

          if v_to_concept_id is null then
            raise exception 'Destination concept with slug "%" not found for concept mapping.', v_to_concept_slug;
          end if;

          -- Validate destination concept is attached to destination version through curriculum_node_concepts
          if not exists (
            select 1
            from public.curriculum_node_concepts cnc
            join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
            where cn.target_version_id = v_version_id
              and cnc.concept_id = v_to_concept_id
          ) then
            raise exception 'Destination concept "%" (id: %) is not associated with destination target version "%".',
              v_to_concept_slug, v_to_concept_id, v_version_id;
          end if;

          if v_mapping ? 'transfer_weight' and v_mapping->>'transfer_weight' is not null then
            v_transfer_weight := (v_mapping->>'transfer_weight')::numeric;
          else
            v_transfer_weight := 1.0;
          end if;

          if v_transfer_weight < 0.0 or v_transfer_weight > 1.0 then
            raise exception 'Concept mapping transfer_weight % must be between 0.0 and 1.0.', v_transfer_weight;
          end if;
        end if;

        insert into public.target_version_concept_mappings (
          from_target_version_id, from_concept_id, to_target_version_id, to_concept_id,
          mapping_type, transfer_weight, metadata
        ) values (
          v_from_tv_id,
          v_from_concept_id,
          v_version_id,
          v_to_concept_id,
          v_mapping_type,
          v_transfer_weight,
          coalesce(v_mapping->'metadata', '{}'::jsonb)
        )
        on conflict (
          from_target_version_id,
          from_concept_id,
          to_target_version_id,
          coalesce(to_concept_id, '00000000-0000-0000-0000-000000000000'::uuid)
        ) do update
        set mapping_type = excluded.mapping_type,
            transfer_weight = excluded.transfer_weight,
            metadata = excluded.metadata;

        v_concept_mappings_count := v_concept_mappings_count + 1;

      else
        -- Backwards compatibility with raw UUID payload
        v_from_concept_id := (v_mapping->>'from_concept_id')::uuid;
        v_to_concept_id := case when v_mapping->>'to_concept_id' is not null and trim(v_mapping->>'to_concept_id') <> ''
                                then (v_mapping->>'to_concept_id')::uuid
                                else null end;
        v_mapping_type := coalesce(v_mapping->>'mapping_type', 'unchanged');
        if v_mapping_type = 'equivalent' then
          v_mapping_type := 'unchanged';
        end if;

        if v_mapping_type not in ('unchanged', 'renamed', 'expanded', 'narrowed', 'replaced', 'removed') then
          raise exception 'Invalid mapping_type "%" for concept mapping.', v_mapping_type;
        end if;

        v_from_tv_id := coalesce((v_mapping->>'from_target_version_id')::uuid, v_version_id);
        v_to_tv_id := coalesce((v_mapping->>'to_target_version_id')::uuid, v_version_id);

        if v_mapping_type = 'removed' then
          if v_to_concept_id is not null then
            raise exception 'Removed concept mapping for source concept id % cannot specify a destination concept.', v_from_concept_id;
          end if;
          if v_mapping ? 'transfer_weight' and v_mapping->>'transfer_weight' is not null and (v_mapping->>'transfer_weight')::numeric <> 0.0 then
            raise exception 'Removed concept mapping for source concept id % must have transfer_weight = 0 (got %).',
              v_from_concept_id, (v_mapping->>'transfer_weight')::numeric;
          end if;
          v_transfer_weight := 0.0;
        else
          if v_to_concept_id is null then
            raise exception 'Destination concept id must be specified for mapping_type "%".', v_mapping_type;
          end if;

          if v_mapping ? 'transfer_weight' and v_mapping->>'transfer_weight' is not null then
            v_transfer_weight := (v_mapping->>'transfer_weight')::numeric;
          else
            v_transfer_weight := 1.0;
          end if;

          if v_transfer_weight < 0.0 or v_transfer_weight > 1.0 then
            raise exception 'Concept mapping transfer_weight % must be between 0.0 and 1.0.', v_transfer_weight;
          end if;
        end if;

        -- Validate source concept attached to from_target_version
        if not exists (
          select 1
          from public.curriculum_node_concepts cnc
          join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
          where cn.target_version_id = v_from_tv_id
            and cnc.concept_id = v_from_concept_id
        ) then
          raise exception 'Source concept id % is not associated with source target version %.',
            v_from_concept_id, v_from_tv_id;
        end if;

        -- Validate destination concept attached to to_target_version if present
        if v_to_concept_id is not null and not exists (
          select 1
          from public.curriculum_node_concepts cnc
          join public.curriculum_nodes cn on cn.id = cnc.curriculum_node_id
          where cn.target_version_id = v_to_tv_id
            and cnc.concept_id = v_to_concept_id
        ) then
          raise exception 'Destination concept id % is not associated with destination target version %.',
            v_to_concept_id, v_to_tv_id;
        end if;

        insert into public.target_version_concept_mappings (
          from_target_version_id, from_concept_id, to_target_version_id, to_concept_id,
          mapping_type, transfer_weight, metadata,
          confidence, rationale
        ) values (
          v_from_tv_id,
          v_from_concept_id,
          v_to_tv_id,
          v_to_concept_id,
          v_mapping_type,
          v_transfer_weight,
          coalesce(v_mapping->'metadata', '{}'::jsonb),
          case when v_mapping->>'confidence' is not null then (v_mapping->>'confidence')::numeric else null end,
          v_mapping->>'rationale'
        )
        on conflict (
          from_target_version_id,
          from_concept_id,
          to_target_version_id,
          coalesce(to_concept_id, '00000000-0000-0000-0000-000000000000'::uuid)
        ) do update
        set mapping_type = excluded.mapping_type,
            transfer_weight = excluded.transfer_weight,
            metadata = excluded.metadata,
            confidence = excluded.confidence,
            rationale = excluded.rationale;

        v_concept_mappings_count := v_concept_mappings_count + 1;
      end if;
    end loop;
  end if;
  -- 13. Return Ingestion Summary
  return jsonb_build_object(
    'target_version_id', v_version_id,
    'concepts_count', v_concepts_count,
    'domains_count', v_domains_count,
    'objectives_count', v_objectives_count,
    'lessons_count', v_lessons_count,
    'blocks_count', v_blocks_count,
    'assessment_items_count', v_items_count,
    'flashcards_count', v_flashcards_count,
    'stimuli_count', v_stimuli_count,
    'questions_count', v_questions_count,
    'mappings_count', v_mappings_count,
    'concept_mappings_count', v_concept_mappings_count
  );
end;
$$;

revoke all on function public.ingest_curriculum_manifest(jsonb) from public, anon, authenticated;
grant execute on function public.ingest_curriculum_manifest(jsonb) to service_role;


-- ============================================================================
-- 4. CLEP Simulation Exam Attempt Tracking & Attempt Lifecycle (EXM Security)
-- ============================================================================

create table if not exists public.clep_simulation_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  target_version_id uuid not null references public.target_versions(id),
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'expired', 'abandoned')),
  issued_item_ids uuid[] not null,
  total_questions integer not null check (total_questions > 0),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  submitted_at timestamptz,
  time_spent_seconds integer check (time_spent_seconds is null or time_spent_seconds >= 0),
  raw_score integer check (raw_score is null or (raw_score >= 0 and raw_score <= total_questions)),
  accuracy_percentage numeric(5,2) check (accuracy_percentage is null or (accuracy_percentage >= 0 and accuracy_percentage <= 100)),
  response_sha256 text,
  responses jsonb,
  results jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clep_attempt_valid_expiry check (expires_at > issued_at)
);

create index if not exists clep_sim_attempts_user_idx
  on public.clep_simulation_attempts(user_id, issued_at desc);

create index if not exists clep_sim_attempts_version_idx
  on public.clep_simulation_attempts(target_version_id);

alter table public.clep_simulation_attempts enable row level security;
revoke all on public.clep_simulation_attempts from public, anon, authenticated;
grant select on public.clep_simulation_attempts to authenticated;
grant all on public.clep_simulation_attempts to service_role;

drop policy if exists clep_simulation_attempts_select_owner on public.clep_simulation_attempts;
create policy clep_simulation_attempts_select_owner
  on public.clep_simulation_attempts for select to authenticated
  using (user_id = (select auth.uid()));

comment on table public.clep_simulation_attempts is
  'Server-recorded CLEP simulation exam attempts. Enforces single-use attempt lifecycle, server-calculated elapsed time, and owner-only read isolation.';


-- ============================================================================
-- 5. Secure Simulation Exam Issuance RPC (Authenticated Learner Only)
-- ============================================================================
create or replace function public.clep_issue_simulation_exam(
  p_target_version_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  v_target_id uuid;
  v_version_status text;
  v_target_status text;
  v_is_public boolean;
  v_item_ids uuid[];
  v_count integer;
  v_issued_at timestamptz;
  v_expires_at timestamptz;
  v_attempt_id uuid;
  v_questions jsonb;
begin
  -- 1. Authentication check
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to issue simulation exam' using errcode = '42501';
  end if;

  -- 2. Verify target version is published and public
  select v.target_id, v.status, t.status, t.is_public
  into v_target_id, v_version_status, v_target_status, v_is_public
  from public.target_versions v
  join public.learning_targets t on t.id = v.target_id
  where v.id = p_target_version_id;

  if not found then
    raise exception 'Target version not found: %', p_target_version_id using errcode = 'P0002';
  end if;

  if v_version_status <> 'published' or v_target_status <> 'published' or v_is_public is not true then
    raise exception 'Cannot issue simulation exam for unpublished target version: %', p_target_version_id using errcode = '42501';
  end if;

  -- 3. Gather protected simulation item IDs
  select array_agg(i.id order by i.created_at, i.id), count(i.id)
  into v_item_ids, v_count
  from public.assessment_items i
  where i.origin_target_version_id = p_target_version_id
    and public.is_protected_simulation_item(i.metadata);

  if v_count = 0 or v_item_ids is null then
    raise exception 'No simulation items found for target version: %', p_target_version_id using errcode = 'P0002';
  end if;

  -- 4. Establish server-controlled timestamps (90-min test + 5-min network buffer)
  v_issued_at := clock_timestamp();
  v_expires_at := v_issued_at + interval '95 minutes';

  -- 5. Record attempt in database
  insert into public.clep_simulation_attempts (
    user_id,
    target_id,
    target_version_id,
    status,
    issued_item_ids,
    total_questions,
    issued_at,
    expires_at
  ) values (
    v_user_id,
    v_target_id,
    p_target_version_id,
    'in_progress',
    v_item_ids,
    v_count,
    v_issued_at,
    v_expires_at
  )
  returning id into v_attempt_id;

  -- 6. Project ONLY safe question fields (ZERO scoring keys or explanations leaked)
  select jsonb_agg(
    jsonb_build_object(
      'id', i.id,
      'interaction_type', i.interaction_type,
      'prompt', i.prompt,
      'response_spec', jsonb_build_object('options', i.response_spec->'options'),
      'metadata', jsonb_build_object(
        'bank', i.metadata->>'bank',
        'item_role', i.metadata->>'item_role'
      ),
      'concept_ids', coalesce(
        (select jsonb_agg(c.concept_id) from public.assessment_item_concepts c where c.assessment_item_id = i.id),
        '[]'::jsonb
      )
    )
    order by i.created_at, i.id
  )
  into v_questions
  from public.assessment_items i
  where i.id = any(v_item_ids);

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'target_version_id', p_target_version_id,
    'total_questions', v_count,
    'time_limit_minutes', 90,
    'issued_at', v_issued_at,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$$;

revoke all on function public.clep_issue_simulation_exam(uuid) from public, anon;
grant execute on function public.clep_issue_simulation_exam(uuid) to authenticated;
grant execute on function public.clep_issue_simulation_exam(uuid) to service_role;
comment on function public.clep_issue_simulation_exam(uuid) is
  'Issues authorized 90-minute CLEP simulation exam questions bound to a server-recorded attempt. Returns safe options only; scoring keys and explanations remain server-side.';


-- ============================================================================
-- 6. Secure Simulation Exam Submission & Server-Side Scoring RPC
-- ============================================================================
create or replace function public.clep_submit_simulation_exam(
  p_attempt_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_user_id uuid;
  a public.clep_simulation_attempts%rowtype;
  v_version_status text;
  v_target_status text;
  v_is_public boolean;
  v_answered_count integer;
  v_key text;
  v_item_uuid uuid;
  v_item record;
  v_user_answer integer;
  v_correct_answer integer;
  v_is_correct boolean;
  v_correct_count integer := 0;
  v_percentage numeric;
  v_results jsonb := '[]'::jsonb;
  v_readiness text;
  v_time_spent_seconds integer;
  v_response_hash text;
begin
  -- 1. Authentication check
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required to submit simulation exam' using errcode = '42501';
  end if;

  -- 2. Input validation
  if p_attempt_id is null or p_responses is null or jsonb_typeof(p_responses) <> 'object' then
    raise exception 'Valid attempt_id and response object required' using errcode = '22023';
  end if;

  -- 3. Lock attempt row and verify ownership
  select * into a
  from public.clep_simulation_attempts
  where id = p_attempt_id
  for update;

  if not found then
    raise exception 'Simulation attempt not found: %', p_attempt_id using errcode = 'P0002';
  end if;

  if a.user_id <> v_user_id then
    raise exception 'Unauthorized: caller does not own this simulation attempt' using errcode = '42501';
  end if;

  -- 4. Replay protection: attempt must be in_progress
  if a.status <> 'in_progress' then
    raise exception 'Simulation attempt has already been submitted or closed (status: %)', a.status using errcode = '23505';
  end if;

  -- 5. Server-enforced deadline check
  if clock_timestamp() > a.expires_at then
    update public.clep_simulation_attempts
    set status = 'expired', updated_at = clock_timestamp()
    where id = a.id;
    raise exception 'Simulation attempt has expired (deadline: %)', a.expires_at using errcode = '42501';
  end if;

  -- 6. Target version must still be published and public
  select v.status, t.status, t.is_public
  into v_version_status, v_target_status, v_is_public
  from public.target_versions v
  join public.learning_targets t on t.id = v.target_id
  where v.id = a.target_version_id;

  if v_version_status <> 'published' or v_target_status <> 'published' or v_is_public is not true then
    raise exception 'Target version is no longer published' using errcode = '42501';
  end if;

  -- 7. Reject empty response object (cannot scrape answers without answering)
  select count(*) into v_answered_count
  from jsonb_object_keys(p_responses);

  if v_answered_count = 0 then
    raise exception 'Cannot submit empty responses: at least one answered question is required' using errcode = '22023';
  end if;

  -- 8. Validate that all submitted keys are valid UUIDs and belong to the issued items
  for v_key in select jsonb_object_keys(p_responses)
  loop
    begin
      v_item_uuid := v_key::uuid;
    exception when others then
      raise exception 'Invalid question ID format in responses: %', v_key using errcode = '22023';
    end;

    if not (v_item_uuid = any(a.issued_item_ids)) then
      raise exception 'Submitted question does not belong to this exam attempt: %', v_key using errcode = '22023';
    end if;
  end loop;

  -- 9. Server-calculated elapsed time (does not trust client-reported time)
  v_time_spent_seconds := round(extract(epoch from (clock_timestamp() - a.issued_at)))::integer;
  if v_time_spent_seconds < 0 then
    v_time_spent_seconds := 0;
  end if;

  -- 10. Grade answers and apply selective review policy
  for v_item in
    select
      i.id,
      i.prompt,
      i.response_spec,
      i.scoring_spec,
      i.explanation
    from public.assessment_items i
    where i.id = any(a.issued_item_ids)
    order by i.created_at, i.id
  loop
    v_correct_answer := (v_item.scoring_spec->>'correct_index')::integer;

    if p_responses ? (v_item.id::text) then
      v_user_answer := (p_responses->>(v_item.id::text))::integer;
      v_is_correct := (v_user_answer = v_correct_answer);
      if v_is_correct then
        v_correct_count := v_correct_count + 1;
      end if;

      -- Reveal post-submission explanation & key ONLY for answered questions
      v_results := v_results || jsonb_build_object(
        'id', v_item.id,
        'answered', true,
        'is_correct', v_is_correct,
        'user_answer', v_user_answer,
        'correct_answer', v_correct_answer,
        'explanation', v_item.explanation
      );
    else
      -- Unanswered question: marked unattempted, ZERO correct key or explanation revealed
      v_results := v_results || jsonb_build_object(
        'id', v_item.id,
        'answered', false,
        'is_correct', false,
        'user_answer', null,
        'correct_answer', null,
        'explanation', null
      );
    end if;
  end loop;

  v_percentage := round((v_correct_count::numeric / a.total_questions::numeric) * 100, 1);

  if v_percentage >= 70.0 then
    v_readiness := 'Competitive Diagnostic Standing';
  elsif v_percentage >= 50.0 then
    v_readiness := 'Approaching Foundation';
  else
    v_readiness := 'Needs Reinforcement';
  end if;

  v_response_hash := encode(sha256(convert_to(p_responses::text, 'UTF8')), 'hex');

  -- 11. Atomic state transition: mark attempt completed with grading results
  update public.clep_simulation_attempts
  set status = 'completed',
      submitted_at = clock_timestamp(),
      time_spent_seconds = v_time_spent_seconds,
      raw_score = v_correct_count,
      accuracy_percentage = v_percentage,
      response_sha256 = v_response_hash,
      responses = p_responses,
      results = v_results,
      updated_at = clock_timestamp()
  where id = a.id;

  return jsonb_build_object(
    'attempt_id', a.id,
    'target_version_id', a.target_version_id,
    'raw_score', v_correct_count,
    'total_questions', a.total_questions,
    'accuracy_percentage', v_percentage,
    'time_spent_seconds', v_time_spent_seconds,
    'readiness_indicator', v_readiness,
    'is_calibrated_clep_score', false,
    'scoring_disclaimer', 'Diagnostic score estimate only. Official College Board scaled scores require statistical equating and proprietary form calibration.',
    'results', v_results
  );
end;
$$;

revoke all on function public.clep_submit_simulation_exam(uuid, jsonb) from public, anon;
grant execute on function public.clep_submit_simulation_exam(uuid, jsonb) to authenticated;
grant execute on function public.clep_submit_simulation_exam(uuid, jsonb) to service_role;
comment on function public.clep_submit_simulation_exam(uuid, jsonb) is
  'Evaluates submitted simulation exam answers on the server against canonical scoring keys. Requires an active, authenticated attempt; enforces deadlines and single submission.';
