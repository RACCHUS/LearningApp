-- ============================================================================
-- Phase F.1: Production Taxonomy Ingestion Hardening
-- Migration: 20261008000002_phase_f1_production_taxonomy_hardening.sql
-- Description:
--   1. Replaces occupation_nodes uniqueness with version-safe constraint
--      including data_release_version (NULLS NOT DISTINCT) to avoid O*NET
--      multi-release collision (e.g. 31.0 vs 31.1).
--   2. Adds retrieval_url column to taxonomy_source_artifacts for full provenance.
--   3. Creates service_role-only staging tables for atomic two-phase ingestion.
--   4. Adds atomic transactional RPC finalize_official_taxonomy_import() that
--      promotes staged records, reconciles absent records, and verifies exact counts.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. O*NET Version-Safe Unique Constraint on occupation_nodes
-- ----------------------------------------------------------------------------
alter table public.occupation_nodes
  drop constraint if exists occupation_nodes_taxonomy_system_taxonomy_version_code_key;

alter table public.occupation_nodes
  add constraint occupation_nodes_system_version_release_code_key
  unique nulls not distinct (taxonomy_system, taxonomy_version, data_release_version, code);

-- ----------------------------------------------------------------------------
-- 2. Artifact Retrieval URL Provenance
-- ----------------------------------------------------------------------------
alter table public.taxonomy_source_artifacts
  add column if not exists retrieval_url text;

-- ----------------------------------------------------------------------------
-- 3. Service-Role-Only Staging Tables for Atomic Taxonomy Ingestion
-- ----------------------------------------------------------------------------
create table if not exists public.stg_taxonomy_source_artifacts (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null,
  source_system text not null,
  release_version text not null,
  artifact_name text not null,
  source_url text,
  retrieval_url text,
  sha256 text,
  file_size_bytes bigint,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.stg_external_classification_nodes (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null,
  system text not null,
  version text not null,
  code text not null,
  source_parent_code text,
  level_code text not null,
  level_depth integer not null default 1,
  title text not null,
  definition text,
  cross_references text[] not null default '{}',
  illustrative_examples text[] not null default '{}',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.stg_occupation_nodes (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null,
  code text not null,
  title text not null,
  description text,
  level text not null,
  taxonomy_system text not null,
  taxonomy_version text not null,
  data_release_version text,
  job_zone integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.stg_external_classification_occupation_mappings (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null,
  classification_system text not null,
  classification_version text not null,
  classification_code text not null,
  occupation_system text not null,
  occupation_version text not null,
  occupation_code text not null,
  mapping_source text not null default 'nces_bls_crosswalk_2020',
  mapping_version text not null default '2020',
  mapping_kind text not null default 'official_qualitative',
  source_notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.stg_taxonomy_node_lineage (
  id uuid primary key default gen_random_uuid(),
  import_run_id uuid not null,
  source_system text not null,
  from_version text not null,
  from_code text,
  to_version text not null,
  to_code text,
  transition_type text not null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Indices on import_run_id and search keys for high-performance lookup and finalization
create index if not exists stg_art_run_idx on public.stg_taxonomy_source_artifacts(import_run_id);
create index if not exists stg_cip_run_idx on public.stg_external_classification_nodes(import_run_id, system, version, code);
create index if not exists stg_occ_run_idx on public.stg_occupation_nodes(import_run_id, taxonomy_system, taxonomy_version, data_release_version, code);
create index if not exists stg_map_run_idx on public.stg_external_classification_occupation_mappings(import_run_id);
create index if not exists stg_lin_run_idx on public.stg_taxonomy_node_lineage(import_run_id, source_system, from_version, to_version);

-- Enable RLS and lock down staging tables strictly to service_role
alter table public.stg_taxonomy_source_artifacts enable row level security;
alter table public.stg_external_classification_nodes enable row level security;
alter table public.stg_occupation_nodes enable row level security;
alter table public.stg_external_classification_occupation_mappings enable row level security;
alter table public.stg_taxonomy_node_lineage enable row level security;

create policy "service_role_manage_stg_artifacts"
  on public.stg_taxonomy_source_artifacts for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "service_role_manage_stg_cip"
  on public.stg_external_classification_nodes for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "service_role_manage_stg_occ"
  on public.stg_occupation_nodes for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "service_role_manage_stg_map"
  on public.stg_external_classification_occupation_mappings for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

create policy "service_role_manage_stg_lin"
  on public.stg_taxonomy_node_lineage for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- ----------------------------------------------------------------------------
-- 4. Atomic Finalize RPC
-- ----------------------------------------------------------------------------
create or replace function public.finalize_official_taxonomy_import(
  p_import_run_id uuid
)
returns jsonb
language plpgsql
security definer
set statement_timeout = '120s'
as $$
declare
  v_cip_stg_count integer;
  v_soc_stg_count integer;
  v_onet_stg_count integer;
  v_map_stg_count integer;
  v_cip_lin_count integer;
  v_soc_lin_count integer;

  v_cip_active_count integer;
  v_soc_active_count integer;
  v_onet_active_count integer;
  v_map_active_count integer;
  v_orphan_cip integer;
  v_orphan_soc integer;
  v_orphan_onet integer;

  v_cip_rel_id uuid := 'a1000000-0000-0000-0000-000000000001'::uuid;
  v_soc_rel_id uuid := 'a1000000-0000-0000-0000-000000000002'::uuid;
  v_onet_rel_id uuid := 'a1000000-0000-0000-0000-000000000003'::uuid;
begin
  -- Elevate statement timeout within transaction
  perform set_config('statement_timeout', '120000', true);

  -- 1. Verify staged record counts match frozen specifications
  select count(*) into v_cip_stg_count
  from public.stg_external_classification_nodes
  where import_run_id = p_import_run_id and system = 'cip' and version = '2020';

  select count(*) into v_soc_stg_count
  from public.stg_occupation_nodes
  where import_run_id = p_import_run_id and taxonomy_system = 'bls_soc' and taxonomy_version = 'soc_2018';

  select count(*) into v_onet_stg_count
  from public.stg_occupation_nodes
  where import_run_id = p_import_run_id
    and taxonomy_system = 'onet_soc'
    and taxonomy_version = '2019'
    and data_release_version = 'onet_31_0';

  select count(*) into v_map_stg_count
  from public.stg_external_classification_occupation_mappings
  where import_run_id = p_import_run_id;

  select count(*) into v_cip_lin_count
  from public.stg_taxonomy_node_lineage
  where import_run_id = p_import_run_id and source_system = 'cip';

  select count(*) into v_soc_lin_count
  from public.stg_taxonomy_node_lineage
  where import_run_id = p_import_run_id and source_system = 'bls_soc';

  if v_cip_stg_count <> 2809 then
    raise exception 'Staged CIP 2020 nodes count (%) does not match required 2809.', v_cip_stg_count;
  end if;
  if v_soc_stg_count <> 1447 then
    raise exception 'Staged SOC 2018 nodes count (%) does not match required 1447.', v_soc_stg_count;
  end if;
  if v_onet_stg_count <> 1016 then
    raise exception 'Staged O*NET 2019 nodes count (%) does not match required 1016.', v_onet_stg_count;
  end if;
  if v_map_stg_count <> 5723 then
    raise exception 'Staged CIP-SOC mappings count (%) does not match required 5723.', v_map_stg_count;
  end if;
  if v_cip_lin_count <> 2699 then
    raise exception 'Staged CIP lineage count (%) does not match required 2699.', v_cip_lin_count;
  end if;
  if v_soc_lin_count <> 900 then
    raise exception 'Staged SOC lineage count (%) does not match required 900.', v_soc_lin_count;
  end if;

  -- 2. Upsert source releases
  insert into public.taxonomy_source_releases (
    id, source_system, release_version, release_date, source_url, license_name, license_url, attribution_text, metadata
  ) values
    (v_cip_rel_id, 'nces_cip', '2020', '2020-01-01', 'https://nces.ed.gov/ipeds/cipcode/resources.aspx?y=56', 'US_Public_Domain', 'https://www2.ed.gov/notices/copyright/index.html', 'National Center for Education Statistics, U.S. Department of Education', '{"taxonomy": "CIP 2020"}'::jsonb),
    (v_soc_rel_id, 'bls_soc', '2018', '2018-01-01', 'https://www.bls.gov/soc/2018/home.htm', 'US_Public_Domain', 'https://www.bls.gov/bls/linksite.htm', 'Bureau of Labor Statistics, U.S. Department of Labor', '{"taxonomy": "2018 Standard Occupational Classification"}'::jsonb),
    (v_onet_rel_id, 'onet', 'onet_31_0', '2026-08-01', 'https://www.onetcenter.org/db_releases.html', 'CC_BY_4_0', 'https://www.onetcenter.org/license_db.html', 'This product includes information from the O*NET 31.0 Database by the U.S. Department of Labor, Employment and Training Administration (USDOL/ETA), used under CC BY 4.0. O*NET® is a trademark of USDOL/ETA.', '{"taxonomy": "O*NET-SOC 2019", "database_release": "31.0"}'::jsonb)
  on conflict (source_system, release_version) do update set
    source_url = excluded.source_url,
    attribution_text = excluded.attribution_text,
    metadata = excluded.metadata,
    retrieved_at = now();

  -- 3. Upsert artifacts from staging
  insert into public.taxonomy_source_artifacts (
    source_release_id, artifact_name, source_url, retrieval_url, sha256, file_size_bytes, retrieved_at, metadata
  )
  select
    case
      when s.source_system = 'nces_cip' then v_cip_rel_id
      when s.source_system = 'bls_soc' then v_soc_rel_id
      else v_onet_rel_id
    end,
    s.artifact_name,
    s.source_url,
    s.retrieval_url,
    s.sha256,
    s.file_size_bytes,
    now(),
    s.metadata
  from public.stg_taxonomy_source_artifacts s
  where s.import_run_id = p_import_run_id
  on conflict (source_release_id, artifact_name) do update set
    source_url = excluded.source_url,
    retrieval_url = excluded.retrieval_url,
    sha256 = excluded.sha256,
    file_size_bytes = excluded.file_size_bytes,
    retrieved_at = now(),
    metadata = excluded.metadata;

  -- 4. Upsert CIP Nodes (external_classification_nodes)
  -- Pass 1: Upsert records
  insert into public.external_classification_nodes (
    source_release_id, system, version, code, source_parent_code, level_code, level_depth,
    title, definition, cross_references, illustrative_examples, metadata, is_active
  )
  select
    v_cip_rel_id,
    s.system,
    s.version,
    s.code,
    s.source_parent_code,
    s.level_code,
    s.level_depth,
    s.title,
    s.definition,
    s.cross_references,
    s.illustrative_examples,
    s.metadata,
    true
  from public.stg_external_classification_nodes s
  where s.import_run_id = p_import_run_id
  on conflict (system, version, code) do update set
    source_release_id = excluded.source_release_id,
    source_parent_code = excluded.source_parent_code,
    level_code = excluded.level_code,
    level_depth = excluded.level_depth,
    title = excluded.title,
    definition = excluded.definition,
    cross_references = excluded.cross_references,
    illustrative_examples = excluded.illustrative_examples,
    metadata = excluded.metadata,
    is_active = true;

  -- Pass 2: Reconstruct parent_id within CIP hierarchy
  update public.external_classification_nodes n
  set parent_id = p.id
  from public.external_classification_nodes p
  where n.system = 'cip'
    and n.version = '2020'
    and p.system = 'cip'
    and p.version = '2020'
    and n.source_parent_code is not null
    and p.code = n.source_parent_code
    and (n.parent_id is null or n.parent_id <> p.id);

  -- Pass 3: Reconcile absent CIP nodes (deactivate any old rows not present in official release)
  update public.external_classification_nodes n
  set is_active = false
  where n.system = 'cip'
    and n.version = '2020'
    and n.is_active = true
    and not exists (
      select 1 from public.stg_external_classification_nodes s
      where s.import_run_id = p_import_run_id
        and s.system = 'cip'
        and s.version = '2020'
        and s.code = n.code
    );

  -- 5. Upsert BLS SOC Nodes (occupation_nodes)
  -- Pass 1: Upsert SOC nodes
  insert into public.occupation_nodes (
    code, title, description, level, taxonomy_system, taxonomy_version, data_release_version,
    job_zone, source_release_id, metadata, is_active
  )
  select
    s.code,
    s.title,
    s.description,
    s.level,
    s.taxonomy_system,
    s.taxonomy_version,
    s.data_release_version,
    s.job_zone,
    v_soc_rel_id,
    s.metadata,
    true
  from public.stg_occupation_nodes s
  where s.import_run_id = p_import_run_id
    and s.taxonomy_system = 'bls_soc'
  on conflict (taxonomy_system, taxonomy_version, data_release_version, code) do update set
    title = excluded.title,
    description = excluded.description,
    level = excluded.level,
    job_zone = excluded.job_zone,
    source_release_id = excluded.source_release_id,
    metadata = excluded.metadata,
    is_active = true,
    updated_at = now();

  -- Pass 2: Reconstruct SOC parent_id
  -- 2a. Minor groups -> Major groups (e.g. 15-1200 -> 15-0000)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'minor_group'
    and p.level = 'major_group'
    and p.code = substring(o.code from 1 for 2) || '-0000'
    and (o.parent_id is null or o.parent_id <> p.id);

  -- 2b. Broad occupations -> Minor groups (standard 5-char e.g. 15-1250 -> 15-1200)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'broad_occupation'
    and p.level = 'minor_group'
    and p.code = substring(o.code from 1 for 5) || '00'
    and (o.parent_id is null or o.parent_id <> p.id);

  -- 2c. Broad occupations -> Minor groups (overflow 4-char e.g. 11-9110 -> 11-9000, 29-1210 -> 29-1000)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'broad_occupation'
    and o.parent_id is null
    and p.level = 'minor_group'
    and p.code = substring(o.code from 1 for 4) || '000';

  -- 2c-fallback. Broad occupations fallback -> Major groups (if minor missing)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'broad_occupation'
    and o.parent_id is null
    and p.level = 'major_group'
    and p.code = substring(o.code from 1 for 2) || '-0000';

  -- 2d. Detailed occupations -> Broad occupations (standard 6-char e.g. 15-1252 -> 15-1250)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'detailed_occupation'
    and p.level = 'broad_occupation'
    and p.code = substring(o.code from 1 for 6) || '0'
    and (o.parent_id is null or o.parent_id <> p.id);

  -- 2e. Detailed occupations -> Broad occupations (Physicians 29-1221..29-1229 -> 29-1210)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'detailed_occupation'
    and o.code in ('29-1221', '29-1222', '29-1223', '29-1224', '29-1229')
    and p.level = 'broad_occupation'
    and p.code = '29-1210'
    and (o.parent_id is null or o.parent_id <> p.id);

  -- 2f. Detailed occupations fallback -> Minor groups (if broad missing)
  update public.occupation_nodes o
  set parent_id = p.id
  from public.occupation_nodes p
  where o.taxonomy_system = 'bls_soc'
    and o.taxonomy_version = 'soc_2018'
    and p.taxonomy_system = 'bls_soc'
    and p.taxonomy_version = 'soc_2018'
    and o.level = 'detailed_occupation'
    and o.parent_id is null
    and p.level = 'minor_group'
    and (
      p.code = substring(o.code from 1 for 5) || '00' or
      p.code = substring(o.code from 1 for 4) || '000'
    );

  -- 6. Upsert O*NET Nodes (occupation_nodes)
  insert into public.occupation_nodes (
    code, title, description, level, taxonomy_system, taxonomy_version, data_release_version,
    job_zone, source_release_id, parent_id, metadata, is_active
  )
  select
    s.code,
    s.title,
    s.description,
    s.level,
    s.taxonomy_system,
    s.taxonomy_version,
    s.data_release_version,
    s.job_zone,
    v_onet_rel_id,
    p.id,
    s.metadata,
    true
  from public.stg_occupation_nodes s
  join public.occupation_nodes p
    on p.taxonomy_system = 'bls_soc'
   and p.taxonomy_version = 'soc_2018'
   and p.code = split_part(s.code, '.', 1)
  where s.import_run_id = p_import_run_id
    and s.taxonomy_system = 'onet_soc'
    and s.taxonomy_version = '2019'
    and s.data_release_version = 'onet_31_0'
  on conflict (taxonomy_system, taxonomy_version, data_release_version, code) do update set
    title = excluded.title,
    description = excluded.description,
    job_zone = excluded.job_zone,
    parent_id = excluded.parent_id,
    source_release_id = excluded.source_release_id,
    metadata = excluded.metadata,
    is_active = true,
    updated_at = now();

  -- Reconcile absent SOC/O*NET nodes
  update public.occupation_nodes o
  set is_active = false
  where o.is_active = true
    and (
      (o.taxonomy_system = 'bls_soc' and o.taxonomy_version = 'soc_2018' and not exists (
        select 1 from public.stg_occupation_nodes s
        where s.import_run_id = p_import_run_id
          and s.taxonomy_system = 'bls_soc'
          and s.taxonomy_version = 'soc_2018'
          and s.code = o.code
      )) or
      (o.taxonomy_system = 'onet_soc' and o.taxonomy_version = '2019' and o.data_release_version = 'onet_31_0' and not exists (
        select 1 from public.stg_occupation_nodes s
        where s.import_run_id = p_import_run_id
          and s.taxonomy_system = 'onet_soc'
          and s.taxonomy_version = '2019'
          and s.data_release_version = 'onet_31_0'
          and s.code = o.code
      ))
    );

  -- 7. Upsert CIP-SOC Crosswalk
  create temp table tmp_staged_mappings on commit drop as
  select
    c.id as classification_node_id,
    o.id as occupation_id,
    v_cip_rel_id as source_release_id,
    s.mapping_source,
    s.mapping_version,
    s.mapping_kind,
    s.source_notes
  from public.stg_external_classification_occupation_mappings s
  join public.external_classification_nodes c
    on c.system = s.classification_system
   and c.version = s.classification_version
   and c.code = s.classification_code
  join public.occupation_nodes o
    on o.taxonomy_system = s.occupation_system
   and o.taxonomy_version = s.occupation_version
   and o.code = s.occupation_code
  where s.import_run_id = p_import_run_id;

  create index tmp_stg_map_idx on tmp_staged_mappings(classification_node_id, occupation_id);

  insert into public.external_classification_occupation_mappings (
    classification_node_id, occupation_id, source_release_id, mapping_source, mapping_version, mapping_kind, source_notes
  )
  select
    classification_node_id, occupation_id, source_release_id, mapping_source, mapping_version, mapping_kind, source_notes
  from tmp_staged_mappings
  on conflict (classification_node_id, occupation_id, source_release_id) do update set
    mapping_source = excluded.mapping_source,
    mapping_version = excluded.mapping_version,
    mapping_kind = excluded.mapping_kind,
    source_notes = excluded.source_notes;

  -- Reconcile deleted official crosswalk mappings for this release
  delete from public.external_classification_occupation_mappings m
  where m.source_release_id = v_cip_rel_id
    and m.mapping_source = 'nces_bls_crosswalk_2020'
    and m.mapping_version = '2020'
    and not exists (
      select 1
      from tmp_staged_mappings s
      where s.classification_node_id = m.classification_node_id
        and s.occupation_id = m.occupation_id
    );

  -- 8. Upsert Lineage from staging with exact reconciliation
  create temp table tmp_staged_lineage on commit drop as
  select
    s.source_system,
    s.from_version,
    coalesce(s.from_code, '') as from_code_key,
    s.from_code,
    s.to_version,
    coalesce(s.to_code, '') as to_code_key,
    s.to_code,
    s.transition_type,
    s.notes,
    s.metadata
  from public.stg_taxonomy_node_lineage s
  where s.import_run_id = p_import_run_id;

  create index tmp_stg_lin_idx on tmp_staged_lineage(
    source_system, from_version, from_code_key, to_version, to_code_key, transition_type
  );

  -- Reconcile absent lineage edges for official CIP 2010 -> 2020 release
  delete from public.taxonomy_node_lineage l
  where l.source_system = 'cip'
    and l.from_version = '2010'
    and l.to_version = '2020'
    and not exists (
      select 1
      from tmp_staged_lineage s
      where s.source_system = 'cip'
        and s.from_version = '2010'
        and s.to_version = '2020'
        and s.from_code_key = coalesce(l.from_code, '')
        and s.to_code_key = coalesce(l.to_code, '')
        and s.transition_type = l.transition_type
    );

  -- Reconcile absent lineage edges for official SOC 2010 -> 2018 release
  delete from public.taxonomy_node_lineage l
  where l.source_system = 'bls_soc'
    and l.from_version = '2010'
    and l.to_version = '2018'
    and not exists (
      select 1
      from tmp_staged_lineage s
      where s.source_system = 'bls_soc'
        and s.from_version = '2010'
        and s.to_version = '2018'
        and s.from_code_key = coalesce(l.from_code, '')
        and s.to_code_key = coalesce(l.to_code, '')
        and s.transition_type = l.transition_type
    );

  -- Upsert staged lineage
  insert into public.taxonomy_node_lineage (
    source_system, from_version, from_code, to_version, to_code, transition_type, notes, metadata
  )
  select
    source_system, from_version, from_code, to_version, to_code, transition_type, notes, metadata
  from tmp_staged_lineage
  on conflict (
    source_system,
    from_version,
    coalesce(from_code, ''),
    to_version,
    coalesce(to_code, ''),
    transition_type
  ) do update set
    notes = excluded.notes,
    metadata = excluded.metadata;

  -- 9. Transactional Validation Invariants (Exact Counts & Zero Orphans)
  select count(*) into v_cip_active_count
  from public.external_classification_nodes
  where system = 'cip' and version = '2020' and is_active = true;

  select count(*) into v_soc_active_count
  from public.occupation_nodes
  where taxonomy_system = 'bls_soc' and taxonomy_version = 'soc_2018' and is_active = true;

  select count(*) into v_onet_active_count
  from public.occupation_nodes
  where taxonomy_system = 'onet_soc'
    and taxonomy_version = '2019'
    and data_release_version = 'onet_31_0'
    and is_active = true;

  select count(*) into v_map_active_count
  from public.external_classification_occupation_mappings
  where source_release_id = v_cip_rel_id
    and mapping_source = 'nces_bls_crosswalk_2020'
    and mapping_version = '2020';

  select count(*) into v_cip_lin_count
  from public.taxonomy_node_lineage
  where source_system = 'cip' and from_version = '2010' and to_version = '2020';

  select count(*) into v_soc_lin_count
  from public.taxonomy_node_lineage
  where source_system = 'bls_soc' and from_version = '2010' and to_version = '2018';

  if v_cip_active_count <> 2809 then
    raise exception 'Final active CIP count (%) does not match exact source count 2809.', v_cip_active_count;
  end if;
  if v_soc_active_count <> 1447 then
    raise exception 'Final active SOC count (%) does not match exact source count 1447.', v_soc_active_count;
  end if;
  if v_onet_active_count <> 1016 then
    raise exception 'Final active O*NET count (%) does not match exact source count 1016.', v_onet_active_count;
  end if;
  if v_map_active_count <> 5723 then
    raise exception 'Final official CIP-SOC mappings count (%) does not match exact source count 5723.', v_map_active_count;
  end if;
  if v_cip_lin_count <> 2699 then
    raise exception 'Final active CIP 2010 -> 2020 lineage count (%) does not match exact source count 2699.', v_cip_lin_count;
  end if;
  if v_soc_lin_count <> 900 then
    raise exception 'Final active SOC 2010 -> 2018 lineage count (%) does not match exact source count 900.', v_soc_lin_count;
  end if;

  select count(*) into v_orphan_cip from public.external_classification_nodes
  where system = 'cip' and version = '2020' and is_active = true and level_code <> 'series' and parent_id is null;
  if v_orphan_cip <> 0 then
    raise exception 'Integrity error: % orphan CIP non-series nodes exist after finalization.', v_orphan_cip;
  end if;

  select count(*) into v_orphan_soc from public.occupation_nodes
  where taxonomy_system = 'bls_soc' and taxonomy_version = 'soc_2018' and is_active = true and level <> 'major_group' and parent_id is null;
  if v_orphan_soc <> 0 then
    raise exception 'Integrity error: % orphan SOC non-major-group nodes exist after finalization.', v_orphan_soc;
  end if;

  select count(*) into v_orphan_onet from public.occupation_nodes
  where taxonomy_system = 'onet_soc'
    and taxonomy_version = '2019'
    and data_release_version = 'onet_31_0'
    and is_active = true
    and parent_id is null;
  if v_orphan_onet <> 0 then
    raise exception 'Integrity error: % orphan O*NET nodes exist after finalization.', v_orphan_onet;
  end if;

  -- 10. Clean up staging data for this run
  delete from public.stg_taxonomy_source_artifacts where import_run_id = p_import_run_id;
  delete from public.stg_external_classification_nodes where import_run_id = p_import_run_id;
  delete from public.stg_occupation_nodes where import_run_id = p_import_run_id;
  delete from public.stg_external_classification_occupation_mappings where import_run_id = p_import_run_id;
  delete from public.stg_taxonomy_node_lineage where import_run_id = p_import_run_id;

  return jsonb_build_object(
    'status', 'success',
    'import_run_id', p_import_run_id,
    'cip_nodes', v_cip_active_count,
    'soc_nodes', v_soc_active_count,
    'onet_nodes', v_onet_active_count,
    'cip_soc_mappings', v_map_active_count,
    'cip_lineage', v_cip_lin_count,
    'soc_lineage', v_soc_lin_count
  );
end;
$$;

-- Revoke execute from public/anon and grant to service_role
revoke execute on function public.finalize_official_taxonomy_import(uuid) from public, anon, authenticated;
grant execute on function public.finalize_official_taxonomy_import(uuid) to service_role;
