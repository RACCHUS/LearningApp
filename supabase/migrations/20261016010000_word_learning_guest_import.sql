-- W1 guest transfer: stable import provenance enables retry-safe list import.
-- The imported list stays owned by the current signed-in user; data from another
-- account is never queried or reassigned across RLS boundaries.
alter table public.word_lists
  add column if not exists import_origin text;

create unique index if not exists word_lists_import_origin_unique
  on public.word_lists (user_id, import_origin)
  where import_origin is not null;
