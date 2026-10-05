-- ============================================================================
-- Migration: 20261006000000_import_ownership_and_staging.sql
-- Description: Phase C.5 — Import Ownership, Atomicity & Staging Visibility
--
-- Key fixes:
--   1. content_import_artifacts tracking table for strict artifact ownership.
--   2. origin_target_version_id column on lessons, assessment_stimuli,
--      assessment_items, and flashcards for target-version-bound RLS.
--   3. curriculum_reviewers table and is_target_reviewer() helper for beta previews.
--   4. Hardened RLS policies: draft and review content are strictly hidden from
--      public queries until published; review_ready can be previewed by designated reviewers.
--   5. TargetVersion lifecycle trigger enforcing frozen review_ready and state transitions.
--   6. Hardened clean_draft_target_version() restricted to service_role/owner and
--      operating strictly via content_import_artifacts (no cross-target data loss).
--   7. Atomic ingest_curriculum_manifest() transaction RPC.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Explicit Artifact Ownership Model
-- ----------------------------------------------------------------------------

-- Add origin_target_version_id to content entities
alter table public.lessons
  add column if not exists origin_target_version_id uuid
    references public.target_versions(id) on delete set null;

create index if not exists lessons_origin_tv_idx
  on public.lessons(origin_target_version_id);

alter table public.assessment_stimuli
  add column if not exists origin_target_version_id uuid
    references public.target_versions(id) on delete set null;

create index if not exists assessment_stimuli_origin_tv_idx
  on public.assessment_stimuli(origin_target_version_id);

alter table public.assessment_items
  add column if not exists origin_target_version_id uuid
    references public.target_versions(id) on delete set null;

create index if not exists assessment_items_origin_tv_idx
  on public.assessment_items(origin_target_version_id);

alter table public.flashcards
  add column if not exists origin_target_version_id uuid
    references public.target_versions(id) on delete set null;

create index if not exists flashcards_origin_tv_idx
  on public.flashcards(origin_target_version_id);

-- Import artifact tracking table
create table if not exists public.content_import_artifacts (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null references public.target_versions(id) on delete cascade,
  entity_type text not null check (entity_type in (
    'lesson', 'lesson_block', 'flashcard', 'assessment_item',
    'assessment_stimulus', 'term', 'question', 'curriculum_node', 'content_source_mapping'
  )),
  entity_id uuid not null,
  manifest_key text,
  created_at timestamptz not null default now(),
  unique (target_version_id, entity_type, entity_id)
);

create index if not exists content_import_artifacts_tv_idx
  on public.content_import_artifacts(target_version_id, entity_type);

alter table public.content_import_artifacts enable row level security;
drop policy if exists "artifacts_access" on public.content_import_artifacts;
create policy "artifacts_access" on public.content_import_artifacts
  for all using (
    auth.role() = 'service_role'
    or exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = content_import_artifacts.target_version_id
        and lt.created_by = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- 2. Designated Beta Reviewers Table & Helper
-- ----------------------------------------------------------------------------
create table if not exists public.curriculum_reviewers (
  id uuid primary key default gen_random_uuid(),
  target_id uuid references public.learning_targets(id) on delete cascade, -- null = global reviewer
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'reviewer' check (role in ('reviewer', 'editor', 'admin')),
  created_at timestamptz not null default now()
);

create unique index if not exists curr_reviewers_user_target_idx
  on public.curriculum_reviewers(user_id, coalesce(target_id, '00000000-0000-0000-0000-000000000000'::uuid));

alter table public.curriculum_reviewers enable row level security;
drop policy if exists "reviewers_read" on public.curriculum_reviewers;
create policy "reviewers_read" on public.curriculum_reviewers
  for select using (auth.uid() = user_id or auth.role() = 'service_role');

-- Reviewer authorization helper
create or replace function public.is_target_reviewer(p_target_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.curriculum_reviewers
    where user_id = p_user_id
      and (target_id is null or target_id = p_target_id)
  );
$$;

-- ----------------------------------------------------------------------------
-- 3. Lesson Visibility Helper
-- ----------------------------------------------------------------------------
create or replace function public.is_lesson_visible(p_lesson_id uuid, p_user_id uuid)
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
        l.user_id = p_user_id
        or (l.origin_target_version_id is null and l.visibility = 'public')
        or (l.origin_target_version_id is not null and exists (
          select 1 from public.target_versions tv
          join public.learning_targets lt on lt.id = tv.target_id
          where tv.id = l.origin_target_version_id
            and (
              (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
              or (lt.created_by = p_user_id)
              or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, p_user_id))
            )
        ))
      )
  );
$$;

-- ----------------------------------------------------------------------------
-- 4. Staging Visibility: Secure RLS Policies
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
          or (target_versions.status = 'review_ready' and public.is_target_reviewer(t.id, auth.uid()))
        )
    )
  );

drop policy if exists "versions_update" on public.target_versions;
create policy "versions_update" on public.target_versions
  for update using (
    target_versions.status in ('draft', 'review_ready')
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
    )
  );

drop policy if exists "versions_delete" on public.target_versions;
create policy "versions_delete" on public.target_versions
  for delete using (
    target_versions.status = 'draft'
    and exists (
      select 1 from public.learning_targets t
      where t.id = target_versions.target_id
        and t.created_by = auth.uid()
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
          or (v.status = 'review_ready' and public.is_target_reviewer(t.id, auth.uid()))
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
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
        )
    ))
  );

-- Lesson Blocks
drop policy if exists "lesson_blocks_read" on public.lesson_blocks;
create policy "lesson_blocks_read" on public.lesson_blocks
  for select using (public.is_lesson_visible(lesson_id, auth.uid()));

-- Terms
drop policy if exists terms_read_visible on public.terms;
create policy terms_read_visible on public.terms
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id, auth.uid()));

-- Questions
drop policy if exists questions_read_visible on public.questions;
create policy questions_read_visible on public.questions
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id, auth.uid()));

-- Lesson Concepts
drop policy if exists lesson_concepts_read on public.lesson_concepts;
create policy lesson_concepts_read on public.lesson_concepts
  for select to authenticated, anon
  using (public.is_lesson_visible(lesson_id, auth.uid()));

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
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
        )
    ))
  );

-- Assessment Items
drop policy if exists "assessment_items_read" on public.assessment_items;
create policy "assessment_items_read" on public.assessment_items
  for select using (
    user_id = auth.uid()
    or (lesson_id is not null and public.is_lesson_visible(lesson_id, auth.uid()))
    or (origin_target_version_id is not null and exists (
      select 1 from public.target_versions tv
      join public.learning_targets lt on lt.id = tv.target_id
      where tv.id = assessment_items.origin_target_version_id
        and (
          (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
          or (lt.created_by = auth.uid())
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
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
          or (a.lesson_id is not null and public.is_lesson_visible(a.lesson_id, auth.uid()))
          or (a.origin_target_version_id is not null and exists (
            select 1 from public.target_versions tv
            join public.learning_targets lt on lt.id = tv.target_id
            where tv.id = a.origin_target_version_id
              and (
                (tv.status = 'published' and lt.status = 'published' and lt.is_public = true)
                or (lt.created_by = auth.uid())
                or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
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
          or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
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
                or (tv.status = 'review_ready' and public.is_target_reviewer(lt.id, auth.uid()))
              )
          ))
          or (f.origin_target_version_id is null and f.user_id is null)
        )
    )
  );

-- ----------------------------------------------------------------------------
-- 5. TargetVersion State Machine Trigger
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
    -- Published versions cannot change status except to 'retired'
    if old.status = 'published' and new.status <> 'retired' and new.status <> 'published' then
      raise exception 'Published versions are immutable and can only transition to "retired".';
    end if;

    -- Retired versions are completely immutable
    if old.status = 'retired' and (new.status <> 'retired' or new.* is distinct from old.*) then
      raise exception 'Retired versions are completely immutable.';
    end if;

    -- Draft status transitions: must go through review_ready before publishing
    if old.status = 'draft' then
      if new.status not in ('draft', 'review_ready') then
        raise exception 'Invalid status transition: draft must be staged to "review_ready" before publishing.';
      end if;
    end if;

    -- review_ready status transitions
    if old.status = 'review_ready' then
      if new.status not in ('draft', 'published', 'review_ready') then
        raise exception 'Invalid status transition: review_ready can only transition to "draft" or "published".';
      end if;

      -- While in review_ready (status not changing), metadata is frozen!
      if new.status = 'review_ready' and (
        new.version_code <> old.version_code or
        new.title is distinct from old.title or
        new.description is distinct from old.description or
        new.metadata is distinct from old.metadata or
        new.target_id <> old.target_id
      ) then
        raise exception 'TargetVersion is frozen in "review_ready" status. Revert status to "draft" before making edits.';
      end if;
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_target_versions_lifecycle on public.target_versions;
create trigger trg_target_versions_lifecycle
  before update or delete on public.target_versions
  for each row execute function public.trg_target_versions_lifecycle();

-- ----------------------------------------------------------------------------
-- 6. Hardened clean_draft_target_version (Service-Role / Owner Only)
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
  v_target_id uuid;
  v_target_owner uuid;
begin
  select tv.status, tv.target_id, lt.created_by
  into v_status, v_target_id, v_target_owner
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

  -- 1. Delete content_source_mappings explicitly tracked as artifacts of this draft
  delete from public.content_source_mappings
  where id in (
    select entity_id
    from public.content_import_artifacts
    where target_version_id = p_version_id
      and entity_type = 'content_source_mapping'
  )
  or (entity_type = 'target_version' and entity_id = p_version_id);

  -- Clean any orphaned content_source_mappings whose referenced entity no longer exists
  delete from public.content_source_mappings
  where (entity_type = 'lesson' and not exists (select 1 from public.lessons where id = entity_id))
     or (entity_type = 'curriculum_node' and not exists (select 1 from public.curriculum_nodes where id = entity_id))
     or (entity_type = 'assessment_stimulus' and not exists (select 1 from public.assessment_stimuli where id = entity_id))
     or (entity_type = 'assessment_item' and not exists (select 1 from public.assessment_items where id = entity_id))
     or (entity_type = 'flashcard' and not exists (select 1 from public.flashcards where id = entity_id));

  -- 2. Delete assessment_items created specifically for this draft version
  delete from public.assessment_items
  where origin_target_version_id = p_version_id
     or id in (
       select entity_id
       from public.content_import_artifacts
       where target_version_id = p_version_id
         and entity_type = 'assessment_item'
     );

  -- 3. Delete assessment_stimuli created specifically for this draft version
  delete from public.assessment_stimuli
  where origin_target_version_id = p_version_id
     or id in (
       select entity_id
       from public.content_import_artifacts
       where target_version_id = p_version_id
         and entity_type = 'assessment_stimulus'
     );

  -- 4. Delete flashcards created specifically for this draft version
  delete from public.flashcards
  where origin_target_version_id = p_version_id
     or id in (
       select entity_id
       from public.content_import_artifacts
       where target_version_id = p_version_id
         and entity_type = 'flashcard'
     );

  -- 5. Delete official lessons created specifically for this draft version
  -- (Deleting the lesson automatically cascades to lesson_blocks, terms, questions, lesson_concepts)
  delete from public.lessons
  where origin_target_version_id = p_version_id
     or id in (
       select entity_id
       from public.content_import_artifacts
       where target_version_id = p_version_id
         and entity_type = 'lesson'
     )
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

  -- 6. Delete curriculum nodes of this draft (cascades to curriculum_node_concepts, cnl)
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
-- 7. Fully Transactional Ingestion RPC (ingest_curriculum_manifest)
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
  v_stimuli_count int := 0;
  v_domains_count int := 0;
  v_objectives_count int := 0;
  v_lessons_count int := 0;
  v_blocks_count int := 0;
  v_items_count int := 0;
  v_flashcards_count int := 0;
  v_questions_count int := 0;
  v_mappings_count int := 0;

  -- Iterators
  v_source_rel jsonb;
  v_source_artifact jsonb;
  v_rel_id uuid;
  v_stim jsonb;
  v_stim_id uuid;
  v_stim_key text;
  v_domain jsonb;
  v_domain_id uuid;
  v_obj jsonb;
  v_obj_id uuid;
  v_concept_id uuid;
  v_lesson jsonb;
  v_lesson_id uuid;
  v_block jsonb;
  v_term jsonb;
  v_question jsonb;
  v_item jsonb;
  v_item_id uuid;
  v_fc jsonb;
  v_fc_id uuid;
  v_mapping jsonb;
  v_from_concept_id uuid;
  v_to_concept_id uuid;
  v_source_mapping jsonb;
  v_mapping_id uuid;
  v_source_releases_map jsonb := '{}'::jsonb;
  v_default_rel_id uuid := null;
  v_source_rel_idx int := 0;
  v_entity_rel_id uuid;

  -- Key Maps
  v_stimuli_map jsonb := '{}'::jsonb;
begin
  -- 1. Security Check: Service role only
  if coalesce(current_setting('request.jwt.claim.role', true), '') <> 'service_role'
     and auth.role() <> 'service_role' then
    raise exception 'Unauthorized: ingest_curriculum_manifest requires service_role privilege';
  end if;

  -- 2. Extract Field
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

  -- 3. Extract Target
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

  -- 4. Extract TargetVersion
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

  -- 6. Ingest Source Releases & Artifacts
  if jsonb_typeof(payload->'source_releases') = 'array' then
    for v_source_rel in select * from jsonb_array_elements(payload->'source_releases')
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

      -- Artifacts
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

  -- 7. Ingest Shared Stimuli (root-level & objective-level)
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
            coalesce(v_stim->>'citation', 'Official Blueprint Stimulus'),
            'Assessment stimulus mapping',
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

  -- 8. Ingest Standalone Target-level Flashcards
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

      -- Link concepts
      if jsonb_typeof(v_fc->'concept_ids') = 'array' then
        for v_concept_id in select (jsonb_array_elements_text(v_fc->'concept_ids'))::uuid
        loop
          insert into public.flashcard_concepts (flashcard_id, concept_id)
          values (v_fc_id, v_concept_id)
          on conflict do nothing;
        end loop;
      end if;
    end loop;
  end if;

  -- 9. Ingest Domains, Objectives, Lessons, Blocks, Assessment Items
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
            coalesce(v_domain->>'citation', 'Domain ' || coalesce(v_domain->>'code', '')),
            'Curriculum domain node citation',
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
            else
              v_entity_rel_id := coalesce((v_source_releases_map->>(v_domain->>'source_release_id'))::uuid, v_default_rel_id);
            end if;

            if v_entity_rel_id is not null then
              insert into public.content_source_mappings (
                source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
              ) values (
                v_entity_rel_id,
                'curriculum_node',
                v_obj_id,
                'official_blueprint',
                coalesce(v_obj->>'citation', 'Objective ' || coalesce(v_obj->>'code', '')),
                'Curriculum objective node citation',
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

          -- Link objective concepts
          if jsonb_typeof(v_obj->'concept_ids') = 'array' then
            for v_concept_id in select (jsonb_array_elements_text(v_obj->'concept_ids'))::uuid
            loop
              insert into public.curriculum_node_concepts (curriculum_node_id, concept_id)
              values (v_obj_id, v_concept_id)
              on conflict do nothing;
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
                else
                  v_entity_rel_id := coalesce(
                    (v_source_releases_map->>(v_obj->>'source_release_id'))::uuid,
                    coalesce((v_source_releases_map->>(v_domain->>'source_release_id'))::uuid, v_default_rel_id)
                  );
                end if;

                if v_entity_rel_id is not null then
                  insert into public.content_source_mappings (
                    source_release_id, entity_type, entity_id, relationship, citation_location, notes, metadata
                  ) values (
                    v_entity_rel_id,
                    'lesson',
                    v_lesson_id,
                    'derived_from',
                    coalesce(v_lesson->>'citation', coalesce(v_lesson->>'title', 'Lesson')),
                    'Lesson derived from authoritative source',
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

              -- Scoped lesson concept linking (NO global leakage!)
              if jsonb_typeof(v_lesson->'concept_ids') = 'array' then
                for v_concept_id in select (jsonb_array_elements_text(v_lesson->'concept_ids'))::uuid
                loop
                  insert into public.lesson_concepts (lesson_id, concept_id)
                  values (v_lesson_id, v_concept_id)
                  on conflict do nothing;
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
                  );
                  v_blocks_count := v_blocks_count + 1;
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
                end loop;
              end if;

            end loop;
          end if; -- lessons

        end loop;
      end if; -- objectives

    end loop;
  end if; -- domains

  -- 10. Ingest Source Mappings
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

  -- 11. Ingest Concept Version Mappings
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
        case when v_mapping->>'to_target_version_id' is not null
             then (v_mapping->>'to_target_version_id')::uuid
             else null end,
        v_to_concept_id,
        coalesce(v_mapping->>'mapping_type', 'exact_match'),
        coalesce((v_mapping->>'confidence')::numeric, 1.0),
        v_mapping->>'rationale'
      )
      on conflict do nothing;
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'target_id', v_target_id,
    'target_slug', v_target_slug,
    'target_version_id', v_version_id,
    'version_code', v_version_code,
    'stimuli_count', v_stimuli_count,
    'domains_count', v_domains_count,
    'objectives_count', v_objectives_count,
    'lessons_count', v_lessons_count,
    'blocks_count', v_blocks_count,
    'assessment_items_count', v_items_count,
    'flashcards_count', v_flashcards_count,
    'questions_count', v_questions_count,
    'mappings_count', v_mappings_count
  );
end;
$$;

revoke all on function public.ingest_curriculum_manifest(jsonb) from public, anon, authenticated;
grant execute on function public.ingest_curriculum_manifest(jsonb) to service_role;
