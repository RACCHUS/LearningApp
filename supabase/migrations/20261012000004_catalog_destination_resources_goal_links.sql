-- Phase P2b: user-owned draft links and approved off-site preparation links.
-- The Learning App does NOT issue any third-party credential.
create table public.catalog_destination_goal_links (
  target_id uuid primary key references public.learning_targets(id) on delete cascade,
  source_namespace text not null,
  source_key text not null,
  created_at timestamptz not null default now(),
  foreign key (source_namespace, source_key)
    references public.catalog_verified_destinations(source_namespace,source_key)
    on update restrict on delete restrict
);
create index catalog_destination_goal_links_identity_idx
  on public.catalog_destination_goal_links (source_namespace,source_key);
comment on table public.catalog_destination_goal_links is
  'Learner-owned private goals referring to reviewed external issuer directories. Linking DOES NOT confer official target, verification, a course or award.';

alter table public.catalog_destination_goal_links enable row level security;
revoke all on public.catalog_destination_goal_links from public,anon,authenticated;
grant select,insert,delete on public.catalog_destination_goal_links to authenticated;
grant select,insert,update,delete on public.catalog_destination_goal_links to service_role;

create policy destination_goal_links_owner_select
  on public.catalog_destination_goal_links for select to authenticated using (
    exists (select 1 from public.learning_targets t where t.id=target_id
      and t.created_by=(select auth.uid()))
  );
create policy destination_goal_links_owner_insert
  on public.catalog_destination_goal_links for insert to authenticated with check (
    exists (select 1 from public.learning_targets t where t.id=target_id
      and t.created_by=(select auth.uid()) and not t.is_official
      and t.status='draft' and t.review_status='unreviewed')
    and exists (select 1 from public.catalog_verified_destinations d
      join public.learning_targets t on t.id=target_id
      where d.source_namespace=public.catalog_destination_goal_links.source_namespace
        and d.source_key=public.catalog_destination_goal_links.source_key
        and d.publication_status='published'
        and d.destination_type=t.target_type
        and d.destination_type in ('certification','licensure_exam','standardized_exam','academic_program'))
  );
create policy destination_goal_links_owner_delete
  on public.catalog_destination_goal_links for delete to authenticated using (
    exists (select 1 from public.learning_targets t where t.id=target_id
      and t.created_by=(select auth.uid()))
  );

create table public.catalog_destination_resources (
  source_namespace text not null,
  source_key text not null,
  resource_key text not null check (resource_key ~ '^[a-z0-9_-]{3,70}$'),
  title text not null check (length(btrim(title)) between 6 and 180),
  resource_kind text not null check (resource_kind in (
    'official_study_guide','issuer_training','official_exam_plan','issuer_prep_directory')),
  resource_url text not null check (resource_url ~ '^https://[^[:space:]]+$'),
  source_publisher text not null check (length(btrim(source_publisher)) between 2 and 120),
  rights_scope text not null default 'external_link_only'
    check (rights_scope='external_link_only'),
  review_note text not null check (length(btrim(review_note)) >= 30),
  verified_at timestamptz not null,
  status text not null default 'published' check (status in ('published','retired')),
  sort_order integer not null default 100 check (sort_order between 1 and 9999),
  primary key(source_namespace,source_key,resource_key),
  foreign key (source_namespace,source_key)
    references public.catalog_verified_destinations(source_namespace,source_key)
    on update restrict on delete restrict
);
comment on table public.catalog_destination_resources is
  'Curated, outbound links to issuer-owned preparation/reference resources only; no copied lessons, paywall bypass, free-access claims, or course equivalency.';

create index catalog_destination_resources_visible_idx
  on public.catalog_destination_resources(source_namespace,source_key,sort_order)
  where status='published';
alter table public.catalog_destination_resources enable row level security;
revoke all on public.catalog_destination_resources from public,anon,authenticated;
grant select on public.catalog_destination_resources to anon,authenticated;
grant select,insert,update,delete on public.catalog_destination_resources to service_role;
create policy destination_resource_published_parent
  on public.catalog_destination_resources for select to anon,authenticated
  using (status='published' and exists(
    select 1 from public.catalog_verified_destinations d
    where d.source_namespace=public.catalog_destination_resources.source_namespace
      and d.source_key=public.catalog_destination_resources.source_key
      and d.publication_status='published'
  ));
