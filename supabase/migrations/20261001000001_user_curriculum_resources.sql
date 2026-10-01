-- User-owned supplements to exact published curriculum nodes. This table
-- never changes curriculum_node_lessons or official requirement counts.
create table public.user_curriculum_resources (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  curriculum_node_id uuid not null
    references public.curriculum_nodes(id) on delete cascade,
  lesson_id uuid not null
    references public.lessons(id) on delete cascade,
  relationship text not null default 'personal_study'
    check (relationship = 'personal_study'),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, curriculum_node_id, lesson_id, relationship)
);

create index user_curriculum_resources_owner_node_idx
  on public.user_curriculum_resources(user_id, curriculum_node_id, sort_order, created_at);

create trigger user_curriculum_resources_touch
  before update on public.user_curriculum_resources
  for each row execute function public.touch_updated_at();

alter table public.user_curriculum_resources enable row level security;
revoke all on public.user_curriculum_resources from anon;
grant select, insert, update, delete on public.user_curriculum_resources to authenticated;

create policy user_curriculum_resources_owner_read
  on public.user_curriculum_resources
  for select to authenticated
  using (user_id = auth.uid());

create policy user_curriculum_resources_owner_insert
  on public.user_curriculum_resources
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.lessons l
      where l.id = lesson_id and l.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_id
        and t.is_official
        and t.status = 'published'
        and t.is_public
        and v.status = 'published'
    )
  );

create policy user_curriculum_resources_owner_update
  on public.user_curriculum_resources
  for update to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.lessons l
      where l.id = lesson_id and l.user_id = auth.uid()
    )
    and exists (
      select 1
      from public.curriculum_nodes n
      join public.target_versions v on v.id = n.target_version_id
      join public.learning_targets t on t.id = v.target_id
      where n.id = curriculum_node_id
        and t.is_official
        and t.status = 'published'
        and t.is_public
        and v.status = 'published'
    )
  );

create policy user_curriculum_resources_owner_delete
  on public.user_curriculum_resources
  for delete to authenticated
  using (user_id = auth.uid());
