-- =============================================================================
-- Migration 56: ECO-01 Community Q&A Access-Control & Counter Hardening
-- Description:
--   1. Separates anonymous public SELECT policies from authenticated author/admin
--      policies, eliminating 42501 execution errors on private.is_admin() for anon.
--   2. Enforces parent-question publication constraints on community_answers
--      select, upvoting, and moderation reporting.
--   3. Installs BEFORE UPDATE tamper-prevention triggers on community_questions
--      and community_answers preventing non-admins from mutating authoritative
--      counters (upvote_count, answer_count, view_count), is_seeded, is_accepted,
--      or timestamps.
--   4. Revokes public/anon execution on trigger functions.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Hardened Community Questions SELECT Policies
-- -----------------------------------------------------------------------------
drop policy if exists community_questions_select_policy on public.community_questions;
drop policy if exists community_questions_public_select_policy on public.community_questions;
drop policy if exists community_questions_auth_select_policy on public.community_questions;

-- Public policy: accessible to anon, authenticated, and service_role without calling private.is_admin()
create policy community_questions_public_select_policy on public.community_questions
  for select
  to anon, authenticated, service_role
  using (status = 'published');

-- Authenticated policy: author access to own drafts & admin oversight
create policy community_questions_auth_select_policy on public.community_questions
  for select
  to authenticated
  using (author_id = auth.uid() or private.is_admin());

-- -----------------------------------------------------------------------------
-- 2. Hardened Community Answers SELECT Policies (Parent Visibility Enforced)
-- -----------------------------------------------------------------------------
drop policy if exists community_answers_select_policy on public.community_answers;
drop policy if exists community_answers_public_select_policy on public.community_answers;
drop policy if exists community_answers_auth_select_policy on public.community_answers;

-- Public policy: answer must be published AND parent question must be published
create policy community_answers_public_select_policy on public.community_answers
  for select
  to anon, authenticated, service_role
  using (
    status = 'published'
    and exists (
      select 1 from public.community_questions q
       where q.id = question_id
         and q.status = 'published'
    )
  );

-- Authenticated policy: author access if parent question is accessible to author or admin
create policy community_answers_auth_select_policy on public.community_answers
  for select
  to authenticated
  using (
    (author_id = auth.uid() and exists (
      select 1 from public.community_questions q
       where q.id = question_id
         and (q.status = 'published' or q.author_id = auth.uid() or private.is_admin())
    ))
    or private.is_admin()
  );

-- -----------------------------------------------------------------------------
-- 3. Tamper-Proofing Authoritative Counters & System Fields (BEFORE UPDATE Triggers)
-- -----------------------------------------------------------------------------
create or replace function public.prevent_community_question_tampering()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Allow authorized internal updates initiated by trusted security-definer RPCs or triggers
  if current_setting('community.internal_counter_update', true) = 'true' then
    return new;
  end if;

  if not private.is_admin() then
    -- Non-admin authors cannot manipulate authoritative counters, seeded flag, or timestamps
    if new.upvote_count <> old.upvote_count or
       new.view_count <> old.view_count or
       new.answer_count <> old.answer_count or
       new.is_seeded <> old.is_seeded or
       new.created_at <> old.created_at or
       new.author_id <> old.author_id then
      raise exception 'Direct modification of system-maintained community question fields is forbidden'
        using errcode = '42501';
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_community_question_tampering on public.community_questions;
create trigger trg_prevent_community_question_tampering
  before update on public.community_questions
  for each row execute function public.prevent_community_question_tampering();

create or replace function public.prevent_community_answer_tampering()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Allow authorized internal updates initiated by trusted security-definer RPCs or triggers
  if current_setting('community.internal_counter_update', true) = 'true' then
    return new;
  end if;

  if not private.is_admin() then
    -- Non-admin authors cannot manipulate upvote_count, is_accepted, question link, or timestamps
    if new.upvote_count <> old.upvote_count or
       new.is_accepted <> old.is_accepted or
       new.created_at <> old.created_at or
       new.author_id <> old.author_id or
       new.question_id <> old.question_id then
      raise exception 'Direct modification of system-maintained community answer fields is forbidden'
        using errcode = '42501';
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_community_answer_tampering on public.community_answers;
create trigger trg_prevent_community_answer_tampering
  before update on public.community_answers
  for each row execute function public.prevent_community_answer_tampering();

-- Authoritative answer count trigger function (sets internal_counter_update to allow question counter updates)
create or replace function public.handle_community_answer_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform set_config('community.internal_counter_update', 'true', true);

  if tg_op = 'INSERT' then
    if new.status = 'published' then
      update public.community_questions
         set answer_count = answer_count + 1,
             updated_at = now()
       where id = new.question_id;
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status <> 'published' and new.status = 'published' then
      update public.community_questions
         set answer_count = answer_count + 1,
             updated_at = now()
       where id = new.question_id;
    elsif old.status = 'published' and new.status <> 'published' then
      update public.community_questions
         set answer_count = greatest(0, answer_count - 1),
             updated_at = now()
       where id = new.question_id;
    end if;
  elsif tg_op = 'DELETE' then
    if old.status = 'published' then
      update public.community_questions
         set answer_count = greatest(0, answer_count - 1),
             updated_at = now()
       where id = old.question_id;
    end if;
  end if;
  return null;
end;
$$;

-- Column privileges hardening (defense in depth for authenticated updates)
revoke update on table public.community_questions from authenticated;
grant update (title, body_markdown, status, concept_id, target_id, lesson_id, cip_code) on table public.community_questions to authenticated;

revoke update on table public.community_answers from authenticated;
grant update (body_markdown, status) on table public.community_answers to authenticated;

-- Revoke execute on trigger functions from public & anon
revoke all on function public.handle_community_answer_count() from public, anon;
revoke all on function public.prevent_community_question_tampering() from public, anon;
revoke all on function public.prevent_community_answer_tampering() from public, anon;

-- -----------------------------------------------------------------------------
-- 4. Update Atomic Upvoting RPC with Parent Question Visibility Check
-- -----------------------------------------------------------------------------
create or replace function public.cast_community_vote(
  p_target_type text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
  v_exists boolean;
  v_voted boolean;
  v_new_count integer;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Authentication required to vote' using errcode = '42501';
  end if;

  if p_target_type not in ('question', 'answer') then
    raise exception 'Invalid vote target_type: %', p_target_type using errcode = '22023';
  end if;

  -- Verify target existence and visibility (including parent question visibility for answers)
  if p_target_type = 'question' then
    select exists (
      select 1 from public.community_questions
       where id = p_target_id
         and (status = 'published' or author_id = v_uid or private.is_admin())
    ) into v_exists;
  else
    select exists (
      select 1 from public.community_answers a
       join public.community_questions q on q.id = a.question_id
       where a.id = p_target_id
         and (
           (a.status = 'published' and q.status = 'published')
           or (a.author_id = v_uid and (q.status = 'published' or q.author_id = v_uid or private.is_admin()))
           or private.is_admin()
         )
    ) into v_exists;
  end if;

  if not v_exists then
    raise exception 'Target % does not exist or is inaccessible', p_target_id using errcode = 'P0002';
  end if;

  -- Transaction advisory lock per user & target
  perform pg_advisory_xact_lock(hashtext('vote_' || v_uid::text || '_' || p_target_id::text));

  select exists (
    select 1 from public.community_votes
     where user_id = v_uid
       and target_type = p_target_type
       and target_id = p_target_id
  ) into v_voted;

  -- Set transaction-local internal counter flag so tamper trigger allows atomic RPC updates
  perform set_config('community.internal_counter_update', 'true', true);

  if v_voted then
    -- Remove vote (toggle off)
    delete from public.community_votes
     where user_id = v_uid
       and target_type = p_target_type
       and target_id = p_target_id;

    if p_target_type = 'question' then
      update public.community_questions
         set upvote_count = greatest(0, upvote_count - 1),
             updated_at = now()
       where id = p_target_id
       returning upvote_count into v_new_count;
    else
      update public.community_answers
         set upvote_count = greatest(0, upvote_count - 1),
             updated_at = now()
       where id = p_target_id
       returning upvote_count into v_new_count;
    end if;

    return jsonb_build_object('voted', false, 'upvote_count', v_new_count);
  else
    -- Add vote (toggle on)
    insert into public.community_votes (user_id, target_type, target_id)
    values (v_uid, p_target_type, p_target_id);

    if p_target_type = 'question' then
      update public.community_questions
         set upvote_count = upvote_count + 1,
             updated_at = now()
       where id = p_target_id
       returning upvote_count into v_new_count;
    else
      update public.community_answers
         set upvote_count = upvote_count + 1,
             updated_at = now()
       where id = p_target_id
       returning upvote_count into v_new_count;
    end if;

    return jsonb_build_object('voted', true, 'upvote_count', v_new_count);
  end if;
end;
$$;

revoke all on function public.cast_community_vote(text, uuid) from public, anon;
grant execute on function public.cast_community_vote(text, uuid) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5. Update Moderation Report RPC with Parent Question Visibility Check
-- -----------------------------------------------------------------------------
create or replace function public.submit_moderation_report(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_description text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_caller_id uuid;
  v_report_id uuid;
  v_recent_reports_count integer;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'Authentication required to submit moderation reports' using errcode = '42501';
  end if;

  if p_reason not in ('spam', 'harassment', 'misinformation', 'copyright', 'minor_safety', 'inappropriate', 'other') then
    raise exception 'Invalid report reason: %', p_reason using errcode = '22023';
  end if;

  -- Validate target type, verify actual target existence AND caller visibility authorization
  case p_target_type
    when 'course' then
      if not exists (
        select 1 from public.courses
         where id = p_target_id
           and (is_public = true or user_id = v_caller_id)
      ) then
        raise exception 'Target course % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'lesson' then
      if not public.is_lesson_visible(p_target_id) then
        raise exception 'Target lesson % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'study_set' then
      if not exists (
        select 1 from public.study_sets
         where id = p_target_id
           and user_id = v_caller_id
      ) then
        raise exception 'Target study_set % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'word_list' then
      if not exists (
        select 1 from public.word_lists
         where id = p_target_id
           and user_id = v_caller_id
      ) then
        raise exception 'Target word_list % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'curriculum' then
      if not exists (
        select 1 from public.curriculum_nodes cn
          join public.target_versions v on v.id = cn.target_version_id
          join public.learning_targets t on t.id = v.target_id
         where cn.id = p_target_id
           and (
             (t.status = 'published' and t.is_public = true and v.status = 'published')
             or t.created_by = v_caller_id
           )
      ) then
        raise exception 'Target curriculum % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'resource' then
      if not exists (
        select 1 from public.user_curriculum_resources
         where id = p_target_id
           and user_id = v_caller_id
      ) then
        raise exception 'Target resource % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'question' then
      if not exists (
        select 1 from public.questions q
         where q.id = p_target_id
           and q.lesson_id is not null
           and public.is_lesson_visible(q.lesson_id)
      ) then
        raise exception 'Target question % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'community_question' then
      if not exists (
        select 1 from public.community_questions cq
         where cq.id = p_target_id
           and (cq.status = 'published' or cq.author_id = v_caller_id or private.is_admin())
      ) then
        raise exception 'Target community question % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'community_answer' then
      if not exists (
        select 1 from public.community_answers ca
         join public.community_questions cq on cq.id = ca.question_id
         where ca.id = p_target_id
           and (
             (ca.status = 'published' and cq.status = 'published')
             or (ca.author_id = v_caller_id and (cq.status = 'published' or cq.author_id = v_caller_id or private.is_admin()))
             or private.is_admin()
           )
      ) then
        raise exception 'Target community answer % does not exist or caller lacks access', p_target_id using errcode = 'P0002';
      end if;
    when 'profile' then
      raise exception 'Profile reporting is disabled until public profile launch' using errcode = '0A000';
    else
      raise exception 'Invalid target_type: %', p_target_type using errcode = '22023';
  end case;

  -- Transactional concurrency lock: serialize submissions per user to prevent concurrent rate limit bypass
  perform pg_advisory_xact_lock(hashtext('moderation_report_rate_limit'), hashtext(v_caller_id::text));

  -- Rate limit check: maximum 10 reports per hour per user
  select count(*)::integer into v_recent_reports_count
    from public.moderation_reports
   where reporter_id = v_caller_id
     and created_at > now() - interval '1 hour';

  if v_recent_reports_count >= 10 then
    raise exception 'Rate limit exceeded: too many moderation reports submitted. Please wait before submitting additional reports.' using errcode = 'P0004';
  end if;

  -- Deduplication check for active report on the same target
  if exists (
    select 1
      from public.moderation_reports
     where reporter_id = v_caller_id
       and target_type = p_target_type
       and target_id = p_target_id
       and status in ('pending', 'under_review')
  ) then
    raise exception 'Duplicate report: you already have an active report for this content.' using errcode = '23505';
  end if;

  insert into public.moderation_reports (
    reporter_id, target_type, target_id, reason, description, status
  ) values (
    v_caller_id, p_target_type, p_target_id, p_reason, p_description, 'pending'
  ) returning id into v_report_id;

  return v_report_id;
end;
$$;

revoke all on function public.submit_moderation_report(text, uuid, text, text) from public, anon;
grant execute on function public.submit_moderation_report(text, uuid, text, text) to authenticated, service_role;
