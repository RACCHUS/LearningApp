-- Study-time estimates for the projected readiness date (ingestion plan v1.2
-- §8.5 item 4 and §8.7). Switch learning.readiness_projection (default OFF).
--
-- get_target_study_estimates returns, per objective, an estimated study-time
-- range computed from the lesson content LearningApp holds. It says nothing
-- about a learner; the app combines it with the learner's objective statuses
-- (get_target_objective_readiness) and their chosen daily goal to project a
-- date range, always labelled as an estimate.
--
-- Heuristic "content-v1" (to be replaced by observed medians, §8.5):
--   reading  words in the objective's lesson blocks, at 180 (low) to 100
--            (high) words a minute;
--   practice 2-4 minutes per practice prompt;
--   checks   1-2 minutes per graded question (assessment items and lesson
--            questions; held-out checks have no lesson and are not counted);
--   tasks    20-45 minutes per hands-on performance task.
-- An objective with lessons is never estimated under 5 minutes; one with no
-- lessons gets no estimate (it is "not yet available", not zero).
--
-- Guests may read published or retired versions of public targets, as with
-- get_target_readiness_coverage (20261124060000).
BEGIN;

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.readiness_projection', 'Projected readiness date', 'Learning', 'release', false, 'experimental', false,
  'Estimated study time left and a projected date range on the daily plan, from lesson content and the learner''s daily goal')
ON CONFLICT (feature_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_target_study_estimates(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF (SELECT auth.uid()) IS NULL AND NOT EXISTS (
    SELECT 1
    FROM public.target_versions tv
    JOIN public.learning_targets lt ON lt.id = tv.target_id
    WHERE tv.id = p_target_version_id
      AND tv.status IN ('published', 'retired')
      AND lt.is_public
  ) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.readiness_projection') THEN
    RETURN jsonb_build_object('enabled', false);
  END IF;

  WITH objectives AS (
    SELECT o.id, o.code, o.sort_order
    FROM public.curriculum_nodes o
    WHERE o.target_version_id = p_target_version_id
      AND o.node_type = 'objective'
  ),
  obj_lessons AS (
    SELECT DISTINCT o.id AS objective_id, cnl.lesson_id
    FROM objectives o
    JOIN public.curriculum_node_lessons cnl ON cnl.curriculum_node_id = o.id
  ),
  words AS (
    SELECT ol.objective_id,
           coalesce(sum(coalesce(array_length(
             regexp_split_to_array(btrim(s.v #>> '{}'), '\s+'), 1), 0)), 0) AS n
    FROM obj_lessons ol
    JOIN public.lesson_blocks b ON b.lesson_id = ol.lesson_id
    CROSS JOIN LATERAL jsonb_path_query(b.content, 'strict $.** ? (@.type() == "string")') AS s(v)
    WHERE btrim(s.v #>> '{}') <> ''
    GROUP BY ol.objective_id
  ),
  blocks AS (
    SELECT ol.objective_id,
           count(*) FILTER (WHERE b.block_type = 'practice_prompt') AS prompts,
           count(*) FILTER (WHERE b.block_type = 'performance_task') AS tasks
    FROM obj_lessons ol
    JOIN public.lesson_blocks b ON b.lesson_id = ol.lesson_id
    GROUP BY ol.objective_id
  ),
  graded AS (
    SELECT ol.objective_id,
           (SELECT count(*) FROM public.assessment_items ai WHERE ai.lesson_id = ol.lesson_id)
           + (SELECT count(*) FROM public.questions q WHERE q.lesson_id = ol.lesson_id) AS n
    FROM obj_lessons ol
  ),
  graded_sum AS (
    SELECT objective_id, sum(n) AS n FROM graded GROUP BY objective_id
  ),
  estimates AS (
    SELECT o.code, o.sort_order,
           EXISTS (SELECT 1 FROM obj_lessons ol WHERE ol.objective_id = o.id) AS has_lessons,
           coalesce(w.n, 0) AS words,
           coalesce(bl.prompts, 0) AS prompts,
           coalesce(bl.tasks, 0) AS tasks,
           coalesce(g.n, 0) AS graded
    FROM objectives o
    LEFT JOIN words w ON w.objective_id = o.id
    LEFT JOIN blocks bl ON bl.objective_id = o.id
    LEFT JOIN graded_sum g ON g.objective_id = o.id
  )
  SELECT jsonb_build_object(
    'enabled', true,
    'method', 'content-v1',
    'objectives', coalesce(jsonb_agg(
      CASE WHEN e.has_lessons THEN
        jsonb_build_object(
          'code', e.code,
          'minutes_low', greatest(5, round(e.words / 180.0 + 2 * e.prompts + 1 * e.graded + 20 * e.tasks)),
          'minutes_high', greatest(5, round(e.words / 100.0 + 4 * e.prompts + 2 * e.graded + 45 * e.tasks)),
          'words', e.words, 'practice_prompts', e.prompts, 'graded_questions', e.graded, 'tasks', e.tasks)
      ELSE
        jsonb_build_object('code', e.code, 'minutes_low', NULL, 'minutes_high', NULL)
      END
      ORDER BY e.sort_order, e.code), '[]'::jsonb)
  )
  INTO v_result
  FROM estimates e;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_study_estimates(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_target_study_estimates(uuid) TO anon, authenticated, service_role;

COMMIT;
