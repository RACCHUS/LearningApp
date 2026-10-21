-- EXM-02B foundation: durable, owner-isolated, UNGRADED drill step events.
-- Version-pinned attempts without exposing approved answer keys or inventing
-- verified correctness. Client-submitted times and completion are self-reported.
-- No hosted migration is applied by committing this file.

create table public.exam_reference_drill_events (
  id uuid primary key default gen_random_uuid(),
  owner_auth_uid uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  client_attempt_id uuid not null,
  assessment_item_id uuid not null
    references public.assessment_items(id) on delete restrict,
  approved_binding_id uuid not null
    references public.assessment_item_reference_validity(id) on delete restrict,
  manifest_revision_id uuid not null
    references public.exam_reference_manifest_revisions(id) on delete restrict,
  exam_part_key text not null
    check (exam_part_key ~ '^[a-z][a-z0-9_]*$'),
  administration_date date not null,
  item_content_revision integer not null check (item_content_revision > 0),
  answer_location_revision integer not null check (answer_location_revision > 0),
  drill_step text not null check (
    drill_step in (
      'resource_choice', 'section_location', 'interpretation', 'application'
    )),
  -- This is *not* a scored answer or a verified mastery claim. The client
  -- never receives the private editor-approved answer locations from here.
  responded boolean not null,
  app_elapsed_ms integer not null
    check (app_elapsed_ms between 0 and 86400000),
  self_reported_book_ms integer
    check (self_reported_book_ms between 0 and 86400000),
  started_at timestamptz not null,
  completed_at timestamptz not null,
  verification_state text not null default 'unverified'
    check (verification_state='unverified'),
  recorded_at timestamptz not null default now(),
  constraint exam_drill_event_time_order check (completed_at >= started_at),
  constraint exam_drill_event_elapsed_bound check (
    completed_at - started_at <= interval '2 days'
  ),
  constraint exam_drill_one_step_per_attempt
    unique(owner_auth_uid,client_attempt_id,drill_step)
);

create index exam_drill_events_owner_newest
  on public.exam_reference_drill_events(owner_auth_uid,recorded_at desc);
create index exam_drill_events_manifest_aggregate
  on public.exam_reference_drill_events(manifest_revision_id,drill_step);
comment on table public.exam_reference_drill_events is
  'Private, owner-only, append-only practice events (except user deletion). UNGRADED; duration from client may be self-reported. No hidden answer text or exam passing prediction.';

-- This trigger is privileged solely to validate against private editorial
-- approval rows, and to enforce consistent identity across a drill attempt.
-- Access is NOT offered as an RPC. RLS independently verifies the caller.
create function public.guard_exam_reference_drill_event()
returns trigger
language plpgsql security definer
set search_path = pg_catalog,public,pg_temp
as $guard$
declare
  binding public.assessment_item_reference_validity%rowtype;
  manifest public.exam_reference_manifest_revisions%rowtype;
begin
  if tg_op='DELETE' then
    -- Explicit owner deletion is allowed for privacy; cannot edit history.
    return old;
  end if;
  if tg_op='UPDATE' then
    raise exception 'Reference drill attempts are append-only';
  end if;

  -- Server receive time must not be spoofable by client payloads.
  new.recorded_at := now();
  if new.completed_at > now() + interval '5 minutes'
     or new.started_at > now() + interval '5 minutes' then
    raise exception 'Future-dated drill events are not accepted';
  end if;

  select * into binding from public.assessment_item_reference_validity
    where id=new.approved_binding_id;
  if not found or binding.publication_status <> 'published'
     or binding.review_status <> 'approved'
     or binding.rights_review_status <> 'approved'
     or binding.assessment_item_id <> new.assessment_item_id
     or binding.manifest_revision_id <> new.manifest_revision_id
     or binding.item_content_revision <> new.item_content_revision
     or binding.answer_location_revision <> new.answer_location_revision
     or binding.item_content_sha256 is distinct from
       public.exam_reference_item_fingerprint(new.assessment_item_id) then
    raise exception 'No matching approved and untampered answer binding exists';
  end if;

  select * into manifest from public.exam_reference_manifest_revisions
    where id=new.manifest_revision_id;
  if not found or manifest.publication_status <> 'published'
     or manifest.exam_part_key <> new.exam_part_key
     or new.administration_date < manifest.effective_from
     or (manifest.effective_until is not null
       and new.administration_date > manifest.effective_until) then
    raise exception 'Reference manifest is unavailable for this exam part/date';
  end if;

  if exists (
    select 1 from public.exam_reference_drill_events previous
    where previous.owner_auth_uid=new.owner_auth_uid
      and previous.client_attempt_id=new.client_attempt_id
      and (
        previous.assessment_item_id <> new.assessment_item_id
        or previous.approved_binding_id <> new.approved_binding_id
        or previous.manifest_revision_id <> new.manifest_revision_id
        or previous.exam_part_key <> new.exam_part_key
        or previous.administration_date <> new.administration_date
      )
  ) then
    raise exception 'Attempt cannot mix items, bindings, manifests or exam dates';
  end if;
  return new;
end
$guard$;

revoke all on function public.guard_exam_reference_drill_event()
  from public,anon,authenticated;

create trigger trg_guard_exam_reference_drill_event
before insert or update or delete on public.exam_reference_drill_events
for each row execute function public.guard_exam_reference_drill_event();

alter table public.exam_reference_drill_events enable row level security;
revoke all on public.exam_reference_drill_events from public,anon,authenticated;
grant select,insert,delete on public.exam_reference_drill_events to authenticated;
grant select,insert,delete on public.exam_reference_drill_events to service_role;

-- Anonymous Supabase Auth guests also use the authenticated DB role. Require
-- a *permanent* authenticated user and exact auth.uid, not merely TO role.
create policy exm_drill_permanent_owner_select
  on public.exam_reference_drill_events
  for select to authenticated
  using (
    owner_auth_uid = (select auth.uid())
    and (select (auth.jwt()->>'is_anonymous')::boolean) is false
  );
create policy exm_drill_permanent_owner_insert
  on public.exam_reference_drill_events
  for insert to authenticated
  with check (
    owner_auth_uid = (select auth.uid())
    and (select (auth.jwt()->>'is_anonymous')::boolean) is false
  );
create policy exm_drill_permanent_owner_delete
  on public.exam_reference_drill_events
  for delete to authenticated
  using (
    owner_auth_uid = (select auth.uid())
    and (select (auth.jwt()->>'is_anonymous')::boolean) is false
  );

-- No authenticated UPDATE policy/grant; no guest or public access. Service
-- validators must never upgrade this untrusted client event to official
-- scored evidence without server-side answer checking in a separate phase.
