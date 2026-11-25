-- Companion to external resources, EX-3 (companion plan v1.0 §3.4 rungs 2-3,
-- §7.2): the outline of a learner's outside resource and the objectives the
-- learner confirmed for each part.
--
-- * No new switch: this sits behind `content.learner_resources` and its write
--   goes through the same server guard. Reading your own rows and removing
--   the resource (which removes its outline) never depend on the switch.
-- * A section is a title the learner typed or pasted, in order, with the
--   objective keys they confirmed. `map_source` records how the proposal was
--   made (ticked by hand, on-device word match, or the learner's own AI
--   chat). Whatever the source, the learner confirmed it and nobody reviewed
--   it. The server reads nothing from another site.
-- * Confirming an outline also ticks its objectives as covered by the
--   resource. It never marks anything studied, and nothing here is evidence:
--   supabase/tests/learner_resource_sections_test.sql asserts that no other
--   function reads this table.
-- * Private to the owner (RLS), removed with the resource and the account.
--   No direct writes from browsers. Additive only.

create table if not exists public.learner_resource_sections (
  resource_id uuid not null references public.learner_external_resources(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  position integer not null check (position between 1 and 200),
  title text not null check (char_length(btrim(title)) between 1 and 200),
  objective_keys text[] not null default '{}' check (cardinality(objective_keys) <= 50),
  map_source text not null default 'learner'
    check (map_source in ('learner', 'outline_match', 'own_ai')),
  created_at timestamptz not null default now(),
  primary key (resource_id, position)
);

create index if not exists learner_resource_sections_owner
  on public.learner_resource_sections (user_id);

alter table public.learner_resource_sections enable row level security;

create policy learner_resource_sections_select on public.learner_resource_sections
  for select to authenticated
  using (user_id = (select auth.uid()));

revoke all on table public.learner_resource_sections from public, anon;
revoke insert, update, delete, truncate, references, trigger
  on table public.learner_resource_sections from authenticated;
grant select on table public.learner_resource_sections to authenticated;

-- Replace the outline of one of the caller's resources. `p_sections` is a
-- JSON array of {"title", "objective_keys": [...], "source"} in order; an
-- empty array clears the outline. Returns how many sections were saved.
create or replace function public.set_learner_resource_sections(
  p_resource_id uuid,
  p_sections jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_sections constant integer := 200;
  c_max_keys constant integer := 300;
  v_uid uuid := private.learner_resources_writer();
  v_target uuid;
  v_sections jsonb := coalesce(p_sections, '[]'::jsonb);
  v_count integer;
begin
  select r.target_id into v_target
    from public.learner_external_resources r
   where r.id = p_resource_id and r.user_id = v_uid
     for update;
  if v_target is null then
    raise exception 'resource_not_found' using errcode = 'P0002';
  end if;

  if jsonb_typeof(v_sections) <> 'array' then
    raise exception 'invalid_outline' using errcode = 'P0001';
  end if;
  v_count := jsonb_array_length(v_sections);
  if v_count > c_max_sections then
    raise exception 'too_many_sections' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from jsonb_array_elements(v_sections) as e
     where jsonb_typeof(e) <> 'object'
        or jsonb_typeof(coalesce(e -> 'objective_keys', '[]'::jsonb)) <> 'array'
  ) then
    raise exception 'invalid_outline' using errcode = 'P0001';
  end if;
  -- Every key must be a node of some version of this target.
  if exists (
    select 1
      from jsonb_array_elements(v_sections) as e,
           jsonb_array_elements_text(e -> 'objective_keys') as k
     where btrim(k) <> ''
       and not exists (
         select 1
           from public.curriculum_nodes n
           join public.target_versions tv on tv.id = n.target_version_id
          where tv.target_id = v_target
            and (n.code = btrim(k) or (coalesce(n.code, '') = '' and n.title = btrim(k))))
  ) then
    raise exception 'unknown_objective' using errcode = 'P0001';
  end if;

  delete from public.learner_resource_sections s where s.resource_id = p_resource_id;
  insert into public.learner_resource_sections
    (resource_id, user_id, position, title, objective_keys, map_source)
  select p_resource_id, v_uid, t.ord::integer, btrim(t.e ->> 'title'),
         coalesce((select array_agg(distinct btrim(k) order by btrim(k))
                     from jsonb_array_elements_text(t.e -> 'objective_keys') as k
                    where btrim(k) <> ''), '{}'),
         coalesce(t.e ->> 'source', 'learner')
    from jsonb_array_elements(v_sections) with ordinality as t(e, ord);

  -- The learner confirmed these parts cover these objectives, so they count
  -- as covered by the resource. Existing ticks and "studied" marks are kept.
  insert into public.learner_resource_objectives (resource_id, user_id, objective_key)
  select distinct p_resource_id, v_uid, k
    from public.learner_resource_sections s, unnest(s.objective_keys) as k
   where s.resource_id = p_resource_id
  on conflict (resource_id, objective_key) do nothing;
  if (select count(*) from public.learner_resource_objectives o where o.resource_id = p_resource_id) > c_max_keys then
    raise exception 'too_many_objectives' using errcode = 'P0001';
  end if;

  update public.learner_external_resources r set updated_at = now() where r.id = p_resource_id;
  return v_count;
end;
$$;

revoke all on function public.set_learner_resource_sections(uuid, jsonb) from public, anon;
grant execute on function public.set_learner_resource_sections(uuid, jsonb) to authenticated;
