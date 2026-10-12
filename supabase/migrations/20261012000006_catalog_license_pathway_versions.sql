-- P2e: carefully reviewed, versioned regulator-sourced *selected* licensing steps.
-- This does not change the original issuer directory's requirements_status:
-- a sourced partial pathway is NOT a comprehensive eligibility assessment.
create function public.catalog_license_tree_valid(node jsonb, depth integer default 0)
returns boolean language plpgsql immutable security invoker
set search_path = pg_catalog
as $$
declare
  kind text;
  item jsonb;
begin
  if node is null or jsonb_typeof(node) <> 'object' or depth > 8 then
    return false;
  end if;
  kind := node->>'op';
  if kind in ('all','any') then
    if jsonb_typeof(node->'children') is distinct from 'array'
       or jsonb_array_length(node->'children') < 2
       or jsonb_array_length(node->'children') > 20
       or (select count(*) from jsonb_object_keys(node)) <> 2 then
      return false;
    end if;
    for item in select value from jsonb_array_elements(node->'children') loop
      if not public.catalog_license_tree_valid(item, depth+1) then
        return false;
      end if;
    end loop;
    return true;
  elsif kind = 'step' then
    return (select count(*) from jsonb_object_keys(node)) between 4 and 5
       and node ? 'label' and node ? 'stage' and node ? 'source_url'
       and ((select count(*) from jsonb_object_keys(node)) = 4 or node ? 'condition')
       and length(btrim(node->>'label')) between 8 and 280
       and node->>'stage' in (
         'education','training','experience','examination',
         'background_screening','application','appointment',
         'continuing_education','authorization','other')
       and (node->>'source_url') ~ '^https://[^[:space:]]+$'
       and (not (node ? 'condition') or
         (jsonb_typeof(node->'condition')='string' and
          length(btrim(node->>'condition')) between 10 and 280));
  end if;
  return false;
end
$$;
revoke all on function public.catalog_license_tree_valid(jsonb,integer) from public,anon,authenticated;
grant execute on function public.catalog_license_tree_valid(jsonb,integer) to service_role;
comment on function public.catalog_license_tree_valid(jsonb,integer) is
 'Reject unsupported or malformed nested AND/OR pathway expressions. Source domain and legal accuracy require separate reviewer checks.';

create table public.catalog_license_pathway_versions (
  id uuid primary key default gen_random_uuid(),
  source_namespace text not null,
  source_key text not null,
  revision integer not null check (revision between 1 and 100000),
  jurisdiction text not null check (length(jurisdiction) between 2 and 48),
  route_kind text not null default 'examination'
    check (route_kind in ('examination','endorsement','renewal','other')),
  title text not null check (length(btrim(title)) between 8 and 180),
  overview text not null check (length(btrim(overview)) between 80 and 1200),
  coverage text not null default 'selected_steps_only'
    check (coverage='selected_steps_only'),
  source_url text not null check (source_url ~ '^https://[^[:space:]]+$'),
  source_checked_at timestamptz not null,
  reviewed_at timestamptz,
  reviewer text,
  effective_from date,
  effective_until date,
  supersedes_revision integer,
  review_status text not null default 'pending'
    check (review_status in ('pending','approved','rejected')),
  publication_status text not null default 'draft'
    check (publication_status in ('draft','published','retired')),
  pathway_tree jsonb not null check (public.catalog_license_tree_valid(pathway_tree)),
  created_at timestamptz not null default now(),
  constraint license_pathway_parent_fk foreign key (source_namespace,source_key)
    references public.catalog_verified_destinations(source_namespace,source_key)
    on update restrict on delete restrict,
  constraint license_pathway_revision_unique unique (source_namespace,source_key,revision),
  constraint license_pathway_supersedes_ck check (
    supersedes_revision is null or
    (supersedes_revision > 0 and supersedes_revision < revision)),
  constraint license_pathway_effective_range_ck check (
    effective_from is null or effective_until is null
    or effective_until >= effective_from),
  constraint license_pathway_approval_ck check (
    publication_status <> 'published' or (
      review_status='approved' and reviewed_at is not null
      and reviewer is not null and length(btrim(reviewer)) >= 3))
);
create unique index catalog_license_pathway_one_current_idx
  on public.catalog_license_pathway_versions (source_namespace,source_key)
  where publication_status='published';
create index catalog_license_pathway_visibility_idx
  on public.catalog_license_pathway_versions
  (source_namespace,source_key,publication_status,source_checked_at desc);

comment on table public.catalog_license_pathway_versions is
 'Versioned, regulator-sourced selected licensure steps. Explicit nested AND/OR. Partial coverage only; not comprehensive qualification, license issuance, course, or exam award.';

create function public.guard_catalog_license_pathway_version()
returns trigger language plpgsql security invoker
set search_path = public,pg_temp
as $$
declare d record;
begin
  if tg_op='DELETE' then
    if old.publication_status <> 'draft' then
      raise exception 'Reviewed pathways cannot be deleted; retire and version instead';
    end if;
    return old;
  end if;

  if tg_op='UPDATE' and old.publication_status in ('published','retired') then
    if old.publication_status='published'
       and new.publication_status='retired'
       and (to_jsonb(new) - 'publication_status')
           = (to_jsonb(old) - 'publication_status') then
      return new;
    end if;
    raise exception 'Published pathway versions are immutable; create a new revision';
  end if;

  select destination_type,jurisdiction,publication_status
    into d from public.catalog_verified_destinations
    where source_namespace=new.source_namespace and source_key=new.source_key;

  if not found or d.destination_type <> 'professional_license'
       or d.jurisdiction is distinct from new.jurisdiction then
    raise exception 'Pathway must match a professional license and its jurisdiction';
  end if;

  if new.source_checked_at > now() then
    raise exception 'Source review timestamp cannot be in the future';
  end if;

  if new.publication_status='published' then
    if d.publication_status <> 'published'
       or new.review_status <> 'approved'
       or new.reviewed_at is null
       or new.reviewer is null
       or length(btrim(new.reviewer)) < 3
       or new.reviewed_at < new.source_checked_at
       or new.reviewed_at > now()
       or new.source_checked_at < now() - interval '180 days' then
      raise exception 'Publishing requires current documented regulator review';
    end if;
    if new.supersedes_revision is not null and not exists (
      select 1 from public.catalog_license_pathway_versions previous
      where previous.source_namespace=new.source_namespace
        and previous.source_key=new.source_key
        and previous.revision=new.supersedes_revision
        and previous.publication_status='retired'
    ) then
      raise exception 'Superseded revision must first be retired';
    end if;
  end if;
  return new;
end
$$;
revoke all on function public.guard_catalog_license_pathway_version() from public,anon,authenticated;
create trigger trg_guard_catalog_license_pathway
before insert or update or delete on public.catalog_license_pathway_versions
for each row execute function public.guard_catalog_license_pathway_version();

-- A destination revoked or retired due to issuer review changes immediately
-- retires a published pathway (and prevents stale resurrection).
create function public.retire_license_pathways_after_destination_change()
returns trigger language plpgsql security invoker
set search_path=public,pg_temp
as $$
begin
  if old.publication_status='published' and new.publication_status='retired' then
    update public.catalog_license_pathway_versions
       set publication_status='retired'
     where source_namespace=new.source_namespace
       and source_key=new.source_key
       and publication_status='published';
  end if;
  return new;
end
$$;
revoke all on function public.retire_license_pathways_after_destination_change() from public,anon,authenticated;
create trigger trg_retire_license_pathway_with_destination
after update of publication_status on public.catalog_verified_destinations
for each row execute function public.retire_license_pathways_after_destination_change();

alter table public.catalog_license_pathway_versions enable row level security;
revoke all on public.catalog_license_pathway_versions from public,anon,authenticated;
grant select on public.catalog_license_pathway_versions to anon,authenticated;
grant select,insert,update,delete on public.catalog_license_pathway_versions to service_role;
create policy catalog_license_pathway_reviewed_public_select
on public.catalog_license_pathway_versions for select to anon,authenticated
using (
  publication_status='published' and review_status='approved'
  and source_checked_at >= now() - interval '180 days'
  and (effective_from is null or effective_from <= current_date)
  and (effective_until is null or effective_until >= current_date)
  and exists (
    select 1 from public.catalog_verified_destinations d
    where d.source_namespace=public.catalog_license_pathway_versions.source_namespace
      and d.source_key=public.catalog_license_pathway_versions.source_key
      and d.publication_status='published'
      and d.destination_type='professional_license'
      and d.jurisdiction=public.catalog_license_pathway_versions.jurisdiction
  )
);
