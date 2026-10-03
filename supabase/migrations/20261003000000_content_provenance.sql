-- ============================================================================
-- Migration: 20261003000000_content_provenance.sql
-- Description: Traceable Content Provenance Layer
--              Tracks authoritative source releases (e.g. CompTIA SY0-701 blueprint,
--              NCLEX-RN Test Plan, AAMC MCAT guide) and maps curriculum nodes,
--              concepts, lessons, and questions to their exact source citations.
-- ============================================================================

-- 1. Authoritative Source Releases
create table if not exists public.content_source_releases (
  id uuid primary key default gen_random_uuid(),
  publisher text not null,
  title text not null,
  version text not null,
  source_url text,
  retrieved_at timestamptz not null default now(),
  license text,
  sha256 text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (publisher, title, version)
);

create index if not exists content_source_releases_pub_ver_idx
  on public.content_source_releases(publisher, title, version);

create trigger trg_content_source_releases_touch
  before update on public.content_source_releases
  for each row execute function public.touch_updated_at();

-- 2. Content Source Mappings (Traceability Junction)
create table if not exists public.content_source_mappings (
  id uuid primary key default gen_random_uuid(),
  source_release_id uuid not null
    references public.content_source_releases(id) on delete cascade,
  entity_type text not null
    check (entity_type in ('target_version', 'curriculum_node', 'lesson', 'knowledge_concept', 'question', 'flashcard')),
  entity_id uuid not null,
  relationship text not null default 'derived_from'
    check (relationship in ('official_blueprint', 'primary_text', 'derived_from', 'reference_citation', 'standards_benchmark')),
  citation_location text,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (source_release_id, entity_type, entity_id, relationship)
);

create index if not exists content_source_mappings_entity_idx
  on public.content_source_mappings(entity_type, entity_id);

create index if not exists content_source_mappings_release_idx
  on public.content_source_mappings(source_release_id);

-- 3. Row-Level Security
alter table public.content_source_releases enable row level security;
alter table public.content_source_mappings enable row level security;

-- Read policies: Published provenance citations are transparent and readable to all learners & guests
drop policy if exists "content_source_releases_read" on public.content_source_releases;
create policy "content_source_releases_read" on public.content_source_releases
  for select to authenticated, anon
  using (true);

drop policy if exists "content_source_mappings_read" on public.content_source_mappings;
create policy "content_source_mappings_read" on public.content_source_mappings
  for select to authenticated, anon
  using (true);

-- Write policies: Provenance ingestion and administrative publication via service role
drop policy if exists "content_source_releases_service_write" on public.content_source_releases;
create policy "content_source_releases_service_write" on public.content_source_releases
  for all to authenticated
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

drop policy if exists "content_source_mappings_service_write" on public.content_source_mappings;
create policy "content_source_mappings_service_write" on public.content_source_mappings
  for all to authenticated
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
