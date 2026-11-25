-- Companion to external resources, EX-7 (companion plan v1.0 §5.1 layer L3,
-- §7.3, §7.4): the in-app player for embeddable video.
--
-- 1. Registers the `content.companion_embeds` gate. Additive: one new
--    registry row, default OFF and NOT release-ready.
--
--    What the gate covers: loading a third party's video player inside the
--    companion screen, and only after the learner taps play. Like
--    `content.companion_capture`, it switches a client feature. The player
--    writes nothing to LearningApp, so there is no server write to gate, and
--    this row must not be read as a server gate.
--
--    It must stay OFF until the app's Terms of Service and Privacy Policy
--    carry the wording the provider's developer policies require (see
--    docs/product/COMPANION_EMBEDS.md). That is an owner decision.
--
--    Shutoff behavior: no player and no third-party request. "Open (leaves
--    LearningApp)" works as before.
--
-- 2. Adds `start_seconds` to a part of an outline: where that part begins in
--    a video, typed by the learner or read on the device from a timestamp in
--    the pasted outline. It lets "play this part" start the video there.
--    Nullable, additive. `set_learner_resource_sections` is replaced to carry
--    it; nothing else about that function changes.
--
-- Playing a video is never evidence: nothing is recorded when a video plays,
-- and no readiness or coverage function reads these tables.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.companion_embeds', 'Companion in-app video player', 'Content', 'release', false, 'experimental', false,
  'Client feature: plays an embeddable video from its provider inside the companion screen after the learner taps play; nothing is recorded; needs the provider wording in the Terms and Privacy Policy before it is switched on; Open (leaves LearningApp) stays available when OFF')
ON CONFLICT (feature_key) DO NOTHING;

alter table public.learner_resource_sections
  add column if not exists start_seconds integer
    check (start_seconds is null or start_seconds between 0 and 86400);

-- Replace the outline of one of the caller's resources. `p_sections` is a
-- JSON array of {"title", "objective_keys": [...], "source", "minutes",
-- "start"} in order ("start" is seconds into a video); an empty array
-- clears the outline. A part whose title is unchanged
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
        or jsonb_typeof(coalesce(e -> 'start', 'null'::jsonb)) not in ('number', 'null')
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
    (resource_id, user_id, position, title, objective_keys, map_source, est_minutes, start_seconds, studied_at)
  select p_resource_id, v_uid, t.ord::integer, btrim(t.e ->> 'title'),
         coalesce((select array_agg(distinct btrim(k) order by btrim(k))
                     from jsonb_array_elements_text(t.e -> 'objective_keys') as k
                    where btrim(k) <> ''), '{}'),
         coalesce(t.e ->> 'source', 'learner'),
         round((t.e ->> 'minutes')::numeric)::integer,
         round((t.e ->> 'start')::numeric)::integer,
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

revoke all on function public.set_learner_resource_sections(uuid, jsonb) from public, anon;
grant execute on function public.set_learner_resource_sections(uuid, jsonb) to authenticated;
