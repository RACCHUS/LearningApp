-- EXM-03: secure the browser-to-canonical-scorer boundary and prevent
-- protected independently approved exam answer keys leaking through legacy
-- assessment_items SELECT('*') policies.
-- No write is performed against hosted learner data by committing this file.

-- The issuer inserts assignments without providing this column. The default
-- binds newly issued learner practice to the same verified JWT session.
-- Synthetic/backend-only assignments have null; public submit fails closed.
alter table public.exam_part_practice_assignments
  add column issued_session_id uuid
    default (nullif(auth.jwt()->>'session_id',''))::uuid;

create index exm03_assignment_owner_session_idx
 on public.exam_part_practice_assignments
 (owner_id,issued_session_id,issued_at desc);

create function public.exm03_submit_assigned_practice(
  p_assignment_id uuid,
  p_responses jsonb
)
returns jsonb
language plpgsql volatile security definer
set search_path=pg_catalog,public,pg_temp
as $submit$
declare
  actor_id uuid;
  active_session uuid;
  matching_assignment public.exam_part_practice_assignments%rowtype;
  result jsonb;
begin
  actor_id := (select auth.uid());
  if actor_id is null
     or (auth.jwt()->>'role') is distinct from 'authenticated'
     or (auth.jwt()->>'is_anonymous') is distinct from 'false'
     or coalesce(auth.jwt()->>'session_id','') !~
          '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
     or p_assignment_id is null
     or p_responses is null
     or jsonb_typeof(p_responses) is distinct from 'object'
     or pg_column_size(p_responses) > 65536 then
    raise exception 'Live permanent session and bounded responses required'
      using errcode='42501';
  end if;
  active_session := (auth.jwt()->>'session_id')::uuid;

  if not exists (
    select 1 from auth.sessions s
    where s.id=active_session and s.user_id=actor_id
      and (s.not_after is null or s.not_after>now())
  ) then
    raise exception 'Authentication session is no longer active'
      using errcode='42501';
  end if;

  -- Neither the user ID nor the issued session may be client-provided.
  -- Assignment locks in the canonical scorer serialize concurrent retries.
  select * into matching_assignment
  from public.exam_part_practice_assignments a
  where a.id=p_assignment_id
    and a.owner_id=actor_id
    and a.issued_session_id=active_session;
  if not found then
    raise exception 'Practice assignment does not belong to this session'
      using errcode='42501';
  end if;

  -- No untrusted grader, question IDs, correct answer, version, or score
  -- arguments are accepted. This function inherits the backend's protected
  -- canonical scorer and all of its review/replay validations.
  result := public.exm03_record_assigned_practice(
    p_assignment_id,p_responses);

  -- Complete writes are still subject to same-session verification.
  if not exists (
    select 1 from auth.sessions s
    where s.id=active_session and s.user_id=actor_id
      and (s.not_after is null or s.not_after>now())
  ) then
    raise exception 'Session ended during practice submission'
      using errcode='42501';
  end if;
  return result;
end
$submit$;

revoke all on function public.exm03_submit_assigned_practice(uuid,jsonb)
  from public,anon,authenticated;
grant execute on function public.exm03_submit_assigned_practice(uuid,jsonb)
  to authenticated;
comment on function public.exm03_submit_assigned_practice(uuid,jsonb) is
 'Exact live-session owner-bound educational practice submission. Calls private canonical scorer; identity from verified JWT only. Never an official examination result.';

-- Existing learning activities consume assessment_items directly.
-- Approved EXM-02A question bindings have a protected scoring_spec; exclude
-- precisely those items from direct anon/authenticated table reads, including
-- permissive owner and lesson policies. Trusted canonical issuer is the safe
-- read path, while the private grader retains privileged access.
create function public.exm03_has_protected_binding(p_item_id uuid)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,pg_temp
as $private$
  select exists (
    select 1 from public.assessment_item_reference_validity b
    where b.assessment_item_id=p_item_id
      and b.publication_status='published'
      and b.review_status='approved'
      and b.rights_review_status='approved'
  );
$private$;
revoke all on function public.exm03_has_protected_binding(uuid)
  from public,anon,authenticated;
grant execute on function public.exm03_has_protected_binding(uuid)
  to anon,authenticated;

create policy exm03_no_direct_read_of_approved_answers
 on public.assessment_items
 as restrictive for select to anon,authenticated
 using (not public.exm03_has_protected_binding(id));

comment on policy exm03_no_direct_read_of_approved_answers
 on public.assessment_items is
 'Prevent direct learner or anon scoring_spec exposure for independently approved published exam items; read their safe projection via the authenticated practice issuer. Other legacy items remain unaffected.';

-- Approved items must not bypass through a normal SELECT(*) or
-- owner/lesson version visibility policy. No client editor can read their
-- private canonical scoring rubric through this table.
