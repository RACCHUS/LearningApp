-- Word Learning W1: private word lists and skill-aware review.
-- Additive only; do not apply to hosted Supabase without explicit authorization.
create table if not exists public.word_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 160),
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists word_lists_user_updated_idx
  on public.word_lists(user_id, updated_at desc);

create table if not exists public.word_list_entries (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.word_lists(id) on delete cascade,
  word text not null check (length(trim(word)) between 1 and 160),
  form_key text not null check (length(form_key) between 1 and 1000),
  locale text not null default 'en-US',
  entry_kind text not null default 'ordinary'
    check (entry_kind in ('ordinary', 'proper_name', 'custom')),
  case_policy text not null default 'ignore_case'
    check (case_policy in ('ignore_case', 'exact')),
  accepted_forms jsonb not null default '[]'::jsonb
    check (jsonb_typeof(accepted_forms) = 'array'),
  pronunciation_hint text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (list_id, form_key)
);

create index if not exists word_list_entries_order_idx
  on public.word_list_entries(list_id, sort_order, created_at);

alter table public.word_lists enable row level security;
alter table public.word_list_entries enable row level security;

create policy word_lists_owner_only on public.word_lists
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy word_list_entries_owner_only on public.word_list_entries
  for all to authenticated
  using (
    exists (select 1 from public.word_lists wl
      where wl.id = word_list_entries.list_id and wl.user_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.word_lists wl
      where wl.id = word_list_entries.list_id and wl.user_id = (select auth.uid()))
  );

-- Existing review_items remains the single review scheduler.
-- A stable content_id such as 'word:v1:<form-key>:spelling' is shared
-- across lists; it is not a foreign key to a word_list_entries row.
alter table public.review_items
  drop constraint if exists review_items_content_type_check;
alter table public.review_items
  add constraint review_items_content_type_check
  check (content_type in ('term', 'question', 'concept', 'flashcard', 'word_skill'));

-- The Dart ReviewableItem serializer already emits 'metadata'. Earlier
-- stored SQL did not declare it. Add safely before W1 persists word reviews.
alter table public.review_items
  add column if not exists metadata jsonb not null default '{}'::jsonb;
