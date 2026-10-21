-- =============================================================================
-- Migration 55: ECO-01 Community Q&A Baseline & Moderation Integration
-- Description:
--   Establishes the concept-scoped Community Q&A schema (community_questions,
--   community_answers, community_votes), maintaining strict domain separation
--   from assessment engine questions.
--   Enforces Phase 1 private engineering boundaries:
--     - Public UGC creation is restricted to administrators and curated seed FAQs.
--     - Authenticated learners can create draft or under-review questions/answers.
--     - Integrates with moderation_reports and submit_moderation_report RPC.
--     - Provides cast_community_vote atomic upvote RPC.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Extend moderation_reports target_type check constraint
-- -----------------------------------------------------------------------------
alter table public.moderation_reports
  drop constraint if exists moderation_reports_target_type_check;

alter table public.moderation_reports
  add constraint moderation_reports_target_type_check
  check (target_type in (
    'course', 'lesson', 'study_set', 'word_list', 'curriculum',
    'resource', 'question', 'profile', 'community_question', 'community_answer'
  ));

-- -----------------------------------------------------------------------------
-- 2. Create Community Questions Table
-- -----------------------------------------------------------------------------
create table if not exists public.community_questions (
  id uuid primary key default gen_random_uuid(),
  author_id uuid references auth.users(id) on delete cascade not null,
  title text not null check (length(trim(title)) >= 5 and length(title) <= 200),
  body_markdown text not null check (length(trim(body_markdown)) >= 10 and length(body_markdown) <= 10000),
  status text not null default 'draft' check (status in ('draft', 'under_review', 'published', 'archived')),
  is_seeded boolean not null default false,
  concept_id text,
  target_id text,
  lesson_id uuid references public.lessons(id) on delete set null,
  cip_code text,
  view_count integer not null default 0 check (view_count >= 0),
  upvote_count integer not null default 0 check (upvote_count >= 0),
  answer_count integer not null default 0 check (answer_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for Community Questions
create index if not exists idx_community_questions_status_created
  on public.community_questions (status, created_at desc);

create index if not exists idx_community_questions_concept
  on public.community_questions (concept_id, created_at desc)
  where concept_id is not null;

create index if not exists idx_community_questions_target
  on public.community_questions (target_id, created_at desc)
  where target_id is not null;

create index if not exists idx_community_questions_lesson
  on public.community_questions (lesson_id, created_at desc)
  where lesson_id is not null;

create index if not exists idx_community_questions_author
  on public.community_questions (author_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 3. Create Community Answers Table
-- -----------------------------------------------------------------------------
create table if not exists public.community_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid references public.community_questions(id) on delete cascade not null,
  author_id uuid references auth.users(id) on delete cascade not null,
  body_markdown text not null check (length(trim(body_markdown)) >= 10 and length(body_markdown) <= 20000),
  is_ai_generated boolean not null default false,
  ai_model_name text check (ai_model_name is null or (length(trim(ai_model_name)) > 0 and length(ai_model_name) <= 64)),
  is_accepted boolean not null default false,
  status text not null default 'published' check (status in ('draft', 'under_review', 'published', 'archived', 'flagged')),
  upvote_count integer not null default 0 check (upvote_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Indexes for Community Answers
create index if not exists idx_community_answers_question_created
  on public.community_answers (question_id, created_at asc);

create index if not exists idx_community_answers_author
  on public.community_answers (author_id, created_at desc);

-- -----------------------------------------------------------------------------
-- 4. Create Community Votes Table
-- -----------------------------------------------------------------------------
create table if not exists public.community_votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  target_type text not null check (target_type in ('question', 'answer')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);

create index if not exists idx_community_votes_target
  on public.community_votes (target_type, target_id);

-- -----------------------------------------------------------------------------
-- 5. Trigger for Answer Count on Community Questions
-- -----------------------------------------------------------------------------
create or replace function public.handle_community_answer_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
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

drop trigger if exists trg_community_answer_count on public.community_answers;
create trigger trg_community_answer_count
  after insert or update of status or delete on public.community_answers
  for each row execute function public.handle_community_answer_count();

-- -----------------------------------------------------------------------------
-- 6. Atomic Upvoting RPC
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

  -- Verify target existence and visibility
  if p_target_type = 'question' then
    select exists (
      select 1 from public.community_questions
       where id = p_target_id
         and (status = 'published' or author_id = v_uid or private.is_admin())
    ) into v_exists;
  else
    select exists (
      select 1 from public.community_answers
       where id = p_target_id
         and (status = 'published' or author_id = v_uid or private.is_admin())
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
-- 7. Update submit_moderation_report with community targets
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
         where ca.id = p_target_id
           and (ca.status = 'published' or ca.author_id = v_caller_id or private.is_admin())
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

-- -----------------------------------------------------------------------------
-- 8. Row Level Security & Defense-in-Depth Permissions
-- -----------------------------------------------------------------------------
alter table public.community_questions enable row level security;
alter table public.community_answers enable row level security;
alter table public.community_votes enable row level security;

-- Table-level grants: least privilege
revoke all on table public.community_questions from public, anon;
revoke all on table public.community_answers from public, anon;
revoke all on table public.community_votes from public, anon;

grant select on table public.community_questions to anon, authenticated;
grant insert, update, delete on table public.community_questions to authenticated;

grant select on table public.community_answers to anon, authenticated;
grant insert, update, delete on table public.community_answers to authenticated;

grant select on table public.community_votes to authenticated;
-- Direct writes to votes revoked: must use cast_community_vote RPC
revoke insert, update, delete on table public.community_votes from authenticated;

-- Policies for Community Questions
create policy community_questions_select_policy on public.community_questions
  for select
  using (status = 'published' or author_id = auth.uid() or private.is_admin());

create policy community_questions_insert_policy on public.community_questions
  for insert
  to authenticated
  with check (
    (author_id = auth.uid() and is_seeded = false and status in ('draft', 'under_review'))
    or private.is_admin()
  );

create policy community_questions_update_policy on public.community_questions
  for update
  to authenticated
  using (
    (author_id = auth.uid() and is_seeded = false and status in ('draft', 'under_review'))
    or private.is_admin()
  )
  with check (
    (author_id = auth.uid() and is_seeded = false and status in ('draft', 'under_review'))
    or private.is_admin()
  );

create policy community_questions_delete_policy on public.community_questions
  for delete
  to authenticated
  using (
    (author_id = auth.uid() and status = 'draft')
    or private.is_admin()
  );

-- Policies for Community Answers
create policy community_answers_select_policy on public.community_answers
  for select
  using (status = 'published' or author_id = auth.uid() or private.is_admin());

create policy community_answers_insert_policy on public.community_answers
  for insert
  to authenticated
  with check (
    (author_id = auth.uid() and status in ('draft', 'under_review'))
    or private.is_admin()
  );

create policy community_answers_update_policy on public.community_answers
  for update
  to authenticated
  using (
    (author_id = auth.uid() and status in ('draft', 'under_review'))
    or private.is_admin()
  )
  with check (
    (author_id = auth.uid() and status in ('draft', 'under_review'))
    or private.is_admin()
  );

create policy community_answers_delete_policy on public.community_answers
  for delete
  to authenticated
  using (
    (author_id = auth.uid() and status = 'draft')
    or private.is_admin()
  );

-- Policies for Community Votes
create policy community_votes_select_policy on public.community_votes
  for select
  to authenticated
  using (user_id = auth.uid() or private.is_admin());
