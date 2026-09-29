# Canonical Taxonomy Architecture: Dual-Layer Learning Ontology, External Classifications (CIP / SOC / O*NET), and Labor Market Crosswalks

**Document Status:** Final Architecture Baseline (Locked for Implementation) — v2.4 Certified Specification  
**Target File:** `CANONICAL_TAXONOMY_ARCHITECTURE.md` (Repository Root)  
**Applies To:** Learning Architecture v2 (`learning_targets`, `target_versions`, `fields`, `courses`, `knowledge_concepts`, `occupation_nodes`)  
**Version:** 2.4 — Implementation-Locked Baseline (Certified Production Ready)  
**Author:** Antigravity Engineering & System Architecture  

---

## 1. Executive Summary & Core Philosophical Paradigm

### 1.1 The True Dual-Layer Architecture: Decoupling Internal Ontology from External Classifications
The core conceptual foundation of this architecture is the **strict separation between internal ontology and external classification systems**:

> **Official government taxonomies (CIP, SOC, ISCED, NAICS) are authoritative external classifications that seed and map to LearningApp; they do NOT define the immutable identity or permanent schema of our internal ontology.**

If external codes are embedded directly as the primary identity of internal `fields`, then when a decennial update occurs (such as CIP 2030), the platform is forced into an impossible dilemma: either duplicate internal fields (`Field A: Computer Science (CIP 2020)` vs `Field B: Computer Science (CIP 2030)`), or perform destructive updates that mutate existing learner progress and course links.

To permanently solve this, LearningApp implements a **True Dual-Layer Model**:
1. **Internal Canonical Plane:** Our internal `fields` have permanent, immutable UUIDs and their own coherent browsing hierarchy.
2. **External Classification Plane:** Dedicated `external_classification_nodes` store external taxonomies (CIP 2020, CIP 2030, ISCED-F 2013) with full hierarchical referential integrity (`parent_id`).
3. **Crosswalk Layer:** The `field_external_classifications` junction links our permanent internal fields to one or more external classification nodes without altering internal identity.
4. **Labor Crosswalk Layer:** The official NCES/BLS crosswalk is stored at the external layer (`external_classification_occupation_mappings`) linking CIP nodes directly to SOC occupations. An application view (`v_field_occupation_mappings`) exposes these relationships to internal fields transparently.

```
                 INTERNAL ONTOLOGY                           EXTERNAL CLASSIFICATIONS
             ┌─────────────────────────┐                    ┌─────────────────────────┐
             │    LearningApp Field    │                    │  external_class_nodes   │
             │   (Permanent UUID)      │◄───(many-to-many)─►│ (CIP 2020/2030, parent_id)
             └────────────┬────────────┘                    └────────────┬────────────┘
                          │                                              │ (Official Crosswalk)
                          ├──────────────────────────────┐               ▼
                          ▼                              ▼  ┌─────────────────────────┐
             ┌─────────────────────────┐    ┌──────────┐ │  │ ext_class_occ_mappings │
             │     CatalogCluster      │    │ Targets  │ │  │ (CIP Code ↔ SOC Code)   │
             │   (Presentation Layer)  │    │ & Courses│ │  └────────────┬────────────┘
             └─────────────────────────┘    └──────────┘ │               │
                                                         │               ▼
                                            ┌────────────┴────────┐ ┌─────────────────────────┐
                                            │ v_field_occ_mappings│◄┤     occupation_nodes    │
                                            │  (Application View) │ │ (Hierarchical 5-Tiers)  │
                                            └─────────────────────┘ └────────────┬────────────┘
                                                                                 │
                                                                                 ▼
                                                                    ┌─────────────────────────┐
                                                                    │  occupation_industries  │
                                                                    │  (BLS Matrix & NAICS)   │
                                                                    └─────────────────────────┘
```

### 1.2 Core Standards Reference Matrix

| Domain | Standard / Authority | Internal Entity | Role & Ingestion Policy |
|---|---|---|---|
| **Fields of Study** | **NCES CIP 2020** (US Dept of Education) | `fields` $\longleftrightarrow$ `external_classification_nodes` | Initial canonical seed (~48 series, ~450 groups, ~2,400 programs). Internal UUIDs remain permanent. |
| **International Fields** | **UNESCO ISCED-F 2013** | `external_classification_nodes` | Many-to-many external classification crosswalk (11 broad, 29 narrow, 80 detailed fields). |
| **Occupations & Labor** | **BLS SOC 2018 + O\*NET-SOC 2019** | `occupation_nodes` | Independent 5-tier labor taxonomy (Major $\rightarrow$ Minor $\rightarrow$ Broad $\rightarrow$ Detailed $\rightarrow$ O\*NET Extension). |
| **Field ↔ Career Relations** | **NCES / BLS Official Crosswalk** | `external_classification_occupation_mappings` | **Qualitative, content-based alignment** linking CIP nodes to SOC nodes with required release provenance. Queried via view `v_field_occupation_mappings`. |
| **Labor Analytics & Fit** | **BLS Projections & Outcomes** | `field_occupation_metrics` | Generic, typed analytical metrics with explicit geography, population, methodology, and fail-closed privacy safeguards. |
| **Industries** | **US Census NAICS 2022 + BLS Matrix** | `occupation_industries` | Many-to-many matrix capturing actual employment concentrations by industry sector. |
| **Non-Institutional Topics** | **LearningApp Native Fields** | `fields` (`field_kind = 'native_field'`) | Native fields with semantic lateral relations, NOT forced sub-children of CIP codes. |
| **K–12 Curriculum & Benchmarks**| **State Standards, NGSS, Common Core, AP** | `learning_targets` (`target_type = 'curriculum_standard'`) | Specific academic benchmarks modeled as formal targets, not artificial CIP field nodes. |

---

## 2. Ontological Separation: The Six Independent Planes

To eliminate cross-domain leakage, the architecture strictly segregates knowledge into six distinct planes:

1. **Instructional Field Plane (`fields`):** Bodies of human inquiry and knowledge disciplines (e.g., *Computer Science*, *Biochemistry*, *Organic Horticulture*, *Ancient History*).
2. **Occupational Plane (`occupation_nodes`):** Roles in the economy defined by work activities, tools, and labor outcomes (e.g., *Software Developers*, *Data Scientists*, *Electricians*).
3. **Target Plane (`learning_targets`):** Discrete, purposeful milestones a learner pursues (e.g., *B.S. in Computer Science*, *CompTIA Security+*, *Florida 8th Grade Mathematics*, *USMLE Step 1*).
4. **Teaching Plane (`courses`, `modules`, `lessons`):** Sequenced instructional delivery vehicles designed to teach a syllabus.
5. **Knowledge Concept Plane (`knowledge_concepts`):** Atomic, testable units of understanding (e.g., *Quicksort Partitioning*, *Photosystem II*, *The Fourteenth Amendment*).
6. **Presentation Plane (`catalog_clusters`):** High-level visual clusters in the UI (e.g., "Computing & Tech", "Health & Medicine") decoupled from underlying relational keys.

---

## 3. The Field Taxonomy & CIP 2020 Ingestion

### 3.1 All 48 CIP 2-Digit Series (No Manual Hardcoding)
CIP 2020 contains **48 primary two-digit series**, not 47. Crucially, the non-degree series provide official coverage for remedial education, life skills, recreational crafts, and secondary diplomas:
- `01`: Agriculture, Agriculture Operations, and Related Sciences
- `03`: Natural Resources and Conservation
- `04`: Architecture and Related Services
- `05`: Area, Ethnic, Cultural, Gender, and Group Studies
- `09`: Communication, Journalism, and Related Programs
- `10`: Communications Technologies/Technicians and Support Services
- `11`: Computer and Information Sciences and Support Services
- `12`: Culinary, Entertainment, and Personal Services
- `13`: Education
- `14`: Engineering
- `15`: Engineering/Engineering-Related Technologies/Technicians
- `16`: Foreign Languages, Literatures, and Linguistics
- `19`: Family and Consumer Sciences/Human Sciences
- `22`: Legal Professions and Studies
- `23`: English Language and Literature/Letters
- `24`: Liberal Arts and Sciences, General Studies and Humanities
- `25`: Library Science
- `26`: Biological and Biomedical Sciences
- `27`: Mathematics and Statistics
- `28`: Military Science, Leadership and Operational Art
- `29`: Military Technologies and Applied Sciences
- `30`: Multi/Interdisciplinary Studies
- `31`: Parks, Recreation, Leisure, Fitness, and Kinesiology
- `32`: Basic Skills and Developmental/Remedial Education *(essential for foundational learning)*
- `33`: Citizenship Activities
- `34`: Health-Related Knowledge and Skills
- `35`: Interpersonal and Social Skills
- `36`: Leisure and Recreational Activities *(hobbies, sports, crafts)*
- `37`: Personal Awareness and Self-Improvement
- `38`: Philosophy and Religious Studies
- `39`: Theology and Religious Vocations
- `40`: Physical Sciences
- `41`: Science Technologies/Technicians
- `42`: Psychology
- `43`: Homeland Security, Law Enforcement, Firefighting and Related Protective Services
- `44`: Public Administration and Social Service Professions
- `45`: Social Sciences
- `46`: Construction Trades
- `47`: Mechanic and Repair Technologies/Technicians
- `48`: Precision Production
- `49`: Transportation and Materials Moving
- `50`: Visual and Performing Arts
- `51`: Health Professions and Related Programs
- `52`: Business, Management, Marketing, and Related Support Services
- `53`: High School/Secondary Diplomas and Certificates *(foundational K-12 completion)*
- `54`: History
- `60`: Health Professions Residency/Fellowship Programs
- `61`: Medical Residency/Fellowship Programs

**Architectural Rule:** The application code and database migration scripts must **never hardcode** the series list. The ingestion engine reads `CIPCode2020.csv` directly and dynamically materializes all 48 series.

### 3.2 Dual-Layer Model Implementation (Bootstrap Once, Map Permanently)
1. **Bootstrap Phase (CIP 2020):**
   - Ingests all 48 series, groups, and programs into `external_classification_nodes`, resolving parent-child links into `parent_id`.
   - Seeds initial `fields` rows with clean slugs and names. Each generated `fields` row receives a permanent UUID.
   - Inserts `exact_match` rows into `field_external_classifications`.
2. **Future Editions Phase (CIP 2030+):**
   - Ingests CIP 2030 into `external_classification_nodes` with `version = '2030'`.
   - Links the new classification nodes to existing `fields` rows via `field_external_classifications`.
   - Populates `taxonomy_node_lineage` using the official NCES CIP 2020 $\rightarrow$ 2030 change crosswalk.
   - **Discipline Evolution Rule:** A new taxonomy release never creates duplicate internal Fields merely because an external classification code changed. New internal Fields are created only when a new classification edition represents a genuinely distinct, emerging learning domain that the internal ontology should model separately (e.g. true discipline splits). For renames, code moves, and cosmetic reclassifications, the existing internal Field identity is preserved and mapped to the new external node.

### 3.3 Decennial Lineage Tracking with Valid Null Endpoints and Idempotency
When external agencies publish edition changes, official statuses include deletions (which have no `to_code`) and new introductions (which have no `from_code`). Duplicate protection is enforced via an expression index:

```sql
create table if not exists public.taxonomy_node_lineage (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,       -- 'cip', 'soc', etc.
  from_version text not null,
  from_code text,
  to_version text not null,
  to_code text,
  transition_type text not null check (
    transition_type in (
      'unchanged',
      'renamed',
      'split_into',
      'merged_into',
      'moved_to',
      'deleted',
      'newly_introduced'
    )
  ),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (
    (transition_type = 'deleted' and from_code is not null and to_code is null) or
    (transition_type = 'newly_introduced' and from_code is null and to_code is not null) or
    (transition_type not in ('deleted', 'newly_introduced') and from_code is not null and to_code is not null)
  )
);

create unique index if not exists taxonomy_lineage_unique_idx
  on public.taxonomy_node_lineage (
    source_system,
    from_version,
    coalesce(from_code, ''),
    to_version,
    coalesce(to_code, ''),
    transition_type
  );
```

### 3.4 Non-Institutional Topics & Interdisciplinary Fields
In real life:
- **Bioinformatics** belongs equally to Computer Science, Molecular Biology, and Statistics.
- **Prompt Engineering**, **Drone Videography**, **Parenting**, and **Chess Strategy** are valid learning disciplines that do not have clean 1-to-1 institutional homes.

**The Solution:**
1. **Primary Navigation Anchor:** Every native `field` has an optional `parent_id` providing a sensible default home in the browsing tree.
2. **Semantic Lateral Links:** Interdisciplinary bonds are recorded in `field_relations`.
3. **Relation Symmetry Rules:**
   - **Directional relations:** `interdisciplinary_parent`, `applied_domain_of`.
   - **Symmetric relations:** `shares_foundations`, `cross_disciplinary_partner`. Enforced via canonical ordering (`from_field_id < to_field_id`) to prevent duplicate inverse rows.

---

## 4. Careers & Occupations: BLS SOC 2018 + O*NET

### 4.1 Strict Hierarchy for Occupation Nodes
BLS Standard Occupational Classification (SOC) defines 4 discrete levels, while O\*NET extends the detailed level with granular specialty codes. The hierarchy is cleanly represented via a self-referential tree:

```
Level 1: Major Group (2 digits, e.g., '15-0000: Computer and Mathematical Occupations')
  └── Level 2: Minor Group (4 digits, e.g., '15-1200: Computer Occupations')
        └── Level 3: Broad Occupation (5 digits, e.g., '15-1250: Software and Web Developers...')
              └── Level 4: Detailed Occupation (6 digits, e.g., '15-1252: Software Developers')
                    └── Level 5: O*NET Extension (8 digits, e.g., '15-1252.00', '15-1253.00')
```

### 4.2 Distinguishing Taxonomy Version from Data Release
O\*NET has two distinct version dimensions:
1. **Taxonomy Structure:** `O*NET-SOC 2019` (the structural classification).
2. **Database Content Release:** e.g., `O*NET 31.0` (August 2026), updated quarterly with task lists, salary statistics, and job zone descriptions.

**Ingestion Taxonomy Identity Rule:**
- **SOC major/minor/broad/detailed nodes:**
  `taxonomy_system = 'bls_soc'`, `taxonomy_version = 'soc_2018'`, `data_release_version = null`.
- **O\*NET extension nodes (`.XX`):**
  `taxonomy_system = 'onet_soc'`, `taxonomy_version = '2019'`, `data_release_version = 'onet_31_0'`.

This prevents base SOC government groups from falsely claiming O*NET 31.0 provenance while ensuring O*NET extensions carry accurate release stamps.

---

## 5. Educational-to-Labor Market Crosswalks: Truth in Data

### 5.1 Official Crosswalk at the External Layer
The official NCES / BLS CIP–SOC Crosswalk maps **CIP classification nodes to SOC occupation nodes**. It does not map internal LearningApp fields directly.

Therefore:
1. **Raw Federal Crosswalk (`external_classification_occupation_mappings`):** Anchored directly to `external_classification_nodes.id` and `occupation_nodes.id` with mandatory release provenance (`source_release_id NOT NULL`). Unweighted, qualitative binary mapping (`mapping_kind = 'official_qualitative'`).
2. **Application View (`v_field_occupation_mappings`):** Transparently joins internal fields through `field_external_classifications` to expose related occupations to the UI.
3. **Analytical Metrics Layer (`field_occupation_metrics`):** A typed, generic metrics table that stores empirical outcome statistics only when supported by credible sources.

### 5.2 Metrics Attribution, Full Dimensionality, & Fail-Closed Privacy
- **Full Dimensional Uniqueness:** To allow distinct geographic (e.g. US national vs. Florida state), population cohorts (e.g. all workers vs. recent bachelor's graduates), and source releases to coexist without collisions, the unique constraint incorporates:
  ```sql
  unique nulls not distinct (
    field_id,
    occupation_id,
    metric_type,
    geography,
    population,
    data_year,
    methodology_version,
    source_release_id
  )
  ```
  PostgreSQL 15+ `NULLS NOT DISTINCT` treats `NULL` `source_release_id` values (such as internally computed app analytics) as identical, guaranteeing that learner statistics cannot duplicate while permitting multi-release official statistics to coexist. A fallback expression index using `coalesce(source_release_id, '00000000-0000-0000-0000-000000000000'::uuid)` is also generated.
- **Separation of Publication and Privacy:**
  - `is_published boolean not null default false` controls overall availability.
  - `privacy_threshold_met boolean not null default false` represents statistical privacy validation ($N \ge 50$ distinct learners).
- **Fail-Closed Privacy Safeguard:** A database check constraint enforces that `app_user_transition_share` metrics must have `sample_size >= 50` and `privacy_threshold_met = true`.
- **RLS Policy:**
  ```sql
  create policy "public_read_field_occ_metrics" on public.field_occupation_metrics for select using (
    is_published = true and (
      metric_type <> 'app_user_transition_share' or privacy_threshold_met = true
    )
  );
  ```
  Government metrics become visible when `is_published = true`, while learner-derived analytics strictly require both publication approval AND statistical threshold satisfaction.
- **Derived Alignment:** Metrics of type `derived_education_alignment_score` are explicitly documented as internal calculations using BLS educational requirement inputs, never misrepresented as official BLS scores.
- **Metric Bounds:** `check (metric_value >= 0.0 and metric_value <= 1.0)`.

---

## 6. Many-to-Many Relationships Across Targets, Concepts, and Industries

### 6.1 Learning Targets Span Multiple Fields
- A single `field_id` on `learning_targets` is retained strictly as the **primary browse placement** (the single default category for navigation).
- The complete multidisciplinary membership is recorded in `learning_target_fields (target_id, field_id, role, display_order)`.
- **Target Readiness Boundary Rule:** Field membership roles **MUST NEVER** be used to calculate a learner's target readiness score. Readiness strictly derives from `TargetVersion -> CurriculumNode -> Concept weights`.

### 6.2 Knowledge Concepts Span Multiple Fields
Fundamental cognitive concepts do not exist in academic isolation:
- **Bayes' Theorem** is taught in Probability (Math), Machine Learning (CS), Biostatistics (Biology), and Diagnostic Reasoning (Medicine).
- Recorded in `concept_fields (concept_id, field_id, relationship)`.

### 6.3 K–12 and Academic Standards are Curriculum Targets
Grade-level standards (e.g. *Florida B.E.S.T. 7th Grade Math*, *Next Generation Science Standards - High School Chemistry*, *AP US History*) are modeled as **`learning_targets`** with `target_type = 'curriculum_standard'` and linked to underlying fields via `learning_target_fields`. They are **never forced as artificial nodes into the CIP Field tree**.

### 6.4 Occupations ↔ Industries (BLS National Employment Matrix)
Rather than asserting that occupations belong to industries in a false tree, we model the BLS National Employment Matrix as a many-to-many relationship with range validation:
```sql
create table if not exists public.occupation_industries (
  occupation_id uuid not null references public.occupation_nodes(id) on delete cascade,
  naics_code text not null,
  industry_title text not null,
  employment_count integer check (employment_count is null or employment_count >= 0),
  industry_share numeric(5,4) check (industry_share is null or (industry_share >= 0.0 and industry_share <= 1.0)),
  data_year integer not null,
  source_release_id uuid references public.taxonomy_source_releases(id) on delete set null,
  primary key (occupation_id, naics_code, data_year)
);
```

---

## 7. Search, Aliasing, & Linguistic Extensibility

The full-text search index incorporates:
1. Canonical Name (`A` weight)
2. Aliases, trade acronyms, and abbreviations e.g. *"CS"*, *"HVAC"*, *"RN"*, *"cyber"*, *"AI"*, *"ML"* (`A` weight)
3. Official illustrative examples and cross-references (`B` weight)
4. Description text (`C` weight)

---

## 8. Presentation Layer: Catalog Clusters

To navigate 2,400+ nodes without cognitive overload, the UI displays 12 visual clusters strictly isolated in a presentation-layer model (`catalog_clusters` and `catalog_cluster_fields`):
1. 💻 **Computing & Information Technology**
2. 🏥 **Health Professions & Medicine**
3. ⚙️ **Engineering & Applied Technology**
4. 📈 **Business, Finance & Management**
5. 🔬 **Physical & Biological Sciences**
6. 📐 **Mathematics, Statistics & Data**
7. ⚖️ **Law, Public Policy & Security**
8. 🎨 **Visual Arts, Performing Arts & Design**
9. 🌍 **Social Sciences, Psychology & Education**
10. 📚 **Humanities, Languages & Literature**
11. 🔨 **Skilled Construction & Mechanical Trades**
12. 🌾 **Agriculture, Natural Resources & Environment**

---

## 9. Complete Consolidated DDL Specification

```sql
-- ============================================================================
-- Canonical Taxonomy Architecture v2.3 Consolidated Schema
-- ============================================================================

-- 0. TAXONOMY SOURCE RELEASES & ARTIFACTS (Provenance, Checksums & Licensing)
create table if not exists public.taxonomy_source_releases (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,        -- 'nces_cip', 'bls_soc', 'onet', 'unesco_isced', 'bls_matrix'
  release_version text not null,      -- '2020', '2018', 'onet_31_0'
  release_date date,
  retrieved_at timestamptz not null default now(),
  source_url text,
  license_name text not null,         -- 'US_Public_Domain', 'CC_BY_4_0', etc.
  license_url text,
  attribution_text text,
  metadata jsonb not null default '{}'::jsonb,
  unique (source_system, release_version)
);

create table if not exists public.taxonomy_source_artifacts (
  id uuid primary key default gen_random_uuid(),
  source_release_id uuid not null references public.taxonomy_source_releases(id) on delete cascade,
  artifact_name text not null,        -- e.g. 'Occupation Data.txt', 'CIPCode2020.csv'
  source_url text,
  sha256 text,
  file_size_bytes bigint,
  retrieved_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (source_release_id, artifact_name)
);

-- 1. EXTEND INTERNAL FIELDS TABLE
-- Clean field_kind, no illegal defaults, explicit population required
alter table public.fields
  add column if not exists field_kind text not null default 'native_field'
    check (field_kind in ('broad_field', 'subfield', 'program_classification', 'native_field')),
  add column if not exists aliases text[] not null default '{}',
  add column if not exists cross_references text[] not null default '{}',
  add column if not exists illustrative_examples text[] not null default '{}',
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create index if not exists fields_kind_idx on public.fields(field_kind, sort_order);

-- Full-Text Search tsvector column, trigger, and GIN index
alter table public.fields
  add column if not exists search_tsv tsvector;

create or replace function public.fields_generate_search_tsv()
returns trigger as $$
begin
  new.search_tsv :=
    setweight(to_tsvector('english', coalesce(new.name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(array_to_string(new.aliases, ' '), '')), 'A') ||
    setweight(to_tsvector('english', coalesce(array_to_string(new.cross_references, ' '), '')), 'B') ||
    setweight(to_tsvector('english', coalesce(array_to_string(new.illustrative_examples, ' '), '')), 'B') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'C');
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_fields_search_tsv on public.fields;
create trigger trg_fields_search_tsv
  before insert or update on public.fields
  for each row execute function public.fields_generate_search_tsv();

create index if not exists fields_search_tsv_idx
  on public.fields using gin(search_tsv);

-- 2. EXTERNAL CLASSIFICATION NODES (Authoritative Standard Records with parent_id FK)
create table if not exists public.external_classification_nodes (
  id uuid primary key default gen_random_uuid(),
  source_release_id uuid not null references public.taxonomy_source_releases(id) on delete cascade,
  parent_id uuid references public.external_classification_nodes(id) on delete set null,
  system text not null,               -- 'cip', 'isced_f', etc.
  version text not null,              -- '2020', '2030', '2013'
  code text not null,                 -- '11', '11.07', '11.0701'
  source_parent_code text,            -- e.g. '11', '11.07' from raw source file
  level_code text not null,           -- e.g. 'series', 'group', 'program', 'broad', 'narrow', 'detailed'
  level_depth integer not null default 1 check (level_depth between 1 and 10),
  title text not null,
  definition text,
  cross_references text[] not null default '{}',
  illustrative_examples text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (system, version, code)
);

create index if not exists ext_class_nodes_code_idx
  on public.external_classification_nodes(system, version, code);
create index if not exists ext_class_nodes_parent_idx
  on public.external_classification_nodes(parent_id);

-- 3. FIELD EXTERNAL CLASSIFICATIONS (Many-to-Many Linking Internal to External)
create table if not exists public.field_external_classifications (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  classification_node_id uuid not null references public.external_classification_nodes(id) on delete cascade,
  mapping_type text not null check (
    mapping_type in ('exact_match', 'broad_match', 'narrow_match', 'interdisciplinary_related')
  ),
  notes text,
  created_at timestamptz not null default now(),
  unique (field_id, classification_node_id)
);

create index if not exists field_ext_class_field_idx
  on public.field_external_classifications(field_id);

-- 4. TAXONOMY NODE LINEAGE (Decennial Version Transitions with Idempotency)
create table if not exists public.taxonomy_node_lineage (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  from_version text not null,
  from_code text,
  to_version text not null,
  to_code text,
  transition_type text not null check (
    transition_type in (
      'unchanged',
      'renamed',
      'split_into',
      'merged_into',
      'moved_to',
      'deleted',
      'newly_introduced'
    )
  ),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (
    (transition_type = 'deleted' and from_code is not null and to_code is null) or
    (transition_type = 'newly_introduced' and from_code is null and to_code is not null) or
    (transition_type not in ('deleted', 'newly_introduced') and from_code is not null and to_code is not null)
  )
);

create unique index if not exists taxonomy_lineage_unique_idx
  on public.taxonomy_node_lineage (
    source_system,
    from_version,
    coalesce(from_code, ''),
    to_version,
    coalesce(to_code, ''),
    transition_type
  );

-- 5. LATERAL FIELD RELATIONS (With Symmetry Guarantees)
create table if not exists public.field_relations (
  from_field_id uuid not null references public.fields(id) on delete cascade,
  to_field_id uuid not null references public.fields(id) on delete cascade,
  relation_type text not null check (
    relation_type in (
      'interdisciplinary_parent',
      'applied_domain_of',
      'shares_foundations',
      'cross_disciplinary_partner'
    )
  ),
  notes text,
  primary key (from_field_id, to_field_id, relation_type),
  check (from_field_id <> to_field_id),
  check (
    relation_type not in ('shares_foundations', 'cross_disciplinary_partner')
    or from_field_id < to_field_id
  )
);

create or replace view public.v_field_relations_bidirectional as
  select from_field_id, to_field_id, relation_type, notes from public.field_relations
  union all
  select to_field_id as from_field_id, from_field_id as to_field_id, relation_type, notes
  from public.field_relations
  where relation_type in ('shares_foundations', 'cross_disciplinary_partner');

-- 6. OCCUPATION NODES (5-Tier Hierarchical Labor Taxonomy)
create table if not exists public.occupation_nodes (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.occupation_nodes(id) on delete set null,
  code text not null,
  title text not null,
  description text,
  level text not null check (
    level in ('major_group', 'minor_group', 'broad_occupation', 'detailed_occupation', 'onet_extension')
  ),
  taxonomy_system text not null,       -- 'bls_soc' or 'onet_soc'
  taxonomy_version text not null,      -- 'soc_2018' or '2019'
  data_release_version text,          -- Null for base SOC; 'onet_31_0' for O*NET extensions
  job_zone integer check (job_zone between 1 and 5),
  source_release_id uuid references public.taxonomy_source_releases(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (taxonomy_system, taxonomy_version, code),
  check (
    (level = 'onet_extension' and taxonomy_system = 'onet_soc') or
    (level <> 'onet_extension' and taxonomy_system = 'bls_soc')
  )
);

create index if not exists occupation_nodes_parent_idx on public.occupation_nodes(parent_id);
create index if not exists occupation_nodes_level_idx on public.occupation_nodes(level);

-- 7. EXTERNAL CLASSIFICATION OCCUPATION MAPPINGS (Raw Federal CIP-SOC Crosswalk)
-- Non-null provenance guarantees airtight idempotency
create table if not exists public.external_classification_occupation_mappings (
  id uuid primary key default gen_random_uuid(),
  classification_node_id uuid not null references public.external_classification_nodes(id) on delete cascade,
  occupation_id uuid not null references public.occupation_nodes(id) on delete cascade,
  source_release_id uuid not null references public.taxonomy_source_releases(id) on delete cascade,
  mapping_source text not null default 'nces_bls_crosswalk_2020',
  mapping_version text not null default '2020',
  mapping_kind text not null default 'official_qualitative' check (
    mapping_kind in ('official_qualitative', 'advisory_board', 'curated_extension')
  ),
  source_notes text,
  created_at timestamptz not null default now(),
  unique (classification_node_id, occupation_id, source_release_id)
);

-- Convenient Application View joining internal Fields to related Occupations
create or replace view public.v_field_occupation_mappings as
  select distinct
    fec.field_id,
    ecom.occupation_id,
    ecn.system as classification_system,
    ecn.version as classification_version,
    ecn.code as classification_code,
    ocn.code as occupation_code,
    ocn.title as occupation_title,
    ecom.mapping_kind,
    ecom.source_release_id
  from public.external_classification_occupation_mappings ecom
  join public.external_classification_nodes ecn on ecn.id = ecom.classification_node_id
  join public.field_external_classifications fec on fec.classification_node_id = ecn.id
  join public.occupation_nodes ocn on ocn.id = ecom.occupation_id;

-- 8. FIELD OCCUPATION METRICS (Typed Labor Market Analytics with Strict Dimensionality & Fail-Closed Privacy)
create table if not exists public.field_occupation_metrics (
  id uuid primary key default gen_random_uuid(),
  field_id uuid not null references public.fields(id) on delete cascade,
  occupation_id uuid not null references public.occupation_nodes(id) on delete cascade,
  metric_type text not null check (
    metric_type in (
      'observed_worker_field_share',
      'graduate_transition_share',
      'derived_education_alignment_score',
      'app_user_transition_share'
    )
  ),
  metric_value numeric(8,5) not null check (metric_value >= 0.0 and metric_value <= 1.0),
  population text not null default 'all_applicable',
  geography text not null default 'US',
  data_year integer not null,
  source_release_id uuid references public.taxonomy_source_releases(id) on delete set null,
  methodology_version text not null default 'source_native_v1',
  sample_size integer check (sample_size is null or sample_size >= 0),
  is_published boolean not null default false,          -- Controlled publication
  privacy_threshold_met boolean not null default false, -- Fail-closed
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique nulls not distinct (
    field_id,
    occupation_id,
    metric_type,
    geography,
    population,
    data_year,
    methodology_version,
    source_release_id
  ),
  -- Fail-closed check: app user transitions require minimum sample size and verified threshold
  check (
    (metric_type <> 'app_user_transition_share') or
    (sample_size is not null and sample_size >= 50 and privacy_threshold_met = true)
  )
);

-- Fallback expression index for query planner optimization and universal uniqueness
create unique index if not exists field_occ_metrics_unique_idx
  on public.field_occupation_metrics (
    field_id,
    occupation_id,
    metric_type,
    geography,
    population,
    data_year,
    methodology_version,
    coalesce(source_release_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

create index if not exists field_occ_metrics_field_idx on public.field_occupation_metrics(field_id);
create index if not exists field_occ_metrics_occ_idx on public.field_occupation_metrics(occupation_id);

-- 9. OCCUPATION INDUSTRIES (BLS National Employment Matrix)
create table if not exists public.occupation_industries (
  occupation_id uuid not null references public.occupation_nodes(id) on delete cascade,
  naics_code text not null,
  industry_title text not null,
  employment_count integer check (employment_count is null or employment_count >= 0),
  industry_share numeric(5,4) check (industry_share is null or (industry_share >= 0.0 and industry_share <= 1.0)),
  data_year integer not null,
  source_release_id uuid references public.taxonomy_source_releases(id) on delete set null,
  primary key (occupation_id, naics_code, data_year)
);

-- 10. MULTIDISCIPLINARY TARGET & CONCEPT BINDINGS
-- Learning target type enum extended with 'curriculum_standard'
alter table public.learning_targets
  drop constraint if exists learning_targets_target_type_check;

alter table public.learning_targets
  add constraint learning_targets_target_type_check check (
    target_type in (
      'career',
      'academic_program',
      'certification',
      'licensure_exam',
      'standardized_exam',
      'curriculum_standard'
    )
  );

create table if not exists public.learning_target_fields (
  target_id uuid not null references public.learning_targets(id) on delete cascade,
  field_id uuid not null references public.fields(id) on delete cascade,
  role text not null default 'supporting' check (
    role in ('primary', 'supporting', 'interdisciplinary_core', 'elective')
  ),
  display_order integer not null default 0,
  created_at timestamptz not null default now(),
  primary key (target_id, field_id)
);

create table if not exists public.concept_fields (
  concept_id uuid not null references public.knowledge_concepts(id) on delete cascade,
  field_id uuid not null references public.fields(id) on delete cascade,
  relationship text not null default 'core_concept' check (
    relationship in ('core_concept', 'foundational_prerequisite', 'applied_domain', 'shared_cross_field')
  ),
  created_at timestamptz not null default now(),
  primary key (concept_id, field_id)
);

-- 11. CATALOG CLUSTERS (Presentation Layer)
create table if not exists public.catalog_clusters (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text,
  emoji text,
  icon text,
  accent_color text,
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table if not exists public.catalog_cluster_fields (
  cluster_id uuid not null references public.catalog_clusters(id) on delete cascade,
  field_id uuid not null references public.fields(id) on delete cascade,
  sort_order integer not null default 0,
  primary key (cluster_id, field_id)
);

-- 12. SECURITY & RLS POLICIES (With Visibility Inheritance & Fail-Closed Privacy)
alter table public.taxonomy_source_releases enable row level security;
alter table public.taxonomy_source_artifacts enable row level security;
alter table public.external_classification_nodes enable row level security;
alter table public.field_external_classifications enable row level security;
alter table public.taxonomy_node_lineage enable row level security;
alter table public.field_relations enable row level security;
alter table public.occupation_nodes enable row level security;
alter table public.external_classification_occupation_mappings enable row level security;
alter table public.field_occupation_metrics enable row level security;
alter table public.occupation_industries enable row level security;
alter table public.learning_target_fields enable row level security;
alter table public.concept_fields enable row level security;
alter table public.catalog_clusters enable row level security;
alter table public.catalog_cluster_fields enable row level security;

-- Static taxonomy tables are public read
create policy "public_read_source_releases" on public.taxonomy_source_releases for select using (true);
create policy "public_read_source_artifacts" on public.taxonomy_source_artifacts for select using (true);
create policy "public_read_ext_class_nodes" on public.external_classification_nodes for select using (true);
create policy "public_read_field_ext_class" on public.field_external_classifications for select using (true);
create policy "public_read_taxonomy_lineage" on public.taxonomy_node_lineage for select using (true);
create policy "public_read_field_relations" on public.field_relations for select using (true);
create policy "public_read_occupation_nodes" on public.occupation_nodes for select using (true);
create policy "public_read_ext_class_occ_map" on public.external_classification_occupation_mappings for select using (true);
create policy "public_read_occ_industries" on public.occupation_industries for select using (true);
create policy "public_read_catalog_clusters" on public.catalog_clusters for select using (true);
create policy "public_read_cluster_fields" on public.catalog_cluster_fields for select using (true);

-- Metrics table requires publication flag AND verified privacy threshold for user data
create policy "public_read_field_occ_metrics" on public.field_occupation_metrics for select using (
  is_published = true and (
    metric_type <> 'app_user_transition_share' or privacy_threshold_met = true
  )
);

-- User-content junction tables inherit parent visibility
create policy "target_fields_read_inherited" on public.learning_target_fields for select using (
  exists (
    select 1 from public.learning_targets t
    where t.id = learning_target_fields.target_id
      and (t.is_public = true or t.created_by = auth.uid())
  )
);

create policy "concept_fields_read_inherited" on public.concept_fields for select using (
  exists (
    select 1 from public.knowledge_concepts c
    where c.id = concept_fields.concept_id
      and (c.status = 'active' or c.created_by = auth.uid())
  )
);
```

---

## 10. Data Ingestion Pipeline & Provenance Governance

### 10.1 Provenance, Attribution, and Checksums
All ingested external files are cataloged with release date, source URL, cryptographic hash, and license attribution in `taxonomy_source_releases` and `taxonomy_source_artifacts`:
- **NCES CIP 2020:** Public Domain (US Federal Government work).
- **BLS SOC 2018:** Public Domain (US Federal Government work).
- **O\*NET Database (Release 31.0):** Creative Commons Attribution 4.0 International (CC BY 4.0), sponsored by the U.S. Department of Labor, Employment and Training Administration (USDOL/ETA). Attribution is displayed on occupation detail surfaces.

### 10.2 Ingestion Engine Workflow (`tool/seed_taxonomy.dart`)
```
Phase 0: Record Source Releases & Artifacts
  0.1 Insert release rows into public.taxonomy_source_releases.
  0.2 Record downloaded files into public.taxonomy_source_artifacts with SHA256 checksums and file sizes.

Phase 1: Ingest CIP 2020 External Classification
  1.1 Stream CIPCode2020.csv.
  1.2 Insert all codes into public.external_classification_nodes (system = 'cip', version = '2020').
  1.3 Two-pass resolution: resolve source_parent_code into parent_id FK.
  1.4 Populate definition, cross_references, and illustrative_examples arrays.

Phase 2: Bootstrap Canonical LearningApp Fields
  2.1 Generate permanent internal UUIDs for 48 broad series -> public.fields (field_kind = 'broad_field').
  2.2 Generate permanent internal UUIDs for 4-digit groups -> public.fields (field_kind = 'subfield').
  2.3 Generate permanent internal UUIDs for 6-digit programs -> public.fields (field_kind = 'program_classification').
  2.4 Insert 1-to-1 exact mappings into public.field_external_classifications.

Phase 3: Ingest SOC 2018 & O*NET 31.0
  3.1 Stream soc_2018_definitions.csv.
  3.2 Ingest Major Groups -> public.occupation_nodes (level = 'major_group', taxonomy_system = 'bls_soc', taxonomy_version = 'soc_2018').
  3.3 Ingest Minor Groups -> public.occupation_nodes (level = 'minor_group', parent_id = major.id, taxonomy_system = 'bls_soc', taxonomy_version = 'soc_2018').
  3.4 Ingest Broad Occupations -> public.occupation_nodes (level = 'broad_occupation', parent_id = minor.id, taxonomy_system = 'bls_soc', taxonomy_version = 'soc_2018').
  3.5 Ingest Detailed Occupations -> public.occupation_nodes (level = 'detailed_occupation', parent_id = broad.id, taxonomy_system = 'bls_soc', taxonomy_version = 'soc_2018').
  3.6 Stream O*NET 31.0 Occupation Data.txt:
      Insert O*NET extensions (.XX) -> public.occupation_nodes (
        level = 'onet_extension',
        parent_id = detailed.id,
        taxonomy_system = 'onet_soc',
        taxonomy_version = '2019',
        data_release_version = 'onet_31_0'
      ).

Phase 4: Ingest Official CIP–SOC Crosswalk
  4.1 Stream CIP2020_SOC2018_Crosswalk.csv.
  4.2 Map CIP classification_node_id and SOC occupation_id.
  4.3 Upsert into public.external_classification_occupation_mappings with mandatory source_release_id.
  4.4 Application queries automatically consume crosswalks via public.v_field_occupation_mappings.

Phase 5: Ingest Presentation Catalog Clusters
  5.1 Seed 12 CatalogClusters with emojis, titles, and theme colors.
  5.2 Map 48 broad fields to appropriate visual clusters in public.catalog_cluster_fields.
```

---

## 11. Complete Review Resolution Matrix (Frozen Baseline)

This table certifies how all feedback items across all review cycles have been resolved in Architecture v2.4:

| Issue | Severity | Resolution in Architecture v2.4 |
|---|---|---|
| **Metrics uniqueness missing geography/population/release** | Critical schema | Extended unique key to `(field_id, occupation_id, metric_type, geography, population, data_year, methodology_version, source_release_id)` using PostgreSQL 15+ `unique nulls not distinct` plus fallback expression index with `COALESCE`. |
| **O\*NET extension taxonomy identity** | Critical data integrity | Added DB check constraint `((level = 'onet_extension' and taxonomy_system = 'onet_soc') or (level <> 'onet_extension' and taxonomy_system = 'bls_soc'))` and ingestion rules to guarantee clean system segregation without defaults. |
| **External hierarchy lacks parent FK** | Critical referential | Added `parent_id uuid references external_classification_nodes(id)` with two-pass ingestion resolution. |
| **Crosswalk provenance nullable** | Critical idempotency | Made `source_release_id NOT NULL` on `external_classification_occupation_mappings` eliminating PostgreSQL NULL uniqueness bypass. |
| **Publication flag mixed with privacy threshold** | High | Separated `is_published` from `privacy_threshold_met`. RLS checks `is_published = true` for government data and both flags for learner data. |
| **Discipline evolution rule too absolute** | Refinement | Explicitly formalized that new internal fields ARE created for genuine discipline splits/new learning domains, while renames preserve identity. |
| **Multi-artifact provenance support** | Provenance | Added `public.taxonomy_source_artifacts` table under `taxonomy_source_releases` tracking individual files and SHA256 checksums. |
| **Crosswalk attached at wrong layer** | Critical architectural | Moved raw crosswalk to `external_classification_occupation_mappings` (CIP node $\longleftrightarrow$ SOC node). Exposed to internal fields via `v_field_occupation_mappings`. |
| **Privacy threshold not enforced** | Critical security | `privacy_threshold_met` defaults to `false` (fail-closed). DB check constraint enforces $N \ge 50$ for `app_user_transition_share`. RLS selects only verified rows. |
| **NULL methodology_version defeats uniqueness** | Critical schema | `methodology_version` made `NOT NULL default 'source_native_v1'`. Added `0.0 <= metric_value <= 1.0` range check. |
| **Lineage lost duplicate protection** | Critical schema | Added unique expression index `taxonomy_lineage_unique_idx` using `COALESCE` on `from_code` and `to_code`. |
| **O\*NET release version overstated** | Data integrity | Removed global default on `occupation_nodes.data_release_version`; populated strictly when enriched by O*NET. |
| **External classification level rigid** | Extensibility | Replaced hardcoded enum with `level_code text not null` and `level_depth integer not null default 1`. |
| **Illegal DDL Defaults** | Critical bug | Eliminated redundant `source_level` / `node_kind`. Consolidated into `field_kind text not null` with zero illegal defaults. |
| **Internal vs External Identity Conflict** | Critical schema | Introduced `external_classification_nodes` + `field_external_classifications`. Internal `fields` have permanent UUIDs that survive decennial updates. |
| **Lineage Nullable Endpoints** | Critical schema | Made `from_code` / `to_code` nullable in `taxonomy_node_lineage` with exact check constraints for `deleted` and `newly_introduced`. |
| **Labor-Market Ranking Attribution** | High | Replaced with `field_occupation_metrics` (typed metrics, explicit population, data year, methodology, and privacy thresholds). |
| **Derived Score Attribution** | High | Formalized as `derived_education_alignment_score` with methodology versioning, never misrepresented as official BLS figures. |
| **K–12 Target Type Mismatch** | Medium-high | Added `curriculum_standard` to `learning_targets.target_type` check constraint. |
| **`field_id` vs `primary_field_id`** | Clarity | Preserved `field_id` as primary browse placement; full membership handled via `learning_target_fields`. |
| **Target-Field Weight Semantics** | Medium | Removed ambiguous numeric weight; replaced with `role` and `display_order`. Readiness score explicitly isolated to concept graph. |
| **Field Relation Symmetry** | Medium | Enforced canonical ordering (`from_field_id < to_field_id`) on symmetric relations and created `v_field_relations_bidirectional`. |
| **Provenance DDL Missing** | Medium | Added `public.taxonomy_source_releases` table tracking release version, date, SHA256 checksum, URL, and license text. |
| **RLS Leak on User Junctions** | Security | Enforced visibility inheritance on `learning_target_fields` and `concept_fields` checking parent `is_public` or `created_by = auth.uid()`. |
| **Learner Analytics Privacy** | Privacy | Enforced `privacy_threshold_met = true` RLS check and $N \ge 50$ aggregation threshold on learner-derived metrics. |
