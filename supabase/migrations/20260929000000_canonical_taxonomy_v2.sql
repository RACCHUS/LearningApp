-- ============================================================================
-- Canonical Taxonomy Architecture v2.4 Consolidated Schema Migration
-- Migration: 20260929000000_canonical_taxonomy_v2.sql
-- Description: Dual-Layer Learning Ontology, External Standards (CIP/SOC/O*NET),
--              and Labor Market Crosswalks with Full Dimensionality & Fail-Closed Privacy.
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

-- Backfill search_tsv for existing rows
update public.fields set search_tsv =
  setweight(to_tsvector('english', coalesce(name, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(array_to_string(aliases, ' '), '')), 'A') ||
  setweight(to_tsvector('english', coalesce(array_to_string(cross_references, ' '), '')), 'B') ||
  setweight(to_tsvector('english', coalesce(array_to_string(illustrative_examples, ' '), '')), 'B') ||
  setweight(to_tsvector('english', coalesce(description, '')), 'C')
where search_tsv is null;

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
create index if not exists field_ext_class_node_idx
  on public.field_external_classifications(classification_node_id);

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
