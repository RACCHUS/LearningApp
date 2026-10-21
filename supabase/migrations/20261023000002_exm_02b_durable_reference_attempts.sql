-- EXM-02B: private owner-scoped, server-scored reference mastery evidence.
-- Additive technical foundation only; no real pilot, sample scores or live writes.
-- Never accept "verified" correctness directly from a browser client.

create table public.exam_reference_drill_attempts (
  id uuid primary key default gen_random_uuid(),
  owner_auth_user_id uuid not null
    references auth.users(id) on delete cascade,
  client_attempt_key uuid not null,
  step_ordinal integer not null check (step_ordinal between 1 and 4),
  target_version_id uuid not null
    references public.target_versions(id) on delete restrict,
  exam_part_key text not null
    check (exam_part_key ~ '^[a-z][a-z0-9_]*$'),
  intended_exam_date date not null,
  manifest_revision_id uuid not null
    references public.exam_reference_manifest_revisions(id) on delete restrict,
  answer_binding_id uuid not null
    references public.assessment_item_reference_validity(id) on delete restrict,
  assessment_item_id uuid not null
    references public.assessment_items(id) on delete restrict,
  item_content_revision integer not null check (item_content_revision > 0),
  answer_location_revision integer not null check (answer_location_revision > 0),
  drill_mode text not null
    check (drill_mode in ('r1','r2','r3','r4')),
  skill_step text not null
    check (skill_step in ('choose_reference','locate_section','interpret','solve')),
  scoring_version text not null
    check (length(btrim(scoring_version)) between 1 and 80),
  scored_correct boolean not null,
  app_elapsed_ms integer not null
    check (app_elapsed_ms between 0 and 86400000),
  physical_book_self_reported_minutes integer
    check (physical_book_self_reported_minutes between 0 and 1440),
  started_at timestamptz not null,
  completed_at timestamptz not null,
  created_at timestamptz not null default now(),
  retention_policy text not null default 'until_user_deletes'
    check (retention_policy = 'until_user_deletes'),
  unique (owner_auth_user_id,client_attempt_key,step_ordinal),
  constraint exam_attempt_clock_order
    check (completed_at >= started_at),
  constraint exam_attempt_mode_skill check (
    drill_mode='r4' or (drill_mode='r1' and skill_step='choose_reference')
    or (drill_mode='r2' and skill_step='locate_section')
    or (drill_mode='r3' and skill_step='interpret'))
);

create index exam_reference_drill_attempts_owner_recent_idx
  on public.exam_reference_drill_attempts
    (owner_auth_user_id,completed_at desc);
create index exam_reference_drill_attempts_manifest_idx
  on public.exam_reference_drill_attempts
    (manifest_revision_id,assessment_item_id);

comment on table public.exam_reference_drill_attempts is
  'Auth-owned append-only server-scored drill outcomes. No raw answers or reviewer-only data. Browser cannot insert or update; owner can read/delete. Explicit retention until user deletes or account deletion.';

create function public.guard_exam_reference_drill_attempt()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,public
as $$
declare
  binding public.assessment_item_reference_validity%rowtype;
  manifest public.exam_reference_manifest_revisions%rowtype;
begin
  if tg_op = 'UPDATE' then
    raise exception 'Drill attempts are immutable; only delete or append';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;

  select * into binding from public.assessment_item_reference_validity
  where id=new.answer_binding_id;
  if not found or binding.publication_status <> 'published'
    or binding.assessment_item_id <> new.assessment_item_id
    or binding.manifest_revision_id <> new.manifest_revision_id
    or binding.item_content_revision <> new.item_content_revision
    or binding.answer_location_revision <> new.answer_location_revision then
    raise exception 'An approved exact-version item binding is required for a durable attempt';
  end if;

  select * into manifest from public.exam_reference_manifest_revisions
  where id=new.manifest_revision_id;
  if not found or manifest.publication_status <> 'published'
    or manifest.target_version_id <> new.target_version_id
    or manifest.exam_part_key <> new.exam_part_key
    or new.intended_exam_date < manifest.effective_from
    or (manifest.effective_until is not null
        and new.intended_exam_date > manifest.effective_until) then
    raise exception 'Attempt must match the published part and reference edition for the intended exam date';
  end if;
  return new;
end
$$;
revoke all on function public.guard_exam_reference_drill_attempt()
  from public,anon,authenticated;

create trigger trg_guard_exam_reference_drill_attempt
  before insert or update or delete
  on public.exam_reference_drill_attempts
  for each row execute function public.guard_exam_reference_drill_attempt();

alter table public.exam_reference_drill_attempts enable row level security;
revoke all on public.exam_reference_drill_attempts
  from public,anon,authenticated;
grant select,delete on public.exam_reference_drill_attempts
  to authenticated;
grant select,insert,delete on public.exam_reference_drill_attempts
  to service_role;

create policy exam_reference_drill_attempt_owner_read
  on public.exam_reference_drill_attempts for select to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) = owner_auth_user_id
  );

create policy exam_reference_drill_attempt_owner_delete
  on public.exam_reference_drill_attempts for delete to authenticated
  using (
    (select auth.uid()) is not null
    and (select auth.uid()) = owner_auth_user_id
  );

-- Never grant INSERT/UPDATE to authenticated or anon. A future trusted
-- server scorer must verify the real authenticated subject, approved item
-- binding and attempt idempotency before invoking service_role writes.
-- Deletion is available for the owning account; auth-user deletion cascades.
