-- Schema drift backfill (P0-hosted audit item B.7).
--
-- The hosted database has four columns that no committed migration creates,
-- so a database built from migrations (CI, self-hosting, fresh installs)
-- differed from production. Definitions below match the hosted columns
-- exactly (read-only information_schema check, 2026-11-13).
--
-- Additive and idempotent: ADD COLUMN IF NOT EXISTS is a no-op where the
-- column already exists (production). No data, policy or function changes.
alter table public.terms     add column if not exists order_index integer default 0;
alter table public.concepts  add column if not exists order_index integer default 0;
alter table public.questions add column if not exists order_index integer default 0;
alter table public.lessons   add column if not exists content jsonb;
