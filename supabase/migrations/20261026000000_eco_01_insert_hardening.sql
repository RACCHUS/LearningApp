-- =============================================================================
-- Migration 57: ECO-01 Community Q&A INSERT Integrity & Trigger ACL Hardening
-- Description:
--   1. Restricts column-level INSERT privileges on public.community_questions
--      and public.community_answers to genuinely authorable fields. Excludes
--      system-maintained counters (upvote_count, answer_count, view_count)
--      and audit timestamps (created_at, updated_at) from client write access.
--   2. Extends tamper-prevention triggers to BEFORE INSERT OR UPDATE, enforcing
--      clean initial states and server-controlled timestamps even for privileged sessions.
--   3. Hardens RLS WITH CHECK expressions on INSERT to disallow non-clean counter
--      or acceptance states for non-admins.
--   4. Revokes explicit authenticated EXECUTE grants from all community trigger functions.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Column-Level INSERT Privilege Restrictions
-- -----------------------------------------------------------------------------
-- Questions: authenticated authors can specify content, seeding, and taxonomy fields.
-- Counters (upvote_count, view_count, answer_count) and audit timestamps are revoked.
revoke insert on table public.community_questions from authenticated;
grant insert (id, author_id, title, body_markdown, status, is_seeded, concept_id, target_id, lesson_id, cip_code)
  on table public.community_questions to authenticated;

-- Answers: authenticated authors can specify content and acceptance/provenance fields.
-- Counters (upvote_count) and audit timestamps are revoked.
revoke insert on table public.community_answers from authenticated;
grant insert (id, question_id, author_id, body_markdown, is_ai_generated, is_accepted, status)
  on table public.community_answers to authenticated;

-- -----------------------------------------------------------------------------
-- 2. Hardened RLS INSERT Policies (Defense-in-Depth)
-- -----------------------------------------------------------------------------
drop policy if exists community_questions_insert_policy on public.community_questions;
create policy community_questions_insert_policy on public.community_questions
  for insert
  to authenticated
  with check (
    (
      author_id = auth.uid()
      and is_seeded = false
      and status in ('draft', 'under_review')
      and upvote_count = 0
      and answer_count = 0
      and view_count = 0
    )
    or private.is_admin()
  );

drop policy if exists community_answers_insert_policy on public.community_answers;
create policy community_answers_insert_policy on public.community_answers
  for insert
  to authenticated
  with check (
    (
      author_id = auth.uid()
      and status in ('draft', 'under_review')
      and is_accepted = false
      and is_ai_generated = false
      and upvote_count = 0
    )
    or private.is_admin()
  );

-- -----------------------------------------------------------------------------
-- 3. Extend Tamper-Proofing Triggers to BEFORE INSERT OR UPDATE
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

  if tg_op = 'INSERT' then
    if not private.is_admin() then
      if new.upvote_count <> 0 or
         new.view_count <> 0 or
         new.answer_count <> 0 or
         new.is_seeded <> false then
        raise exception 'Direct modification of system-maintained community question fields is forbidden'
          using errcode = '42501';
      end if;
      new.created_at := now();
      new.updated_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
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
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_community_question_tampering on public.community_questions;
create trigger trg_prevent_community_question_tampering
  before insert or update on public.community_questions
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

  if tg_op = 'INSERT' then
    if not private.is_admin() then
      if new.upvote_count <> 0 or
         new.is_accepted <> false or
         new.is_ai_generated <> false then
        raise exception 'Direct modification of system-maintained community answer fields is forbidden'
          using errcode = '42501';
      end if;
      new.created_at := now();
      new.updated_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
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
  end if;

  return new;
end;
$$;

drop trigger if exists trg_prevent_community_answer_tampering on public.community_answers;
create trigger trg_prevent_community_answer_tampering
  before insert or update on public.community_answers
  for each row execute function public.prevent_community_answer_tampering();

-- -----------------------------------------------------------------------------
-- 4. Revoke Authenticated EXECUTE on All Community Trigger Functions
-- -----------------------------------------------------------------------------
revoke all on function public.handle_community_answer_count() from public, anon, authenticated;
revoke all on function public.prevent_community_question_tampering() from public, anon, authenticated;
revoke all on function public.prevent_community_answer_tampering() from public, anon, authenticated;
