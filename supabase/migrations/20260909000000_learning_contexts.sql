-- Learning contexts and resume pointers.
--
-- A LearningContext is a user-level pointer to whatever the learner is
-- pursuing, at whatever level of the hierarchy that thing lives. This is what
-- makes the Goal > Path > Course > Module > Lesson hierarchy optional: only
-- course/lesson/concept are required, and a bare study set is a first-class
-- root. See UI_ARCHITECTURE_LOCKED.md 4.2.
--
-- `goal` is intentionally absent from the root-type check constraint: no Goal
-- entity exists yet (spec D4). Add it in a later migration alongside the table.

create table if not exists public.learning_contexts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null check (char_length(trim(label)) > 0),
  root_type text not null check (
    root_type in ('path', 'course', 'module', 'lesson', 'studySet')
  ),
  root_id text not null check (char_length(root_id) > 0),
  emoji text,
  last_active_at timestamptz not null default now(),
  is_archived boolean not null default false,
  -- >= 0 pins the context; -1 means "order by last_active_at".
  sort_order integer not null default -1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Makes the client-side backfill idempotent at the database level too: a
-- re-run, a second device, or a Hive/Supabase disagreement cannot duplicate.
create unique index if not exists learning_contexts_dedupe_idx
  on public.learning_contexts (user_id, root_type, root_id);

create index if not exists learning_contexts_active_idx
  on public.learning_contexts (user_id, is_archived, last_active_at desc);

create table if not exists public.resume_pointers (
  context_id uuid primary key
    references public.learning_contexts (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  -- Review sessions are deliberately not resumable (spec D5): a due-set is a
  -- query over items due right now, so a persisted batch would replay items
  -- that have since left the due window.
  kind text not null check (kind in ('lesson', 'studySet')),
  activity_id text not null check (char_length(activity_id) > 0),
  item_index integer check (item_index >= 0),
  -- Breadcrumb only. Nullable by design; nothing may branch on their presence.
  course_id text,
  module_id text,
  updated_at timestamptz not null default now()
);

alter table public.learning_contexts enable row level security;
alter table public.resume_pointers enable row level security;

drop policy if exists "learning_contexts_owner" on public.learning_contexts;
create policy "learning_contexts_owner"
  on public.learning_contexts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "resume_pointers_owner" on public.resume_pointers;
create policy "resume_pointers_owner"
  on public.resume_pointers
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists learning_contexts_touch on public.learning_contexts;
create trigger learning_contexts_touch
  before update on public.learning_contexts
  for each row execute function public.touch_updated_at();

drop trigger if exists resume_pointers_touch on public.resume_pointers;
create trigger resume_pointers_touch
  before update on public.resume_pointers
  for each row execute function public.touch_updated_at();
