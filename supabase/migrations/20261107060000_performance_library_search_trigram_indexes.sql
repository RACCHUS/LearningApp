-- Improve substring searches used by the Library without changing query semantics.
-- pg_trgm supports ILIKE '%term%' where a conventional B-tree cannot.
create extension if not exists pg_trgm with schema extensions;

create index if not exists learning_targets_title_trgm_idx
  on public.learning_targets using gin (title extensions.gin_trgm_ops);

create index if not exists knowledge_concepts_name_trgm_idx
  on public.knowledge_concepts using gin (name extensions.gin_trgm_ops);

create index if not exists courses_title_trgm_idx
  on public.courses using gin (title extensions.gin_trgm_ops);
