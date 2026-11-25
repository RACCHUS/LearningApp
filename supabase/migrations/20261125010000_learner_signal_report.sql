-- Learner-signal report (ingestion plan v1.2 slice 13 and §16.4): the two
-- objective-level signals that item statistics do not cover.
--
--   * get_learner_signal_report(version) returns, per objective, aggregated
--     evidence from learners who opted in to product analytics only:
--       completed_learners       completed every lesson linked to the
--                                objective (ANA-001B progress);
--       checked_after_teaching   of those, answered at least one of the
--                                objective's independent checks on or after
--                                the day they completed it;
--       fail_rate                share of those whose mean check score is
--                                below 0.6;
--       median_active_minutes    median active study time on the linked
--                                lessons among completers with any recorded;
--       estimate_low / _high     get_target_study_estimates' range.
--     Any count under 5 accounts is withheld (status
--     small_cohort_suppressed), and so is every rate built on it. Signals:
--       repeated_failure_after_teaching  10+ checked, fail_rate >= 0.5
--                                        (review teaching and Bridges
--                                        before the items);
--       time_off_estimate                10+ timed, median outside the
--                                        estimate range (update the
--                                        estimate).
--     Descriptive only: no comparison, no causal claim (§16.3 cold start).
--   * open_learner_signal_reviews(version) opens one pending moderation
--     report on the objective's first lesson for each repeated-failure
--     signal that has no open report. Nothing is edited or retired. The
--     estimate is computed, not stored, so time_off_estimate stays in the
--     report until the estimate method uses observed medians (§8.5).
-- Both are for admins and moderators only (private.can_read_item_statistics).
-- Checks flagged unreliable while their report is open are left out.
BEGIN;

CREATE OR REPLACE FUNCTION private.learner_signal_rows(p_target_version_id uuid)
RETURNS TABLE (
  objective_id uuid,
  code text,
  title text,
  sort_order integer,
  first_lesson_id uuid,
  lessons bigint,
  held_out_items bigint,
  completed_learners bigint,
  checked_after_teaching bigint,
  failed bigint,
  timed_learners bigint,
  median_active_minutes numeric
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH objectives AS (
    SELECT n.id, n.code, n.title, n.sort_order
    FROM public.curriculum_nodes n
    WHERE n.target_version_id = p_target_version_id
      AND n.node_type = 'objective'
  ),
  obj_lessons AS (
    SELECT DISTINCT o.id AS objective_id, cnl.lesson_id, cnl.sort_order
    FROM objectives o
    JOIN public.curriculum_node_lessons cnl ON cnl.curriculum_node_id = o.id
  ),
  consenting AS (
    SELECT pc.user_id FROM analytics.product_consents pc WHERE pc.consented
  ),
  -- Latest state per learner and lesson, and the first day it was completed.
  lesson_state AS (
    SELECT p.user_id, ol.objective_id, ol.lesson_id,
           (array_agg(p.completed ORDER BY p.reporting_date_utc DESC))[1] AS completed_now,
           min(p.reporting_date_utc) FILTER (WHERE p.completed) AS completed_on,
           sum(coalesce(p.active_seconds, 0)) AS active_seconds
    FROM obj_lessons ol
    JOIN public.learner_activity_progress p
      ON p.content_kind = 'legacy_lesson' AND p.content_id = ol.lesson_id::text
    JOIN consenting c ON c.user_id = p.user_id
    GROUP BY p.user_id, ol.objective_id, ol.lesson_id
  ),
  completers AS (
    SELECT s.objective_id, s.user_id,
           max(s.completed_on) AS completed_on,
           sum(s.active_seconds) AS active_seconds
    FROM lesson_state s
    GROUP BY s.objective_id, s.user_id
    HAVING count(*) FILTER (WHERE s.completed_now)
         = (SELECT count(*) FROM obj_lessons ol WHERE ol.objective_id = s.objective_id)
  ),
  held AS (
    SELECT DISTINCT ai.id, ai.lesson_id
    FROM public.assessment_item_reference_validity v
    JOIN public.exam_reference_manifest_revisions mr ON mr.id = v.manifest_revision_id
    JOIN public.assessment_items ai ON ai.id = v.assessment_item_id
    WHERE mr.target_version_id = p_target_version_id
      AND mr.publication_status = 'published'
      AND v.usage_role = 'held_out_transfer'
      AND v.publication_status = 'published'
      AND v.review_status = 'approved'
      AND v.rights_review_status = 'approved'
      AND NOT private.held_out_item_unreliable(ai.id)
    UNION
    SELECT ai.id, ai.lesson_id
    FROM private.held_out_item_reviews r
    JOIN public.assessment_items ai ON ai.id = r.assessment_item_id
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(ai.id)
      AND NOT private.held_out_item_unreliable(ai.id)
  ),
  held_links AS (
    SELECT cnc.curriculum_node_id AS objective_id, h.id AS item_id
    FROM held h
    JOIN public.assessment_item_concepts aic ON aic.assessment_item_id = h.id
    JOIN public.curriculum_node_concepts cnc ON cnc.concept_id = aic.concept_id
    UNION
    SELECT cnl.curriculum_node_id, h.id
    FROM held h
    JOIN public.curriculum_node_lessons cnl ON cnl.lesson_id = h.lesson_id
  ),
  checked AS (
    SELECT c.objective_id, c.user_id, avg(r.score) AS mean_score
    FROM completers c
    JOIN held_links hl ON hl.objective_id = c.objective_id
    JOIN private.item_response_log r
      ON r.item_id = hl.item_id AND r.user_id = c.user_id
     AND (r.responded_at AT TIME ZONE 'UTC')::date >= c.completed_on
    GROUP BY c.objective_id, c.user_id
  )
  SELECT o.id, o.code, o.title, o.sort_order,
         (SELECT ol.lesson_id FROM obj_lessons ol WHERE ol.objective_id = o.id
          ORDER BY ol.sort_order, ol.lesson_id LIMIT 1),
         (SELECT count(*) FROM obj_lessons ol WHERE ol.objective_id = o.id),
         (SELECT count(DISTINCT hl.item_id) FROM held_links hl WHERE hl.objective_id = o.id),
         (SELECT count(*) FROM completers c WHERE c.objective_id = o.id),
         (SELECT count(*) FROM checked k WHERE k.objective_id = o.id),
         (SELECT count(*) FROM checked k WHERE k.objective_id = o.id AND k.mean_score < 0.6),
         (SELECT count(*) FROM completers c WHERE c.objective_id = o.id AND c.active_seconds > 0),
         (SELECT round((percentile_cont(0.5) WITHIN GROUP (ORDER BY c.active_seconds) / 60.0)::numeric, 1)
          FROM completers c WHERE c.objective_id = o.id AND c.active_seconds > 0)
  FROM objectives o;
$$;
REVOKE ALL ON FUNCTION private.learner_signal_rows(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_learner_signal_report(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  c_min_group constant integer := 5;
  c_min_signal constant integer := 10;
  c_fail_share constant numeric := 0.5;
  v_estimates jsonb;
  v_learners bigint;
  v_rows jsonb;
BEGIN
  IF NOT private.can_read_item_statistics() THEN
    RAISE EXCEPTION 'Admins and moderators only' USING ERRCODE = '42501';
  END IF;

  v_estimates := public.get_target_study_estimates(p_target_version_id);

  SELECT count(DISTINCT p.user_id) INTO v_learners
  FROM public.learner_activity_progress p
  JOIN analytics.product_consents pc ON pc.user_id = p.user_id AND pc.consented
  JOIN public.curriculum_node_lessons cnl ON p.content_kind = 'legacy_lesson'
   AND p.content_id = cnl.lesson_id::text
  JOIN public.curriculum_nodes n ON n.id = cnl.curriculum_node_id
  WHERE n.target_version_id = p_target_version_id;

  SELECT coalesce(jsonb_agg(row ORDER BY s.sort_order, s.code), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT r.*,
           (e.value->>'minutes_low')::numeric AS est_low,
           (e.value->>'minutes_high')::numeric AS est_high
    FROM private.learner_signal_rows(p_target_version_id) r
    LEFT JOIN LATERAL (
      SELECT x.value FROM jsonb_array_elements(coalesce(v_estimates->'objectives', '[]'::jsonb)) x
      WHERE x.value->>'code' = r.code LIMIT 1
    ) e ON true
  ) s
  CROSS JOIN LATERAL (
    SELECT jsonb_build_object(
      'objective_id', s.objective_id,
      'code', s.code,
      'title', s.title,
      'lessons', s.lessons,
      'held_out_items', s.held_out_items,
      'estimate_low', s.est_low,
      'estimate_high', s.est_high,
      'status', CASE WHEN s.completed_learners < c_min_group THEN 'small_cohort_suppressed' ELSE 'ok' END,
      'completed_learners', CASE WHEN s.completed_learners >= c_min_group THEN s.completed_learners END,
      'checked_after_teaching', CASE WHEN s.checked_after_teaching >= c_min_group THEN s.checked_after_teaching END,
      'fail_rate', CASE WHEN s.checked_after_teaching >= c_min_group
                        THEN round(s.failed::numeric / s.checked_after_teaching, 3) END,
      'timed_learners', CASE WHEN s.timed_learners >= c_min_group THEN s.timed_learners END,
      'median_active_minutes', CASE WHEN s.timed_learners >= c_min_group THEN s.median_active_minutes END,
      'signals', to_jsonb(array_remove(ARRAY[
        CASE WHEN s.checked_after_teaching >= c_min_signal
              AND s.failed::numeric / s.checked_after_teaching >= c_fail_share
             THEN 'repeated_failure_after_teaching' END,
        CASE WHEN s.timed_learners >= c_min_signal AND s.est_low IS NOT NULL
              AND (s.median_active_minutes < s.est_low OR s.median_active_minutes > s.est_high)
             THEN 'time_off_estimate' END
      ], NULL))
    ) AS row
  ) j;

  RETURN jsonb_build_object(
    'target_version_id', p_target_version_id,
    'consenting_learners', CASE WHEN v_learners >= c_min_group THEN v_learners END,
    'learners_status', CASE WHEN v_learners >= c_min_group THEN 'ok' ELSE 'small_cohort_suppressed' END,
    'estimate_method', v_estimates->>'method',
    'thresholds', jsonb_build_object(
      'min_group', c_min_group, 'min_signal', c_min_signal,
      'fail_below_mean_score', 0.6, 'fail_share', c_fail_share),
    'objectives', v_rows
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_learner_signal_report(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_learner_signal_report(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.open_learner_signal_reviews(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_report jsonb;
  v_obj jsonb;
  v_lesson uuid;
  v_opened integer := 0;
  v_already integer := 0;
BEGIN
  IF NOT private.can_read_item_statistics() THEN
    RAISE EXCEPTION 'Admins and moderators only' USING ERRCODE = '42501';
  END IF;
  v_report := public.get_learner_signal_report(p_target_version_id);
  FOR v_obj IN SELECT value FROM jsonb_array_elements(v_report->'objectives') LOOP
    CONTINUE WHEN NOT (v_obj->'signals') ? 'repeated_failure_after_teaching';
    SELECT r.first_lesson_id INTO v_lesson
    FROM private.learner_signal_rows(p_target_version_id) r
    WHERE r.objective_id = (v_obj->>'objective_id')::uuid;
    CONTINUE WHEN v_lesson IS NULL;
    IF EXISTS (
      SELECT 1 FROM public.moderation_reports m
      WHERE m.target_type = 'lesson' AND m.target_id = v_lesson
        AND m.status IN ('pending', 'under_review')
        AND m.description LIKE '[Learner Signal] repeated_failure_after_teaching%'
    ) THEN
      v_already := v_already + 1;
      CONTINUE;
    END IF;
    INSERT INTO public.moderation_reports (reporter_id, target_type, target_id, reason, description, status)
    VALUES (NULL, 'lesson', v_lesson, 'other',
      '[Learner Signal] repeated_failure_after_teaching: objective '
      || coalesce(v_obj->>'code', '') || ' ' || coalesce(v_obj->>'title', '')
      || '. Of ' || (v_obj->>'checked_after_teaching') || ' opted-in learners who completed the teaching and then took its independent checks, '
      || round((v_obj->>'fail_rate')::numeric * 100) || '% scored below 60%. '
      || 'Review the teaching and its Bridges before the items. Descriptive evidence only; nothing has been changed automatically (plan §16.4).',
      'pending');
    v_opened := v_opened + 1;
  END LOOP;
  RETURN jsonb_build_object('opened', v_opened, 'already_open', v_already);
END;
$$;
REVOKE ALL ON FUNCTION public.open_learner_signal_reviews(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_learner_signal_reviews(uuid) TO authenticated, service_role;

COMMIT;
