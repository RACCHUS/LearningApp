-- EXM-03 — scoped educational practice-attempt foundation.
-- This table is private, append-only, opt-in at a future application gate.
-- A successful conceptual diagnostic does not automatically create history.
create table if not exists public.exam_part_practice_attempts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references public.learning_targets(id),
  target_version_id uuid not null references public.target_versions(id),
  exam_part_key text not null,
  curriculum_root_node_id uuid not null references public.curriculum_nodes(id),
  practice_kind text not null check (practice_kind in ('diagnostic', 'mock')),
  completed_at timestamptz not null default now(),
  question_count integer not null check (question_count between 1 and 500),
  fully_correct_count integer not null check (fully_correct_count between 0 and question_count),
  partial_count integer not null check (partial_count between 0 and question_count),
  practice_score numeric(8,6) not null check (practice_score between 0 and 1),
  schema_version integer not null default 1 check (schema_version = 1),
  question_edition_fingerprint text not null check (length(question_edition_fingerprint) between 16 and 128),
  created_at timestamptz not null default now(),
  constraint exm03_counts_valid check (fully_correct_count + partial_count <= question_count),
  constraint exm03_part_key_nonempty check (
    exam_part_key = btrim(exam_part_key) and length(exam_part_key) between 1 and 128
  )
);
create index if not exists exm03_practice_owner_part_time
  on public.exam_part_practice_attempts (
    owner_id, target_version_id, exam_part_key, completed_at desc, id desc
  );
alter table public.exam_part_practice_attempts enable row level security;
revoke all on public.exam_part_practice_attempts from anon;
revoke all on public.exam_part_practice_attempts from authenticated;
grant select, delete on public.exam_part_practice_attempts to authenticated;
-- No direct INSERT or UPDATE: only a separately reviewed server-side
-- canonical-scoring transaction may append a verified practice attempt.
create policy exm03_attempt_select_owner
  on public.exam_part_practice_attempts for select to authenticated
  using (owner_id = (select auth.uid()));
create policy exm03_attempt_delete_owner
  on public.exam_part_practice_attempts for delete to authenticated
  using (owner_id = (select auth.uid()));
comment on table public.exam_part_practice_attempts is
  'EXM-03 private owner-only practice history foundation. No client INSERT, no UPDATE, no official score; future canonical server transaction required.';
