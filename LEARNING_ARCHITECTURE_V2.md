# Learning Architecture v2 — Formal Implementation Specification

**Status:** Implementation Baseline (Finalized with Gemini & User/ChatGPT Review)  
**Supersedes:** Unamended v2 draft  
**Companion Documents:** `UI_ARCHITECTURE_LOCKED.md` (interaction baseline and ship gates), `DEPLOYMENT_GUIDE.md`  

---

## 1. Product Law: Knowledge is Global. Learning is Scoped.

A learner's knowledge state belongs to the learner and is reused across multiple goals. The active **Learning Context** defines what material is presented, sequenced, practiced, reviewed, and summarized as relevant right now.

- **Florida AC Class A** study never shows unrelated HVAC or engineering material.
- A **Computer Science BS** can reuse knowledge learned elsewhere without mixing unrelated degree requirements into Learn.
- **Cisco CCNA** reuses prior subnetting mastery without pulling Network+ lessons into the daily sequence.
- **Bayes' Theorem** can be studied directly without fabricating a synthetic course or module container.

This rule is non-negotiable for v2.

---

## 2. Compatibility with Existing v1 System

Existing anchors in the repository that remain intact:
- `lib/providers/router_provider.dart`: Persistent three-destination shell (`Learn` | `Library` | `Progress`).
- `lib/models/learning_context.dart`: `LearningContext` and `ResumePointer`.
- `supabase/migrations/20260909000000_learning_contexts.sql`: `learning_contexts` and `resume_pointers` tables.
- Existing content tables: `lessons`, `terms`, `questions`, `concepts`, `courses`, `course_lessons`, `study_sets`.
- Existing SRS & progress: `review_items` (SM-2 scheduler) and course/study-set progress.
- Existing career/skills schema: `career_paths`, `skills`, junction tables, assessments, and user stats.

**Key constraint:** The legacy `concepts` table is lesson-bound (`lesson_id` foreign key required). v2 introduces an autonomous, canonical knowledge layer (`knowledge_concepts`) rather than mutating legacy concepts in place.

---

## 3. Four-Tier Conceptual Model

```
DISCOVERY TAXONOMY
Field / Provider / Institution / Jurisdiction / Tags
                    │
                    ▼
FORMAL DESTINATIONS
LearningTarget
      │
      ▼
TargetVersion
      │
      ▼
CurriculumNode tree
      │
      ├───────────────────────────────┐
      │ (Explicit Teaching Bindings)   │ (Knowledge Mappings)
      ▼                               ▼
TEACHING STRUCTURE             CANONICAL KNOWLEDGE GRAPH
Course                         KnowledgeConcept
  │                                ↕ (ConceptRelation)
Module                         KnowledgeConcept
  │                                ▲
Lesson ────────────────────────────┤
Question ──────────────────────────┤
Term ──────────────────────────────┤
Flashcard ─────────────────────────┘
```

### 3.1 Discovery Taxonomy
Used to browse, filter, and discover material, not to measure mastery:
- **Field** (e.g. *HVAC*, *Computer Science*, *Nursing*)
- **Provider / Institution / Jurisdiction** (e.g. *Florida DBPR*, *FIU*, *Cisco*)
- **Tags**

### 3.2 Formal Destinations
Represent credentialing, degree, or career endpoints:
- `LearningTarget` (Career, Academic Program, Certification, Licensure Exam, Standardized Exam)
- `TargetVersion` (Published snapshots of official requirements)
- `CurriculumNode` (Hierarchical breakdown of objectives/domains)

### 3.3 Teaching Structure
Curated instruction with explicit pedagogical sequence:
- `Course` $\to$ `Module` $\to$ `Lesson`

### 3.4 Canonical Knowledge Graph
Autonomous, unowned concepts and their semantic connections:
- `KnowledgeConcept` $\leftrightarrow$ `ConceptRelation` (prerequisites, part-of, contrasts-with)
- Many-to-many mappings connecting curriculum nodes, lessons, questions, terms, and flashcards to concepts.

---

## 4. Architectural Invariants

1. **A concept is never owned by a course, lesson, target, or exam.**
2. **Concept mappings define what knowledge is relevant; explicit curriculum bindings define what teaching material is sequenced.** (Eliminates Content Collision).
3. **A lesson may cover many concepts; a concept may appear in many lessons and targets.**
4. **Questions, terms, and flashcards may map to multiple concepts with distinct weights.**
5. **Structural completion and knowledge retrieval evidence remain separate metrics.**
6. **Existing user progress and review items are never discarded by migration.**
7. **Requirement-changing edits create a new `TargetVersion`; published versions are immutable snapshots.**
8. **Learn, contextual Review, and contextual Search must consume `ResolvedScope`.**
9. **Prerequisite traversal is strictly depth-bounded with loop termination.**
10. **`review_items` is the sole scheduler; `user_concept_state` is a read-only analytical projection.**
11. **Offline capability is preserved via a local `ResolvedScopeCache` and `ContextCurriculumSnapshot`.**
12. **Recommendations never trap the learner; the Direct Access Rule ($\le$ 2 deliberate taps) is preserved.**

---

## 5. Backend Schema & Migration Ordering (P1 DDL)

To eliminate foreign key creation errors during sequential migration execution, DDL must be applied in strict dependency order:

```
1. fields
2. learning_targets
3. target_versions
4. courses (extensions)
5. modules
6. course_lessons (extensions)
7. curriculum_nodes
8. curriculum_node_courses, curriculum_node_modules, curriculum_node_lessons
9. knowledge_concepts
10. concept_relations
11. curriculum_node_concepts, lesson_concepts, question_concepts, term_concepts
12. flashcards, flashcard_concepts, study_set_flashcards
13. review_items (schema update: nullable lesson_id, content_type check)
14. learning_contexts (v2 extensions)
15. user_concept_state
16. v2_migration_map
```

### 5.1 Fields
```sql
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
```

### 5.2 Learning Targets
```sql
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
```

### 5.3 Target Versions
```sql
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
```

### 5.4 Courses Extensions & Modules (Created Before Curriculum Junctions)
```sql
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
```

### 5.5 Curriculum Nodes & Explicit Teaching Bindings
```sql
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
```

### 5.6 Canonical Knowledge Layer
```sql
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
```

> **Acyclicity & Cycle Prevention:** The database constraint `check (from_concept_id <> to_concept_id)` enforces 1-hop loop termination. Multi-hop circular dependencies ($A \to B \to C \to A$) are validated and rejected at the content authoring / ingestion layer. At runtime, `ScopeResolver` enforces termination using an in-memory `visited` set and hard depth cap (`maxDepth = 1` or `2`).

### 5.7 Content-to-Concept Mappings & Standalone Flashcards
```sql
-- Target node to concepts
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

-- Lesson to concepts
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

-- Question to concepts
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

-- Term to concepts
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

-- Standalone Flashcards (nullable lesson_id enables unowned decks)
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
```

### 5.8 `review_items` Constraint & Nullability Migration
The existing `review_items` table uses `content_type` (not `item_type`) and currently requires `lesson_id TEXT NOT NULL`. To enable standalone flashcards and preserve concepts:

```sql
-- Allow standalone flashcards and unattached items in review
alter table public.review_items
  alter column lesson_id drop not null;

-- Update content_type constraint to include flashcard while preserving concept
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
```

### 5.9 Learning Contexts v2 Extensions
```sql
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
```

### 5.10 User Concept State (Read-Only Projection)
```sql
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
```

### 5.11 Migration Map Table
```sql
create table if not exists public.v2_migration_map (
  legacy_type text not null,
  legacy_id text not null,
  v2_type text not null,
  v2_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(legacy_type, legacy_id, v2_type)
);
```

### 5.12 Row Level Security (RLS) Explicit Policies

All new catalog and mapping tables strictly inherit visibility from their logical parents, completely preventing metadata or structure leaks for draft or private targets and courses.

```sql
-- 1. Fields (Catalog taxonomy: active fields are public)
alter table public.fields enable row level security;
create policy "fields_read_public" on public.fields
  for select using (is_active = true);

-- 2. Learning Targets
alter table public.learning_targets enable row level security;
create policy "targets_read" on public.learning_targets
  for select using (
    (status = 'published' and is_public = true)
    or (auth.uid() = created_by)
  );
create policy "targets_write" on public.learning_targets
  for all using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

-- 3. Target Versions (Readable only if parent target is published+public OR user is target owner)
alter table public.target_versions enable row level security;
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
create policy "modules_read" on public.modules
  for select using (
    exists (
      select 1 from public.courses c
      where c.id = modules.course_id
        and (c.is_public = true or c.visibility = 'public' or c.user_id = auth.uid())
    )
  );
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
create policy "concepts_read" on public.knowledge_concepts
  for select using (status = 'active' or created_by = auth.uid());
create policy "concepts_write" on public.knowledge_concepts
  for all using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

alter table public.concept_relations enable row level security;
create policy "concept_relations_read" on public.concept_relations
  for select using (true);

-- 8. Content-to-Concept Mappings (Follow underlying content readability)
alter table public.curriculum_node_concepts enable row level security;
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
create policy "lesson_concepts_read" on public.lesson_concepts
  for select using (
    exists (
      select 1 from public.lessons l
      where l.id = lesson_concepts.lesson_id
        and (l.user_id = auth.uid() or true) -- lessons are globally readable per secure_rls
    )
  );

alter table public.question_concepts enable row level security;
create policy "question_concepts_read" on public.question_concepts
  for select using (
    exists (
      select 1 from public.questions q
      where q.id = question_concepts.question_id
    )
  );

alter table public.term_concepts enable row level security;
create policy "term_concepts_read" on public.term_concepts
  for select using (
    exists (
      select 1 from public.terms tm
      where tm.id = term_concepts.term_id
    )
  );

-- 9. Flashcards & Study Set Mappings
alter table public.flashcards enable row level security;
create policy "flashcards_read" on public.flashcards
  for select using (user_id = auth.uid() or user_id is null);
create policy "flashcards_write" on public.flashcards
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter table public.flashcard_concepts enable row level security;
create policy "flashcard_concepts_read" on public.flashcard_concepts
  for select using (
    exists (
      select 1 from public.flashcards f
      where f.id = flashcard_concepts.flashcard_id
        and (f.user_id = auth.uid() or f.user_id is null)
    )
  );

alter table public.study_set_flashcards enable row level security;
-- Note: study_sets table is strictly per-user in current schema (no is_public column)
create policy "study_set_flashcards_read" on public.study_set_flashcards
  for select using (
    exists (
      select 1 from public.study_sets s
      where s.id = study_set_flashcards.study_set_id
        and s.user_id = auth.uid()
    )
  );
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
create policy "user_concept_state_owner" on public.user_concept_state
  for all using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

---

## 6. Local Storage & Dart Models (P0 Prerequisite)

### 6.1 Hive Enum Deserialization Guard
To prevent on-disk index corruption where legacy indices `0..4` would deserialize into wrong enum values:

```dart
enum ContextRootType {
  target,
  path,
  course,
  module,
  lesson,
  concept,
  studySet,
}
```

In `LearningContextAdapter`:
```dart
@override
LearningContext read(BinaryReader reader) {
  final numOfFields = reader.readByte();
  final fields = <int, dynamic>{
    for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
  };
  
  final rawRoot = fields[3];
  ContextRootType rootType;
  if (rawRoot is String) {
    rootType = ContextRootType.values.firstWhere(
      (e) => e.name == rawRoot,
      orElse: () => ContextRootType.course,
    );
  } else if (rawRoot is int) {
    // Deterministic legacy ordinal mapping from v1:
    switch (rawRoot) {
      case 0: rootType = ContextRootType.path; break;
      case 1: rootType = ContextRootType.course; break;
      case 2: rootType = ContextRootType.module; break;
      case 3: rootType = ContextRootType.lesson; break;
      case 4: rootType = ContextRootType.studySet; break;
      default: rootType = ContextRootType.course;
    }
  } else {
    rootType = ContextRootType.course;
  }

  return LearningContext(
    id: fields[0] as String,
    userId: fields[1] as String? ?? '',
    label: fields[2] as String? ?? 'Untitled',
    rootType: rootType,
    rootId: fields[4] as String? ?? '',
    emoji: fields[5] as String?,
    lastActiveAt: fields[6] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0),
    isArchived: fields[7] as bool? ?? false,
    sortOrder: (fields[8] as num?)?.toInt() ?? -1,
    targetVersionId: fields[9] as String?,
    activeFocusType: fields[10] as String?,
    activeFocusId: fields[11] as String?,
    scopeMode: ScopeMode.values.byName(fields[12] as String? ?? 'coreAndPrerequisites'),
    scopeConfig: (fields[13] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

@override
void write(BinaryWriter writer, LearningContext obj) {
  writer
    ..writeByte(14)
    ..writeByte(0)..write(obj.id)
    ..writeByte(1)..write(obj.userId)
    ..writeByte(2)..write(obj.label)
    ..writeByte(3)..write(obj.rootType.name) // Stable String serialization in v2
    ..writeByte(4)..write(obj.rootId)
    ..writeByte(5)..write(obj.emoji)
    ..writeByte(6)..write(obj.lastActiveAt)
    ..writeByte(7)..write(obj.isArchived)
    ..writeByte(8)..write(obj.sortOrder)
    ..writeByte(9)..write(obj.targetVersionId)
    ..writeByte(10)..write(obj.activeFocusType)
    ..writeByte(11)..write(obj.activeFocusId)
    ..writeByte(12)..write(obj.scopeMode.name)
    ..writeByte(13)..write(obj.scopeConfig);
}
```

### 6.2 Update `ReviewableItem` in Dart
In `lib/models/spaced_repetition.dart`:
```dart
enum ReviewableContentType {
  term,
  multipleChoice,
  trueFalse,
  fillInBlank,
  concept,
  matching,
  question,
  flashcard, // New in v2
}

class ReviewableItem {
  final String id;
  final String contentId;
  final ReviewableContentType contentType;
  final String? lessonId; // Nullable for standalone flashcards
  final String title;
  final String? subtitle;
  final int repetitionLevel;
  final double easeFactor;
  final DateTime nextReviewDate;
  final DateTime? lastReviewedAt;
  final int totalReviews;
  final int correctReviews;
  final Map<String, dynamic>? metadata;
  // ...
}
```

### 6.3 Hive Type Registry Allocations
In `lib/core/hive_type_ids.dart`:
- `static const int resolvedScopeCache = 12;`
- `static const int contextCurriculumSnapshot = 13;`

---

## 7. ScopeResolver & Deterministic Sequencing

### 7.1 Scope Data Structures
```dart
enum ScopeRole { core, supporting, related }

/// Review batches are queries, not durable scheduled activities.
enum ScopedActivityKind { lesson, studySet }

class ScopedLearningActivity {
  final String activityId;
  final ScopedActivityKind kind;
  final String? curriculumNodeId;
  final int curriculumOrder;
  final int activityOrder;
  final ScopeRole role;
  final String title;
  final Duration estimatedDuration;

  const ScopedLearningActivity({
    required this.activityId,
    required this.kind,
    this.curriculumNodeId,
    this.curriculumOrder = 0,
    this.activityOrder = 0,
    this.role = ScopeRole.core,
    required this.title,
    this.estimatedDuration = const Duration(minutes: 10),
  });
}

class ResolvedScope {
  final String contextId;
  final Set<String> coreConceptIds;
  final Set<String> supportingConceptIds;
  final Set<String> relatedConceptIds; // Excluded from Learn sequence

  final Set<String> curriculumNodeIds;

  /// Deterministically ordered teaching candidates for NextActionEngine
  final List<ScopedLearningActivity> orderedActivities;

  final Set<String> questionIds;
  final Set<String> termIds;
  final Set<String> flashcardIds;

  final DateTime resolvedAt;

  const ResolvedScope({
    required this.contextId,
    required this.coreConceptIds,
    required this.supportingConceptIds,
    required this.relatedConceptIds,
    required this.curriculumNodeIds,
    required this.orderedActivities,
    required this.questionIds,
    required this.termIds,
    required this.flashcardIds,
    required this.resolvedAt,
  });
}
```

### 7.2 Sequencing Algorithm Grounded in Database Schema

Lessons do not have a standalone `sort_order` column; ordered association is driven by binding type and `course_lessons.order_index`:

```
Direct Lesson Binding:
  curriculum_node.sort_order 
    → curriculum_node_lessons.sort_order

Module Binding:
  curriculum_node.sort_order 
    → curriculum_node_modules.sort_order 
    → course_lessons.order_index

Course Binding:
  curriculum_node.sort_order 
    → curriculum_node_courses.sort_order 
    → modules.sort_order (if present) 
    → course_lessons.order_index
```

#### Deduplication Rule:
If the same lesson is reachable through both an explicit lesson binding and an inherited course/module binding:
1. The **first occurrence** in the explicitly ordered curriculum sequence wins.
2. Direct lesson bindings take precedence over inherited course/module duplicates.

### 7.3 Resolution by Context Root Type

#### 1. Target Context:
1. Load selected `TargetVersion` and its `curriculum_nodes` tree.
2. Filter nodes based on `scope_config` (e.g. Major requirements only).
3. Query `curriculum_node_concepts` $\to$ collect `coreConceptIds`.
4. **Bounded Prerequisite Traversal:**
   - Traverse `concept_relations` where `relation_type = 'prerequisite'` AND `auto_include = true`.
   - Maintain a `Set<String> visited` to guarantee loop termination.
   - Limit traversal to `maxDepth = 1` (default) or `maxDepth = 2` (if enabled in `scope_config`).
   - Add reached concepts to `supportingConceptIds`.
5. **Teaching Material Resolution (Explicit Bindings):**
   - Query `curriculum_node_courses`, `curriculum_node_modules`, and `curriculum_node_lessons`.
   - Expand attached courses and modules into their constituent lessons via `course_lessons.order_index`.
   - Sort activities by the composite key above and apply the deduplication rule.
6. **Practice Item Resolution:**
   - Map questions, terms, and flashcards belonging to `coreConceptIds` and `supportingConceptIds` into practice sets.

#### 2. Concept Context (The Selection Architecture):
- **Principle:** *Concept determines the knowledge scope; the selected teaching resource determines the instructional sequence.*
- When multiple primary lessons teach the same concept (e.g. *Bayes' Theorem* taught in medical diagnosis, machine learning, and probability theory):
  - `StartLearningScreen` presents the recommended canonical lesson alongside alternative learning tracks.
  - The chosen lesson ID is stored in the context's `scope_config['selectedLessonId']`.
  - If only one primary lesson exists, the choice is skipped and the context launches immediately.
  - Core concept = selected concept.
  - Supporting concepts = immediate required prerequisites (`depth = 1`).
  - Activities = user-selected instructional sequence for that concept.

#### 3. Course / Module / Lesson Context:
- Activities derive strictly from the teaching hierarchy sequence (`course_lessons.order_index`).
- Concepts derive from mapped `lesson_concepts`.

#### 4. StudySet Context:
- Scope is strictly the items in the study set. No external content is inferred.

### 7.4 Offline Snapshot & Cache Strategy
When a context is resolved online:
1. Serialize `ResolvedScope` to `resolved_scopes` Hive box.
2. Serialize a lightweight `ContextCurriculumSnapshot` (node titles, codes, parent links, active focus) to `context_snapshots` Hive box.
3. On app start / context switch:
   - Load from Hive cache immediately $\implies$ UI renders instantly offline.
   - If connected and cache is stale, re-resolve in the background and update Hive.

---

## 8. Global Knowledge State & Evidence Attribution

### 8.1 Responsibility Separation
- **`review_items` (SM-2):** Sole scheduler of review interactions. Determines when and what concrete items are due.
- **`user_concept_state`:** Purely an analytical projection over historical evidence. Does **not** schedule due dates.

### 8.2 Evidence Propagation Contract
Every completed learning activity produces a normalized `evidenceValue` $\in [0.0, 1.0]$:
- Standard MCQ correct: `1.0`
- Standard MCQ incorrect: `0.0`
- SM-2 Recall Grade: normalized rating ($\text{grade} \ge 3 \implies 1.0$, else $0.0$)
- Partial credit / rubric: fractional value ($0.0 \dots 1.0$)

For each concept mapped to the item:
$$\Delta \text{weighted\_total} = \text{mappingWeight}$$
$$\Delta \text{weighted\_correct} = \text{evidenceValue} \times \text{mappingWeight}$$

---

## 9. Target Readiness

Readiness is evaluated per `TargetVersion`:
$$\text{Readiness} = \frac{\sum_{c \in \text{coreConcepts}} \text{ConceptReadiness}(c) \times \text{Weight}(c)}{\sum_{c \in \text{coreConcepts}} \text{Weight}(c)}$$

Reported exclusively via qualitative bands:
- **Strong coverage**
- **Developing**
- **Needs reinforcement**
- **Not yet assessed**

Structural completion (e.g. *Course 100% complete*) and Knowledge Readiness (e.g. *Bands: mostly developing*) remain strictly distinct and are never merged into a single blended percentage.

---

## 10. Learn Screen & Navigation: Point 3 Decision

### 10.1 Calm Surface, Direct Gateway
To protect the calmness guarantee of `UI_ARCHITECTURE_LOCKED.md` while providing effortless agency for large targets:

```
┌──────────────────────────────────────────┐
│  Florida AC Class A  ▾       [Account]   │   ← switcher (plain text if 1 context)
├──────────────────────────────────────────┤
│                                          │
│  Continue                                │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │  Refrigeration Cycle               │  │
│  │  HVAC Systems · Lesson 3 of 14     │  │
│  │  · ~12 min                         │  │
│  │                                    │  │
│  │  ┌──────────┐                      │  │
│  │  │ Continue │   Exam outline →     │  │   ← ONE primary, ONE secondary
│  │  └──────────┘                      │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ─────────────────────────────────────   │
│                                          │
│  8 concepts ready to reinforce · ~5 min  │   ← conditional; absent if 0
│  [ Review ]                              │
│                                          │
└──────────────────────────────────────────┘
```

1. **`Exam outline →` is the gateway for direct choice:**
   - 1 tap reaches the full curriculum tree (`TargetOutlineScreen`).
   - Every topic, module, or lesson is immediately selectable (Direct Access Rule satisfied in $\le$ 2 taps).
2. **Contextual Search lives outside Learn:**
   - Inside `TargetOutlineScreen` as a dedicated in-context filter, OR
   - Inside `LibraryScreen` with the search bar pre-scoped to `[ In: Florida AC Class A ▾ ]`.
3. **Learn remains serene:** Zero clutter, no competing button rows, and no in-page search bars.

---

## 11. Search & Library Architecture

### 11.1 Global Library Search
Searches across all entity types with clear disambiguation tags:
- `Florida Air Conditioning Contractor Class A` $\cdot$ *Licensure Exam (Florida)*
- `Computer Science BS` $\cdot$ *Academic Program (FIU)*
- `Cisco CCNA` $\cdot$ *Certification (Cisco)*
- `Thermodynamics` $\cdot$ *Course*
- `Bayes' Theorem` $\cdot$ *Concept*

### 11.2 Contextual Library Search
When arriving from an active context or selecting a scope filter chip, Library filters results strictly to:
$$\text{Library Results} \cap \text{ResolvedScope(activeContext)}$$
A prominent chip `[ Search entire library ]` allows clearing the scope in one tap.

---

## 12. RLS Performance & Benchmark Gate

Rather than prematurely duplicating `is_public` across all child tables (which risks desynchronization security leaks):
1. **P1 Schema:** Implement standard relational RLS with indexed foreign keys (see §5.12).
2. **Benchmark Gate:** Execute `EXPLAIN ANALYZE` on a realistic 500-node curriculum tree with simulated anonymous and authenticated traffic.
3. **Optimization Threshold:** If RLS join overhead exceeds $25\text{ms}$, implement a `security definer` RPC function (`get_target_curriculum(version_id)`) or a materialized catalog view rather than brittle schema denormalization.

---

## 13. Phased Implementation Roadmap

```
P0: Safety Baseline & Migration Fixes
 ├── Hive enum string serialization + fallback reader in LearningContextAdapter
 ├── Update ReviewableItem (final String? lessonId) & ReviewableContentType.flashcard
 ├── Allocate Hive type IDs 12/13
 └── Migration map table (v2_migration_map)

P1: Additive Schema & DDL
 ├── Ordered execution: fields → targets → versions → courses → modules → nodes → junctions
 ├── knowledge_concepts, concept_relations
 ├── flashcards & study_set_flashcards
 ├── review_items constraint update (content_type, drop not null on lesson_id)
 └── Complete RLS policies enabled on all tables

P2: Additive Data Migration
 ├── career_paths → learning_targets
 ├── legacy concepts → knowledge_concepts
 └── safe module groupings

P3: ScopeResolver & Context Engine
 ├── ScopedLearningActivity & ResolvedScope (orderedActivities)
 ├── Bounded prerequisite traversal (maxDepth = 1, visited set)
 ├── Offline ResolvedScopeCache & snapshot
 └── NextActionEngine integration

P4: Library & Outline Screens
 ├── TargetDetailScreen, ConceptDetailScreen
 ├── TargetOutlineScreen (with in-context search)
 └── StartLearningScreen (context configuration & concept resource selection)

P5: Learn & Review Scope Enforcement
 ├── NextActionEngine consumption of ResolvedScope
 ├── Contextual review filtering
 └── Target readiness projections

P6: Legacy Retirement
 ├── Redirect /careers routes to target routes
 └── Deprecate legacy lesson-owned concepts
```

---

## 14. Content Ingestion Pipeline & Traceable Content Provenance Layer

### 14.1 The Safe Ingestion Pipeline
To safeguard the integrity of official learning targets and prevent premature, accidental, or illegal modifications to published curricula, all content follows a strict, multi-stage ingestion and publication lifecycle:

```
Official Source Blueprint (CompTIA, IEEE/BLS, ACM, NCLEX, USMLE, MCAT)
       ↓
Source Manifest (YAML / JSON structured blueprint)
       ↓
Draft TargetVersion (created_by = NULL, status = 'draft')
       ↓
Curriculum Nodes (Domains & Objectives)
       ↓
Knowledge Concepts & Prerequisite Relations
       ↓
Original Pedagogical Lessons & Assessment Questions
       ↓
Traceable Provenance Mappings (content_source_mappings)
       ↓
Automated Validation & Unit Testing (test/services/curriculum_manifest_test.dart)
       ↓
Human & Content QA Review
       ↓
Promote to Published (TargetVersion.status = 'published')
       ↓  (Strict Database Immutability via RLS)
Old TargetVersion Retired (status = 'retired')
```

### 14.2 Content Integrity & Legal Standards
1. **Official Blueprints Determine Coverage & Objectives**: Official public examination blueprints, accreditation guidelines, and professional bodies of knowledge define the hierarchical domain breakdown, weightings, and learning objectives.
2. **Authoritative Sources Determine Facts**: Curricular definitions and domain facts are grounded in verified reference documentation (e.g. NIST SP 800-61, RFC standards, ACM guidelines).
3. **Original Generated & Authored Assessments**: Assessment questions and practice items are authored originally to test concept mastery, never copied from proprietary commercial question dumps or protected actual exam questions.
4. **Per-Item Traceability**: Every curriculum node, concept, lesson, and question maintains an explicit junction record in `content_source_mappings` pointing to its exact source citation location.

### 14.3 Traceable Provenance Schema
- **`content_source_releases`**: Tracks the external authoritative publisher, official document title, edition/version code, retrieved timestamp, license, and cryptographic hash (`sha256`).
- **`content_source_mappings`**: Connects any curriculum entity (`target_version`, `curriculum_node`, `lesson`, `knowledge_concept`, `question`, `flashcard`) to a `content_source_releases` entry with a relationship tag (`official_blueprint`, `primary_text`, `derived_from`, `reference_citation`, `standards_benchmark`) and exact `citation_location`.

### 14.4 Ingestion CLI Tooling (`tool/ingest_curriculum.dart`)
- **`--dry-run`**: Validates manifest schema, entity relationships, integrity, domain weights, and prerequisite references without performing database writes.
- **`--dir <dir>`**: Batch mode validating all manifests in directory transactions (validate all -> plan -> apply).
- **`--apply`**: Ingests into draft `TargetVersion`, upserts source releases, curriculum nodes, concepts, public lessons, blocks, assessment items, and provenance mappings using `SUPABASE_SERVICE_ROLE_KEY`.
- **`--stage-review`**: Advances draft version to `review_ready` for verification and QA testing.
- **`--publish`**: Promotes draft or review_ready version to `published` status, enforcing permanent database immutability. Supports `--retire-previous` to cleanly transition prior published editions.

---

## 15. Content Primitives V2 & Industrialized Ingestion Pipeline

### 15.1 Ordered Lesson Document Model (`lesson_blocks`)
Rather than constraining lesson content to narrow string columns or flat text, rich lessons are modeled as ordered documents comprising polymorphic instructional blocks:

```
Lesson
 ├── Markdown Block (Introduction & Core Exposition)
 ├── Callout Block (Warning / Caution / Exam Tip)
 ├── Code Block (Syntax Highlighted Sample with Execution Context)
 ├── Table Block (Comparison / Matrix / Feature Grid)
 ├── Image / Diagram Block (Architectural or Clinical Asset)
 ├── Formula Block (LaTeX / Math Notation)
 ├── Example Block (Real-world Scenario)
 └── Practice Prompt Block (Active Retrieval Probe)
```

**Database Schema:**
- Table: `public.lesson_blocks`
- Fields: `id`, `lesson_id`, `sort_order`, `block_type`, `content (jsonb)`, `metadata (jsonb)`, `created_at`, `updated_at`.
- Supported Types: `'markdown'`, `'callout'`, `'code'`, `'table'`, `'image'`, `'formula'`, `'example'`, `'practice_prompt'`.
- Row-Level Security: Inherits from parent `lessons(visibility, user_id)`.

### 15.2 Extensible Assessment Architecture (`assessment_items` & `assessment_stimuli`)
To support complex clinical vignettes, cloud architecture diagrams, multi-select items (SATA), and interactive evaluation without database column proliferation, assessments are partitioned into shared stimuli and polymorphic items:

1. **Shared Stimuli (`public.assessment_stimuli`)**:
   - Represents the shared scenario, clinical patient case, architecture diagram, data table, or code snippet.
   - Referenced by multiple assessment items (e.g., 4 questions evaluating a single clinical case or cloud architecture).
   - Fields: `id`, `stimulus_type`, `title`, `body`, `structured_data (jsonb)`, `asset_refs (jsonb)`, `metadata (jsonb)`.
   - Types: `'clinical_case'`, `'architecture_diagram'`, `'code_snippet'`, `'data_table'`, `'scenario'`, `'passage'`.

2. **Assessment Items (`public.assessment_items`)**:
   - Replaces hard-coded `correct_answer: int` with decoupled specifications.
   - Fields: `id`, `lesson_id`, `stimulus_id`, `interaction_type`, `prompt`, `response_spec (jsonb)`, `scoring_spec (jsonb)`, `explanation`, `difficulty`, `cognitive_level`, `metadata (jsonb)`.
   - Interaction Types:
     - `single_choice`: standard MCQ with single selection.
     - `multi_select`: Select-All-That-Apply (SATA) with `scoring_method` (`all_or_nothing` or `partial_credit`).
     - `ordered_response`: sequencing tasks (e.g. incident response steps).
     - `matching`: key-value pairing.
     - `matrix_grid`: multi-row, multi-column clinical decisions or feature grids.
     - `numeric_entry`: dosage, subnet, or exact quantitative answers.
     - `cloze`: fill-in-the-blank or dropdown cloze sentences.
     - `code_output`: programming prediction questions.

3. **Concept Junction (`public.assessment_item_concepts`)**:
   - Links items to canonical `knowledge_concepts` with `role ('primary' | 'supporting')` and `weight (0.0 to 1.0)`.

### 15.3 Early Canonical Concept Resolution & Deduplication
To prevent cross-target concept duplication (e.g., `hash-table` vs `hash-tables` vs `hashing-algorithms`), concept resolution happens at ingestion time before mass content is loaded:

```
Incoming Manifest Concept
          ↓
[1. Exact Slug Match?] ──────────> YES: Reuse Existing Canonical Concept
          ↓ NO
[2. Slug in Concept Aliases?] ───> YES: Map to Canonical Concept Slug
          ↓ NO
[3. Exact Name Match?] ──────────> YES: Reuse Canonical Concept
          ↓ NO
[4. Name in Concept Aliases?] ───> YES: Reuse Canonical Concept
          ↓ NO
[Insert New Canonical Concept] with declared aliases array
```

- Backed by database RPC `public.resolve_canonical_concept(p_slug, p_name)` and GIN index on `knowledge_concepts.aliases`.

### 15.4 Staging Lifecycle & Version Immutability
Published `TargetVersion` records are strictly immutable. To accommodate quality assurance, editorial review, and beta testing, target versions support a 4-state lifecycle:

$$\text{draft} \longrightarrow \text{review\_ready} \longrightarrow \text{published} \longrightarrow \text{retired}$$

- **`draft`**: Ingestion in progress, editable by target owner / service role.
- **`review_ready`**: Content complete, eligible for QA, internal testing, and beta verification without public catalog exposure.
- **`published`**: Final immutable release. Database RLS blocks any updates or deletions.
- **`retired`**: Deprecated prior edition; preserved for historical user transcript integrity.

### 15.5 Cross-Version Progress Transfer (`target_version_concept_mappings`)
When an authoritative blueprint updates (e.g., CompTIA Security+ SY0-601 $\to$ SY0-701), learner progress transfers through canonical concepts, not unstable curriculum node IDs:

- Table: `public.target_version_concept_mappings`
- Fields: `from_target_version_id`, `from_concept_id`, `to_target_version_id`, `to_concept_id`, `mapping_type`, `transfer_weight`.
- Mapping Types: `'unchanged'`, `'renamed'`, `'expanded'`, `'narrowed'`, `'replaced'`, `'removed'`.
- Transfer Weight: $0.0 \le w \le 1.0$ controls the fraction of retrieval evidence carried forward.

### 15.6 Pedagogical Diagnostics & Scoring Safeguards
To maintain scientific credibility and prevent false claims of certification:
1. **Diagnostic Language**:
   - **Prohibited**: Overclaiming "Mastered" (e.g., "Domain 1: 90% Mastered").
   - **Required**: Evidence-based phrasing such as "Strong evidence", "Needs reinforcement", or "Practice readiness: 78%".
2. **Separation of Official Facts vs. App Estimates**:
   - **Official Facts**: Published passing standard (e.g. 750/900), time limit, question count range, official domain weights.
   - **App Estimates**: Statistical readiness projection, practice performance score, Bayesian mastery estimates, remediation recommendations.
   - These are stored separately and displayed with appropriate certainty framing.
3. **Adaptive Practice Boundaries**:
   - Adaptive testing is designated as **"adaptive practice mode"** or **"CAT-style simulation"**.
   - The app adapts difficulty, domain balance, and uncertainty without claiming to reproduce proprietary operational algorithms (such as the proprietary NCLEX CAT algorithm).

---

## 16. Revised Phased Content & Platform Roadmap

```
Phase A: Content Primitives (~85–90% — Hardened)
 ├── Generic ordered lesson block model (lesson_blocks)
 ├── Extensible assessment interaction schema (assessment_items)
 ├── Shared vignettes & diagrams (assessment_stimuli)
 ├── Concept junctions (assessment_item_concepts)
 ├── Version concept mapping table (target_version_concept_mappings with nullable to_concept_id for removals)
 └── Hardened assessment & stimulus RLS policies (private items strictly protected from public leaks)

Phase B: Canonical Concept Resolution & Manifest Contract (~85% — Hardened)
 ├── Canonical concept alias indexing & RPC resolver (resolve_canonical_concept with field matching & ambiguity detection)
 ├── Formal JSON Schema contract (curriculum_manifest.schema.json with interaction-specific schemas & additionalProperties: false)
 ├── Manifest validation rules and alias ingestion
 └── Reference manifest enrichment (provenance SHA-256 fix, multi-source releases, explicit concept_slugs)

Phase C: Ingestion Industrialization & Content Hardening (~85% — Hardened)
 ├── Batch directory ingestion CLI with 3-phase execution (--dir, --dry-run, --apply)
 ├── Pedagogical quality linter & diagnostic gate (tool/lint_manifest.dart with JSON schema enforcement & dual-assessment validation)
 ├── Staging lifecycle transition (--stage-review, review_ready freeze & --publish prerequisite gate)
 ├── Idempotent draft ingestion (clean_draft_target_version atomic cleanup RPC)
 ├── Strictly scoped lesson concept linking (eliminating cross-objective leakage)
 ├── Parity for objective-level flashcards & stimuli, and removed concept mappings
 └── Main CI validation gate (.github/workflows/flutter-ci.yml manifest lint & dry-run)

Phase D: Learning Presentation (NEXT)
 ├── Rich Lesson Block Reader (markdown, callout, code, table, formula, example, prompt)
 ├── New assessment interaction renderers (multi-select/SATA, ordered response, matching)
 ├── Shared case study & exhibit renderer
 └── Provenance & citation inspector UI

Phase E: Assessment & Readiness Engine
 ├── Constraint-based weighted mock exam generator (domain weights, difficulty, formats)
 ├── Domain diagnostic profiling (evidence-based, non-overclaiming wording)
 ├── Timed exam simulation mode
 ├── Target-specific passing standard vs. app-estimated readiness models
 └── Adaptive practice mode (CAT-style practice)

Phase F: Full Taxonomy & Crosswalk Expansion
 ├── Version/release-driven CIP, SOC, and O*NET importers
 ├── Cross-target canonical concept sharing (Computer Science BS ↔ Software Engineer ↔ Certs)
 └── Occupational career crosswalk linking

Phase G: Version Migration & Governance
 ├── Target version migration tooling & concept transfer evaluation
 ├── Review-ready staging dashboard & QA workflows
 └── Publication and retirement pipeline
```

---

## 13. Target Version Governance & Security Model

Target versions evolve across lifecycles (`draft` → `review_ready` → `published` → `retired`). To ensure zero leakage of draft curriculum or concept mappings while preserving seamless historical access for learners enrolled prior to retirement, the authorization model enforces a strict two-tier architecture:

### 13.1 Two-Tier Visibility Architecture
1. **Normal (Catalog) Visibility (`public.is_target_version_visible`)**:
   - Covers active catalog discovery: published versions of published, public learning targets; target owners; and assigned reviewers when status is `review_ready` (plus `service_role`).
   - Deliberately excludes retired versions so they cannot be newly browsed, discovered, or selected as destinations.
   - Enforced by `target_version_concept_mappings` read RLS, destination validation in `evaluate_target_version_migration`, and `migrate_user_context_target_version`.

2. **Historical-Context Access (`public.has_historical_target_version_access`)**:
   - Covers legitimate learners who enrolled in a version before it retired.
   - Requires `target_versions.status = 'retired'` AND an existing `learning_contexts` row referencing `target_version_id` owned by the caller.
   - Enforced by `target_versions` read RLS (`versions_read`) and the source version authorization in `evaluate_target_version_migration`.

### 13.2 Controlled Context Assignment (`validate_learning_context_target_version`)
To prevent attackers from arbitrarily assigning unpublished draft or retired UUIDs to their own `learning_contexts` to manufacture authorization evidence:
- A `BEFORE INSERT OR UPDATE` trigger on `public.learning_contexts` enforces that:
  - On `INSERT` or when `target_version_id` is mutated, the target version must satisfy `public.is_target_version_visible` (unless caller has `service_role`).
  - For target-root contexts (`root_type = 'target'`), `root_id` must match `target_versions.target_id`.
  - Non-admin callers cannot reassign context ownership (`user_id`).
  - Existing context rows pointing to a version that subsequently became retired remain valid and mutable for non-version fields (e.g., `last_active_at`, `label`), granting legitimate historical access without vulnerability to self-assigned elevation.



