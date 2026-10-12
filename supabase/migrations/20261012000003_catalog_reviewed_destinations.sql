-- P2: public directory of source-reviewed issuer names and links only.
-- NOT a certification issuance database, course catalog or requirements audit.
-- Private intake and raw candidate metadata are never SELECT-granted to clients.
create table public.catalog_verified_destinations (
  source_namespace text not null,
  source_key text not null,
  destination_type text not null check (destination_type in
    ('certification','professional_license','licensure_exam','standardized_exam','academic_program','training_course')),
  title text not null check (length(btrim(title)) between 3 and 240),
  issuer_name text not null check (length(btrim(issuer_name)) between 2 and 200),
  jurisdiction text not null check (length(jurisdiction) between 2 and 48),
  official_url text not null check (official_url ~ '^https://[^[:space:]]+$'),
  verification_scope text not null default 'issuer_identity_and_link'
    check (verification_scope='issuer_identity_and_link'),
  requirements_status text not null default 'not_verified'
    check (requirements_status='not_verified'),
  popularity_status text not null default 'not_measured'
    check (popularity_status='not_measured'),
  publication_status text not null default 'published'
    check (publication_status in ('published','retired')),
  verification_note text not null check (length(btrim(verification_note)) >= 40),
  verified_at timestamptz not null,
  editorial_order integer not null default 100 check (editorial_order between 1 and 9999),
  created_at timestamptz not null default now(),
  primary key(source_namespace,source_key),
  foreign key(source_namespace,source_key)
    references public.catalog_intake_candidates(source_namespace,source_key)
    on update restrict on delete restrict
);
comment on table public.catalog_verified_destinations is
  'Safe public subset containing reviewed credential/issuer identity and outbound authoritative URL ONLY; no claims of eligibility, exam costs, contents, popularity or award issuance.';
create index catalog_verified_destinations_search_idx
  on public.catalog_verified_destinations(destination_type, title)
  where publication_status='published';

alter table public.catalog_verified_destinations enable row level security;
revoke all on public.catalog_verified_destinations from public, anon, authenticated;
grant select on public.catalog_verified_destinations to anon,authenticated;
grant select,insert,update,delete on public.catalog_verified_destinations to service_role;
create policy catalog_verified_destinations_public_select
  on public.catalog_verified_destinations
  for select to anon, authenticated
  using (publication_status='published');

-- Trusted admin writers must first mark matching intake candidates as reviewed.
-- All public fields (including URLs) must be consistent with the reviewed source.
create function public.guard_verified_destination_origin()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare c record;
begin
  select destination_type,title,issuer_name,jurisdiction,source_url,
         review_status,publication_status,source_rights,verified_at
    into c from public.catalog_intake_candidates
   where source_namespace=new.source_namespace and source_key=new.source_key;
  if not found or c.review_status <> 'approved'
     or c.publication_status <> 'published'
     or c.source_rights <> 'approved_for_display'
     or c.verified_at is null
     or c.destination_type is distinct from new.destination_type
     or c.title is distinct from new.title
     or c.issuer_name is distinct from new.issuer_name
     or c.jurisdiction is distinct from new.jurisdiction
     or c.source_url is distinct from new.official_url then
    raise exception 'Public destination lacks matching approved issuer identity and link';
  end if;
  return new;
end
$$;
revoke all on function public.guard_verified_destination_origin() from public,anon,authenticated;
create trigger trg_guard_verified_destination_origin
before insert or update on public.catalog_verified_destinations
for each row execute function public.guard_verified_destination_origin();

-- If a reviewer revokes source approval, public listing must disappear as part
-- of the SAME transaction. Do not rely on an application job to remember this.
create function public.retire_destination_after_intake_review_change()
returns trigger language plpgsql security invoker
set search_path = public, pg_temp
as $$
begin
  if new.review_status <> 'approved'
     or new.publication_status <> 'published'
     or new.source_rights <> 'approved_for_display'
     or new.verified_at is null
     or new.source_url is distinct from old.source_url then
    update public.catalog_verified_destinations
       set publication_status='retired'
     where source_namespace=new.source_namespace
       and source_key=new.source_key
       and publication_status='published';
  end if;
  return new;
end
$$;
revoke all on function public.retire_destination_after_intake_review_change() from public,anon,authenticated;
create trigger trg_retire_destination_after_intake_review_change
after update of review_status,publication_status,source_rights,source_url,verified_at
on public.catalog_intake_candidates
for each row execute function public.retire_destination_after_intake_review_change();
