# Canonical Taxonomy Architecture: CIP 2020, SOC 2018, & Knowledge Classification
**Document Status:** Architecture Proposal & Specification for External Review (ChatGPT / Systems Architects)  
**Target File:** `CANONICAL_TAXONOMY_ARCHITECTURE.md` (Repository Root)  
**Applies To:** Learning Architecture v2 (`learning_targets`, `target_versions`, `fields`, `courses`, `knowledge_concepts`)  
**Version:** 1.0 — Architecture Proposal  
**Author:** Antigravity Engineering & System Architecture  

---

## 1. Executive Summary & Purpose

### 1.1 The Problem Statement
Our learning platform requires an exhaustive, sensible, and authoritative canonical taxonomy for **"What can someone learn?"** that satisfies three strict criteria:
1. **Extensive:** A user must be able to explore, search, or enroll in virtually any recognized branch of human knowledge without finding obvious blind spots or omitted disciplines.
2. **Authoritative & Free of Arbitrary Duplication:** The taxonomy must be grounded in an established, maintained statistical/governmental standard rather than an ad-hoc, hallucinated list of categories generated on the fly.
3. **Ontologically Clean:** Educational programs ("What do you study?"), occupations ("What job do you do?"), industries ("Where do you work?"), and granular micro-skills ("What discrete concept did you master?") must never be collapsed into a single tangled hierarchy.

### 1.2 Core Architectural Decision
Instead of inventing a proprietary classification or forcing jobs into an academic hierarchy, we ground the platform in five specialized external standards connected by official government crosswalks, complemented by an isolated app-curated extension tier:

| Domain | Standard / Authority | Role in LearningApp | Source Level / Granularity |
|---|---|---|---|
| **Fields of Study / Learning Programs** | **NCES CIP 2020** (U.S. Dept of Education) | **Primary Canonical Seed for `fields`** | 2-digit (Broad) → 4-digit (Intermediate) → 6-digit (Detailed Program) |
| **International Normalization** | **UNESCO ISCED-F 2013** | Top-level international grouping & metadata | 11 Broad Fields → 29 Narrow Fields |
| **Occupations & Careers** | **BLS SOC 2018 + O\*NET 29.x** | **Independent Career/Occupation Taxonomy** | 23 Major Groups → 98 Minor → 459 Broad → 867 Detailed Occupations |
| **Field ↔ Career Crosswalk** | **NCES / BLS Official CIP–SOC Crosswalk** | Bidirectional empirical junction table | Many-to-Many mapping with official educational alignment |
| **Industries** | **US Census NAICS 2022** | Occupational context ("In which sector?") | 2-digit to 6-digit industry classification |
| **Non-Academic / Hobbyist Knowledge** | **LearningApp Extensions (`learning_app`)** | Discrete skill/hobby extensions | Anchored under appropriate CIP parents with distinct provenance |

---

## 2. Ontological Separation: The Five Core Concepts

A primary failure mode of learning platforms is treating "Field", "Career", "Course", and "Concept" as interchangeable categories. We strictly separate them into distinct planes:

```
                            ┌────────────────────────┐
                            │    UNESCO ISCED-F      │
                            │ (International Groups) │
                            └───────────┬────────────┘
                                        │ (High-level grouping)
                                        ▼
                            ┌────────────────────────┐
                            │      NCES CIP 2020     │
                            │    (Fields of Study)   │
                            └─────┬────────────┬─────┘
                                  │            │
            ┌─────────────────────┘            └──────────────────────┐
            ▼                                                         ▼
┌────────────────────────┐                                ┌────────────────────────┐
│     CIP-SOC CROSSWALK  │                                │    LEARNING TARGETS    │
│  (Official Many-to-Many│                                │ (Certifications, Exams,│
└───────────┬────────────┘                                │  Degrees, Bootcamps)   │
            │                                             └───────────┬────────────┘
            ▼                                                         │
┌────────────────────────┐                                            ▼
│    BLS SOC / O*NET     │                                ┌────────────────────────┐
│ (Occupations / Careers)│                                │    COURSES & MODULES   │
└───────────┬────────────┘                                │  (Structured Curricula)│
            │                                             └───────────┬────────────┘
            ▼                                                         │
┌────────────────────────┐                                            ▼
│       US NAICS         │                                ┌────────────────────────┐
│ (Employing Industries) │                                │   KNOWLEDGE CONCEPTS   │
└────────────────────────┘                                │   (Atomic Concept IDs) │
                                                          └────────────────────────┘
```

### 2.1 The Plane Definitions
1. **Instructional Field (`fields` table):** A body of knowledge, discipline, or instructional program (e.g., *CIP 11.0701: Computer Science*; *CIP 27.0501: Statistics, General*; *CIP 01.0308: Agroecology*).
2. **Occupation (`occupations` table):** A recognized set of work activities and labor roles (e.g., *SOC 15-1252: Software Developers*; *SOC 29-1141: Registered Nurses*).
3. **Learning Target (`learning_targets` table):** A formal destination or milestone a learner pursues (e.g., *CompTIA Security+*, *AWS Solutions Architect Associate*, *California Bar Exam*, *BS in Computer Science*). Targets point to a `field_id` and optionally link to `occupations`.
4. **Course & Lesson (`courses`, `lessons`):** Structured teaching units designed to teach a syllabus.
5. **Knowledge Concept (`knowledge_concepts` table):** The atomic, testable node of understanding (e.g., *Binary Search*, *Encapsulation*, *Mitochondrial ATP Synthesis*).

---

## 3. The Field Taxonomy: NCES CIP 2020 Deep Dive

### 3.1 Structural Hierarchy
CIP 2020 provides a complete, 3-tiered taxonomic hierarchy across 47 primary series:

```
Level 1: 2-Digit CIP Series (Broad Field)
  Example: 11 - COMPUTER AND INFORMATION SCIENCES AND SUPPORT SERVICES
    │
    └── Level 2: 4-Digit CIP Group (Field / Subfield)
          Example: 11.07 - Computer Science
            │
            └── Level 3: 6-Digit CIP Program (Instructional Program Specialization)
                  Example: 11.0701 - Computer Science
                  Example: 11.0104 - Informatics
                  Example: 11.0401 - Information Science/Studies
                  Example: 11.1003 - Computer and Information Systems Security/Information Assurance
```

### 3.2 The 47 CIP 2-Digit Root Series
The root series represent the total breadth of structured instructional programs:
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
- `54`: History
- `60`: Health Professions Residency/Fellowship Programs
- `61`: Medical Residency/Fellowship Programs

### 3.3 The Disambiguation & "No Duplicates" Philosophy
A critical requirement is that our system must not contain messy, accidental duplicates, yet must preserve legitimate contextual distinctions.

#### The "Statistics" Proof Case
In CIP 2020:
- `27.0501`: **Statistics, General** (Under Mathematics & Statistics) — Instruction focused on mathematical statistics, probability theory, stochastic processes, and formal mathematical proofs.
- `52.1302`: **Business Statistics** (Under Business & Management) — Instruction focused on decision support, econometrics, market forecasting, and commercial data interpretation.

**Resolution Rule:**
1. **Never merge purely based on title string similarity.** Two nodes with identical or overlapping titles are preserved if their `source_system` and `source_code` differ.
2. The composite key `(source_system, source_code)` is the **immutable external identity**.
3. Lateral relationships are captured via a dedicated `field_relations` junction table (e.g. `relation_type = 'interdisciplinary_affinity'` or `'shares_concept_foundations'`) rather than destructive data merges.

---

## 4. Careers & Occupations: BLS SOC 2018 + O*NET

### 4.1 Independent Occupational Hierarchy
Occupations do not belong as child nodes inside educational fields. A Software Developer is an occupation; Computer Science is a field of study. People with Software Engineering degrees work as Software Developers, but so do people with Mathematics, Physics, Electrical Engineering, or self-taught backgrounds.

The 2018 SOC standard organizes occupations into:
- **23 Major Groups** (e.g. `15-0000`: Computer and Mathematical Occupations)
- **98 Minor Groups** (e.g. `15-1200`: Computer Occupations)
- **459 Broad Occupations** (e.g. `15-1250`: Software and Web Developers, Programmers, and Testers)
- **867 Detailed Occupations** (e.g. `15-1252`: Software Developers)
- **O\*NET Extensions** (e.g. `15-1252.00`: Software Developers; `15-1253.00`: Software Quality Assurance Analysts and Testers)

### 4.2 The NCES / BLS Official CIP–SOC Crosswalk
NCES and the Bureau of Labor Statistics publish an official content-validated mapping linking CIP 2020 instructional programs to SOC 2018 occupations.
- **Example Mapping:**
  - CIP `11.0701` (Computer Science) ↔ SOC `15-1252` (Software Developers)
  - CIP `11.0701` (Computer Science) ↔ SOC `15-1221` (Computer and Information Research Scientists)
  - CIP `11.0701` (Computer Science) ↔ SOC `15-1251` (Computer Programmers)
  - CIP `11.1003` (Computer Security) ↔ SOC `15-1212` (Information Security Analysts)
- This official crosswalk allows our app to provide instant, validated career discovery ("What can I do with a degree/certification in X?") without guessing or hallucinating career paths.

---

## 5. Non-Academic & Hobbyist Knowledge: The App-Curated Extension Tier

While CIP 2020 covers virtually every formal academic, vocational, and professional discipline, it is not designed for non-institutional learning topics such as:
- Sourdough Bread Baking
- Chess Opening Theory
- Home Solar Installation & DIY Microgrids
- Video Editing with DaVinci Resolve
- Competitive Speedrunning
- Parenting & Infant Sleep Scaffolding

### 5.1 Extension Architecture
We do not invent a second parallel database for these topics. Instead, they exist within the same recursive `fields` table with:
- `source_system = 'learning_app'`
- `parent_id` anchored under the most appropriate official CIP parent node:
  ```
  CIP 12.0501 (Baking and Pastry Arts/Baker/Pastry Chef)
      └── learning_app:sourdough-baking (Sourdough Bread Craft & Fermentation)

  CIP 31.0508 (Sports Studies / Gaming)
      └── learning_app:chess-strategy (Chess Strategy & Openings)

  CIP 10.0304 (Animation, Interactive Technology, Video Graphics and Special Effects)
      └── learning_app:davinci-resolve-editing (DaVinci Resolve Workflow)
  ```
This ensures the entire taxonomy remains unified, searchable, and hierarchically traversable.

---

## 6. Database Schema Specification (PostgreSQL / Supabase DDL)

To implement this architecture, we extend the v2 `fields` table and introduce the `occupations` table, `field_occupations` crosswalk junction, and `field_relations` lateral links.

### 6.1 Extended `public.fields` Schema
```sql
-- Migration: Additive taxonomy columns to public.fields
alter table public.fields
  add column if not exists source_system text not null default 'learning_app',
  add column if not exists source_code text,
  add column if not exists source_level text not null default 'field'
    check (source_level in ('broad', 'intermediate', 'detailed', 'specialization', 'extension')),
  add column if not exists node_kind text not null default 'field'
    check (node_kind in ('broad_series', 'subfield_group', 'program_classification', 'extension_field')),
  add column if not exists source_version text default '2020',
  add column if not exists source_url text,
  add column if not exists isced_code text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

-- Unique constraint ensuring no duplicates within the same source system
create unique index if not exists fields_source_system_code_idx
  on public.fields(source_system, source_code)
  where source_code is not null;

-- Fast hierarchical retrieval index
create index if not exists fields_source_level_idx
  on public.fields(source_level, sort_order);

-- Full-Text Search generated column and GIN index
alter table public.fields
  add column if not exists search_tsv tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(source_code, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'C')
  ) stored;

create index if not exists fields_search_tsv_idx
  on public.fields using gin(search_tsv);
```

### 6.2 The `public.occupations` Schema (SOC 2018 / O*NET)
```sql
create table if not exists public.occupations (
  id uuid primary key default gen_random_uuid(),
  soc_code text not null unique,
  title text not null,
  description text,
  major_group_code text not null,
  minor_group_code text not null,
  broad_code text not null,
  source_system text not null default 'soc_2018',
  source_version text not null default '2018',
  source_url text,
  typical_entry_education text,
  work_experience_required text,
  on_the_job_training text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists occupations_major_group_idx
  on public.occupations(major_group_code);

create index if not exists occupations_soc_code_idx
  on public.occupations(soc_code);

alter table public.occupations enable row level security;
create policy "occupations_read_all" on public.occupations for select using (true);
```

### 6.3 The Official CIP–SOC Crosswalk Junction (`public.field_occupations`)
```sql
create table if not exists public.field_occupations (
  field_id uuid not null
    references public.fields(id) on delete cascade,
  occupation_id uuid not null
    references public.occupations(id) on delete cascade,
  match_source text not null default 'nces_bls_crosswalk_2020',
  is_primary boolean not null default false,
  confidence numeric(4,3) default 1.000,
  notes text,
  created_at timestamptz not null default now(),
  primary key (field_id, occupation_id)
);

create index if not exists field_occupations_occ_idx
  on public.field_occupations(occupation_id);
```

### 6.4 Lateral Field Relations (`public.field_relations`)
```sql
create table if not exists public.field_relations (
  from_field_id uuid not null
    references public.fields(id) on delete cascade,
  to_field_id uuid not null
    references public.fields(id) on delete cascade,
  relation_type text not null check (
    relation_type in (
      'cross_disciplinary',
      'shares_foundations',
      'common_dual_major',
      'alternative_track'
    )
  ),
  weight numeric(4,3) not null default 1.000,
  metadata jsonb not null default '{}'::jsonb,
  primary key (from_field_id, to_field_id, relation_type),
  check (from_field_id <> to_field_id)
);
```

---

## 7. Data Ingestion & Pipeline Specification

### 7.1 Source Data Ingestion Assets
The seeding pipeline uses official public data releases from the U.S. Federal Government:
1. **NCES CIP 2020 Full Schema:**
   - Source: `https://nces.ed.gov/ipeds/cipcode/resources.aspx?y=56`
   - File: `CIPCode2020.csv`
   - Key attributes: `CIPCode` (e.g. `11.0701`), `CIPTitle`, `CIPDefinition`, `CrossReferences`, `Examples`.
2. **NCES / BLS CIP 2020 to SOC 2018 Crosswalk:**
   - File: `CIP2020_SOC2018_Crosswalk.csv`
   - Key attributes: `CIP2020Code`, `CIP2020Title`, `SOC2018Code`, `SOC2018Title`.
3. **BLS 2018 SOC Definitions & Education Data:**
   - Source: `https://www.bls.gov/soc/2018/`
   - File: `soc_2018_definitions.csv` and `soc_2018_education.csv`.

### 7.2 Ingestion Engine Steps (`scripts/seed_taxonomy.dart`)
```
Step 1: Ingest CIP 2-Digit Root Series
  Parse codes where length = 2 (e.g. '11', '14', '51').
  Insert into public.fields (parent_id = NULL, source_level = 'broad', node_kind = 'broad_series').

Step 2: Ingest CIP 4-Digit Groups
  Parse codes where pattern = XX.YY (e.g. '11.07', '14.08').
  Resolve parent_id by looking up source_code = XX.
  Insert into public.fields (source_level = 'intermediate', node_kind = 'subfield_group').

Step 3: Ingest CIP 6-Digit Detailed Programs
  Parse codes where pattern = XX.YYYY (e.g. '11.0701', '52.1302').
  Resolve parent_id by looking up source_code = XX.YY.
  Insert into public.fields (source_level = 'detailed', node_kind = 'program_classification').

Step 4: Ingest SOC 2018 Occupations
  Insert all 867 detailed occupations and 23 major groups into public.occupations.

Step 5: Ingest CIP–SOC Crosswalk Junction
  Read CIP2020_SOC2018_Crosswalk.csv.
  Join field_id by CIP code and occupation_id by SOC code.
  Upsert into public.field_occupations with ON CONFLICT DO NOTHING.

Step 6: Ingest App Extension Nodes
  Insert curated non-academic nodes under their respective CIP parents.
```

---

## 8. UX, Catalog Discovery, & Navigation Design

### 8.1 The User Problem: Navigating 2,400+ Nodes
With ~47 root series, ~450 intermediate subfields, and ~2,400 detailed 6-digit CIP programs, dumping a flat list on users would be overwhelming. The UI implements **Progressive Categorical Disclosure**:

```
[ Search Everything: e.g. "Python", "Data Science", "Nursing", "Carpentry" ]
  │
  ├── 1. Instant Search Dropdown
  │      Shows instant fuzzy matches categorized by:
  │      - Learning Targets (e.g. "Certified Data Privacy Solutions Engineer")
  │      - Fields of Study (e.g. "11.0701: Computer Science")
  │      - Related Careers (e.g. "15-1252: Software Developers")
  │
  ├── 2. Top-Level Broad Explorer (Learn / Library Surface)
  │      Displays 12 High-Level Visual Clusters (aggregated from CIP & ISCED-F):
  │      ┌───────────────────────┬───────────────────────┐
  │      │ 💻 Computing & Tech   │ 🏥 Health & Medicine  │
  │      │ ⚙️ Engineering        │ 📈 Business & Finance │
  │      │ 🎨 Arts & Design      │ 🔬 Physical Sciences  │
  │      │ ⚖️ Law & Policy       │ 📐 Math & Data        │
  │      │ 🔨 Trades & Skilled   │ 🌍 Social Sciences    │
  │      │ 🌾 Agriculture & Bio  │ 📚 Humanities & Lang  │
  │      └───────────────────────┴───────────────────────┘
  │
  └── 3. Hierarchical Drilldown Screen (`/field/:fieldSlug`)
         Level 1 (Broad): e.g. "Computing & Information Technology"
           Level 2 (Group): e.g. "11.07: Computer Science"
             Level 3 (Specialization): "11.0701: Computer Science, General"
               ↳ Active Targets (Degrees, Certs, Bootcamps)
               ↳ Courses in this Specialization
               ↳ Related Careers (from SOC Crosswalk: Software Developer, System Architect)
```

### 8.2 Career-First Discovery Mode
Learners frequently know the **career** they desire before they know the formal **academic field**:
- A user selects or searches for **"Cybersecurity Analyst"** (SOC `15-1212`).
- The app uses `field_occupations` to display:
  - *"To prepare for this career, explore these Fields of Study:"*
    - **11.1003**: Computer and Information Systems Security
    - **11.0101**: Computer and Information Sciences, General
  - Directly lists corresponding **Learning Targets** (e.g. *CompTIA Security+*, *CISSP*, *B.S. in Cybersecurity*).

---

## 9. Review Criteria & Open Questions for External Reviewers (ChatGPT)

To facilitate rigorous evaluation by ChatGPT or external systems architects, the following architectural trade-offs and design questions are highlighted:

### Question 1: 6-Digit CIP vs Learning Target Granularity
*Issue:* In CIP 2020, 6-digit codes represent instructional programs (e.g. `11.0701: Computer Science`). In our app, we also have `learning_targets` (e.g., an actual degree program, a certification like AWS CCAA, or an exam like MCAT).  
*Review Focus:* Is treating 6-digit CIP codes as the most detailed tier of `fields` (with `learning_targets` attaching to them) the optimal boundary, or should 6-digit codes themselves be modeled as base `learning_targets`?

### Question 2: Handling CIP Decennial Versioning
*Issue:* NCES updates CIP every 10 years (CIP 2010, CIP 2020, CIP 2030). Occasionally codes are deleted, split, or renamed.  
*Review Focus:* Does our composite identity `(source_system, source_code)` combined with `source_version = '2020'` provide adequate immutability without breaking user learning progress or historical target completions when CIP 2030 is eventually released?

### Question 3: Internationalization (ISCED-F vs CIP)
*Issue:* CIP is a United States federal standard. While the disciplines are universal, some nomenclature reflects US educational patterns.  
*Review Focus:* Is our approach of using UNESCO ISCED-F 2013 for top-level aggregation sufficient for international learners in Europe, Asia, and Latin America, or should the schema support a dual-primary taxonomy model?

### Question 4: Crosswalk Weighting & Confidence
*Issue:* The NCES/BLS crosswalk links CIP to SOC without quantitative affinity weights (it is an unweighted binary mapping).  
*Review Focus:* We included `confidence numeric(4,3)` and `is_primary boolean` in `field_occupations`. What is the recommended heuristic for seeding these weights initially before learner behavioral data accumulates?

---

## 10. Summary Checklist for Implementation

- [x] Ontological separation defined (Field vs Occupation vs Target vs Concept).
- [x] External standard selected for fields (NCES CIP 2020).
- [x] External standard selected for careers (BLS SOC 2018 + O*NET 29).
- [x] Official Crosswalk selected for field-to-career relations.
- [x] Schema extension for `public.fields` drafted with `source_system` and `source_code`.
- [x] Schema for `public.occupations` and `public.field_occupations` drafted.
- [x] Ingestion pipeline steps specified for public government CSV datasets.
- [x] Progressive disclosure catalog UI designed to handle 2,400+ nodes seamlessly.
- [x] Root directory cleaned up and old sprint plans relocated to `docs/`.
