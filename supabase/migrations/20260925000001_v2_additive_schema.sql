-- Learning Architecture v2 — Phase 1: Additive Schema & DDL
-- Ordered execution:
--   1. fields
--   2. learning_targets
--   3. target_versions
--   4. courses (extensions)
--   5. modules
--   6. course_lessons (extensions)
--   7. curriculum_nodes
--   8. curriculum_node_courses, curriculum_node_modules, curriculum_node_lessons
--   9. knowledge_concepts
--   10. concept_relations
--   11. curriculum_node_concepts, lesson_concepts, question_concepts, term_concepts
--   12. flashcards, flashcard_concepts, study_set_flashcards
--   13. review_items (schema update: nullable lesson_id, content_type check)
--   14. learning_contexts (v2 extensions)
--   15. user_concept_state
--   16. Complete RLS policies enabled on all tables

-- ============================================================================
-- 1. FIELDS (Discovery Taxonomy)
-- ============================================================================
create table if not exists public.fields (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.fields(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  icon text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fields_parent_idx on public.fields(parent_id);
create index if not exists fields_active_idx on public.fields(is_active, sort_order);

-- ============================================================================
-- 2. LEARNING TARGETS (Formal Destinations)
-- ============================================================================
create table if not exists public.learning_targets (
  id uuid primary key default gen_random_uuid(),
  target_type text not null check (
    target_type in (
      'career',
      'academic_program',
      'certification',
      'licensure_exam',
      'standardized_exam'
    )
  ),
  field_id uuid references public.fields(id) on delete set null,
  title text not null,
  slug text not null unique,
  description text,
  provider_name text,
  institution_name text,
  jurisdiction text,
  image_url text,
  emoji text,
  is_public boolean not null default true,
  is_official boolean not null default false,
  status text not null default 'published'
    check (status in ('draft', 'published', 'archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists learning_targets_type_idx on public.learning_targets(target_type);
create index if not exists learning_targets_field_idx on public.learning_targets(field_id);
create index if not exists learning_targets_catalog_idx on public.learning_targets(status, is_public);

-- ============================================================================
-- 3. TARGET VERSIONS (Snapshot of Requirements)
-- ============================================================================
create table if not exists public.target_versions (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null
    references public.learning_targets(id) on delete cascade,
  version_code text not null,
  title text,
  description text,
  valid_from date,
  valid_until date,
  source_url text,
  source_title text,
  source_retrieved_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'draft'
    check (status in ('draft', 'published', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(target_id, version_code)
);

create index if not exists target_versions_target_idx
  on public.target_versions(target_id, status);

-- ============================================================================
-- 4. COURSES EXTENSIONS & MODULES
-- ============================================================================
alter table public.courses
  add column if not exists field_id uuid
    references public.fields(id) on delete set null;

alter table public.courses
  add column if not exists slug text;

alter table public.courses
  add column if not exists visibility text not null default 'private'
    check (visibility in ('private', 'unlisted', 'public'));

create table if not exists public.modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null
    references public.courses(id) on delete cascade,
  title text not null,
  description text,
  emoji text,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists modules_course_idx
  on public.modules(course_id, sort_order);

alter table public.course_lessons
  add column if not exists module_id uuid
    references public.modules(id) on delete set null;

-- ============================================================================
-- 5. CURRICULUM NODES & EXPLICIT TEACHING BINDINGS
-- ============================================================================
create table if not exists public.curriculum_nodes (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null
    references public.target_versions(id) on delete cascade,
  parent_id uuid references public.curriculum_nodes(id) on delete cascade,
  node_type text not null,
  title text not null,
  code text,
  description text,
  sort_order integer not null default 0,
  importance text not null default 'core'
    check (importance in ('core', 'recommended', 'optional')),
  weight numeric(8,5),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists curriculum_nodes_version_idx
  on public.curriculum_nodes(target_version_id, parent_id, sort_order);

-- Explicit Teaching Bindings (Junctions)
create table if not exists public.curriculum_node_courses (
  curriculum_node_id uuid not null
    references public.curriculum_nodes(id) on delete cascade,
  course_id uuid not null
    references public.courses(id) on delete cascade,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  primary key (curriculum_node_id, course_id)
);

create table if not exists public.curriculum_node_modules (
  curriculum_node_id uuid not null
    references public.curriculum_nodes(id) on delete cascade,
  module_id uuid not null
    references public.modules(id) on delete cascade,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  primary key (curriculum_node_id, module_id)
);

create table if not exists public.curriculum_node_lessons (
  curriculum_node_id uuid not null
    references public.curriculum_nodes(id) on delete cascade,
  lesson_id uuid not null
    references public.lessons(id) on delete cascade,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  primary key (curriculum_node_id, lesson_id)
);

create index if not exists node_courses_node_idx on public.curriculum_node_courses(curriculum_node_id);
create index if not exists node_modules_node_idx on public.curriculum_node_modules(curriculum_node_id);
create index if not exists node_lessons_node_idx on public.curriculum_node_lessons(curriculum_node_id);

-- ============================================================================
-- 6. CANONICAL KNOWLEDGE LAYER
-- ============================================================================
create table if not exists public.knowledge_concepts (
  id uuid primary key default gen_random_uuid(),
  field_id uuid references public.fields(id) on delete set null,
  name text not null,
  slug text,
  description text,
  short_definition text,
  aliases text[] not null default '{}',
  emoji text,
  status text not null default 'active'
    check (status in ('active', 'deprecated', 'merged')),
  merged_into_id uuid
    references public.knowledge_concepts(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  source_type text,
  source_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists knowledge_concepts_slug_idx
  on public.knowledge_concepts(slug)
  where slug is not null;

create index if not exists knowledge_concepts_field_idx
  on public.knowledge_concepts(field_id);

create table if not exists public.concept_relations (
  from_concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  to_concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  relation_type text not null check (
    relation_type in (
      'prerequisite',
      'part_of',
      'related_to',
      'contrasts_with',
      'applies_to'
    )
  ),
  prerequisite_kind text not null default 'required'
    check (prerequisite_kind in ('required', 'recommended')),
  auto_include boolean not null default true,
  strength numeric(5,4) not null default 1.0
    check (strength >= 0 and strength <= 1),
  metadata jsonb not null default '{}'::jsonb,
  primary key(from_concept_id, to_concept_id, relation_type),
  check (from_concept_id <> to_concept_id)
);

create index if not exists concept_relations_to_idx
  on public.concept_relations(to_concept_id, relation_type);

-- ============================================================================
-- 7. CONTENT-TO-CONCEPT MAPPINGS & STANDALONE FLASHCARDS
-- ============================================================================
create table if not exists public.curriculum_node_concepts (
  curriculum_node_id uuid not null
    references public.curriculum_nodes(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  relevance text not null default 'core'
    check (relevance in ('core', 'supporting', 'related')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  primary key(curriculum_node_id, concept_id)
);

create index if not exists curriculum_node_concepts_concept_idx
  on public.curriculum_node_concepts(concept_id);

create table if not exists public.lesson_concepts (
  lesson_id uuid not null
    references public.lessons(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary'
    check (role in ('primary', 'supporting', 'prerequisite', 'mentioned')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  sort_order integer not null default 0,
  primary key(lesson_id, concept_id)
);

create index if not exists lesson_concepts_concept_idx
  on public.lesson_concepts(concept_id);

create table if not exists public.question_concepts (
  question_id uuid not null
    references public.questions(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary'
    check (role in ('primary', 'supporting')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  primary key(question_id, concept_id)
);

create index if not exists question_concepts_concept_idx
  on public.question_concepts(concept_id);

create table if not exists public.term_concepts (
  term_id uuid not null
    references public.terms(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary'
    check (role in ('primary', 'supporting')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  primary key(term_id, concept_id)
);

create index if not exists term_concepts_concept_idx
  on public.term_concepts(concept_id);

create table if not exists public.flashcards (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  front text not null,
  back text not null,
  explanation text,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.flashcard_concepts (
  flashcard_id uuid not null
    references public.flashcards(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary'
    check (role in ('primary', 'supporting')),
  weight numeric(6,5) not null default 1.0
    check (weight >= 0 and weight <= 1),
  primary key(flashcard_id, concept_id)
);

create table if not exists public.study_set_flashcards (
  study_set_id uuid not null
    references public.study_sets(id) on delete cascade,
  flashcard_id uuid not null
    references public.flashcards(id) on delete cascade,
  sort_order integer not null default 0,
  primary key (study_set_id, flashcard_id)
);

-- ============================================================================
-- 8. REVIEW_ITEMS CONSTRAINT & NULLABILITY MIGRATION
-- ============================================================================
alter table public.review_items
  alter column lesson_id drop not null;

alter table public.review_items
  drop constraint if exists review_items_content_type_check;

alter table public.review_items
  add constraint review_items_content_type_check
  check (
    content_type in (
      'term',
      'question',
      'concept',
      'flashcard'
    )
  );

-- ============================================================================
-- 9. LEARNING CONTEXTS v2 EXTENSIONS
-- ============================================================================
alter table public.learning_contexts
  drop constraint if exists learning_contexts_root_type_check;

alter table public.learning_contexts
  add constraint learning_contexts_root_type_check
  check (
    root_type in (
      'target',
      'path',
      'course',
      'module',
      'lesson',
      'concept',
      'studySet'
    )
  );

alter table public.learning_contexts
  add column if not exists target_version_id uuid
    references public.target_versions(id) on delete set null;

alter table public.learning_contexts
  add column if not exists active_focus_type text;

alter table public.learning_contexts
  add column if not exists active_focus_id text;

alter table public.learning_contexts
  add column if not exists scope_mode text not null default 'core_and_prerequisites'
    check (
      scope_mode in (
        'core_only',
        'core_and_prerequisites',
        'custom'
      )
    );

alter table public.learning_contexts
  add column if not exists scope_config jsonb not null default '{}'::jsonb;

-- ============================================================================
-- 10. USER CONCEPT STATE (Read-Only Analytical Projection)
-- ============================================================================
create table if not exists public.user_concept_state (
  user_id uuid not null
    references auth.users(id) on delete cascade,
  concept_id uuid not null
    references public.knowledge_concepts(id) on delete cascade,

  retrieval_band text not null default 'unassessed'
    check (
      retrieval_band in (
        'unassessed',
        'needs_reinforcement',
        'developing',
        'well_retained',
        'well_established'
      )
    ),

  confidence text not null default 'low'
    check (confidence in ('low', 'medium', 'high')),

  evidence_count integer not null default 0,
  weighted_correct numeric(12,5) not null default 0,
  weighted_total numeric(12,5) not null default 0,
  last_evidence_at timestamptz,
  updated_at timestamptz not null default now(),

  primary key(user_id, concept_id)
);

create index if not exists user_concept_state_band_idx
  on public.user_concept_state(user_id, retrieval_band);

-- ============================================================================
-- 11. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- 1. Fields (Catalog taxonomy: active fields are public)
alter table public.fields enable row level security;
drop policy if exists "fields_read_public" on public.fields;
create policy "fields_read_public" on public.fields
  for select using (is_active = true);

-- 2. Learning Targets
alter table public.learning_targets enable row level security;
drop policy if exists "targets_read" on public.learning_targets;
create policy "targets_read" on public.learning_targets
  for select using (
    (status = 'published' and is_public = true)
    or (auth.uid() = created_by)
  );
drop policy if exists "targets_write" on public.learning_targets;
create policy "targets_write" on public.learning_targets
  for all using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

-- 3. Target Versions (Readable only if parent target is published+public OR user is owner)
alter table public.target_versions enable row level security;
drop policy if exists "versions_read" on public.target_versions;
create policy "versions_read" on public.target_versions
  for select using (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and (
          (t.status = 'published' and t.is_public = true and target_versions.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );
drop policy if exists "versions_write" on public.target_versions;
create policy "versions_write" on public.target_versions
  for all using (
    exists (
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

-- 4. Modules (Readable only if parent course is public OR user is course owner)
alter table public.modules enable row level security;
drop policy if exists "modules_read" on public.modules;
create policy "modules_read" on public.modules
  for select using (
    exists (
      select 1 from public.courses c
      where c.id = modules.course_id
        and (c.is_public = true or c.visibility = 'public' or c.user_id = auth.uid())
    )
  );
drop policy if exists "modules_write" on public.modules;
create policy "modules_write" on public.modules
  for all using (
    exists (
      select 1 from public.courses c
      where c.id = modules.course_id
        and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.courses c
      where c.id = modules.course_id
        and c.user_id = auth.uid()
    )
  );

-- 5. Curriculum Nodes (Readable only if parent target version is readable)
alter table public.curriculum_nodes enable row level security;
drop policy if exists "nodes_read" on public.curriculum_nodes;
create policy "nodes_read" on public.curriculum_nodes
  for select using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );
drop policy if exists "nodes_write" on public.curriculum_nodes;
create policy "nodes_write" on public.curriculum_nodes
  for all using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and t.created_by = auth.uid()
    )
  );

-- 6. Teaching Junctions (Readable only if parent curriculum node is readable)
alter table public.curriculum_node_courses enable row level security;
drop policy if exists "node_courses_read" on public.curriculum_node_courses;
create policy "node_courses_read" on public.curriculum_node_courses
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_courses.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );

alter table public.curriculum_node_modules enable row level security;
drop policy if exists "node_modules_read" on public.curriculum_node_modules;
create policy "node_modules_read" on public.curriculum_node_modules
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_modules.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );

alter table public.curriculum_node_lessons enable row level security;
drop policy if exists "node_lessons_read" on public.curriculum_node_lessons;
create policy "node_lessons_read" on public.curriculum_node_lessons
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_lessons.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );

-- 7. Canonical Knowledge Concepts & Relations
alter table public.knowledge_concepts enable row level security;
drop policy if exists "concepts_read" on public.knowledge_concepts;
create policy "concepts_read" on public.knowledge_concepts
  for select using (status = 'active' or created_by = auth.uid());
drop policy if exists "concepts_write" on public.knowledge_concepts;
create policy "concepts_write" on public.knowledge_concepts
  for all using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

alter table public.concept_relations enable row level security;
drop policy if exists "concept_relations_read" on public.concept_relations;
create policy "concept_relations_read" on public.concept_relations
  for select using (true);

-- 8. Content-to-Concept Mappings (Follow underlying parent content readability)
alter table public.curriculum_node_concepts enable row level security;
drop policy if exists "node_concepts_read" on public.curriculum_node_concepts;
create policy "node_concepts_read" on public.curriculum_node_concepts
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_concepts.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
        )
    )
  );

alter table public.lesson_concepts enable row level security;
drop policy if exists "lesson_concepts_read" on public.lesson_concepts;
create policy "lesson_concepts_read" on public.lesson_concepts
  for select using (
    exists (
      select 1 from public.lessons l
      where l.id = lesson_concepts.lesson_id
        and (l.user_id = auth.uid() or true)
    )
  );

alter table public.question_concepts enable row level security;
drop policy if exists "question_concepts_read" on public.question_concepts;
create policy "question_concepts_read" on public.question_concepts
  for select using (
    exists (
      select 1 from public.questions q
      where q.id = question_concepts.question_id
    )
  );

alter table public.term_concepts enable row level security;
drop policy if exists "term_concepts_read" on public.term_concepts;
create policy "term_concepts_read" on public.term_concepts
  for select using (
    exists (
      select 1 from public.terms tm
      where tm.id = term_concepts.term_id
    )
  );

-- 9. Flashcards & Study Set Mappings
alter table public.flashcards enable row level security;
drop policy if exists "flashcards_read" on public.flashcards;
create policy "flashcards_read" on public.flashcards
  for select using (user_id = auth.uid() or user_id is null);
drop policy if exists "flashcards_write" on public.flashcards;
create policy "flashcards_write" on public.flashcards
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter table public.flashcard_concepts enable row level security;
drop policy if exists "flashcard_concepts_read" on public.flashcard_concepts;
create policy "flashcard_concepts_read" on public.flashcard_concepts
  for select using (
    exists (
      select 1 from public.flashcards f
      where f.id = flashcard_concepts.flashcard_id
        and (f.user_id = auth.uid() or f.user_id is null)
    )
  );

alter table public.study_set_flashcards enable row level security;
drop policy if exists "study_set_flashcards_read" on public.study_set_flashcards;
create policy "study_set_flashcards_read" on public.study_set_flashcards
  for select using (
    exists (
      select 1 from public.study_sets s
      where s.id = study_set_flashcards.study_set_id
        and s.user_id = auth.uid()
    )
  );
drop policy if exists "study_set_flashcards_write" on public.study_set_flashcards;
create policy "study_set_flashcards_write" on public.study_set_flashcards
  for all using (
    exists (
      select 1 from public.study_sets s
      where s.id = study_set_flashcards.study_set_id
        and s.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.study_sets s
      where s.id = study_set_flashcards.study_set_id
        and s.user_id = auth.uid()
    )
  );

-- 10. User Concept State (Strictly Private)
alter table public.user_concept_state enable row level security;
drop policy if exists "user_concept_state_owner" on public.user_concept_state;
create policy "user_concept_state_owner" on public.user_concept_state
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
