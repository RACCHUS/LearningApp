-- Companion to external resources, EX-4 (companion plan v1.0 §3.1, §7.2):
-- self-reported progress through the parts of a learner's outside resource,
-- and an optional time estimate per part.
--
-- * No new switch: behind `content.learner_resources`, through the same
--   server guard. Reading your own rows never depends on the switch.
-- * `studied_at` on a section is SELF-REPORT ("I studied this part outside
--   LearningApp"). It moves the learner's own plan and resume point. It is
--   never evidence: no readiness, coverage or evidence function reads this
--   table (supabase/tests/learner_resource_section_progress_test.sql).
-- * `est_minutes` is the learner's own estimate (typed, or read on the device
--   from a duration in the pasted outline). The server reads nothing from
--   another site.
-- * The plan named a separate `learner_resource_progress` table. The marks
--   live on the section row instead, so a part and its progress cannot drift
--   apart; replacing the outline keeps the mark of every part whose title is
--   unchanged.
-- * Additive only: two nullable columns, one replaced function body, one new
--   function.

alter table public.learner_resource_sections
  add column if not exists est_minutes integer
    check (est_minutes is null or est_minutes between 1 and 600),
  add column if not exists studied_at timestamptz;

-- Replace the outline of one of the caller's resources. `p_sections` is a
-- JSON array of {"title", "objective_keys": [...], "source", "minutes"} in
-- order; an empty array clears the outline. A part whose title is unchanged
-- keeps its "studied" mark. Returns how many sections were saved.
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
  v_studied jsonb;
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
        or jsonb_typeof(coalesce(e -> 'minutes', 'null'::jsonb)) not in ('number', 'null')
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

  select coalesce(jsonb_object_agg(s.title, s.studied_at), '{}'::jsonb) into v_studied
    from public.learner_resource_sections s
   where s.resource_id = p_resource_id and s.studied_at is not null;

  delete from public.learner_resource_sections s where s.resource_id = p_resource_id;
  insert into public.learner_resource_sections
    (resource_id, user_id, position, title, objective_keys, map_source, est_minutes, studied_at)
  select p_resource_id, v_uid, t.ord::integer, btrim(t.e ->> 'title'),
         coalesce((select array_agg(distinct btrim(k) order by btrim(k))
                     from jsonb_array_elements_text(t.e -> 'objective_keys') as k
                    where btrim(k) <> ''), '{}'),
         coalesce(t.e ->> 'source', 'learner'),
         round((t.e ->> 'minutes')::numeric)::integer,
         (v_studied ->> btrim(t.e ->> 'title'))::timestamptz
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

-- Mark or unmark one part as studied (self-report only). When every part
-- that covers an objective is studied, that objective is marked studied too;
-- unmarking a part never unmarks an objective.
create or replace function public.set_learner_resource_section_studied(
  p_resource_id uuid,
  p_position integer,
  p_studied boolean
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.learner_resources_writer();
  v_at timestamptz;
  v_keys text[];
begin
  update public.learner_resource_sections s
     set studied_at = case when coalesce(p_studied, false) then coalesce(s.studied_at, now()) end
   where s.resource_id = p_resource_id
     and s.user_id = v_uid
     and s.position = p_position
  returning s.studied_at, s.objective_keys into v_at, v_keys;
  if not found then
    raise exception 'section_not_found' using errcode = 'P0002';
  end if;

  if v_at is not null then
    update public.learner_resource_objectives o
       set studied_at = now()
     where o.resource_id = p_resource_id
       and o.user_id = v_uid
       and o.studied_at is null
       and o.objective_key = any (v_keys)
       and not exists (
         select 1 from public.learner_resource_sections s
          where s.resource_id = p_resource_id
            and o.objective_key = any (s.objective_keys)
            and s.studied_at is null);
  end if;
  return v_at;
end;
$$;

revoke all on function public.set_learner_resource_sections(uuid, jsonb) from public, anon;
revoke all on function public.set_learner_resource_section_studied(uuid, integer, boolean) from public, anon;
grant execute on function public.set_learner_resource_sections(uuid, jsonb) to authenticated;
grant execute on function public.set_learner_resource_section_studied(uuid, integer, boolean) to authenticated;
