-- =============================================================================
-- Migration 62: ECO-02 Author Review Feedback, Context & Internal Notes Separation
--
-- Addresses educator review follow-up findings:
-- 1. Adds internal_notes to public.community_review_audit to separate confidential
--    moderation rationale from learner-facing editorial feedback.
-- 2. Updates review_community_question and review_community_answer RPCs to accept
--    both p_notes (author feedback) and p_internal_notes (internal moderation).
-- 3. Introduces public.fetch_my_submission_feedback(p_target_id uuid) allowing
--    authors to retrieve actionable decision feedback for their own submissions
--    without exposing reviewer identity, internal notes, or other users' audits.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Schema Enhancement: Separate Internal Moderation Notes on Review Audit
-- -----------------------------------------------------------------------------
alter table public.community_review_audit
  add column if not exists internal_notes text;

-- -----------------------------------------------------------------------------
-- 2. Hardened Question Review RPC (Accepts Author Feedback & Internal Notes)
-- -----------------------------------------------------------------------------
drop function if exists public.review_community_question(uuid, text, text);

create or replace function public.review_community_question(
  p_question_id uuid,
  p_action text,
  p_notes text default null,
  p_internal_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_question record;
  v_new_status text;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null or not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges'
      using errcode = '42501';
  end if;

  if p_action not in ('publish', 'reject', 'archive') then
    raise exception 'Invalid review action: %', p_action
      using errcode = '22023';
  end if;

  select * into v_question
    from public.community_questions
   where id = p_question_id
     for update;

  if not found then
    raise exception 'Question % not found', p_question_id
      using errcode = 'P0002';
  end if;

  -- Public UGC Launch Gate: Non-seeded learner questions cannot be published until public UGC is enabled
  if p_action = 'publish' and not v_question.is_seeded and not private.is_community_ugc_public_enabled() then
    raise exception 'Public learner UGC is currently disabled. Learner questions cannot be published before operational launch clearance.'
      using errcode = '22000';
  end if;

  v_new_status := case
    when p_action = 'publish' then 'published'
    when p_action = 'reject' then 'archived'
    when p_action = 'archive' then 'archived'
  end;

  -- Allow internal modification of status and updated_at
  perform set_config('community.internal_counter_update', 'true', true);

  update public.community_questions
     set status = v_new_status,
         updated_at = now()
   where id = p_question_id;

  -- Insert durable audit record separating learner feedback (notes) and confidential notes (internal_notes)
  insert into public.community_review_audit (
    target_type, target_id, reviewer_id, action, previous_status, new_status, notes, internal_notes
  ) values (
    'question', p_question_id, v_caller_id, p_action, v_question.status, v_new_status, p_notes, p_internal_notes
  );

  return jsonb_build_object(
    'success', true,
    'question_id', p_question_id,
    'action', p_action,
    'previous_status', v_question.status,
    'status', v_new_status,
    'notes', p_notes,
    'internal_notes', p_internal_notes
  );
end;
$$;

revoke all on function public.review_community_question(uuid, text, text, text) from public, anon;
grant execute on function public.review_community_question(uuid, text, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. Hardened Answer Review RPC (Accepts Author Feedback & Internal Notes)
-- -----------------------------------------------------------------------------
drop function if exists public.review_community_answer(uuid, text, text);

create or replace function public.review_community_answer(
  p_answer_id uuid,
  p_action text,
  p_notes text default null,
  p_internal_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_answer record;
  v_parent_question record;
  v_new_status text;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null or not private.is_moderator() then
    raise exception 'Access denied: caller does not possess moderator privileges'
      using errcode = '42501';
  end if;

  if p_action not in ('publish', 'reject', 'archive', 'flag') then
    raise exception 'Invalid review action: %', p_action
      using errcode = '22023';
  end if;

  select * into v_answer
    from public.community_answers
   where id = p_answer_id
     for update;

  if not found then
    raise exception 'Answer % not found', p_answer_id
      using errcode = 'P0002';
  end if;

  select * into v_parent_question
    from public.community_questions
   where id = v_answer.question_id;

  if not found then
    raise exception 'Parent question not found'
      using errcode = 'P0002';
  end if;

  if p_action = 'publish' then
    if v_parent_question.status <> 'published' then
      raise exception 'Cannot publish answer for non-published parent question'
        using errcode = '22000';
    end if;

    if not v_answer.is_seeded and not private.is_community_ugc_public_enabled() then
      raise exception 'Public learner UGC is currently disabled. Learner answers cannot be published before operational launch clearance.'
        using errcode = '22000';
    end if;

    v_new_status := 'published';
  elsif p_action = 'reject' or p_action = 'archive' then
    v_new_status := 'archived';
  elsif p_action = 'flag' then
    v_new_status := 'flagged';
  end if;

  perform set_config('community.internal_counter_update', 'true', true);

  update public.community_answers
     set status = v_new_status,
         updated_at = now()
   where id = p_answer_id;

  -- Insert durable audit record separating learner feedback (notes) and confidential notes (internal_notes)
  insert into public.community_review_audit (
    target_type, target_id, reviewer_id, action, previous_status, new_status, notes, internal_notes
  ) values (
    'answer', p_answer_id, v_caller_id, p_action, v_answer.status, v_new_status, p_notes, p_internal_notes
  );

  return jsonb_build_object(
    'success', true,
    'answer_id', p_answer_id,
    'action', p_action,
    'status', v_new_status,
    'notes', p_notes,
    'internal_notes', p_internal_notes
  );
end;
$$;

revoke all on function public.review_community_answer(uuid, text, text, text) from public, anon;
grant execute on function public.review_community_answer(uuid, text, text, text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. Learner-Facing Decision Feedback Query RPC
--
-- Returns decision feedback strictly for submissions authored by the calling user.
-- Omits reviewer identity, confidential internal notes, and other authors' data.
-- -----------------------------------------------------------------------------
create or replace function public.fetch_my_submission_feedback(
  p_target_id uuid default null
)
returns table (
  id uuid,
  target_type text,
  target_id uuid,
  action text,
  new_status text,
  feedback text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  return query
  select
    cra.id,
    cra.target_type,
    cra.target_id,
    cra.action,
    cra.new_status,
    cra.notes as feedback,
    cra.created_at
  from public.community_review_audit cra
  where (p_target_id is null or cra.target_id = p_target_id)
    and cra.notes is not null
    and (
      (cra.target_type = 'question' and exists (
        select 1 from public.community_questions cq
        where cq.id = cra.target_id and cq.author_id = v_user_id
      ))
      or
      (cra.target_type = 'answer' and exists (
        select 1 from public.community_answers ca
        where ca.id = cra.target_id and ca.author_id = v_user_id
      ))
    )
  order by cra.created_at desc;
end;
$$;

revoke all on function public.fetch_my_submission_feedback(uuid) from public, anon;
grant execute on function public.fetch_my_submission_feedback(uuid) to authenticated, service_role;
