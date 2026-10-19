-- EXM-02A foundation: source/edition-specific validity for canonical assessment items.
-- Private editorial record. No learner-facing answer locations or review notes are exposed.
-- No content is seeded or automatically approved when a reference manifest changes.

create function public.exam_item_answer_locations_valid(p_locations jsonb)
returns boolean
language plpgsql immutable security invoker
set search_path=pg_catalog
as $$
declare
  entry jsonb;
begin
  if jsonb_typeof(p_locations) is distinct from 'array'
     or jsonb_array_length(p_locations) < 1
     or jsonb_array_length(p_locations) > 12 then
    return false;
  end if;
  for entry in select value from jsonb_array_elements(p_locations) loop
    if jsonb_typeof(entry) is distinct from 'object'
       or length(btrim(coalesce(entry->>'section',''))) < 1
       or length(btrim(coalesce(entry->>'source_page',''))) < 1
       or length(coalesce(entry->>'section','')) > 240
       or length(coalesce(entry->>'source_page','')) > 80 then
      return false;
    end if;
  end loop;
  return true;
end
$$;
revoke all on function public.exam_item_answer_locations_valid(jsonb)
  from public,anon,authenticated;
grant execute on function public.exam_item_answer_locations_valid(jsonb)
  to service_role;

create table public.assessment_item_reference_validity (
  id uuid primary key default gen_random_uuid(),
  assessment_item_id uuid not null
    references public.assessment_items(id) on update restrict on delete restrict,
  manifest_revision_id uuid not null
    references public.exam_reference_manifest_revisions(id)
      on update restrict on delete restrict,
  item_content_revision integer not null check (item_content_revision > 0),
  item_content_sha256 text not null check (item_content_sha256 ~ '^[a-f0-9]{64}$'),
  answer_location_revision integer not null check (answer_location_revision > 0),
  reference_edition_key text not null
    check (reference_edition_key ~ '^[a-z][a-z0-9_-]{1,90}$'),
  reference_edition text not null check (length(btrim(reference_edition)) between 1 and 180),
  source_release_id uuid not null
    references public.content_source_releases(id)
      on update restrict on delete restrict,
  expected_locations jsonb not null
    check (public.exam_item_answer_locations_valid(expected_locations)),
  author_ref text not null check (length(btrim(author_ref)) between 3 and 150),
  -- Explicit boolean supplied by accountable human; never default to false.
  ai_drafted boolean not null,
  reviewer_ref text,
  reviewer_qualification_evidence text,
  reviewer_edition_access_evidence text,
  rights_review_status text not null default 'pending'
    check (rights_review_status in ('pending','approved','rejected')),
  review_status text not null default 'pending'
    check (review_status in ('pending','approved','rejected')),
  publication_status text not null default 'draft'
    check (publication_status in ('draft','published','retired')),
  reviewed_at timestamptz,
  review_minutes integer check (review_minutes between 1 and 10000),
  created_at timestamptz not null default now(),
  unique (assessment_item_id,manifest_revision_id,
    item_content_revision,answer_location_revision),
  constraint exam_answer_independent_reviewer check (
    reviewer_ref is null or btrim(reviewer_ref) <> btrim(author_ref)),
  constraint exam_answer_published_approval check (
    publication_status <> 'published'
    or (review_status='approved'
      and rights_review_status='approved'
      and reviewer_ref is not null and length(btrim(reviewer_ref)) >= 3
      and reviewer_qualification_evidence is not null
      and length(btrim(reviewer_qualification_evidence)) >= 8
      and reviewer_edition_access_evidence is not null
      and length(btrim(reviewer_edition_access_evidence)) >= 8
      and reviewed_at is not null and review_minutes is not null))
);

create unique index exam_item_one_published_binding_per_manifest
  on public.assessment_item_reference_validity
    (assessment_item_id,manifest_revision_id)
  where publication_status='published';

create index exam_item_reference_re_review_idx
  on public.assessment_item_reference_validity
    (manifest_revision_id,publication_status,assessment_item_id);

comment on table public.assessment_item_reference_validity is
 'PRIVATE editorial answer-location review records. Exact manifest ID, item content and answer revisions; separate qualified human approval. No auto-carry-forward or client read grants.';

create function public.guard_exam_item_reference_validity()
returns trigger
language plpgsql security invoker
set search_path=pg_catalog,public
as $$
declare
  m public.exam_reference_manifest_revisions%rowtype;
  i public.assessment_items%rowtype;
  entry jsonb;
  valid_book boolean;
begin
  if tg_op='DELETE' then
    if old.publication_status <> 'draft' then
      raise exception 'Reviewed answer-location bindings cannot be deleted';
    end if;
    return old;
  end if;

  if tg_op='UPDATE' and old.publication_status in ('published','retired') then
    if old.publication_status='published'
       and new.publication_status='retired'
       and (to_jsonb(new)-'publication_status')
           = (to_jsonb(old)-'publication_status') then
      return new;
    end if;
    raise exception 'Published answer-location bindings are immutable; create a new review revision';
  end if;

  select * into m from public.exam_reference_manifest_revisions
    where id=new.manifest_revision_id;
  select * into i from public.assessment_items where id=new.assessment_item_id;

  if not found or i.origin_target_version_id is null
     or i.origin_target_version_id <> m.target_version_id then
    raise exception 'Item must be canonical and owned by the exact manifest target version';
  end if;

  if new.publication_status='published' then
    if m.publication_status <> 'published' then
      raise exception 'Cannot approve an answer for an unpublished/retired reference manifest';
    end if;

    valid_book := false;
    for entry in select value from jsonb_array_elements(m.reference_entries) loop
      if entry->>'key' = new.reference_edition_key
         and entry->>'edition' = new.reference_edition then
        valid_book := true;
      end if;
    end loop;
    if not valid_book then
      raise exception 'Answer source edition is not part of this exact manifest revision';
    end if;

    if not exists (
      select 1 from public.content_source_releases sr
      where sr.id = new.source_release_id
        and sr.version = new.reference_edition
    ) then
      raise exception 'Answer citation source release is not the exact edition';
    end if;

    if new.review_status <> 'approved'
       or new.rights_review_status <> 'approved'
       or new.reviewer_ref is null
       or new.reviewer_qualification_evidence is null
       or new.reviewer_edition_access_evidence is null
       or new.reviewed_at is null
       or new.reviewed_at > now()
       or new.review_minutes is null
       or btrim(new.author_ref) = btrim(new.reviewer_ref) then
      raise exception 'Independent source/edition/rights review is required';
    end if;
  end if;

  return new;
end
$$;
revoke all on function public.guard_exam_item_reference_validity()
  from public,anon,authenticated;

create trigger trg_guard_exam_item_reference_validity
  before insert or update or delete
  on public.assessment_item_reference_validity
  for each row execute function public.guard_exam_item_reference_validity();

-- A learner can edit their own ordinary assessment items, but cannot alter
-- an item after a reviewed edition binding has been published against its
-- exact content. New question text requires a new canonical item identity.
create function public.guard_exam_item_after_reference_approval()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,pg_temp
as $$
begin
  if exists (
    select 1 from public.assessment_item_reference_validity b
    where b.assessment_item_id=old.id
      and b.publication_status in ('published','retired')
  ) then
    if tg_op='DELETE' then
      raise exception 'Reviewed reference item is immutable';
    end if;
    if (to_jsonb(new)-'updated_at') is distinct from
       (to_jsonb(old)-'updated_at') then
      raise exception 'Reviewed reference item content is immutable; create a new item';
    end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end
$$;
revoke all on function public.guard_exam_item_after_reference_approval()
  from public,anon,authenticated;

create trigger trg_guard_exam_item_after_reference_approval
  before update or delete on public.assessment_items
  for each row execute function public.guard_exam_item_after_reference_approval();

-- A dynamic "affected item" queue; NEVER automatically reapproves old
-- bindings when a manifest revision changes. Service role only.
create function public.exam_reference_items_requiring_review(
  p_prior_manifest_id uuid, p_new_manifest_id uuid
) returns table (assessment_item_id uuid, previous_binding_id uuid)
language sql stable security invoker
set search_path=pg_catalog,public
as $$
  select distinct old_binding.assessment_item_id,
         old_binding.id as previous_binding_id
  from public.assessment_item_reference_validity old_binding
  join public.exam_reference_manifest_revisions prior
    on prior.id=old_binding.manifest_revision_id
  join public.exam_reference_manifest_revisions next_manifest
    on next_manifest.id=p_new_manifest_id
  where old_binding.manifest_revision_id=p_prior_manifest_id
    and old_binding.publication_status in ('published','retired')
    and prior.target_version_id=next_manifest.target_version_id
    and prior.exam_part_key=next_manifest.exam_part_key
    and not exists (
      select 1 from public.assessment_item_reference_validity newer
      where newer.assessment_item_id=old_binding.assessment_item_id
        and newer.manifest_revision_id=next_manifest.id
        and newer.publication_status='published'
    )
$$;
revoke all on function public.exam_reference_items_requiring_review(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.exam_reference_items_requiring_review(uuid,uuid)
  to service_role;

alter table public.assessment_item_reference_validity enable row level security;
revoke all on public.assessment_item_reference_validity
  from public,anon,authenticated;
grant select,insert,update,delete on public.assessment_item_reference_validity
  to service_role;
-- No anon/authenticated SELECT and no RLS public policy: answer keys and
-- pending reviewer credentials remain private, including held-out items.
