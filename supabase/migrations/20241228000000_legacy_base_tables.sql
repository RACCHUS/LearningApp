-- Bootstrap the legacy public tables that predate supabase/migrations.
-- Existing installations already have these tables, so this migration is
-- intentionally idempotent. Do not restore the old RLS policies here:
-- 20260528000000_secure_rls_with_anonymous_guests.sql defines their secure
-- replacements.

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  created_at timestamptz default now(),
  display_name text
);

create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  tags text[] default '{}',
  emoji text,
  user_id uuid references public.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.terms (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  term text not null,
  definition text not null,
  example text,
  emoji text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  user_id uuid references public.users(id)
);

create table if not exists public.concepts (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  concept_text text not null,
  example_text text,
  key_points text[],
  emoji text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  user_id uuid references public.users(id)
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  question_text text not null,
  options jsonb not null,
  correct_answer integer not null,
  type text default 'mcq' check (type in ('mcq', 'true_false', 'short_answer')),
  explanation text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  user_id uuid references public.users(id)
);

create table if not exists public.user_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete cascade,
  date date default current_date,
  questions_answered integer default 0,
  correct_count integer default 0,
  lesson_completed boolean default false,
  study_time_minutes integer default 0,
  study_time_seconds integer default 0,
  unique (user_id, lesson_id, date)
);

create table if not exists public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  time_of_day time not null,
  frequency text default 'daily' check (frequency in ('daily', 'weekdays', 'custom')),
  mode text default 'lesson' check (mode in ('lesson', 'flashcard', 'quiz')),
  goal_count integer default 5,
  is_active boolean default true
);

create table if not exists public.offline_content (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  lesson_id uuid references public.lessons(id) on delete cascade,
  cached_at timestamptz default now(),
  unique (user_id, lesson_id)
);
