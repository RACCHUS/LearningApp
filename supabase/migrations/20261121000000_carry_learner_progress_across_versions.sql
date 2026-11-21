-- Learner history survives publication of a new curriculum version
-- (master plan v2.6 P5.2 acceptance).
--
-- When a version is retired (normally by publishing its corrected
-- replacement with retire_previous), each of its lessons is linked to the
-- same-title lesson in the same target's published version, and learners'
-- lesson-level progress is copied to the new lesson. Old rows are kept as
-- history. Concept mastery (user_concept_state) is keyed by shared
-- knowledge_concepts and needs no copy.
--
-- 1. private.lesson_lineage: old lesson -> current replacement (one hop;
--    earlier hops are re-pointed when a replacement is itself replaced).
-- 2. private.carry_lessons_from_version(version): records lineage and copies
--    learner_activity_progress and user_curriculum_resources.
-- 3. A deferred constraint trigger runs it when a version becomes retired,
--    at commit, when the replacement's publication is visible.
-- 4. record_learner_progress maps late events (offline devices) for a
--    retired lesson onto its replacement. The existing function is moved
--    unchanged to private.record_learner_progress_core; the public wrapper
--    only rewrites content_id, then delegates (same validation, same digest
--    rules, same grants).
-- 5. lesson_replacement prefers recorded lineage.
-- 6. Backfill for versions retired before this migration.

CREATE TABLE IF NOT EXISTS private.lesson_lineage (
  old_lesson_id uuid PRIMARY KEY REFERENCES public.lessons(id) ON DELETE CASCADE,
  new_lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CHECK (old_lesson_id <> new_lesson_id)
);
CREATE INDEX IF NOT EXISTS lesson_lineage_new_idx ON private.lesson_lineage(new_lesson_id);
ALTER TABLE private.lesson_lineage ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.lesson_lineage FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.carry_lessons_from_version(p_version uuid)
RETURNS integer LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_target uuid;
  v_linked integer := 0;
BEGIN
  SELECT v.target_id INTO v_target
  FROM public.target_versions v
  WHERE v.id = p_version AND v.status = 'retired';
  IF v_target IS NULL THEN
    RETURN 0;
  END IF;

  -- Same target, same title, published, public, and unambiguous.
  WITH old AS (
    SELECT l.id, l.title FROM public.lessons l
    WHERE l.origin_target_version_id = p_version
  ), cand AS (
    SELECT o.id AS old_id, n.id AS new_id,
           count(*) OVER (PARTITION BY o.id) AS matches
    FROM old o
    JOIN public.lessons n ON n.title = o.title AND n.visibility = 'public'
    JOIN public.target_versions v
      ON v.id = n.origin_target_version_id
     AND v.target_id = v_target AND v.status = 'published'
  )
  INSERT INTO private.lesson_lineage (old_lesson_id, new_lesson_id)
  SELECT old_id, new_id FROM cand WHERE matches = 1
  ON CONFLICT (old_lesson_id) DO UPDATE
    SET new_lesson_id = EXCLUDED.new_lesson_id, recorded_at = now();
  GET DIAGNOSTICS v_linked = ROW_COUNT;

  -- Keep lineage one hop: anything that pointed at a lesson that has now
  -- been replaced points at the replacement instead.
  UPDATE private.lesson_lineage a
  SET new_lesson_id = b.new_lesson_id, recorded_at = now()
  FROM private.lesson_lineage b
  WHERE a.new_lesson_id = b.old_lesson_id AND a.old_lesson_id <> b.new_lesson_id;

  -- Lesson progress: copy (history stays on the old row). Merging never
  -- loses completion or study time.
  INSERT INTO public.learner_activity_progress AS p
    (user_id, content_kind, content_id, version_key, reporting_date_utc,
     completed, active_seconds, updated_at)
  SELECT p0.user_id, p0.content_kind, g.new_lesson_id::text, p0.version_key,
         p0.reporting_date_utc, p0.completed, p0.active_seconds, now()
  FROM public.learner_activity_progress p0
  JOIN private.lesson_lineage g ON p0.content_id = g.old_lesson_id::text
  JOIN public.lessons l ON l.id = g.old_lesson_id
  WHERE p0.content_kind = 'legacy_lesson'
    AND l.origin_target_version_id = p_version
  ON CONFLICT (user_id, content_kind, content_id, version_key, reporting_date_utc)
  DO UPDATE SET
    completed = p.completed OR EXCLUDED.completed,
    active_seconds = CASE
      WHEN p.active_seconds IS NULL THEN EXCLUDED.active_seconds
      WHEN EXCLUDED.active_seconds IS NULL THEN p.active_seconds
      ELSE greatest(p.active_seconds, EXCLUDED.active_seconds) END,
    updated_at = now();

  -- Lessons a learner placed in their curriculum.
  INSERT INTO public.user_curriculum_resources
    (user_id, curriculum_node_id, lesson_id, relationship, sort_order)
  SELECT r.user_id, r.curriculum_node_id, g.new_lesson_id, r.relationship, r.sort_order
  FROM public.user_curriculum_resources r
  JOIN private.lesson_lineage g ON r.lesson_id = g.old_lesson_id
  JOIN public.lessons l ON l.id = g.old_lesson_id
  WHERE l.origin_target_version_id = p_version
  ON CONFLICT (user_id, curriculum_node_id, lesson_id, relationship) DO NOTHING;

  RETURN v_linked;
END;
$$;
REVOKE ALL ON FUNCTION private.carry_lessons_from_version(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.on_target_version_retired()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM private.carry_lessons_from_version(NEW.id);
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION private.on_target_version_retired() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_target_version_retired_carry ON public.target_versions;
CREATE CONSTRAINT TRIGGER trg_target_version_retired_carry
  AFTER UPDATE OF status ON public.target_versions
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  WHEN (NEW.status = 'retired' AND OLD.status IS DISTINCT FROM 'retired')
  EXECUTE FUNCTION private.on_target_version_retired();

-- Late events: move the existing RPC aside unchanged and wrap it.
ALTER FUNCTION public.record_learner_progress(jsonb[]) SET SCHEMA private;
ALTER FUNCTION private.record_learner_progress(jsonb[]) RENAME TO record_learner_progress_core;
REVOKE ALL ON FUNCTION private.record_learner_progress_core(jsonb[])
  FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.record_learner_progress(p_events jsonb[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_mapped jsonb[];
BEGIN
  -- Empty, missing or oversized batches go straight to the core checks.
  IF p_events IS NULL OR coalesce(array_length(p_events, 1), 0) = 0
     OR array_length(p_events, 1) > 25 THEN
    RETURN private.record_learner_progress_core(p_events);
  END IF;
  SELECT array_agg(
           CASE WHEN g.new_lesson_id IS NOT NULL
                THEN pg_catalog.jsonb_set(t.e, '{content_id}', to_jsonb(g.new_lesson_id::text))
                ELSE t.e END
           ORDER BY t.ord)
  INTO v_mapped
  FROM unnest(p_events) WITH ORDINALITY AS t(e, ord)
  LEFT JOIN private.lesson_lineage g
    ON jsonb_typeof(t.e) = 'object'
   AND t.e->>'content_kind' = 'legacy_lesson'
   AND g.old_lesson_id::text = lower(t.e->>'content_id');
  RETURN private.record_learner_progress_core(v_mapped);
END;
$$;
REVOKE ALL ON FUNCTION public.record_learner_progress(jsonb[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_learner_progress(jsonb[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_learner_progress(jsonb[]) TO service_role;

-- Prefer recorded lineage; fall back to the title match.
CREATE OR REPLACE FUNCTION public.lesson_replacement(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_title text;
  v_target uuid;
  v_ids uuid[];
  v_lineage uuid;
BEGIN
  SELECT l.title, v.target_id INTO v_title, v_target
  FROM public.lessons l
  JOIN public.target_versions v ON v.id = l.origin_target_version_id
  WHERE l.id = p_lesson_id AND v.status = 'retired';

  IF v_target IS NULL THEN
    RETURN jsonb_build_object('retired', false, 'replacement_id', NULL);
  END IF;

  SELECT g.new_lesson_id INTO v_lineage
  FROM private.lesson_lineage g
  JOIN public.lessons n ON n.id = g.new_lesson_id AND n.visibility = 'public'
  JOIN public.target_versions v ON v.id = n.origin_target_version_id AND v.status = 'published'
  WHERE g.old_lesson_id = p_lesson_id;
  IF v_lineage IS NOT NULL THEN
    RETURN jsonb_build_object('retired', true, 'replacement_id', v_lineage);
  END IF;

  SELECT array_agg(l.id) INTO v_ids
  FROM public.lessons l
  JOIN public.target_versions v ON v.id = l.origin_target_version_id
  WHERE v.target_id = v_target
    AND v.status = 'published'
    AND l.visibility = 'public'
    AND l.title = v_title;

  RETURN jsonb_build_object(
    'retired', true,
    'replacement_id', CASE WHEN cardinality(v_ids) = 1 THEN v_ids[1] END
  );
END;
$$;
REVOKE ALL ON FUNCTION public.lesson_replacement(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lesson_replacement(uuid) TO anon, authenticated;

-- Backfill: versions retired before this migration, oldest first.
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM public.target_versions WHERE status = 'retired' ORDER BY updated_at LOOP
    PERFORM private.carry_lessons_from_version(r.id);
  END LOOP;
END;
$$;
