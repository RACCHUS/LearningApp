-- EXM-01: independently revisioned, source-reviewed examination reference lists.
-- Does not modify target_versions, curriculum nodes, books, or hosted learner data.
-- Generated in the repository's append-only migration naming sequence.
-- Requires review of official references BEFORE any insert is promoted to published.

create extension if not exists btree_gist with schema extensions;

create function public.exam_reference_manifest_payload_valid(
  p_references jsonb, p_rules jsonb
) returns boolean
language plpgsql immutable security invoker
set search_path = pg_catalog
as $$
declare
  entry jsonb;
  k text;
  seen_keys text[] := '{}'::text[];
  state text;
begin
  if jsonb_typeof(p_references) is distinct from 'array'
     or jsonb_array_length(p_references) > 100
     or jsonb_typeof(p_rules) is distinct from 'array'
     or jsonb_array_length(p_rules) > 50 then
    return false;
  end if;

  for entry in select value from jsonb_array_elements(p_references) loop
    if jsonb_typeof(entry) is distinct from 'object' then
      return false;
    end if;
    k := entry->>'key';
    if k is null or k !~ '^[a-z][a-z0-9_-]{1,90}$'
       or k = any(seen_keys)
       or length(btrim(coalesce(entry->>'edition',''))) < 1
       or length(btrim(coalesce(entry->>'source_page',''))) < 1 then
      return false;
    end if;
    seen_keys := array_append(seen_keys,k);
  end loop;

  seen_keys := '{}'::text[];
  for entry in select value from jsonb_array_elements(p_rules) loop
    if jsonb_typeof(entry) is distinct from 'object' then
      return false;
    end if;
    k := entry->>'name';
    state := entry->>'state';
    if k is null or k !~ '^[a-z][a-z0-9_]{1,90}$'
       or k = any(seen_keys)
       or state not in ('verified','unverified','unknown','not_applicable')
       or state is null then
      return false;
    end if;
    seen_keys := array_append(seen_keys,k);
    if state='verified' then
      if not entry ? 'value' or entry->'value'='null'::jsonb
         or length(btrim(coalesce(entry->>'source_page',''))) < 1 then
        return false;
      end if;
    elsif state in ('unknown','not_applicable') then
      if entry ? 'value' and entry->'value'<>'null'::jsonb then
        return false;
      end if;
    end if;
  end loop;
  return true;
end
$$;

revoke all on function public.exam_reference_manifest_payload_valid(jsonb,jsonb)
  from public,anon,authenticated;
grant execute on function public.exam_reference_manifest_payload_valid(jsonb,jsonb)
  to service_role;

create table public.exam_reference_manifest_revisions (
  id uuid primary key default gen_random_uuid(),
  target_version_id uuid not null
    references public.target_versions(id) on update restrict on delete restrict,
  exam_part_key text not null
    check (exam_part_key ~ '^[a-z][a-z0-9_]*$'),
  revision integer not null check (revision between 1 and 100000),
  supersedes_revision_id uuid
    references public.exam_reference_manifest_revisions(id) on delete restrict,
  effective_from date not null,
  effective_until date,
  source_release_id uuid
    references public.content_source_releases(id) on update restrict on delete restrict,
  official_source_url text,
  source_checked_at timestamptz,
  author_ref text,
  reviewer_ref text,
  reviewed_at timestamptz,
  review_status text not null default 'pending'
    check (review_status in ('pending','approved','rejected')),
  publication_status text not null default 'draft'
    check (publication_status in ('draft','review_ready','published','retired')),
  reference_entries jsonb not null default '[]'::jsonb,
  room_rules jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (target_version_id,exam_part_key,revision),
  constraint exam_manifest_date_order check (
    effective_until is null or effective_until>=effective_from),
  constraint exam_manifest_payload_shape check (
    public.exam_reference_manifest_payload_valid(reference_entries,room_rules)),
  constraint exam_manifest_publication_evidence check (
    publication_status <> 'published' or (
      review_status='approved' and source_release_id is not null
      and official_source_url ~ '^https://[^[:space:]]+$'
      and source_checked_at is not null
      and reviewer_ref is not null and length(btrim(reviewer_ref))>=3
      and author_ref is not null and length(btrim(author_ref))>=3
      and author_ref <> reviewer_ref
      and reviewed_at is not null
      and jsonb_array_length(reference_entries)>0)),
  constraint exam_manifest_no_overlapping_published
    exclude using gist (
      target_version_id with =,
      exam_part_key with =,
      daterange(effective_from,effective_until,'[]') with &&
    ) where (publication_status='published')
);

comment on table public.exam_reference_manifest_revisions is
  'Versioned independently of curricula. Public editorial identity fields are non-sensitive pseudonymous IDs; store private reviewer notes elsewhere. Approved source data, not copyrighted reference text. No learner/anon writes.';
create index exam_manifest_lookup_idx
  on public.exam_reference_manifest_revisions (
    target_version_id,exam_part_key,publication_status,effective_from
  );

create function public.guard_exam_reference_manifest_revision()
returns trigger language plpgsql security invoker
set search_path=pg_catalog,public
as $$
declare
  v record;
  parts jsonb;
  part jsonb;
  root text;
  previous public.exam_reference_manifest_revisions%rowtype;
begin
  if tg_op='DELETE' then
    if old.publication_status <> 'draft' then
      raise exception 'Reviewed or published reference manifests cannot be deleted';
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
    raise exception 'Published reference manifests are immutable; create a new revision';
  end if;

  if new.source_checked_at > now() or new.reviewed_at > now() then
    raise exception 'Source and reviewer timestamps cannot be future-dated';
  end if;

  if new.supersedes_revision_id is not null then
    if new.supersedes_revision_id = new.id then
      raise exception 'Manifest may not supersede itself';
    end if;
    select * into previous
      from public.exam_reference_manifest_revisions
      where id=new.supersedes_revision_id;
    if not found or previous.target_version_id <> new.target_version_id
       or previous.exam_part_key <> new.exam_part_key
       or previous.revision >= new.revision then
      raise exception 'Superseded revision must belong to an earlier revision of this exam part';
    end if;
    if new.publication_status='published'
       and previous.publication_status <> 'retired' then
      raise exception 'Superseded reference manifest must be retired before publication';
    end if;
  end if;

  if new.publication_status='published' then
    select v2.status, lt.status as target_status, lt.is_public, v2.metadata
      into v from public.target_versions v2
      join public.learning_targets lt on lt.id=v2.target_id
      where v2.id=new.target_version_id;

    if not found or v.status <> 'published'
       or v.target_status <> 'published' or v.is_public is distinct from true then
      raise exception 'Exam reference publication requires a public published target version';
    end if;

    parts := v.metadata->'exam_preparation'->'exam_parts';
    if jsonb_typeof(parts) is distinct from 'array' then
      raise exception 'Exam reference publication requires a typed exam-part profile';
    end if;

    root := null;
    for part in select value from jsonb_array_elements(parts) loop
      if part->>'key' = new.exam_part_key then
        root := part->>'curriculum_root_node_id';
        exit;
      end if;
    end loop;

    if root is null or root = ''
       or not exists (
         select 1 from public.curriculum_nodes cn
         where cn.target_version_id=new.target_version_id
           and cn.id::text=root
       ) then
      raise exception 'Exam part requires a valid curriculum root in the same target version';
    end if;

    if new.source_checked_at is null or new.reviewed_at is null
       or new.reviewed_at < new.source_checked_at
       or new.review_status <> 'approved'
       or new.source_release_id is null
       or length(btrim(coalesce(new.official_source_url,'')))=0
       or jsonb_array_length(new.reference_entries)=0 then
      raise exception 'Manifest must be reviewed and source-anchored before publication';
    end if;

    if not exists (
      select 1 from public.content_source_releases sr
      where sr.id=new.source_release_id
        and sr.source_url ~ '^https://[^[:space:]]+    ) then
      raise exception 'Manifest source release must link to a primary HTTPS document';
    end if;
  end if;

  return new;
end
$$;

revoke all on function public.guard_exam_reference_manifest_revision()
  from public,anon,authenticated;

create trigger trg_guard_exam_reference_manifest_revision
before insert or update or delete
on public.exam_reference_manifest_revisions
for each row execute function public.guard_exam_reference_manifest_revision();

alter table public.exam_reference_manifest_revisions enable row level security;
revoke all on public.exam_reference_manifest_revisions
  from public,anon,authenticated;
grant select on public.exam_reference_manifest_revisions to anon,authenticated;
grant select,insert,update,delete on public.exam_reference_manifest_revisions
  to service_role;

create policy exam_reference_manifest_public_select
on public.exam_reference_manifest_revisions for select
to anon,authenticated
using (
  publication_status='published'
  and review_status='approved'
  and exists (
    select 1 from public.target_versions v
    join public.learning_targets t on t.id=v.target_id
    where v.id=exam_reference_manifest_revisions.target_version_id
      and v.status='published'
      and t.status='published' and t.is_public=true
  )
);

-- Intentionally no INSERT/UPDATE/DELETE policy for anon/authenticated.
-- Draft and review_ready records are not visible over the client Data API.

      and sr.source_url = new.official_source_url
    ) then
      raise exception 'Manifest source release must link to a primary HTTPS document';
    end if;
  end if;

  return new;
end
$$;

revoke all on function public.guard_exam_reference_manifest_revision()
  from public,anon,authenticated;

create trigger trg_guard_exam_reference_manifest_revision
before insert or update or delete
on public.exam_reference_manifest_revisions
for each row execute function public.guard_exam_reference_manifest_revision();

alter table public.exam_reference_manifest_revisions enable row level security;
revoke all on public.exam_reference_manifest_revisions
  from public,anon,authenticated;
grant select on public.exam_reference_manifest_revisions to anon,authenticated;
grant select,insert,update,delete on public.exam_reference_manifest_revisions
  to service_role;

create policy exam_reference_manifest_public_select
on public.exam_reference_manifest_revisions for select
to anon,authenticated
using (
  publication_status='published'
  and review_status='approved'
  and exists (
    select 1 from public.target_versions v
    join public.learning_targets t on t.id=v.target_id
    where v.id=exam_reference_manifest_revisions.target_version_id
      and v.status='published'
      and t.status='published' and t.is_public=true
  )
);

-- Intentionally no INSERT/UPDATE/DELETE policy for anon/authenticated.
-- Draft and review_ready records are not visible over the client Data API.
