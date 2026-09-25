# Learning Architecture V2 — Formal Implementation Specification

**Status:** Proposed implementation baseline  
**Repository:** \`RACCHUS/LearningApp\`  
**Supersedes:** The v1 domain/hierarchy assumptions in \`UI_ARCHITECTURE_LOCKED.md\` where this document explicitly differs. The v1 interaction principles remain in force unless overridden here.  
**Core law:** **Knowledge is global. Learning is scoped.**

---

## 1. Purpose

V2 expands LearningApp from a primarily lesson/course/career-path system into a general learning platform that can represent and isolate many different learning intentions without mixing unrelated material.

The same system must support all of these as first-class entry points:

- prepare for a specific licensure exam, such as a Florida contractor licensing exam;
- prepare for a certification, such as CompTIA or Cisco;
- pursue an academic program or major, such as Computer Science;
- pursue a career, such as Network Engineer;
- take a specific college or K–12 course;
- study one module or lesson;
- study one canonical concept;
- use a custom study set.

The learner must be able to choose any of those directly. The app may help sequence work, surface prerequisites, and schedule review, but it must not broaden the current learning experience with unrelated material merely because the global catalog contains related content.

### 1.1 Locked product rules

1. **Knowledge is global. Learning is scoped.**
   - A learner's evidence about a concept is reusable across every target that uses that concept.
   - The active Learning Context determines what appears in Learn, scoped search, contextual review, and context-specific Progress.

2. **Targets are destinations, not containers for duplicated knowledge.**
   - Careers, academic programs, certifications, and exams map to canonical concepts and learning resources.
   - They do not own private copies of concepts.

3. **Concept is the canonical knowledge atom.**
   - Lessons teach concepts.
   - Questions assess concepts.
   - Terms/flashcards reinforce concepts.
   - Exams require concepts.
   - Careers and academic programs require or cover concepts.

4. **Formal curriculum and knowledge are separate.**
   - Curriculum structure answers "what does this target require and how is it organized?"
   - The concept graph answers "what knowledge exists and how does it relate?"

5. **User intent wins.**
   - Reviews and recommendations never silently replace an explicit context/focus choice.
   - Direct access remains available in two deliberate actions or fewer from Learn.

6. **Related is not the same as in scope.**
   - Core material appears.
   - Supporting prerequisites may appear.
   - Merely related material stays out of Learn unless the learner explicitly broadens scope.

7. **Completion and knowledge remain separate.**
   - "63% of curriculum completed" and "retrieval evidence is strong for 42 concepts" are different measurements.

---

## 2. Current-system constraints that V2 must preserve

V2 is a migration, not a rewrite from an empty database.

The current production code/database already has:

- \`lessons\`, with lesson-owned \`terms\`, \`questions\`, and \`concepts\`;
- \`courses\` and \`course_lessons\`;
- \`study_sets\`, \`course_progress\`, and \`study_set_progress\`;
- \`career_paths\`, \`career_path_courses\`, \`skills\`, \`career_path_skills\`, \`course_skills\`;
- skill assessments and \`user_skill_stats\`;
- \`review_items\` using content-level SM-2-style scheduling;
- \`learning_contexts\` and \`resume_pointers\`;
- the three-destination shell: **Learn | Library | Progress**;
- direct lesson/course/study-set flows that must continue to work.

Current \`LearningContext.root_type\` values are:

\`path | course | module | lesson | studySet\`

Current local Hive serialization stores the root type by enum **index**, which makes enum reordering unsafe.

Current \`concepts\` are lesson-owned and the Dart \`Concept\` model requires \`lessonId\`. V2 therefore must not destructively redefine that table/model in its first migration.

---

## 3. V2 domain model

V2 has four independent but connected layers.

### 3.1 Discovery taxonomy

~~~text
LearningField
  ├─ Technology
  │   ├─ Software Development
  │   ├─ Networking
  │   └─ Cybersecurity
  ├─ Healthcare
  ├─ Law
  └─ Business
~~~

A field is a discovery/taxonomy object. It is **not** something the learner completes.

### 3.2 Formal learning targets

A \`LearningTarget\` is a destination whose requirements can be versioned.

Supported V2 target types:

~~~text
career
academic_program
certification
licensure_exam
standardized_exam
~~~

Examples:

- Career: Network Engineer
- Academic program: BS Computer Science at FIU
- Certification: Cisco CCNA
- Certification: CompTIA Security+
- Licensure exam: NCLEX-RN
- Licensure exam: Florida Air Conditioning Contractor Class A
- Standardized exam: AP Computer Science A

Courses, modules, lessons, concepts, and study sets remain direct Learning Context roots; they do **not** need to be wrapped in fake LearningTargets.

### 3.3 Teaching/curriculum structure

~~~text
LearningTarget
  └─ TargetVersion
       └─ CurriculumNode
            ├─ CurriculumNode
            ├─ linked Course
            ├─ linked Lesson
            └─ linked Concepts
~~~

The hierarchy inside a target is target-specific.

An exam can use:

~~~text
Domain → Objective → Subobjective
~~~

An academic program can use:

~~~text
Requirement Group → Course Requirement → Elective Group
~~~

A career can use:

~~~text
Skill Area → Skill
~~~

The same \`CurriculumNode\` entity represents these structures through \`node_type\`.

### 3.4 Global knowledge graph

~~~text
KnowledgeConcept ←→ KnowledgeConcept
       ↑
       ├─ Lesson
       ├─ Question
       ├─ Term / flashcard
       ├─ Assessment question
       ├─ Skill
       └─ Curriculum node
~~~

The canonical concept is not owned by a course, lesson, exam, or career.

---

## 4. Exact PostgreSQL schema

The first V2 migrations are additive. Existing production tables remain intact.

### 4.1 Discovery and provider entities

~~~sql
create table if not exists public.learning_fields (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.learning_fields(id) on delete set null,
  name text not null,
  slug text not null unique,
  description text,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists learning_fields_parent_idx
  on public.learning_fields(parent_id, sort_order);

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  org_type text not null check (
    org_type in ('provider', 'regulator', 'institution', 'school', 'publisher', 'other')
  ),
  jurisdiction_code text,
  website_url text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
~~~

### 4.2 Targets and versions

~~~sql
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
  title text not null,
  slug text not null unique,
  description text,
  organization_id uuid references public.organizations(id) on delete set null,
  jurisdiction_code text,
  is_public boolean not null default true,
  is_official boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists learning_targets_type_idx
  on public.learning_targets(target_type);

create index if not exists learning_targets_org_idx
  on public.learning_targets(organization_id);

create table if not exists public.target_fields (
  target_id uuid not null references public.learning_targets(id) on delete cascade,
  field_id uuid not null references public.learning_fields(id) on delete cascade,
  is_primary boolean not null default false,
  primary key (target_id, field_id)
);

create table if not exists public.target_versions (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.learning_targets(id) on delete cascade,
  version_label text not null,
  external_code text,
  status text not null default 'draft' check (
    status in ('draft', 'current', 'retired')
  ),
  effective_from date,
  effective_to date,
  published_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(target_id, version_label)
);

create unique index if not exists one_current_target_version_idx
  on public.target_versions(target_id)
  where status = 'current';

create index if not exists target_versions_target_idx
  on public.target_versions(target_id, status);

create table if not exists public.target_sources (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null references public.target_versions(id) on delete cascade,
  source_type text not null check (
    source_type in (
      'official_blueprint',
      'catalog',
      'handbook',
      'regulation',
      'standards',
      'provider_page',
      'other'
    )
  ),
  title text not null,
  url text not null,
  is_authoritative boolean not null default false,
  published_at timestamptz,
  retrieved_at timestamptz not null default now(),
  checksum text,
  metadata jsonb not null default '{}'::jsonb
);
~~~

### 4.3 Curriculum tree

~~~sql
create table if not exists public.curriculum_nodes (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null references public.target_versions(id) on delete cascade,
  parent_id uuid references public.curriculum_nodes(id) on delete cascade,
  node_type text not null,
  code text,
  title text not null,
  description text,
  order_index integer not null default 0,
  weight numeric(8,5),
  is_required boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists curriculum_nodes_version_idx
  on public.curriculum_nodes(target_version_id, parent_id, order_index);

create index if not exists curriculum_nodes_parent_idx
  on public.curriculum_nodes(parent_id);
~~~

\`node_type\` is deliberately data-driven instead of a database enum because target structures vary. The application recognizes common types such as:

~~~text
root
exam_domain
exam_objective
exam_subobjective
requirement_group
course_requirement
elective_group
skill_area
skill
topic
custom
~~~

Unknown node types must render generically instead of failing.

### 4.4 Canonical concepts

The existing \`public.concepts\` table remains lesson-owned legacy content. V2 adds a separate canonical concept table.

~~~sql
create table if not exists public.knowledge_concepts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  description text,
  example_text text,
  is_public boolean not null default true,
  is_official boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  merged_into_id uuid references public.knowledge_concepts(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (merged_into_id is null or merged_into_id <> id)
);

create index if not exists knowledge_concepts_name_idx
  on public.knowledge_concepts(name);

create table if not exists public.concept_aliases (
  id uuid primary key default gen_random_uuid(),
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  alias text not null,
  normalized_alias text not null,
  locale text not null default 'en',
  unique(concept_id, normalized_alias)
);

create index if not exists concept_aliases_normalized_idx
  on public.concept_aliases(normalized_alias);

create table if not exists public.concept_fields (
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  field_id uuid not null references public.learning_fields(id) on delete cascade,
  is_primary boolean not null default false,
  primary key (concept_id, field_id)
);

create table if not exists public.concept_relations (
  source_concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  target_concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  relation_type text not null check (
    relation_type in (
      'prerequisite',
      'part_of',
      'related_to',
      'contrasts_with',
      'applies_to'
    )
  ),
  strength numeric(4,3) not null default 1.0 check (
    strength >= 0 and strength <= 1
  ),
  metadata jsonb not null default '{}'::jsonb,
  primary key (source_concept_id, target_concept_id, relation_type),
  check (source_concept_id <> target_concept_id)
);

create index if not exists concept_relations_target_idx
  on public.concept_relations(target_concept_id, relation_type);
~~~

Direction for prerequisites is:

~~~text
source_concept_id = prerequisite
target_concept_id = concept that depends on it
~~~

Example: Binary Numbers → IPv4 Addressing.

### 4.5 Curriculum-to-concept mappings

~~~sql
create table if not exists public.curriculum_node_concepts (
  curriculum_node_id uuid not null references public.curriculum_nodes(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  relevance text not null default 'core' check (
    relevance in ('core', 'supporting', 'related')
  ),
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  is_required boolean not null default true,
  primary key (curriculum_node_id, concept_id)
);

create index if not exists curriculum_node_concepts_concept_idx
  on public.curriculum_node_concepts(concept_id);
~~~

### 4.6 Target curriculum-to-content mappings

~~~sql
create table if not exists public.curriculum_node_courses (
  curriculum_node_id uuid not null references public.curriculum_nodes(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  role text not null default 'primary' check (
    role in ('primary', 'supporting', 'optional')
  ),
  order_index integer not null default 0,
  primary key (curriculum_node_id, course_id)
);

create table if not exists public.curriculum_node_lessons (
  curriculum_node_id uuid not null references public.curriculum_nodes(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  role text not null default 'primary' check (
    role in ('primary', 'supporting', 'optional')
  ),
  order_index integer not null default 0,
  primary key (curriculum_node_id, lesson_id)
);
~~~

These are explicit curation links. Scope may also discover eligible content through concept overlap.

### 4.7 Optional course modules

Modules remain optional. Existing \`course_lessons\` continues to work for courses without modules.

~~~sql
create table if not exists public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  description text,
  order_index integer not null default 0,
  is_required boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists course_modules_course_idx
  on public.course_modules(course_id, order_index);

create table if not exists public.module_lessons (
  module_id uuid not null references public.course_modules(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  order_index integer not null default 0,
  is_required boolean not null default true,
  primary key (module_id, lesson_id)
);

create index if not exists module_lessons_lesson_idx
  on public.module_lessons(lesson_id);
~~~

No synthetic module is required. A course may use direct \`course_lessons\`, modules, or both during migration.

### 4.8 Existing content-to-concept mappings

V2 does **not** immediately replace \`questions\`, \`terms\`, or legacy lesson-owned \`concepts\`. It maps them to canonical knowledge.

~~~sql
create table if not exists public.lesson_knowledge_concepts (
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  legacy_concept_id uuid references public.concepts(id) on delete set null,
  role text not null default 'primary' check (
    role in ('primary', 'supporting', 'prerequisite')
  ),
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  order_index integer not null default 0,
  primary key (lesson_id, concept_id)
);

create table if not exists public.question_knowledge_concepts (
  question_id uuid not null references public.questions(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary' check (
    role in ('primary', 'supporting')
  ),
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  primary key (question_id, concept_id)
);

create table if not exists public.term_knowledge_concepts (
  term_id uuid not null references public.terms(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary' check (
    role in ('primary', 'supporting')
  ),
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  primary key (term_id, concept_id)
);

create table if not exists public.assessment_question_knowledge_concepts (
  assessment_question_id uuid not null
    references public.assessment_questions(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  role text not null default 'primary' check (
    role in ('primary', 'supporting')
  ),
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  primary key (assessment_question_id, concept_id)
);

create table if not exists public.skill_knowledge_concepts (
  skill_id uuid not null references public.skills(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  weight numeric(5,4) not null default 1.0 check (
    weight > 0 and weight <= 1
  ),
  primary key (skill_id, concept_id)
);
~~~

A question may therefore test multiple concepts with different weights.

Example:

~~~text
Question: usable hosts in 192.168.1.0/26

Subnetting          primary      1.00
CIDR                supporting   0.50
IPv4 addressing     supporting   0.25
~~~

An incorrect answer must not count as equal evidence against every linked concept.

### 4.9 Learning paths

A target version can have zero or more curated paths. Paths sequence curriculum nodes, not duplicated course/content objects.

~~~sql
create table if not exists public.learning_paths (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null references public.target_versions(id) on delete cascade,
  title text not null,
  description text,
  path_type text not null default 'full' check (
    path_type in ('full', 'accelerated', 'prerequisite_first', 'custom')
  ),
  is_public boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.learning_path_steps (
  path_id uuid not null references public.learning_paths(id) on delete cascade,
  curriculum_node_id uuid not null references public.curriculum_nodes(id) on delete cascade,
  order_index integer not null default 0,
  is_required boolean not null default true,
  primary key (path_id, curriculum_node_id)
);

create index if not exists learning_path_steps_order_idx
  on public.learning_path_steps(path_id, order_index);
~~~

### 4.10 Concept evidence and derived user state

The evidence log is the durable source of truth for V2 knowledge-state calculations. \`user_concept_state\` is a rebuildable cache.

~~~sql
create table if not exists public.concept_evidence_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  context_id uuid references public.learning_contexts(id) on delete set null,
  source_type text not null check (
    source_type in (
      'question',
      'term',
      'flashcard',
      'assessment_question',
      'lesson',
      'manual'
    )
  ),
  source_id text,
  event_type text not null check (
    event_type in (
      'retrieval_correct',
      'retrieval_incorrect',
      'hinted_correct',
      'known',
      'missed',
      'exposure'
    )
  ),
  evidence_weight numeric(6,4) not null default 1.0,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists concept_evidence_user_concept_idx
  on public.concept_evidence_events(user_id, concept_id, occurred_at desc);

create table if not exists public.user_concept_state (
  user_id uuid not null references auth.users(id) on delete cascade,
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  retrieval_band text not null default 'unseen' check (
    retrieval_band in (
      'unseen',
      'needs_reinforcement',
      'developing',
      'well_retained',
      'well_established'
    )
  ),
  confidence_band text not null default 'low' check (
    confidence_band in ('low', 'medium', 'high')
  ),
  evidence_count integer not null default 0,
  correct_retrievals integer not null default 0,
  incorrect_retrievals integer not null default 0,
  last_evidence_at timestamptz,
  model_version text not null default 'v2-heuristic-1',
  state_payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, concept_id)
);
~~~

V2 does **not** claim that these bands are validated mastery. UI copy continues to describe them as retrieval/knowledge evidence.

---

## 5. LearningContext V2

### 5.1 Root types

The current Dart enum order must remain intact because Hive stores enum indices.

Current order:

~~~text
0 path
1 course
2 module
3 lesson
4 studySet
~~~

V2 appends new values only:

~~~dart
enum ContextRootType {
  path,
  course,
  module,
  lesson,
  studySet,
  target,   // append only
  concept,  // append only
}
~~~

Do not insert values between legacy members.

### 5.2 Supabase migration

~~~sql
alter table public.learning_contexts
  drop constraint if exists learning_contexts_root_type_check;

alter table public.learning_contexts
  add constraint learning_contexts_root_type_check
  check (
    root_type in (
      'path',
      'course',
      'module',
      'lesson',
      'studySet',
      'target',
      'concept'
    )
  );

alter table public.learning_contexts
  add column if not exists target_version_id uuid
    references public.target_versions(id) on delete set null,
  add column if not exists active_focus_type text,
  add column if not exists active_focus_id text,
  add column if not exists scope_mode text not null
    default 'core_plus_prerequisites',
  add column if not exists scope_config jsonb not null
    default '{}'::jsonb,
  add column if not exists scope_revision integer not null default 1;

alter table public.learning_contexts
  add constraint learning_contexts_scope_mode_check
  check (
    scope_mode in ('core_only', 'core_plus_prerequisites', 'custom')
  );

alter table public.learning_contexts
  add constraint learning_contexts_focus_type_check
  check (
    active_focus_type is null or
    active_focus_type in (
      'curriculum_node',
      'course',
      'module',
      'lesson',
      'concept'
    )
  );
~~~

### 5.3 Context semantics

Examples:

~~~text
Florida AC Class A
rootType = target
rootId = <learning_targets.id>
targetVersionId = <current exam version>
scopeMode = core_plus_prerequisites

Computer Science BS
rootType = target
rootId = <program target id>
targetVersionId = <2026-27 catalog>
scopeConfig = {
  "preset": "major_only",
  "included_node_ids": [...],
  "excluded_node_ids": [...]
}

Calculus II
rootType = course
rootId = <course id>

Bayes' theorem
rootType = concept
rootId = <knowledge_concept id>
scopeConfig = {
  "include_prerequisites": true,
  "max_prerequisite_depth": 2
}

One lesson
rootType = lesson

Custom study set
rootType = studySet
~~~

### 5.4 Context vs Focus

A **Context** is the thing the learner chose to pursue.

A **Focus** is the current place inside that context.

~~~text
Context: Florida AC Class A
Focus: Refrigeration Systems

Context: BS Computer Science
Focus: Data Structures

Context: CCNA
Focus: IP Connectivity
~~~

Changing focus must not create a new LearningContext.

### 5.5 Hive migration

The existing \`LearningContextAdapter\` must remain typeId 10.

Do not repurpose existing field IDs 0–8.

Add fields with new IDs:

~~~text
9  rootTypeCode       string, preferred over legacy enum index
10 targetVersionId    string?
11 activeFocusType    string?
12 activeFocusId      string?
13 scopeMode          string
14 scopeConfigJson    string
15 scopeRevision      int
~~~

Writer behavior:

- continue writing legacy field 3 (\`rootType.index\`) for backward compatibility;
- also write field 9 (\`rootType.name\`);
- reader prefers field 9 when present, then falls back to field 3.

This removes future dependence on enum order without invalidating existing Hive data.

---

## 6. ScopeResolver — single source of truth

All context-aware product surfaces must use the same resolver.

### 6.1 Contract

~~~dart
class ResolvedScope {
  final String contextId;

  final Set<String> coreConceptIds;
  final Set<String> supportingConceptIds;
  final Set<String> relatedConceptIds;

  final Set<String> curriculumNodeIds;
  final Set<String> courseIds;
  final Set<String> moduleIds;
  final Set<String> lessonIds;
  final Set<String> questionIds;
  final Set<String> termIds;

  final Set<String> unresolvedPrerequisiteConceptIds;

  final int scopeRevision;
  final DateTime resolvedAt;
}
~~~

~~~dart
abstract interface class ScopeResolver {
  Future<ResolvedScope> resolve(LearningContext context);
}
~~~

### 6.2 Relevance behavior

- **Core:** explicitly required by the selected target/context. Allowed in Learn.
- **Supporting:** prerequisite/support needed for core material. Allowed in Learn when relevant.
- **Related:** relevant but unnecessary. Excluded from Learn by default; visible in Library.

### 6.3 Target context resolution

For \`rootType == target\`:

1. resolve \`targetVersionId\`; if null, use the single \`current\` version;
2. load curriculum nodes after applying \`scope_config\` included/excluded node filters;
3. collect node concepts with \`relevance = core\`;
4. if \`scope_mode = core_plus_prerequisites\`, recursively follow \`concept_relations.relation_type = prerequisite\`;
5. default max prerequisite depth = 2 unless explicitly configured;
6. collect explicitly linked courses/lessons;
7. add lessons/questions/terms whose canonical concept mappings overlap core/supporting scope;
8. never automatically add content based only on \`related_to\`.

### 6.4 Direct course/module/lesson resolution

- Course: use modules/direct course lessons, then their canonical concepts.
- Module: use its module lessons and concepts.
- Lesson: use \`lesson_knowledge_concepts\` plus item mappings.
- Legacy unmapped lesson content may fall back to lesson-level inclusion but must be marked as \`legacyFallback = true\` internally.

### 6.5 Concept context resolution

The selected concept is core.

If prerequisites are enabled, recursively add prerequisite concepts as supporting.

No neighboring \`related_to\` concepts enter Learn automatically.

### 6.6 Study-set resolution

Resolve concept scope from:

1. explicitly selected canonical concept IDs;
2. selected questions/terms via their mappings;
3. full selected lessons via lesson mappings;
4. legacy lesson fallback only when canonical mappings do not yet exist.

### 6.7 Contextual review rule

The Learn review prompt may count/show only due items whose canonical concept mappings intersect:

~~~text
coreConceptIds ∪ supportingConceptIds
~~~

Unrelated due reviews remain globally available but do not appear as debt in the current context.

---

## 7. Learning item model

V2 uses an application-level abstraction first; it does not force an immediate destructive database consolidation.

~~~dart
sealed class LearningItemRef {
  String get id;
  LearningItemType get type;
}

enum LearningItemType {
  question,
  term,
  flashcard,
  assessmentQuestion,
  workedExample,
  exercise,
}
~~~

For initial V2:

- existing \`questions\` are question items;
- existing \`terms\` are term/flashcard-like items;
- existing assessment questions remain assessment items;
- future arbitrary front/back flashcards may get a dedicated table later.

A physical unified \`learning_items\` table is explicitly **deferred** until all content services use this abstraction. Avoid a high-risk rewrite just to normalize tables.

---

## 8. UI information architecture

The three-destination shell remains:

~~~text
Learn | Library | Progress
~~~

### 8.1 Learn

Answers:

> What am I working on now?

Layout:

~~~text
Learn                          [ Current Context ▾ ]

Continue
<current lesson/activity>
<context orientation · estimated time>
[ Continue ]

Choose what to study
[ Outline ]   [ Topics ]   [ Practice ]

Ready to reinforce              // only when relevant
8 concepts · ~5 min
[ Review ]
~~~

No global catalog feed appears on Learn.

### 8.2 Library

Answers:

> What exists? What do I want?

Top:

~~~text
[ Search anything... ]
~~~

Browse sections:

~~~text
Careers
Degrees & Majors
Licenses & Exams
Certifications
Courses
Skills & Concepts
Lessons
Study Sets
~~~

Search results must show type/context clearly:

~~~text
Florida Air Conditioning Contractor Class A
Licensure Exam · Florida

Computer Science BS
Academic Program · <institution>

Cisco CCNA
Certification · Cisco

Calculus II
Course

Bayes' theorem
Concept
~~~

### 8.3 Progress

Two explicit modes:

~~~text
[ This Context ] [ All Knowledge ]
~~~

**This Context**:
- structural target/course completion;
- knowledge evidence for concepts in active scope;
- target-area breakdown.

**All Knowledge**:
- global concept evidence grouped by field;
- no implication that every concept is relevant to the active goal.

---

## 9. Start flows by user intent

### 9.1 Licensure exam example: Florida Air Conditioning Contractor Class A

Flow:

~~~text
Library
→ Search "Florida Air A"
→ Result: Florida Air Conditioning Contractor Class A
→ Target detail
→ Start learning
~~~

Start screen:

~~~text
Florida Air Conditioning Contractor Class A
Licensure Exam · Florida

Version
Current official exam/requirements version

Study scope
● Full exam
○ Choose exam areas

Exam date (optional)
Study-time preference (optional)

[ Start learning ]
~~~

Backend action:

1. create \`LearningContext(rootType=target)\`;
2. pin exact \`targetVersionId\`;
3. save scope preset/config;
4. resolve scope;
5. route to \`/learn\`.

The exact exam curriculum is populated from authoritative source records; V2 must not invent an exam blueprint when source data is missing.

### 9.2 Computer Science major

Search result:

~~~text
Computer Science BS
Academic Program
~~~

When institution-specific versions exist:

~~~text
Institution: <school>
Catalog year: 2026–27

Include
● Major requirements
○ Major + supporting math/science
○ Entire program
~~~

The preset becomes \`scope_config\`, primarily through included/excluded curriculum-node groups.

General-education material never appears in a "major only" context merely because the full degree target contains it.

### 9.3 Certification

CCNA/CompTIA flow is the same target/version flow.

Target version stores the specific blueprint/exam code, e.g. a current provider code.

The learner's canonical concept evidence transfers from previous contexts, but Learn remains certification-scoped.

### 9.4 College or K–12 course

A course can be started directly.

~~~text
Course detail
[ Start learning ]
→ LearningContext(rootType=course)
→ /learn
~~~

No career/degree target is required.

Institutional metadata can be added through an optional course profile later; it is not required for the V2 core.

### 9.5 Single concept

~~~text
Bayes' theorem
Concept

Study scope
● Concept + necessary prerequisites
○ This concept only

[ Start learning ]
~~~

Creates \`rootType=concept\`.

### 9.6 Single lesson

A lesson creates a direct lesson context. Completing it does not auto-enroll the user in a parent course or target.

---

## 10. New screens and routes

Existing routes remain unless explicitly redirected.

### 10.1 Shell routes — unchanged

~~~text
/learn
/library
/progress
~~~

### 10.2 V2 catalog routes

~~~text
/targets/:targetId
/targets/:targetId/start
/library/targets?type=career
/library/targets?type=academic_program
/library/targets?type=certification
/library/targets?type=licensure_exam
/library/targets?type=standardized_exam
/library/courses
/library/concepts
/library/lessons
~~~

Screens:

~~~text
TargetDetailScreen
TargetStartScreen
TargetBrowseScreen
ConceptBrowseScreen
ConceptDetailScreen
~~~

### 10.3 Context routes

~~~text
/contexts/:contextId/outline
/contexts/:contextId/topics
/contexts/:contextId/practice
/contexts/:contextId/search
/contexts/:contextId/settings
~~~

Screens:

~~~text
ContextOutlineScreen
ContextTopicsScreen
ContextPracticeScreen
ContextSearchScreen
ContextSettingsScreen
~~~

### 10.4 Concept route

~~~text
/concepts/:conceptId
~~~

### 10.5 Legacy route compatibility

Keep these routes functional during migration:

~~~text
/careers
/careers/:careerPathId
/courses/:courseId
/course/:courseId/outline
/lesson/:lessonId
/study-sets
/content-picker
~~~

Migration behavior:

- \`/careers\` eventually redirects to \`/library/targets?type=career\`;
- a migrated legacy career detail resolves its mapped V2 target and redirects to \`/targets/:targetId\`;
- course, lesson, and study-set routes remain first-class indefinitely;
- old bookmarks/deep links must not break.

---

## 11. Search

Global search belongs in Library.

Context search belongs inside a context and defaults to that scope.

### 11.1 Global search entity types

~~~text
target
course
lesson
concept
study_set
~~~

### 11.2 Search indexing

Enable trigram search where available:

~~~sql
create extension if not exists pg_trgm;

create index if not exists learning_targets_title_trgm_idx
  on public.learning_targets using gin (title gin_trgm_ops);

create index if not exists knowledge_concepts_name_trgm_idx
  on public.knowledge_concepts using gin (name gin_trgm_ops);

create index if not exists target_versions_code_trgm_idx
  on public.target_versions using gin (external_code gin_trgm_ops);
~~~

Existing course/lesson title search may retain current mechanisms initially.

### 11.3 Search isolation

Inside a Learning Context:

~~~text
Search this exam...
Search this program...
Search this course...
~~~

Results must be filtered by \`ResolvedScope\`.

An explicit action may switch to "Search entire Library."

---

## 12. Progress and evidence behavior

### 12.1 Structural progress

Examples:

~~~text
Target curriculum: 42% traversed
Course: 7 / 12 lessons completed
Module: 3 / 5 lessons completed
~~~

### 12.2 Knowledge state

Tracked per canonical concept globally.

UI exposes bands, not fake precision.

### 12.3 Target readiness

Target readiness is derived from:

- target-version concept weights;
- current user concept state;
- coverage gaps;
- optional curriculum-node weights.

V2 must label this as an estimate, not as a guaranteed exam score or professional competence.

Do not ship a numerical readiness percentage until enough real evidence exists to validate the calculation. Initial UI should prefer:

~~~text
Strong
Developing
Needs reinforcement
Not yet assessed
~~~

by curriculum area.

---

## 13. Migration compatibility

### 13.1 Rule: additive first

No V2 migration may initially drop:

- \`lessons\`
- \`terms\`
- \`questions\`
- legacy \`concepts\`
- \`courses\`
- \`course_lessons\`
- \`study_sets\`
- \`career_paths\`
- \`skills\`
- \`review_items\`
- current progress tables.

### 13.2 Legacy concepts

Backfill one canonical \`knowledge_concepts\` row for every legacy \`concepts\` row.

Do **not** deduplicate automatically by text during migration.

For each legacy concept:

1. create a canonical concept;
2. create \`lesson_knowledge_concepts\`;
3. store \`legacy_concept_id\`.

Duplicate concepts can be curated later using aliases and \`merged_into_id\`.

Automatic text merging at migration time is prohibited because two similar strings are not guaranteed to represent the same knowledge atom.

### 13.3 Existing questions and terms

Do not map each question/term to every concept in its lesson.

That would create false assessment evidence.

Initial mapping options:

1. use explicit metadata when already available;
2. use curated/AI-assisted mapping requiring validation;
3. leave the item unmapped and use lesson-level legacy fallback until curated.

Newly created official content should require canonical concept mapping.

### 13.4 Career paths

Existing \`career_paths\` stay live during transition.

Backfill strategy:

1. create \`learning_targets(target_type='career')\`;
2. create one legacy target version, e.g. \`legacy-v1\`;
3. create curriculum nodes from career-path sections/courses/skills;
4. map \`career_path_courses\` to node/course links;
5. map skills through \`skill_knowledge_concepts\` as those mappings become available;
6. maintain a migration map table or deterministic metadata entry containing legacy \`career_path_id\`.

Do not delete \`user_career_paths\` until migrated contexts and history are proven.

### 13.5 Skills

Skills remain a useful competency aggregation above concepts.

They are **not** the canonical knowledge atom.

Add \`skill_knowledge_concepts\` mappings.

Existing \`user_skill_stats\` remains a legacy assessment summary and must not be silently converted into high-confidence concept knowledge.

### 13.6 Existing LearningContexts

All existing contexts remain valid.

No destructive backfill is required.

New target/concept contexts use the appended root types.

Legacy \`path\` contexts continue to resolve through the old path adapter until their target migration is complete.

### 13.7 Existing review_items

Keep \`review_items\` as the current scheduling queue.

During transition:

- if a due item's content has canonical concept mappings, filter context review by those mappings;
- otherwise use existing lesson/context logic as a legacy fallback;
- new review outcomes also write \`concept_evidence_events\` when concept mappings exist.

No historical per-review events can be reconstructed accurately from aggregate \`review_items\`; do not fabricate them.

### 13.8 Course modules

Existing courses do not need synthetic modules.

If meaningful \`section_title\` values already exist in \`course_lessons\`, an optional migration may create modules from them.

Otherwise, direct \`course_lessons\` remains valid.

---

## 14. RLS and ownership

### 14.1 Catalog tables

Public official catalog rows are readable by all app users.

User-created private targets/concepts are readable by their creator.

Client writes:

- creator may write their own non-official rows;
- official rows are service-role/admin managed;
- end users cannot alter official target/version/source data.

### 14.2 User-state tables

These are owner-only:

~~~text
learning_contexts
resume_pointers
concept_evidence_events
user_concept_state
existing review/progress tables
~~~

Policies use \`auth.uid() = user_id\`.

### 14.3 Mappings do not bypass content RLS

A curriculum node linking to a lesson does not grant access to that lesson.

The session must still satisfy the lesson/course's own read policy.

ScopeResolver filters out resources the active session cannot read.

---

## 15. Application services

Introduce these services/repositories.

~~~text
CatalogRepository
TargetRepository
ConceptRepository
CurriculumRepository
ScopeResolver
ContextSearchRepository
ConceptEvidenceService
UserConceptStateRepository
LegacyContentMappingService
~~~

### 15.1 CatalogRepository

Responsibilities:

- typed global search;
- browse targets by type/field/provider;
- browse courses/concepts/lessons;
- never apply active-context scope.

### 15.2 ScopeResolver

The sole authority for determining active-context relevance.

No screen/provider should recreate independent scope rules.

### 15.3 ConceptEvidenceService

Responsibilities:

- convert mapped review/assessment results into concept evidence;
- multiply item evidence by mapping weight;
- distinguish primary/supporting mappings;
- write evidence events;
- refresh derived \`user_concept_state\`.

### 15.4 LegacyContentMappingService

Provides temporary compatibility for content lacking canonical mappings.

Its use must be observable/telemetry-visible so legacy fallback can be retired rather than becoming permanent invisible behavior.

---

## 16. Learn / NextAction changes

The existing NextAction engine stays user-directed.

V2 changes its input from "context hierarchy guess" to:

~~~text
LearningContext
+ ResolvedScope
+ ResumePointer
+ active Focus
+ eligible activities
+ contextual due reviews
~~~

Priority:

1. resumable activity explicitly started in the current context;
2. activity under current focus;
3. next available activity from the chosen path/curriculum ordering;
4. context-complete state.

Review remains a secondary action unless the learner explicitly enters a review mode.

The engine must never replace a user's newly selected focus merely because another content item scores higher.

---

## 17. Content authoring and catalog ingestion

Manually entering every major exam/career/program through bespoke screens will not scale.

V2 therefore needs an idempotent catalog importer.

### 17.1 Target bundle

Conceptual import shape:

~~~json
{
  "target": {
    "type": "certification",
    "title": "Example Certification",
    "slug": "example-certification",
    "organization_slug": "example-provider"
  },
  "version": {
    "version_label": "2026",
    "external_code": "EX-100",
    "status": "current"
  },
  "sources": [],
  "curriculum": [],
  "concepts": [],
  "mappings": []
}
~~~

Importer requirements:

- idempotent by stable slug/external codes;
- never deletes a previous target version when a new version arrives;
- records source provenance;
- validates duplicate concept candidates but does not auto-merge uncertain matches;
- validates curriculum weights/order;
- supports dry-run output before applying.

### 17.2 Admin/curator surfaces

Not required for the first user-facing V2 release, but reserve routes:

~~~text
/admin/catalog
/admin/catalog/targets
/admin/catalog/targets/:targetId
/admin/catalog/concepts
/admin/catalog/import
~~~

These routes must be protected by an admin authorization mechanism before shipping.

---

## 18. Feature-flag and rollout strategy

V2 is introduced behind a temporary feature flag:

~~~text
LEARNING_ARCHITECTURE_V2
~~~

During rollout:

- V1 Learn/Library/Progress remain available as fallback;
- migrations are additive;
- target/concept contexts are only created when V2 is enabled;
- rollback disables V2 UI/services without deleting V2 data.

Remove the flag only after production migration and telemetry prove stability.

---

## 19. Phased implementation plan

### P0 — Schema foundation and compatibility guardrails

**Goal:** Add the V2 data model without changing user-facing behavior.

Deliver:

- migrations for fields, organizations, targets, versions, sources;
- curriculum nodes;
- canonical concepts and relations;
- mapping tables;
- learning paths;
- context-v2 columns/check constraints;
- RLS;
- Dart data models/repositories behind feature flag;
- Hive LearningContext backward-compatible serialization update.

Tests:

- all existing tests remain green;
- old Hive contexts decode unchanged;
- new enum values do not change legacy enum indices;
- V1 routes/screens behave identically.

**Highest risk:** Hive/context migration and RLS.

### P1 — Canonical concept backfill

**Goal:** Give existing lesson concepts canonical identities without breaking legacy content.

Deliver:

- backfill one canonical concept per legacy concept;
- \`lesson_knowledge_concepts\` mappings;
- no automatic dedupe;
- curator tooling for merge/alias operations;
- concept repository and concept detail read path.

Tests:

- every legacy concept maps to exactly one canonical concept;
- rerunning migration is idempotent;
- no lesson content is deleted or reordered.

### P2 — ScopeResolver and LearningContext V2

**Goal:** Make context scope the authoritative isolation boundary.

Deliver:

- ScopeResolver;
- target/concept root support;
- context focus fields;
- scope presets/config;
- contextual due-review filtering;
- compatibility adapter for legacy path/course/lesson/studySet contexts.

Tests:

- unrelated concepts never enter resolved core/supporting sets;
- prerequisites enter only under configured modes/depth;
- context review excludes unrelated due items;
- legacy contexts resolve as before.

### P3 — Library V2

**Goal:** Let users directly choose what they actually want.

Deliver:

- typed global search;
- target browse by type;
- target detail;
- start-learning flow;
- course/concept/lesson direct start;
- "Your Learning" remains concise;
- no global catalog content leaks into Learn.

Tests:

- user can start target, course, lesson, concept, study set;
- target/version selection creates correct context;
- search type labels are correct;
- no-context zero state reaches a startable item quickly.

### P4 — Learn V2: Context + Focus

**Goal:** Present one scoped workspace.

Deliver:

- current context switcher;
- Focus orientation;
- Continue action;
- Outline / Topics / Practice quick actions;
- contextual review;
- generic context outline screen;
- scoped search.

Tests:

- switching context swaps all scoped data;
- switching focus does not create a new context;
- Direct Access Rule remains satisfied;
- a context with 100 unrelated global lessons shows none of them unless in scope.

### P5 — Evidence and Progress V2

**Goal:** Reuse learning evidence globally while keeping context reporting isolated.

Deliver:

- concept evidence events;
- question/term/assessment mappings write weighted evidence;
- derived user concept state;
- Progress "This Context" / "All Knowledge";
- context-area retrieval bands.

Tests:

- the same concept learned under one target contributes to another target;
- global knowledge changes without polluting the second target's Learn feed;
- supporting concept weights do not equal primary weights;
- completion remains separate from knowledge state.

### P6 — Course modules and richer content mapping

Deliver:

- optional course modules;
- module outline UI;
- direct course-lessons remain supported;
- question/term concept-mapping authoring;
- explicit flashcard model only if arbitrary front/back cards are now needed.

### P7 — Career migration and unified target catalog

Deliver:

- migrate public legacy career paths to career targets;
- redirects from legacy career routes;
- preserve user enrollment/history;
- map skills to concepts;
- retire duplicated career discovery UI after migration verification.

### P8 — Official catalog population

Populate high-value target families with source/version discipline:

- Florida licensing/professional exams;
- CompTIA;
- Cisco;
- NCLEX and other healthcare credentials;
- Bar/licensure structures;
- major academic programs;
- selected standardized/K–12 frameworks.

Each imported target version must include provenance and a review date.

Do not scale catalog quantity faster than source/version maintenance can support.

### P9 — Optional later intelligence

Only after enough real usage/evidence:

- validated target-readiness scoring;
- smarter prerequisite suggestions;
- adaptive practice selection;
- concept deduplication assistance;
- automated target-version change detection.

These are not prerequisites for V2.

---

## 20. Acceptance tests

The following are product-level requirements, not suggestions.

### A. Scope isolation

Given:

- Concept X is in CCNA and Network+.
- Concept Y exists globally but is unrelated to CCNA.
- The active context is CCNA.

Then:

- X may appear;
- Y must not appear in Learn, scoped search, or contextual review;
- Y remains discoverable in Library.

### B. Knowledge transfer

If Concept X has retrieval evidence from Network+ and is also required by CCNA:

- CCNA Progress may acknowledge the existing evidence;
- CCNA Learn remains scoped to CCNA;
- the system does not force the learner to repeat completed material merely because it came from another context.

### C. Version isolation

If an exam target has versions V1 and V2:

- an existing V1 context stays pinned to V1 unless the learner explicitly upgrades;
- creating V2 does not mutate V1 curriculum;
- historical progress remains interpretable.

### D. Direct roots

The user can create and use valid contexts rooted at:

~~~text
target
path
course
module
lesson
studySet
concept
~~~

### E. Legacy continuity

After V2 migrations:

- existing lessons open;
- existing courses open;
- existing study sets open;
- existing review queue remains;
- existing contexts decode;
- old deep links do not 404.

### F. Context review

If 50 items are globally due but only 6 intersect the active scope:

- Learn says 6 ready for review;
- it does not display 50 as current-context debt.

### G. Academic-program scoping

A program with major requirements and general education supports a "major only" context where excluded general-education nodes never appear in Learn.

### H. Single-concept learning

A learner can start one concept without enrolling in a course, target, or career.

---

## 21. Explicit non-goals for the first V2 release

Do not block V2 on:

- perfect concept deduplication;
- a universal \`learning_items\` table;
- AI choosing the user's learning target;
- validated exam-pass probability;
- automatic ingestion of every exam/degree on earth;
- replacing existing spaced repetition;
- deleting legacy career/skill tables;
- forcing every course to have modules;
- forcing every question/term to be mapped before legacy content remains usable.

---

## 22. Migration file plan

Recommended migration sequence:

~~~text
supabase/migrations/
  20260925010000_learning_v2_catalog.sql
  20260925011000_learning_v2_knowledge_graph.sql
  20260925012000_learning_v2_content_mappings.sql
  20260925013000_learning_context_v2.sql
  20260925014000_learning_v2_evidence.sql
  20260925015000_learning_v2_rls.sql
~~~

Backfills should be separate, idempotent scripts so schema deployment and content migration can be rolled out independently.

---

## 23. Change-control rule

This document becomes the V2 implementation baseline once approved.

A locked V2 decision changes only because of:

1. user evidence;
2. implementation evidence;
3. accessibility/security/safety requirements;
4. demonstrated factual or architectural error.

"Another model suggested a different hierarchy" is not by itself grounds for redesign.

---

## 24. Final architecture summary

~~~text
DISCOVERY
LearningField
     │
     ├──────────────┐
     ▼              ▼
LearningTarget    Courses / Concepts / Lessons
     │
TargetVersion
     │
CurriculumNode
     │
     ├────────────── Courses / Lessons
     │
     ▼
KnowledgeConcept  ←──────────── global canonical knowledge
     ▲   ▲   ▲
     │   │   │
 Question Term Lesson / Assessment / Skill
     │
User evidence
     │
UserConceptState

USER EXPERIENCE
LearningContext
     │
     ├─ root = Target / Path / Course / Module / Lesson / Concept / StudySet
     ├─ exact target version when applicable
     ├─ scope settings
     └─ active Focus
              │
              ▼
         ScopeResolver
              │
     ┌────────┼─────────┐
     ▼        ▼         ▼
   Learn    Review    Context Progress

Library remains global.
All Knowledge remains global.
Learn remains scoped.
~~~

**Canonical principle:** **Knowledge is global. Learning is scoped.**
