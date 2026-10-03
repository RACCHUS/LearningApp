-- ============================================================================
-- Migration: 20261004000000_content_primitives_v2.sql
-- Description:
-- 1. Extensible Lesson Block Document Model (lesson_blocks).
-- 2. Extensible Assessment Architecture (assessment_items, assessment_stimuli,
--    assessment_item_concepts).
-- 3. Version Migration Mapping (target_version_concept_mappings).
-- 4. TargetVersion Staging Status ('review_ready').
-- 5. Canonical Concept Alias Indexing & Resolver Function.
-- 6. Content Source Mappings extension for new primitives.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TargetVersion Staging Status ('review_ready')
-- ----------------------------------------------------------------------------
alter table public.target_versions
  drop constraint if exists target_versions_status_check;

alter table public.target_versions
  add constraint target_versions_status_check
  check (status in ('draft', 'review_ready', 'published', 'retired'));

-- Update versions update/delete policy to treat review_ready as editable by owner
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

drop policy if exists "versions_delete" on public.target_versions;
create policy "versions_delete" on public.target_versions
  for delete using (
    target_versions.status not in ('published', 'retired')
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

-- Curriculum nodes write policy: allowed when version is draft or review_ready
drop policy if exists "nodes_write" on public.curriculum_nodes;
create policy "nodes_write" on public.curriculum_nodes
  for all using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status not in ('published', 'retired')
    )
  )
  with check (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
        and v.status not in ('published', 'retired')
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Ordered Lesson Block Model (lesson_blocks)
-- ----------------------------------------------------------------------------
create table if not exists public.lesson_blocks (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null
    references public.lessons(id) on delete cascade,
  sort_order integer not null default 0,
  block_type text not null
    check (block_type in (
      'markdown',
      'callout',
      'code',
      'table',
      'image',
      'formula',
      'example',
      'practice_prompt'
    )),
  content jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists lesson_blocks_lesson_idx
  on public.lesson_blocks(lesson_id, sort_order);

drop trigger if exists trg_lesson_blocks_touch on public.lesson_blocks;
create trigger trg_lesson_blocks_touch
  before update on public.lesson_blocks
  for each row execute function public.touch_updated_at();

alter table public.lesson_blocks enable row level security;

drop policy if exists "lesson_blocks_read_visible" on public.lesson_blocks;
create policy "lesson_blocks_read_visible" on public.lesson_blocks
  for select to authenticated, anon
  using (exists (
    select 1 from public.lessons l
    where l.id = lesson_blocks.lesson_id
      and (l.visibility = 'public' or l.user_id = auth.uid())
  ));

drop policy if exists "lesson_blocks_write_owner" on public.lesson_blocks;
create policy "lesson_blocks_write_owner" on public.lesson_blocks
  for all to authenticated
  using (exists (
    select 1 from public.lessons l
    where l.id = lesson_blocks.lesson_id
      and l.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.lessons l
    where l.id = lesson_blocks.lesson_id
      and l.user_id = auth.uid()
  ));

-- ----------------------------------------------------------------------------
-- 3. Assessment Stimuli (Shared Vignettes, Scenarios, Diagrams)
-- ----------------------------------------------------------------------------
create table if not exists public.assessment_stimuli (
  id uuid primary key default gen_random_uuid(),
  stimulus_type text not null
    check (stimulus_type in (
      'clinical_case',
      'architecture_diagram',
      'code_snippet',
      'data_table',
      'scenario',
      'passage'
    )),
  title text not null,
  body text,
  structured_data jsonb not null default '{}'::jsonb,
  asset_refs jsonb not null default '[]'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trg_assessment_stimuli_touch on public.assessment_stimuli;
create trigger trg_assessment_stimuli_touch
  before update on public.assessment_stimuli
  for each row execute function public.touch_updated_at();

alter table public.assessment_stimuli enable row level security;

drop policy if exists "assessment_stimuli_read" on public.assessment_stimuli;
create policy "assessment_stimuli_read" on public.assessment_stimuli
  for select to authenticated, anon
  using (true);

drop policy if exists "assessment_stimuli_write" on public.assessment_stimuli;
create policy "assessment_stimuli_write" on public.assessment_stimuli
  for all to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

-- ----------------------------------------------------------------------------
-- 4. Extensible Assessment Items (assessment_items)
-- ----------------------------------------------------------------------------
create table if not exists public.assessment_items (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  stimulus_id uuid references public.assessment_stimuli(id) on delete set null,
  interaction_type text not null
    check (interaction_type in (
      'single_choice',
      'multi_select',
      'ordered_response',
      'matching',
      'matrix_grid',
      'numeric_entry',
      'cloze',
      'code_output'
    )),
  prompt text not null,
  response_spec jsonb not null default '{}'::jsonb,
  scoring_spec jsonb not null default '{}'::jsonb,
  explanation text,
  difficulty text not null default 'intermediate'
    check (difficulty in ('beginner', 'intermediate', 'advanced')),
  cognitive_level text
    check (cognitive_level in ('recall', 'comprehension', 'application', 'analysis', 'evaluation')),
  metadata jsonb not null default '{}'::jsonb,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists assessment_items_lesson_idx
  on public.assessment_items(lesson_id);

create index if not exists assessment_items_stimulus_idx
  on public.assessment_items(stimulus_id);

drop trigger if exists trg_assessment_items_touch on public.assessment_items;
create trigger trg_assessment_items_touch
  before update on public.assessment_items
  for each row execute function public.touch_updated_at();

alter table public.assessment_items enable row level security;

drop policy if exists "assessment_items_read" on public.assessment_items;
create policy "assessment_items_read" on public.assessment_items
  for select to authenticated, anon
  using (
    lesson_id is null
    or exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and (l.visibility = 'public' or l.user_id = auth.uid())
    )
  );

drop policy if exists "assessment_items_write" on public.assessment_items;
create policy "assessment_items_write" on public.assessment_items
  for all to authenticated
  using (
    user_id = auth.uid()
    or (lesson_id is not null and exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and l.user_id = auth.uid()
    ))
  )
  with check (
    user_id = auth.uid()
    or (lesson_id is not null and exists (
      select 1 from public.lessons l
      where l.id = assessment_items.lesson_id
        and l.user_id = auth.uid()
    ))
  );

-- ----------------------------------------------------------------------------
-- 5. Assessment Item Concept Junction (assessment_item_concepts)
-- ----------------------------------------------------------------------------
create table if not exists public.assessment_item_concepts (
  assessment_item_id uuid not null
    references public.assessment_items(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary'
    check (role in ('primary', 'supporting')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  primary key(assessment_item_id, concept_id)
);

create index if not exists assessment_item_concepts_concept_idx
  on public.assessment_item_concepts(concept_id);

alter table public.assessment_item_concepts enable row level security;

drop policy if exists "assessment_item_concepts_read" on public.assessment_item_concepts;
create policy "assessment_item_concepts_read" on public.assessment_item_concepts
  for select to authenticated, anon
  using (true);

drop policy if exists "assessment_item_concepts_write" on public.assessment_item_concepts;
create policy "assessment_item_concepts_write" on public.assessment_item_concepts
  for all to authenticated
  using (exists (
    select 1 from public.assessment_items a
    where a.id = assessment_item_concepts.assessment_item_id
      and (a.user_id = auth.uid() or exists (
        select 1 from public.lessons l where l.id = a.lesson_id and l.user_id = auth.uid()
      ))
  ))
  with check (exists (
    select 1 from public.assessment_items a
    where a.id = assessment_item_concepts.assessment_item_id
      and (a.user_id = auth.uid() or exists (
        select 1 from public.lessons l where l.id = a.lesson_id and l.user_id = auth.uid()
      ))
  ));

-- ----------------------------------------------------------------------------
-- 6. TargetVersion Forward Concept Mapping (target_version_concept_mappings)
-- ----------------------------------------------------------------------------
create table if not exists public.target_version_concept_mappings (
  id uuid primary key default gen_random_uuid(),
  from_target_version_id uuid not null
    references public.target_versions(id) on delete cascade,
  from_concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  to_target_version_id uuid not null
    references public.target_versions(id) on delete cascade,
  to_concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  mapping_type text not null
    check (mapping_type in ('unchanged', 'renamed', 'expanded', 'narrowed', 'replaced', 'removed')),
  transfer_weight numeric(5,4) not null default 1.0
    check (transfer_weight >= 0.0 and transfer_weight <= 1.0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (from_target_version_id, from_concept_id, to_target_version_id, to_concept_id)
);

create index if not exists tv_concept_mappings_from_idx
  on public.target_version_concept_mappings(from_target_version_id, from_concept_id);

create index if not exists tv_concept_mappings_to_idx
  on public.target_version_concept_mappings(to_target_version_id, to_concept_id);

alter table public.target_version_concept_mappings enable row level security;

drop policy if exists "tv_concept_mappings_read" on public.target_version_concept_mappings;
create policy "tv_concept_mappings_read" on public.target_version_concept_mappings
  for select to authenticated, anon
  using (true);

-- ----------------------------------------------------------------------------
-- 7. Canonical Concept Resolution & Aliases Indexing
-- ----------------------------------------------------------------------------
create index if not exists knowledge_concepts_aliases_idx
  on public.knowledge_concepts using gin (aliases);

create index if not exists knowledge_concepts_name_lower_idx
  on public.knowledge_concepts(lower(name));

create or replace function public.resolve_canonical_concept(
  p_slug text,
  p_name text default null
)
returns table (
  id uuid,
  field_id uuid,
  slug text,
  name text,
  status text,
  match_type text
) language plpgsql security definer as $$
begin
  -- 1. Exact slug match
  return query
  select c.id, c.field_id, c.slug, c.name, c.status, 'exact_slug'::text
  from public.knowledge_concepts c
  where c.slug = p_slug
  limit 1;

  if found then return; end if;

  -- 2. Slug matches an alias
  return query
  select c.id, c.field_id, c.slug, c.name, c.status, 'slug_alias'::text
  from public.knowledge_concepts c
  where p_slug = any(c.aliases)
  limit 1;

  if found then return; end if;

  -- 3. Case-insensitive name match
  if p_name is not null and trim(p_name) <> '' then
    return query
    select c.id, c.field_id, c.slug, c.name, c.status, 'exact_name'::text
    from public.knowledge_concepts c
    where lower(c.name) = lower(trim(p_name))
    limit 1;

    if found then return; end if;

    -- 4. Name matches an alias
    return query
    select c.id, c.field_id, c.slug, c.name, c.status, 'name_alias'::text
    from public.knowledge_concepts c
    where lower(trim(p_name)) = any(select lower(a) from unnest(c.aliases) a)
    limit 1;

    if found then return; end if;
  end if;

  return;
end;
$$;

-- ----------------------------------------------------------------------------
-- 8. Content Source Mappings Entity Types Extension
-- ----------------------------------------------------------------------------
alter table public.content_source_mappings
  drop constraint if exists content_source_mappings_entity_type_check;

alter table public.content_source_mappings
  add constraint content_source_mappings_entity_type_check
  check (entity_type in (
    'target_version',
    'curriculum_node',
    'lesson',
    'knowledge_concept',
    'question',
    'flashcard',
    'lesson_block',
    'assessment_item',
    'assessment_stimulus'
  ));
