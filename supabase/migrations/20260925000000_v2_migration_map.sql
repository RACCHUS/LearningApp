-- Migration mapping table for Learning Architecture v2.
-- Preserves idempotent mappings between legacy v1 string IDs (e.g. career_paths, courses, lessons)
-- and new v2 UUID primary keys.

create table if not exists public.v2_migration_map (
  legacy_type text not null,
  legacy_id text not null,
  v2_type text not null,
  v2_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (legacy_type, legacy_id, v2_type)
);

create index if not exists v2_migration_map_v2_lookup_idx
  on public.v2_migration_map (v2_type, v2_id);

alter table public.v2_migration_map enable row level security;

-- Read access is permitted for all clients to resolve legacy-to-v2 references
drop policy if exists "v2_migration_map_read" on public.v2_migration_map;
create policy "v2_migration_map_read"
  on public.v2_migration_map
  for select
  using (true);
