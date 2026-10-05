-- ============================================================================
-- Migration: 20261006000003_phase_c5_final_hardening.sql
-- Description: Phase C.5 Final Hardening & Comprehensive Integrity
--
-- Addressed Findings:
--   1. 🔴 Lock content_import_artifacts to service_role; require origin_target_version_id
--         proof during clean_draft_target_version() for defense in depth.
--   2. 🔴 Add review_ready beta preview access to curriculum teaching junctions
--         (curriculum_node_lessons, curriculum_node_concepts, curriculum_node_courses,
--          curriculum_node_modules).
--   3. 🔴 Restrict content_source_mappings read visibility: gate mappings by the
--         visibility of each underlying mapped entity (no draft provenance leakage).
--   4. 🟠 Transactional canonical concept resolution/creation inside
--         ingest_curriculum_manifest (Option A).
--   5. 🟠 Complete authoritative provenance mappings for knowledge_concept,
--         assessment_item, lesson_block, and flashcard.
--   6. 🟠 Freeze all fields during review_ready -> published transition (status-only change).
--   7. 🟠 Enforce published immutability against service_role updates in lifecycle trigger
--         (published can only transition status to 'retired', no other fields mutable).
--   8. 🟡 Scope draft provenance cleanup strictly to the target version (no global deletion).
--   10. 🟡 Derive caller identity in helper functions (is_target_reviewer, is_lesson_visible)
--          from auth.uid() directly without accepting arbitrary untrusted user IDs.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Identity-Secured Helper Functions (Derived from auth.uid())
-- ----------------------------------------------------------------------------

create or replace function public.is_target_reviewer(p_target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.curriculum_reviewers
    where user_id = auth.uid()
      and (target_id is null or target_id = p_target_id)
  );
$$;

create or replace function public.is_lesson_visible(p_lesson_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.lessons l
    where l.id = p_lesson_id
      and (
        l.user_id = auth.uid()
        or (l.origin_target_version_id is null and l.visibility = 'public')
        or (l.origin_target_version_id is not null and exists (
          select 1 from public.target_versions tv
          join public.learning_targets lt on lt.id = tv.target_id
          where tv.id = l.origin_target_version_id
            and (
              (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
              or (lt.created_by = auth.uid())
              or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
            )
        ))
      )
  );
$$;

grant execute on function public.is_target_reviewer(uuid) to authenticated, anon, service_role;
grant execute on function public.is_lesson_visible(uuid) to authenticated, anon, service_role;

-- ----------------------------------------------------------------------------
-- 2. Update Core Content RLS Policies to use 1-Arg Helpers
-- ----------------------------------------------------------------------------

-- Target Versions
drop policy if exists "versions_read" on public.target_versions;
create policy "versions_read" on public.target_versions
  for select using (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and (
          (t.status = 'published' and t.is_public = true and target_versions.status = 'published')
          or (t.created_by = auth.uid())
          or (target_versions.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- Curriculum Nodes
drop policy if exists "nodes_read" on public.curriculum_nodes;
create policy "nodes_read" on public.curriculum_nodes
  for select using (
    exists (
      select 1 from public.target_versions v
      join public.learning_targets t on t.id = v.target_id
      where v.id = curriculum_nodes.target_version_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or (t.created_by = auth.uid())
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- Lessons
drop policy if exists lessons_read_visible on public.lessons;
create policy lessons_read_visible on public.lessons
  for select to authenticated, anon
  using (
    user_id = auth.uid()
    or (origin_target_version_id is null and visibility = 'public')
    or (origin_target_version_id is not null and exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = lessons.origin_target_version_id
        and (
          (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
          or (lt.created_by = auth.uid())
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
        )
    ))
  );

-- Lesson Blocks
drop policy if exists "lesson_blocks_read" on public.lesson_blocks;
create policy "lesson_blocks_read" on public.lesson_blocks
  for select using (public.is_lesson_visible(lesson_id));

-- Terms
drop policy if exists terms_read_visible on public.terms;
create policy terms_read_visible on public.terms
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id));

-- Questions
drop policy if exists questions_read_visible on public.questions;
create policy questions_read_visible on public.questions
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id));

-- Lesson Concepts
drop policy if exists lesson_concepts_read on public.lesson_concepts;
create policy lesson_concepts_read on public.lesson_concepts
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id));

-- Assessment Stimuli
drop policy if exists "assessment_stimuli_read" on public.assessment_stimuli;
create policy "assessment_stimuli_read" on public.assessment_stimuli
  for select using (
    created_by = auth.uid()
    or (origin_target_version_id is null and created_by is null)
    or (origin_target_version_id is not null and exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = assessment_stimuli.origin_target_version_id
        and (
          (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
          or (lt.created_by = auth.uid())
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
        )
    ))
  );

-- Assessment Items
drop policy if exists "assessment_items_read" on public.assessment_items;
create policy "assessment_items_read" on public.assessment_items
  for select using (
    user_id = auth.uid()
    or (lesson_id is not null and public.is_lesson_visible(lesson_id))
    or (origin_target_version_id is not null and exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = assessment_items.origin_target_version_id
        and (
          (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
          or (lt.created_by = auth.uid())
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
        )
    ))
  );

-- Assessment Item Concepts
drop policy if exists "assessment_item_concepts_read" on public.assessment_item_concepts;
create policy "assessment_item_concepts_read" on public.assessment_item_concepts
  for select using (
    exists (
      select 1 from public.assessment_items a
      where a.id = assessment_item_concepts.assessment_item_id
        and (
          a.user_id = auth.uid()
          or (a.lesson_id is not null and public.is_lesson_visible(a.lesson_id))
          or (a.origin_target_version_id is not null and exists (
            select 1 from public.target_versions tv
            join public.learning_targets lt on lt.id = tv.target_id
            where tv.id = a.origin_target_version_id
              and (
                (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                or (lt.created_by = auth.uid())
                or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
              )
          ))
        )
    )
  );

-- Flashcards
drop policy if exists "flashcards_read" on public.flashcards;
create policy "flashcards_read" on public.flashcards
  for select using (
    user_id = auth.uid()
    or (origin_target_version_id is not null and exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = flashcards.origin_target_version_id
        and (
          (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
          or (lt.created_by = auth.uid())
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
        )
    ))
    or (origin_target_version_id is null and user_id is null)
  );

-- Flashcard Concepts
drop policy if exists "flashcard_concepts_read" on public.flashcard_concepts;
create policy "flashcard_concepts_read" on public.flashcard_concepts
  for select using (
    exists (
      select 1 from public.flashcards f
      where f.id = flashcard_concepts.flashcard_id
        and (
          f.user_id = auth.uid()
          or (f.origin_target_version_id is not null and exists (
            select 1 from public.target_versions tv
            join public.learning_targets lt on lt.id = tv.target_id
            where tv.id = f.origin_target_version_id
              and (
                (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                or (lt.created_by = auth.uid())
                or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
              )
          ))
          or (f.origin_target_version_id is null and f.user_id is null)
        )
    )
  );

-- Safely drop deprecated 2-arg helpers now that all dependent policies are migrated
drop function if exists public.is_target_reviewer(uuid, uuid);
drop function if exists public.is_lesson_visible(uuid, uuid);

-- ----------------------------------------------------------------------------
-- 3. Reviewer Preview Access on Teaching Junction Tables
-- ----------------------------------------------------------------------------

-- A. curriculum_node_lessons
alter table public.curriculum_node_lessons enable row level security;
drop policy if exists "node_lessons_read" on public.curriculum_node_lessons;
create policy "node_lessons_read" on public.curriculum_node_lessons
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_lessons.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- B. curriculum_node_concepts
alter table public.curriculum_node_concepts enable row level security;
drop policy if exists "node_concepts_read" on public.curriculum_node_concepts;
create policy "node_concepts_read" on public.curriculum_node_concepts
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_concepts.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- C. curriculum_node_courses
alter table public.curriculum_node_courses enable row level security;
drop policy if exists "node_courses_read" on public.curriculum_node_courses;
create policy "node_courses_read" on public.curriculum_node_courses
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_courses.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- D. curriculum_node_modules
alter table public.curriculum_node_modules enable row level security;
drop policy if exists "node_modules_read" on public.curriculum_node_modules;
create policy "node_modules_read" on public.curriculum_node_modules
  for select using (
    exists (
      select 1 from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_modules.curriculum_node_id
        and (
          (t.status = 'published' and t.is_public = true and v.status = 'published')
          or t.created_by = auth.uid()
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id))
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 4. Entity-Gated Content Source Mappings RLS (No Draft Provenance Leakage)
-- ----------------------------------------------------------------------------

drop policy if exists "content_source_mappings_read" on public.content_source_mappings;
create policy "content_source_mappings_read" on public.content_source_mappings
  for select to authenticated, anon
  using (
    auth.role() = 'service_role'
    or case entity_type
      when 'target_version' then exists (
        select 1 from public.target_versions tv
        join public.learning_targets lt on lt.id = tv.target_id
        where tv.id = content_source_mappings.entity_id
          and (
            (lt.status = 'published' and lt.is_public = true and tv.status = 'published')
            or lt.created_by = auth.uid()
            or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
          )
      )
      when 'curriculum_node' then exists (
        select 1 from public.curriculum_nodes cn
        join public.target_versions tv on tv.id = cn.target_version_id
        join public.learning_targets lt on lt.id = tv.target_id
        where cn.id = content_source_mappings.entity_id
          and (
            (lt.status = 'published' and lt.is_public = true and tv.status = 'published')
            or lt.created_by = auth.uid()
            or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
          )
      )
      when 'lesson' then public.is_lesson_visible(content_source_mappings.entity_id)
      when 'lesson_block' then exists (
        select 1 from public.lesson_blocks lb
        where lb.id = content_source_mappings.entity_id
          and public.is_lesson_visible(lb.lesson_id)
      )
      when 'assessment_item' then exists (
        select 1 from public.assessment_items ai
        where ai.id = content_source_mappings.entity_id
          and (
            ai.user_id = auth.uid()
            or (ai.lesson_id is not null and public.is_lesson_visible(ai.lesson_id))
            or (ai.origin_target_version_id is not null and exists (
              select 1 from public.target_versions tv
              join public.learning_targets lt on lt.id = tv.target_id
              where tv.id = ai.origin_target_version_id
                and (
                  (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                  or (lt.created_by = auth.uid())
                  or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
                )
            ))
          )
      )
      when 'assessment_stimulus' then exists (
        select 1 from public.assessment_stimuli ast
        where ast.id = content_source_mappings.entity_id
          and (
            ast.created_by = auth.uid()
            or (ast.origin_target_version_id is null and ast.created_by is null)
            or (ast.origin_target_version_id is not null and exists (
              select 1 from public.target_versions tv
              join public.learning_targets lt on lt.id = tv.target_id
              where tv.id = ast.origin_target_version_id
                and (
                  (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                  or (lt.created_by = auth.uid())
                  or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
                )
            ))
          )
      )
      when 'flashcard' then exists (
        select 1 from public.flashcards f
        where f.id = content_source_mappings.entity_id
          and (
            f.user_id = auth.uid()
            or (f.origin_target_version_id is not null and exists (
              select 1 from public.target_versions tv
              join public.learning_targets lt on lt.id = tv.target_id
              where tv.id = f.origin_target_version_id
                and (
                  (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                  or (lt.created_by = auth.uid())
                  or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id))
                )
            ))
            or (f.origin_target_version_id is null and f.user_id is null)
          )
      )
      when 'knowledge_concept' then exists (
        select 1 from public.knowledge_concepts kc
        where kc.id = content_source_mappings.entity_id
          and (kc.status = 'active' or kc.created_by = auth.uid())
      )
      when 'question' then exists (
        select 1 from public.questions q
        where q.id = content_source_mappings.entity_id
          and (q.lesson_id is null or public.is_lesson_visible(q.lesson_id))
      )
      when 'term' then exists (
        select 1 from public.terms t
        where t.id = content_source_mappings.entity_id
          and (t.lesson_id is null or public.is_lesson_visible(t.lesson_id))
      )
      else false
    end
  );

-- ----------------------------------------------------------------------------
-- 5. Lock content_import_artifacts Table to service_role Only
-- ----------------------------------------------------------------------------

revoke all on public.content_import_artifacts from public, anon, authenticated;
grant all on public.content_import_artifacts to service_role;

drop policy if exists "artifacts_access" on public.content_import_artifacts;
drop policy if exists "artifacts_service_role" on public.content_import_artifacts;
create policy "artifacts_service_role" on public.content_import_artifacts
  for all using (auth.role() = 'service_role');

-- ----------------------------------------------------------------------------
-- 6. TargetVersion Lifecycle State Machine Trigger
-- ----------------------------------------------------------------------------

create or replace function public.trg_target_versions_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    if old.status <> 'draft' then
      raise exception 'Cannot delete target_version with status "%". Only draft versions may be deleted.', old.status;
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    -- 1. Published immutability: NO field changes allowed, except status transition to 'retired'
    if old.status = 'published' then
      if new.status <> 'retired' then
        raise exception 'Published versions are immutable and cannot be updated. Only transition to "retired" status is permitted.';
      end if;

      -- Even when transitioning to 'retired', no metadata/title/version_code/etc. can be changed
      if (
        new.version_code <> old.version_code or
        new.title is distinct from old.title or
        new.description is distinct from old.description or
        new.metadata is distinct from old.metadata or
        new.target_id <> old.target_id or
        new.valid_from is distinct from old.valid_from
      ) then
        raise exception 'Cannot modify TargetVersion attributes when retiring a published version. It must be a status-only transition.';
      end if;
    end if;

    -- 2. Retired versions are completely immutable
    if old.status = 'retired' and (new.status <> 'retired' or new.* is distinct from old.*) then
      raise exception 'Retired versions are completely immutable.';
    end if;

    -- 3. Draft status transitions: must go through review_ready before publishing
    if old.status = 'draft' then
      if new.status not in ('draft', 'review_ready') then
        raise exception 'Invalid status transition: draft must be staged to "review_ready" before publishing.';
      end if;
    end if;

    -- 4. review_ready status transitions
    if old.status = 'review_ready' then
      if new.status not in ('draft', 'published', 'review_ready') then
        raise exception 'Invalid status transition: review_ready can only transition to "draft" or "published".';
      end if;

      -- In review_ready or when leaving review_ready (to published or draft), NO metadata/field edits allowed!
      if (
        new.version_code <> old.version_code or
        new.title is distinct from old.title or
        new.description is distinct from old.description or
        new.metadata is distinct from old.metadata or
        new.target_id <> old.target_id or
        new.valid_from is distinct from old.valid_from
      ) then
        if new.status = 'published' then
          raise exception 'Cannot modify TargetVersion attributes during publication from "review_ready". Publication must be a status-only transition.';
        elsif new.status = 'review_ready' then
          raise exception 'TargetVersion is frozen in "review_ready" status. Revert status to "draft" before making edits.';
        else
          raise exception 'Status change from "review_ready" to "draft" must be a status-only transition before edits can be made.';
        end if;
      end if;
    end if;

    return new;
  end if;

  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- 7. Defense-in-Depth & Scoped clean_draft_target_version()
-- ----------------------------------------------------------------------------

create or replace function public.clean_draft_target_version(
  p_version_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
  v_target_owner uuid;
begin
  select tv.status, lt.created_by
  into v_status, v_target_owner
  from public.target_versions tv
  join public.learning_targets lt on lt.id = tv.target_id
  where tv.id = p_version_id;

  if v_status is null then
    raise exception 'TargetVersion % not found', p_version_id;
  end if;

  if v_status <> 'draft' then
    raise exception 'Cannot clean TargetVersion with status "%". Only draft versions may be reset.', v_status;
  end if;

  -- Authorization check: service_role or target owner only
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and auth.role() <> 'service_role'
     and (v_target_owner is null or v_target_owner <> auth.uid()) then
    raise exception 'Unauthorized: only service_role or the target owner can clean a draft target version';
  end if;

  -- 1. Scoped provenance mapping deletion (NO cross-target global orphan deletion!):
  delete from public.content_source_mappings
  where (entity_type = 'target_version' and entity_id = p_version_id)
     or (entity_type = 'curriculum_node' and entity_id in (
          select id from public.curriculum_nodes where target_version_id = p_version_id
        ))
     or (entity_type = 'lesson' and entity_id in (
          select id from public.lessons where origin_target_version_id = p_version_id
        ))
     or (entity_type = 'assessment_stimulus' and entity_id in (
          select id from public.assessment_stimuli where origin_target_version_id = p_version_id
        ))
     or (entity_type = 'assessment_item' and entity_id in (
          select id from public.assessment_items where origin_target_version_id = p_version_id
        ))
     or (entity_type = 'flashcard' and entity_id in (
          select id from public.flashcards where origin_target_version_id = p_version_id
        ))
     or (entity_type = 'lesson_block' and entity_id in (
          select lb.id from public.lesson_blocks lb
          join public.lessons l on l.id = lb.lesson_id
          where l.origin_target_version_id = p_version_id
        ))
     or id in (
          select entity_id
          from public.content_import_artifacts
          where target_version_id = p_version_id
            and entity_type = 'content_source_mapping'
        );

  -- 2. Delete assessment_items: defense-in-depth requires origin_target_version_id = p_version_id
  delete from public.assessment_items
  where origin_target_version_id = p_version_id;

  -- 3. Delete assessment_stimuli: defense-in-depth requires origin_target_version_id = p_version_id
  delete from public.assessment_stimuli
  where origin_target_version_id = p_version_id;

  -- 4. Delete flashcards: defense-in-depth requires origin_target_version_id = p_version_id
  delete from public.flashcards
  where origin_target_version_id = p_version_id;

  -- 5. Delete official lessons: defense-in-depth requires origin_target_version_id = p_version_id
  -- (or unowned legacy lessons uniquely joined to this draft's nodes)
  delete from public.lessons
  where origin_target_version_id = p_version_id
     or (
       user_id is null
       and origin_target_version_id is null
       and id in (
         select cnl.lesson_id
         from public.curriculum_node_lessons cnl
         join public.curriculum_nodes cn on cn.id = cnl.curriculum_node_id
         where cn.target_version_id = p_version_id
           and not exists (
             select 1
             from public.curriculum_node_lessons o_cnl
             join public.curriculum_nodes o_cn on o_cn.id = o_cnl.curriculum_node_id
             where o_cnl.lesson_id = cnl.lesson_id
               and o_cn.target_version_id <> p_version_id
           )
       )
     );

  -- 6. Delete curriculum nodes of this draft: must have target_version_id = p_version_id
  delete from public.curriculum_nodes
  where target_version_id = p_version_id;

  -- 7. Delete concept mappings involving this draft version
  delete from public.target_version_concept_mappings
  where from_target_version_id = p_version_id
     or to_target_version_id = p_version_id;

  -- 8. Clean all artifact tracking records for this draft version
  delete from public.content_import_artifacts
  where target_version_id = p_version_id;

end;
$$;

revoke all on function public.clean_draft_target_version(uuid) from public, anon;
grant execute on function public.clean_draft_target_version(uuid) to authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 8. Fully Transactional Ingestion RPC (ingest_curriculum_manifest)
-- ----------------------------------------------------------------------------

create or replace function public.ingest_curriculum_manifest(
  payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_field_id uuid;
  v_field_slug text;
  v_target_id uuid;
  v_target_slug text;
  v_version_id uuid;
  v_version_code text;
  v_version_status text;

  -- Counters
  v_concepts_count int := 0;
  v_stimuli_count int := 0;
  v_domains_count int := 0;
  v_objectives_count int := 0;
  v_lessons_count int := 0;
  v_blocks_count int := 0;
  v_items_count int := 0;
  v_flashcards_count int := 0;
  v_questions_count int := 0;
  v_mappings_count int := 0;

  -- Lookup Maps
  v_stimuli_map jsonb := '{}'::jsonb;         -- stimulus_key -> uuid
  v_concepts_map jsonb := '{}'::jsonb;        -- slug -> uuid
  v_source_releases_map jsonb := '{}'::jsonb; -- source_id or index -> uuid
  v_default_rel_id uuid := null;

  -- Concept processing variables
  v_concept jsonb;
  v_concept_id uuid;
  v_concept_slug text;
  v_concept_name text;
  v_explicit_canon text;
  v_matched_id uuid;
  v_matched_is_ambig boolean;
  v_concept_rel_id uuid;

  -- Content processing variables
  v_stim jsonb;
  v_stim_key text;
  v_stim_id uuid;
  v_domain jsonb;
  v_domain_id uuid;
  v_obj jsonb;
  v_obj_id uuid;
  v_lesson jsonb;
  v_lesson_id uuid;
  v_block jsonb;
  v_block_id uuid;
  v_item jsonb;
  v_item_id uuid;
  v_fc jsonb;
  v_fc_id uuid;
  v_term jsonb;
  v_question jsonb;
  v_mapping jsonb;
  v_source_rel jsonb;
  v_source_rel_idx int := 0;
  v_rel_id uuid;
  v_source_artifact jsonb;
  v_mapping_id uuid;
  v_source_mapping jsonb;
  v_from_concept_id uuid;
  v_to_concept_id uuid;

  v_entity_rel_id uuid;
  v_lesson_rel_id uuid;
  v_obj_rel_id uuid;
  v_raw_concept_ref text;
  v_resolved_cid uuid;
begin
  -- 1. Security Check: Service-role only
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and auth.role() <> 'service_role' then
    raise exception 'Unauthorized: ingest_curriculum_manifest requires service_role privilege';
  end if;

  -- 2. Extract / Upsert Field
  v_field_slug := payload->'field'->>'slug';
  if v_field_slug is not null and v_field_slug <> '' then
    select id into v_field_id from public.fields where slug = v_field_slug;
    if v_field_id is null then
      insert into public.fields (slug, name, description, field_kind)
      values (
        v_field_slug,
        coalesce(payload->'field'->>'name', v_field_slug),
        payload->'field'->>'description',
        'native_field'
      )
      returning id into v_field_id;
    end if;
  end if;

  -- 3. Extract / Upsert LearningTarget
  v_target_slug := payload->'target'->>'slug';
  if v_target_slug is null or v_target_slug = '' then
    raise exception 'Missing target.slug in manifest payload';
  end if;

  select id into v_target_id from public.learning_targets where slug = v_target_slug;
  if v_target_id is null then
    insert into public.learning_targets (
      slug, title, target_type, description, field_id, status, is_public
    ) values (
      v_target_slug,
      coalesce(payload->'target'->>'title', v_target_slug),
      coalesce(payload->'target'->>'target_type', coalesce(payload->'target'->>'target_kind', 'certification')),
      payload->'target'->>'description',
      v_field_id,
      'published',
      true
    )
    returning id into v_target_id;
  end if;

  -- 4. Extract / Upsert TargetVersion
  v_version_code := payload->'target_version'->>'version_code';
  if v_version_code is null or v_version_code = '' then
    raise exception 'Missing target_version.version_code in manifest payload';
  end if;

  select id, status into v_version_id, v_version_status
  from public.target_versions
  where target_id = v_target_id and version_code = v_version_code;

  if v_version_id is null then
    insert into public.target_versions (
      target_id, version_code, title, description, valid_from, status, metadata
    ) values (
      v_target_id,
      v_version_code,
      payload->'target_version'->>'title',
      payload->'target_version'->>'description',
      case when payload->'target_version'->>'valid_from' is not null
           then (payload->'target_version'->>'valid_from')::date
           else null end,
      'draft',
      coalesce(payload->'target_version'->'metadata', '{}'::jsonb)
    )
    returning id, status into v_version_id, v_version_status;
  end if;

  if v_version_status <> 'draft' then
    raise exception 'Cannot ingest into TargetVersion "%" with status "%". Only draft versions may be replaced.', v_version_code, v_version_status;
  end if;

  -- 5. Atomically Clean Previous Draft Content for this TargetVersion
  perform public.clean_draft_target_version(v_version_id);

  -- 6. Ingest Source Releases
  if jsonb_typeof(coalesce(payload->'source_releases', payload->'sources')) = 'array' then
    for v_source_rel in select * from jsonb_array_elements(coalesce(payload->'source_releases', payload->'sources'))
    loop
      insert into public.content_source_releases (
        publisher, title, version, source_url, license, retrieved_at, sha256, metadata
      ) values (
        coalesce(v_source_rel->>'publisher', 'Authoritative Source'),
        coalesce(v_source_rel->>'title', 'Official Blueprint'),
        coalesce(v_source_rel->>'version', 'v1'),
        v_source_rel->>'source_url',
        coalesce(v_source_rel->>'license', v_source_rel->>'license_name'),
        case when v_source_rel->>'retrieved_at' is not null
             then (v_source_rel->>'retrieved_at')::timestamptz
             else now() end,
        v_source_rel->>'sha256',
        coalesce(v_source_rel->'metadata', '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
          'system', v_source_rel->>'system',
          'rights_note', v_source_rel->>'rights_note'
        ))
      )
      on conflict (publisher, title, version) do update
      set source_url = excluded.source_url,
          license = excluded.license,
          retrieved_at = excluded.retrieved_at,
          sha256 = excluded.sha256,
          metadata = excluded.metadata
      returning id into v_rel_id;

      v_source_rel_idx := v_source_rel_idx + 1;
      if v_default_rel_id is null then
        v_default_rel_id := v_rel_id;
      end if;

      if v_source_rel ? 'id' then
        v_source_releases_map := v_source_releases_map || jsonb_build_object(v_source_rel->>'id', v_rel_id::text);
      end if;
      if v_source_rel ? 'source_id' then
        v_source_releases_map := v_source_releases_map || jsonb_build_object(v_source_rel->>'source_id', v_rel_id::text);
      end if;
      v_source_releases_map := v_source_releases_map || jsonb_build_object(
        coalesce(v_source_rel->>'publisher', '') || '/' || coalesce(v_source_rel->>'version', ''), v_rel_id::text
      );
      v_source_releases_map := v_source_releases_map || jsonb_build_object(
        (v_source_rel_idx - 1)::text, v_rel_id::text
      );

      -- Link root target_version to this source release
      insert into public.content_source_mappings (
        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
      ) values (
        v_rel_id,
        'target_version',
        v_version_id,
        'official_blueprint',
        coalesce(payload->'target_version'->>'citation', 'Root Blueprint'),
        'Root target version mapping to authoritative source release',
        '{}'::jsonb
      )
      on conflict (source_release_id, entity_type, entity_id, relationship) do update
      set citation_location = excluded.citation_location,
          notes = excluded.notes,
          metadata = excluded.metadata
      returning id into v_mapping_id;

      v_mappings_count := v_mappings_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'content_source_mapping', v_mapping_id)
      on conflict do nothing;

      -- Source Artifacts
      if jsonb_typeof(v_source_rel->'artifacts') = 'array' then
        for v_source_artifact in select * from jsonb_array_elements(v_source_rel->'artifacts')
        loop
          insert into public.content_source_artifacts (
            source_release_id, artifact_name, source_url, sha256, file_size_bytes, retrieved_at, metadata
          ) values (
            v_rel_id,
            coalesce(v_source_artifact->>'artifact_name', 'blueprint.pdf'),
            v_source_artifact->>'source_url',
            v_source_artifact->>'sha256',
            case when v_source_artifact->>'file_size_bytes' is not null
                 then (v_source_artifact->>'file_size_bytes')::bigint
                 else null end,
            case when v_source_artifact->>'retrieved_at' is not null
                 then (v_source_artifact->>'retrieved_at')::timestamptz
                 else now() end,
            coalesce(v_source_artifact->'metadata', '{}'::jsonb)
          )
          on conflict (source_release_id, artifact_name) do update
          set source_url = excluded.source_url,
              sha256 = excluded.sha256,
              file_size_bytes = excluded.file_size_bytes,
              retrieved_at = excluded.retrieved_at,
              metadata = excluded.metadata;
        end loop;
      end if;
    end loop;
  end if;

  -- 7. Fully Transactional Canonical Concepts Resolution & Ingestion (Option A)
  if jsonb_typeof(payload->'concepts') = 'array' then
    for v_concept in select * from jsonb_array_elements(payload->'concepts')
    loop
      v_concept_slug := v_concept->>'slug';
      v_concept_name := coalesce(v_concept->>'name', v_concept_slug);
      v_explicit_canon := v_concept->>'canonical_concept';
      v_concept_id := null;

      if v_explicit_canon is not null and trim(v_explicit_canon) <> '' then
        select id into v_concept_id
        from public.knowledge_concepts
        where slug = trim(v_explicit_canon);

        if v_concept_id is null then
          raise exception 'Explicit canonical_concept "%" declared for concept "%" (%) does not exist in knowledge_concepts. Overrides must fail closed.', v_explicit_canon, v_concept_name, v_concept_slug;
        end if;

        if v_field_id is not null then
          insert into public.concept_fields (concept_id, field_id, relationship)
          values (v_concept_id, v_field_id, 'core_concept')
          on conflict (concept_id, field_id) do nothing;
        end if;
      else
        -- Ambiguity-safe resolution RPC
        select r.id, r.is_ambiguous into v_matched_id, v_matched_is_ambig
        from public.resolve_canonical_concept(v_concept_slug, v_concept_name, v_field_id) r
        limit 1;

        if v_matched_is_ambig then
          raise exception 'Ambiguous canonical concept match for "%" (%). Multiple concepts share this name across fields and target field does not disambiguate. Declare "canonical_concept: <existing-slug>" explicitly in the manifest to resolve the ambiguity, or make the concept name specific.', v_concept_name, v_concept_slug;
        end if;

        if v_matched_id is not null then
          v_concept_id := v_matched_id;
          if v_field_id is not null then
            insert into public.concept_fields (concept_id, field_id, relationship)
            values (v_concept_id, v_field_id, 'core_concept')
            on conflict (concept_id, field_id) do nothing;
          end if;
        else
          -- Insert new canonical knowledge concept
          insert into public.knowledge_concepts (
            field_id, slug, name, short_definition, description, emoji, aliases, status
          ) values (
            v_field_id,
            v_concept_slug,
            v_concept_name,
            v_concept->>'short_definition',
            v_concept->>'description',
            coalesce(v_concept->>'emoji', '💡'),
            case when jsonb_typeof(v_concept->'aliases') = 'array'
                 then array(select jsonb_array_elements_text(v_concept->'aliases'))
                 else array[]::text[] end,
            'active'
          )
          returning id into v_concept_id;

          if v_field_id is not null then
            insert into public.concept_fields (concept_id, field_id, relationship)
            values (v_concept_id, v_field_id, 'core_concept')
            on conflict (concept_id, field_id) do nothing;
          end if;
        end if;
      end if;

      v_concepts_count := v_concepts_count + 1;
      v_concepts_map := v_concepts_map || jsonb_build_object(v_concept_slug, v_concept_id::text);

      -- Canonical Concept Provenance Mapping
      if v_default_rel_id is not null then
        v_concept_rel_id := null;
        if v_concept ? 'source_release_id' and v_source_releases_map ? (v_concept->>'source_release_id') then
          v_concept_rel_id := (v_source_releases_map->>(v_concept->>'source_release_id'))::uuid;
        elsif v_concept ? 'source_id' and v_source_releases_map ? (v_concept->>'source_id') then
          v_concept_rel_id := (v_source_releases_map->>(v_concept->>'source_id'))::uuid;
        else
          v_concept_rel_id := v_default_rel_id;
        end if;

        if v_concept_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_concept_rel_id,
            'knowledge_concept',
            v_concept_id,
            'authoritative_definition',
            coalesce(v_concept->>'citation', coalesce(v_concept->>'citation_location', 'Concept ' || v_concept_slug)),
            coalesce(v_concept->>'notes', coalesce(v_concept->>'citation_notes', 'Authoritative concept definition from blueprint')),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- 8. Ingest Shared Stimuli (root-level & objective-level)
  if jsonb_typeof(payload->'stimuli') = 'array' then
    for v_stim in select * from jsonb_array_elements(payload->'stimuli')
    loop
      v_stim_key := v_stim->>'stimulus_key';
      insert into public.assessment_stimuli (
        title, body, stimulus_type, metadata, origin_target_version_id
      ) values (
        coalesce(v_stim->>'title', 'Exhibit'),
        coalesce(v_stim->>'body', coalesce(v_stim->>'body_markdown', '')),
        coalesce(v_stim->>'stimulus_type', 'scenario'),
        jsonb_build_object(
          'media_url', v_stim->>'media_url',
          'credit', v_stim->>'credit',
          'attribution', v_stim->>'attribution'
        ),
        v_version_id
      )
      returning id into v_stim_id;

      v_stimuli_count := v_stimuli_count + 1;
      v_stimuli_map := v_stimuli_map || jsonb_build_object(v_stim_key, v_stim_id::text);

      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id, manifest_key)
      values (v_version_id, 'assessment_stimulus', v_stim_id, v_stim_key);

      -- Stimulus Source Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_stim ? 'source_release_id' and v_source_releases_map ? (v_stim->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_stim->>'source_release_id'))::uuid;
        elsif v_stim ? 'source_id' and v_source_releases_map ? (v_stim->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_stim->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'assessment_stimulus',
            v_stim_id,
            'official_blueprint',
            coalesce(v_stim->>'citation', coalesce(v_stim->>'citation_location', 'Official Blueprint Stimulus')),
            coalesce(v_stim->>'notes', 'Assessment stimulus mapping'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- 9. Ingest Standalone Target-level Flashcards
  if jsonb_typeof(payload->'flashcards') = 'array' then
    for v_fc in select * from jsonb_array_elements(payload->'flashcards')
    loop
      insert into public.flashcards (
        front, back, explanation, origin_target_version_id
      ) values (
        v_fc->>'front',
        v_fc->>'back',
        v_fc->>'explanation',
        v_version_id
      )
      returning id into v_fc_id;

      v_flashcards_count := v_flashcards_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'flashcard', v_fc_id);

      -- Link concepts by UUID or slug lookup
      if jsonb_typeof(v_fc->'concept_ids') = 'array' then
        for v_concept_id in select (jsonb_array_elements_text(v_fc->'concept_ids'))::uuid
        loop
          insert into public.flashcard_concepts (flashcard_id, concept_id)
          values (v_fc_id, v_concept_id)
          on conflict do nothing;
        end loop;
      end if;

      if jsonb_typeof(v_fc->'concept_slugs') = 'array' then
        for v_raw_concept_ref in select jsonb_array_elements_text(v_fc->'concept_slugs')
        loop
          if v_concepts_map ? v_raw_concept_ref then
            v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
            insert into public.flashcard_concepts (flashcard_id, concept_id)
            values (v_fc_id, v_resolved_cid)
            on conflict do nothing;
          end if;
        end loop;
      end if;

      -- Flashcard Provenance Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_fc ? 'source_release_id' and v_source_releases_map ? (v_fc->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_release_id'))::uuid;
        elsif v_fc ? 'source_id' and v_source_releases_map ? (v_fc->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'flashcard',
            v_fc_id,
            'derived_from',
            coalesce(v_fc->>'citation', coalesce(v_fc->>'citation_location', coalesce(v_fc->>'front', 'Flashcard'))),
            coalesce(v_fc->>'notes', 'Flashcard derived from authoritative blueprint'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;
    end loop;
  end if;

  -- 10. Ingest Domains, Objectives, Lessons, Blocks, Assessment Items
  if jsonb_typeof(payload->'domains') = 'array' then
    for v_domain in select * from jsonb_array_elements(payload->'domains')
    loop
      insert into public.curriculum_nodes (
        target_version_id, node_type, code, title, description, sort_order, weight, metadata
      ) values (
        v_version_id,
        'domain',
        v_domain->>'code',
        coalesce(v_domain->>'title', 'Domain'),
        v_domain->>'description',
        coalesce((v_domain->>'sort_order')::int, 0),
        case when v_domain->>'weight_percentage' is not null
             then (v_domain->>'weight_percentage')::numeric
             when v_domain->>'weight' is not null
             then (v_domain->>'weight')::numeric
             else null end,
        coalesce(v_domain->'metadata', '{}'::jsonb)
      )
      returning id into v_domain_id;

      v_domains_count := v_domains_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'curriculum_node', v_domain_id);

      -- Domain Source Mapping
      if v_default_rel_id is not null then
        v_entity_rel_id := null;
        if v_domain ? 'source_release_id' and v_source_releases_map ? (v_domain->>'source_release_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid;
        elsif v_domain ? 'source_id' and v_source_releases_map ? (v_domain->>'source_id') then
          v_entity_rel_id := (v_source_releases_map->>(v_domain->>'source_id'))::uuid;
        else
          v_entity_rel_id := v_default_rel_id;
        end if;

        if v_entity_rel_id is not null then
          insert into public.content_source_mappings (
            source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
          ) values (
            v_entity_rel_id,
            'curriculum_node',
            v_domain_id,
            'official_blueprint',
            coalesce(v_domain->>'citation', coalesce(v_domain->>'citation_location', 'Domain ' || coalesce(v_domain->>'code', ''))),
            coalesce(v_domain->>'notes', 'Curriculum domain node citation'),
            '{}'::jsonb
          )
          on conflict (source_release_id, entity_type, entity_id, relationship) do update
          set citation_location = excluded.citation_location,
              notes = excluded.notes,
              metadata = excluded.metadata
          returning id into v_mapping_id;

          v_mappings_count := v_mappings_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'content_source_mapping', v_mapping_id)
          on conflict do nothing;
        end if;
      end if;

      -- Objectives
      if jsonb_typeof(v_domain->'objectives') = 'array' then
        for v_obj in select * from jsonb_array_elements(v_domain->'objectives')
        loop
          insert into public.curriculum_nodes (
            target_version_id, parent_id, node_type, code, title, description, sort_order, metadata
          ) values (
            v_version_id,
            v_domain_id,
            'objective',
            v_obj->>'code',
            coalesce(v_obj->>'title', 'Objective'),
            v_obj->>'description',
            coalesce((v_obj->>'sort_order')::int, 0),
            jsonb_build_object('bloom_level', coalesce(v_obj->>'bloom_level', 'understand'))
          )
          returning id into v_obj_id;

          v_objectives_count := v_objectives_count + 1;
          insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
          values (v_version_id, 'curriculum_node', v_obj_id);

          -- Objective Source Mapping
          if v_default_rel_id is not null then
            v_entity_rel_id := null;
            if v_obj ? 'source_release_id' and v_source_releases_map ? (v_obj->>'source_release_id') then
              v_entity_rel_id := (v_source_releases_map->>(v_obj->>'source_release_id'))::uuid;
            elsif v_obj ? 'source_id' and v_source_releases_map ? (v_obj->>'source_id') then
              v_entity_rel_id := (v_source_releases_map->>(v_obj->>'source_id'))::uuid;
            else
              v_entity_rel_id := coalesce(
                (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid,
                (v_source_releases_map->>(v_domain->>'source_id'))::uuid,
                v_default_rel_id
              );
            end if;

            v_obj_rel_id := v_entity_rel_id;

            if v_entity_rel_id is not null then
              insert into public.content_source_mappings (
                source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
              ) values (
                v_entity_rel_id,
                'curriculum_node',
                v_obj_id,
                'official_blueprint',
                coalesce(v_obj->>'citation', coalesce(v_obj->>'citation_location', 'Objective ' || coalesce(v_obj->>'code', ''))),
                coalesce(v_obj->>'notes', 'Curriculum objective node citation'),
                '{}'::jsonb
              )
              on conflict (source_release_id, entity_type, entity_id, relationship) do update
              set citation_location = excluded.citation_location,
                  notes = excluded.notes,
                  metadata = excluded.metadata
              returning id into v_mapping_id;

              v_mappings_count := v_mappings_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'content_source_mapping', v_mapping_id)
              on conflict do nothing;
            end if;
          end if;

          -- Link objective concepts by UUID or slug
          if jsonb_typeof(v_obj->'concept_ids') = 'array' then
            for v_concept_id in select (jsonb_array_elements_text(v_obj->'concept_ids'))::uuid
            loop
              insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
              values (v_obj_id, v_concept_id)
              on conflict do nothing;
            end loop;
          end if;

          if jsonb_typeof(v_obj->'concept_slugs') = 'array' then
            for v_raw_concept_ref in select jsonb_array_elements_text(v_obj->'concept_slugs')
            loop
              if v_concepts_map ? v_raw_concept_ref then
                v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
                values (v_obj_id, v_resolved_cid)
                on conflict do nothing;
              end if;
            end loop;
          end if;

          -- Objective Flashcards
          if jsonb_typeof(v_obj->'flashcards') = 'array' then
            for v_fc in select * from jsonb_array_elements(v_obj->'flashcards')
            loop
              insert into public.flashcards (
                front, back, explanation, origin_target_version_id
              ) values (
                v_fc->>'front',
                v_fc->>'back',
                v_fc->>'explanation',
                v_version_id
              )
              returning id into v_fc_id;

              v_flashcards_count := v_flashcards_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'flashcard', v_fc_id);

              if jsonb_typeof(v_fc->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_fc->'concept_ids'))::uuid
                loop
                  insert into public.flashcard_concepts (flashcard_id, concept_id)
                  values (v_fc_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_fc->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_fc->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.flashcard_concepts (flashcard_id, concept_id)
                    values (v_fc_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Objective Flashcard Provenance Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_fc ? 'source_release_id' and v_source_releases_map ? (v_fc->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_release_id'))::uuid;
                elsif v_fc ? 'source_id' and v_source_releases_map ? (v_fc->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_fc->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(v_obj_rel_id, v_default_rel_id);
                end if;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'flashcard',
                    v_fc_id,
                    'derived_from',
                    coalesce(v_fc->>'citation', coalesce(v_fc->>'citation_location', coalesce(v_fc->>'front', 'Objective Flashcard'))),
                    coalesce(v_fc->>'notes', 'Flashcard derived from authoritative objective blueprint'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;
            end loop;
          end if;

          -- Objective Assessment Items
          if jsonb_typeof(v_obj->'assessment_items') = 'array' then
            for v_item in select * from jsonb_array_elements(v_obj->'assessment_items')
            loop
              v_stim_key := v_item->>'stimulus_key';
              v_stim_id := null;
              if v_stim_key is not null and v_stimuli_map ? v_stim_key then
                v_stim_id := (v_stimuli_map->>v_stim_key)::uuid;
              end if;

              insert into public.assessment_items (
                stimulus_id, prompt, interaction_type, response_spec, scoring_spec, explanation, origin_target_version_id
              ) values (
                v_stim_id,
                v_item->>'prompt',
                coalesce(v_item->>'interaction_type', 'single_choice'),
                coalesce(v_item->'response_spec', '{}'::jsonb),
                coalesce(v_item->'scoring_spec', '{}'::jsonb),
                v_item->>'explanation',
                v_version_id
              )
              returning id into v_item_id;

              v_items_count := v_items_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'assessment_item', v_item_id);

              if jsonb_typeof(v_item->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_item->'concept_ids'))::uuid
                loop
                  insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                  values (v_item_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_item->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_item->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                    values (v_item_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Objective Assessment Item Provenance Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_item ? 'source_release_id' and v_source_releases_map ? (v_item->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_release_id'))::uuid;
                elsif v_item ? 'source_id' and v_source_releases_map ? (v_item->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(v_obj_rel_id, v_default_rel_id);
                end if;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'assessment_item',
                    v_item_id,
                    'derived_from',
                    coalesce(v_item->>'citation', coalesce(v_item->>'citation_location', substring(coalesce(v_item->>'prompt', 'Assessment Item') from 1 for 100))),
                    coalesce(v_item->>'notes', 'Assessment item derived from authoritative blueprint'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;
            end loop;
          end if;

          -- Lessons
          if jsonb_typeof(v_obj->'lessons') = 'array' then
            for v_lesson in select * from jsonb_array_elements(v_obj->'lessons')
            loop
              insert into public.lessons (
                title, description, visibility, origin_target_version_id
              ) values (
                v_lesson->>'title',
                coalesce(v_lesson->>'description', v_lesson->>'summary'),
                'public',
                v_version_id
              )
              returning id into v_lesson_id;

              v_lessons_count := v_lessons_count + 1;
              insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
              values (v_version_id, 'lesson', v_lesson_id);

              -- Lesson Source Mapping
              if v_default_rel_id is not null then
                v_entity_rel_id := null;
                if v_lesson ? 'source_release_id' and v_source_releases_map ? (v_lesson->>'source_release_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_lesson->>'source_release_id'))::uuid;
                elsif v_lesson ? 'source_id' and v_source_releases_map ? (v_lesson->>'source_id') then
                  v_entity_rel_id := (v_source_releases_map->>(v_lesson->>'source_id'))::uuid;
                else
                  v_entity_rel_id := coalesce(
                    (v_source_releases_map->>(v_obj->>'source_release_id'))::uuid,
                    (v_source_releases_map->>(v_obj->>'source_id'))::uuid,
                    coalesce(
                      (v_source_releases_map->>(v_domain->>'source_release_id'))::uuid,
                      (v_source_releases_map->>(v_domain->>'source_id'))::uuid,
                      v_default_rel_id
                    )
                  );
                end if;

                v_lesson_rel_id := v_entity_rel_id;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'lesson',
                    v_lesson_id,
                    'derived_from',
                    coalesce(v_lesson->>'citation', coalesce(v_lesson->>'citation_location', coalesce(v_lesson->>'title', 'Lesson'))),
                    coalesce(v_lesson->>'notes', 'Lesson derived from authoritative source'),
                    '{}'::jsonb
                  )
                  on conflict (source_release_id, entity_type, entity_id, relationship) do update
                  set citation_location = excluded.citation_location,
                      notes = excluded.notes,
                      metadata = excluded.metadata
                  returning id into v_mapping_id;

                  v_mappings_count := v_mappings_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'content_source_mapping', v_mapping_id)
                  on conflict do nothing;
                end if;
              end if;

              -- Bind lesson to objective
              insert into public.curriculum_node_lessons (curriculum_node_id, lesson_id, sort_order)
              values (v_obj_id, v_lesson_id, coalesce((v_lesson->>'order_index')::int, 0))
              on conflict do nothing;

              -- Scoped lesson concept linking
              if jsonb_typeof(v_lesson->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_lesson->'concept_ids'))::uuid
                loop
                  insert into public.lesson_concepts (lesson_id, concept_id)
                  values (v_lesson_id, v_concept_id)
                  on conflict do nothing;
                end loop;
              end if;

              if jsonb_typeof(v_lesson->'concept_slugs') = 'array' then
                for v_raw_concept_ref in select jsonb_array_elements_text(v_lesson->'concept_slugs')
                loop
                  if v_concepts_map ? v_raw_concept_ref then
                    v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                    insert into public.lesson_concepts (lesson_id, concept_id)
                    values (v_lesson_id, v_resolved_cid)
                    on conflict do nothing;
                  end if;
                end loop;
              end if;

              -- Lesson Blocks
              if jsonb_typeof(v_lesson->'blocks') = 'array' then
                for v_block in select * from jsonb_array_elements(v_lesson->'blocks')
                loop
                  insert into public.lesson_blocks (
                    lesson_id, block_type, content, sort_order
                  ) values (
                    v_lesson_id,
                    coalesce(v_block->>'block_type', 'markdown'),
                    coalesce(v_block->'content', '{}'::jsonb),
                    coalesce((v_block->>'sort_order')::int, 0)
                  )
                  returning id into v_block_id;

                  v_blocks_count := v_blocks_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'lesson_block', v_block_id);

                  -- Lesson Block Provenance Mapping
                  if v_default_rel_id is not null then
                    v_entity_rel_id := null;
                    if v_block ? 'source_release_id' and v_source_releases_map ? (v_block->>'source_release_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_block->>'source_release_id'))::uuid;
                    elsif v_block ? 'source_id' and v_source_releases_map ? (v_block->>'source_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_block->>'source_id'))::uuid;
                    else
                      v_entity_rel_id := coalesce(v_lesson_rel_id, v_default_rel_id);
                    end if;

                    if v_entity_rel_id is not null then
                      insert into public.content_source_mappings (
                        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                      ) values (
                        v_entity_rel_id,
                        'lesson_block',
                        v_block_id,
                        'derived_from',
                        coalesce(v_block->>'citation', coalesce(v_block->>'citation_location', coalesce(v_lesson->>'title', 'Lesson Block'))),
                        coalesce(v_block->>'notes', 'Lesson content block citation'),
                        '{}'::jsonb
                      )
                      on conflict (source_release_id, entity_type, entity_id, relationship) do update
                      set citation_location = excluded.citation_location,
                          notes = excluded.notes,
                          metadata = excluded.metadata
                      returning id into v_mapping_id;

                      v_mappings_count := v_mappings_count + 1;
                      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                      values (v_version_id, 'content_source_mapping', v_mapping_id)
                      on conflict do nothing;
                    end if;
                  end if;
                end loop;
              end if;

              -- Lesson Terms
              if jsonb_typeof(v_lesson->'terms') = 'array' then
                for v_term in select * from jsonb_array_elements(v_lesson->'terms')
                loop
                  insert into public.terms (lesson_id, term, definition)
                  values (v_lesson_id, v_term->>'term', v_term->>'definition');
                end loop;
              end if;

              -- Lesson Questions
              if jsonb_typeof(v_lesson->'questions') = 'array' then
                for v_question in select * from jsonb_array_elements(v_lesson->'questions')
                loop
                  insert into public.questions (
                    lesson_id, question_text, options, correct_answer, type, explanation
                  ) values (
                    v_lesson_id,
                    coalesce(v_question->>'question_text', v_question->>'question'),
                    coalesce(v_question->'options', '[]'::jsonb),
                    coalesce((coalesce(v_question->>'correct_answer', v_question->>'correct_index'))::int, 0),
                    coalesce(v_question->>'type', 'mcq'),
                    v_question->>'explanation'
                  );
                  v_questions_count := v_questions_count + 1;
                end loop;
              end if;

              -- Lesson Assessment Items
              if jsonb_typeof(v_lesson->'assessment_items') = 'array' then
                for v_item in select * from jsonb_array_elements(v_lesson->'assessment_items')
                loop
                  v_stim_key := v_item->>'stimulus_key';
                  v_stim_id := null;
                  if v_stim_key is not null and v_stimuli_map ? v_stim_key then
                    v_stim_id := (v_stimuli_map->>v_stim_key)::uuid;
                  end if;

                  insert into public.assessment_items (
                    lesson_id, stimulus_id, prompt, interaction_type, response_spec, scoring_spec, explanation, origin_target_version_id
                  ) values (
                    v_lesson_id,
                    v_stim_id,
                    v_item->>'prompt',
                    coalesce(v_item->>'interaction_type', 'single_choice'),
                    coalesce(v_item->'response_spec', '{}'::jsonb),
                    coalesce(v_item->'scoring_spec', '{}'::jsonb),
                    v_item->>'explanation',
                    v_version_id
                  )
                  returning id into v_item_id;

                  v_items_count := v_items_count + 1;
                  insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                  values (v_version_id, 'assessment_item', v_item_id);

                  if jsonb_typeof(v_item->'concept_ids') = 'array' then
                    for v_concept_id in select (jsonb_array_elements_text(v_item->'concept_ids'))::uuid
                    loop
                      insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                      values (v_item_id, v_concept_id)
                      on conflict do nothing;
                    end loop;
                  end if;

                  if jsonb_typeof(v_item->'concept_slugs') = 'array' then
                    for v_raw_concept_ref in select jsonb_array_elements_text(v_item->'concept_slugs')
                    loop
                      if v_concepts_map ? v_raw_concept_ref then
                        v_resolved_cid := (v_concepts_map->>v_raw_concept_ref)::uuid;
                        insert into public.assessment_item_concepts (assessment_item_id, concept_id)
                        values (v_item_id, v_resolved_cid)
                        on conflict do nothing;
                      end if;
                    end loop;
                  end if;

                  -- Lesson Assessment Item Provenance Mapping
                  if v_default_rel_id is not null then
                    v_entity_rel_id := null;
                    if v_item ? 'source_release_id' and v_source_releases_map ? (v_item->>'source_release_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_release_id'))::uuid;
                    elsif v_item ? 'source_id' and v_source_releases_map ? (v_item->>'source_id') then
                      v_entity_rel_id := (v_source_releases_map->>(v_item->>'source_id'))::uuid;
                    else
                      v_entity_rel_id := coalesce(v_lesson_rel_id, v_default_rel_id);
                    end if;

                    if v_entity_rel_id is not null then
                      insert into public.content_source_mappings (
                        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                      ) values (
                        v_entity_rel_id,
                        'assessment_item',
                        v_item_id,
                        'derived_from',
                        coalesce(v_item->>'citation', coalesce(v_item->>'citation_location', substring(coalesce(v_item->>'prompt', 'Lesson Assessment Item') from 1 for 100))),
                        coalesce(v_item->>'notes', 'Lesson assessment item derived from authoritative blueprint'),
                        '{}'::jsonb
                      )
                      on conflict (source_release_id, entity_type, entity_id, relationship) do update
                      set citation_location = excluded.citation_location,
                          notes = excluded.notes,
                          metadata = excluded.metadata
                      returning id into v_mapping_id;

                      v_mappings_count := v_mappings_count + 1;
                      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
                      values (v_version_id, 'content_source_mapping', v_mapping_id)
                      on conflict do nothing;
                    end if;
                  end if;
                end loop;
              end if;

            end loop;
          end if; -- lessons

        end loop;
      end if; -- objectives

    end loop;
  end if; -- domains

  -- 11. Ingest Explicit Custom Source Mappings
  if jsonb_typeof(payload->'source_mappings') = 'array' then
    for v_source_mapping in select * from jsonb_array_elements(payload->'source_mappings')
    loop
      insert into public.content_source_mappings (
        source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
      ) values (
        (v_source_mapping->>'source_release_id')::uuid,
        v_source_mapping->>'entity_type',
        (v_source_mapping->>'entity_id')::uuid,
        coalesce(v_source_mapping->>'relationship', 'derived_from'),
        coalesce(v_source_mapping->>'citation_location', v_source_mapping->>'section_reference'),
        coalesce(v_source_mapping->>'notes', v_source_mapping->>'citation_text'),
        coalesce(v_source_mapping->'metadata', '{}'::jsonb)
      )
      on conflict (source_release_id, entity_type, entity_id, relationship) do update
      set citation_location = excluded.citation_location,
          notes = excluded.notes,
          metadata = excluded.metadata
      returning id into v_mapping_id;

      v_mappings_count := v_mappings_count + 1;
      insert into public.content_import_artifacts (target_version_id, entity_type, entity_id)
      values (v_version_id, 'content_source_mapping', v_mapping_id)
      on conflict do nothing;
    end loop;
  end if;

  -- 12. Ingest Concept Version Mappings
  if jsonb_typeof(payload->'target_version_concept_mappings') = 'array' then
    for v_mapping in select * from jsonb_array_elements(payload->'target_version_concept_mappings')
    loop
      v_from_concept_id := (v_mapping->>'from_concept_id')::uuid;
      v_to_concept_id := case when v_mapping->>'to_concept_id' is not null
                              then (v_mapping->>'to_concept_id')::uuid
                              else null end;

      insert into public.target_version_concept_mappings (
        from_target_version_id, from_concept_id, to_target_version_id, to_concept_id,
        mapping_type, confidence, rationale
      ) values (
        v_version_id,
        v_from_concept_id,
        (v_mapping->>'to_target_version_id')::uuid,
        v_to_concept_id,
        coalesce(v_mapping->>'mapping_type', 'equivalent'),
        case when v_mapping->>'confidence' is not null
             then (v_mapping->>'confidence')::numeric
             else 1.0 end,
        v_mapping->>'rationale'
      )
      on conflict (from_target_version_id, from_concept_id, to_target_version_id, to_concept_id) do update
      set mapping_type = excluded.mapping_type,
          confidence = excluded.confidence,
          rationale = excluded.rationale;
    end loop;
  end if;

  -- 13. Return Ingestion Summary
  return jsonb_build_object(
    'target_version_id', v_version_id,
    'concepts_count', v_concepts_count,
    'domains_count', v_domains_count,
    'objectives_count', v_objectives_count,
    'lessons_count', v_lessons_count,
    'blocks_count', v_blocks_count,
    'assessment_items_count', v_items_count,
    'flashcards_count', v_flashcards_count,
    'stimuli_count', v_stimuli_count,
    'questions_count', v_questions_count,
    'mappings_count', v_mappings_count
  );
end;
$$;

revoke all on function public.ingest_curriculum_manifest(jsonb) from public, anon, authenticated;
grant execute on function public.ingest_curriculum_manifest(jsonb) to service_role;
