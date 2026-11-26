-- Companion to external resources, EX-10 (companion plan v1.0 §10): a
-- descriptive outcome report for one goal.
--
--   * get_companion_outcome_report(version) returns grouped counts from
--     learners who opted in to product analytics ONLY
--     (analytics.product_consents), built from rows the server already
--     holds. Nothing new is collected and no event is recorded:
--       goal_learners            opted-in learners with study progress on
--                                the goal's lessons or an outside resource
--                                on the goal;
--       with_outside_resource    of those, how many added an outside
--                                resource to this goal;
--       mapping                  the furthest each of them got: listed
--                                only, ticked objectives, outline matched by
--                                word overlap, outline matched with their
--                                own AI chat;
--       studied_then_checked     (learner, objective) pairs the learner
--                                marked studied, how many were followed by
--                                one of LearningApp's own independent checks
--                                within 7 days, and the mean score of those.
--     Any count that rests on fewer than 5 accounts is withheld (status
--     small_cohort_suppressed), and so is every rate built on it. A figure
--     is also withheld when showing it would let a withheld one be worked
--     out by subtraction: the mapping breakdown is shown only when every
--     rung is empty or holds at least 5 learners, and a share only when the
--     group left over is empty or at least 5.
--   * The report never returns the name, link, kind or outline of anything
--     a learner studies, and it returns no per-learner row.
--   * "Marked studied" is self-report. This function only counts how often a
--     real check followed it. It feeds no readiness, coverage or evidence
--     calculation, and the database tests still assert that no readiness or
--     coverage function mentions an outside-resource table.
--   * The plan's other measures (gap offers opened, return after a break,
--     readiness side by side) need events or definitions that do not exist
--     yet; the report lists them under not_measured, with the reason.
--   * Admins and moderators only (private.can_read_item_statistics), like
--     the learner-signal report. Descriptive only: no comparison between
--     groups and no causal claim.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_companion_outcome_report(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  c_min_group constant integer := 5;
  c_follow_up constant interval := interval '7 days';
  v_target uuid;
  v_goal_learners bigint;
  v_with_resource bigint;
  v_listed bigint;
  v_ticked bigint;
  v_outline bigint;
  v_own_ai bigint;
  v_pairs bigint;
  v_pair_learners bigint;
  v_checked bigint;
  v_checked_learners bigint;
  v_mean numeric;
  v_share_ok boolean;
  v_mapping_ok boolean;
  v_check_ok boolean;
BEGIN
  IF NOT private.can_read_item_statistics() THEN
    RAISE EXCEPTION 'Admins and moderators only' USING ERRCODE = '42501';
  END IF;

  SELECT tv.target_id INTO v_target
  FROM public.target_versions tv WHERE tv.id = p_target_version_id;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'target_version_not_found' USING ERRCODE = 'P0002';
  END IF;

  WITH consenting AS (
    SELECT pc.user_id FROM analytics.product_consents pc WHERE pc.consented
  ),
  -- One row per opted-in learner with an outside resource on this goal: the
  -- furthest mapping rung they reached on any of them.
  per_learner AS (
    SELECT r.user_id,
           bool_or(EXISTS (SELECT 1 FROM public.learner_resource_objectives o
                           WHERE o.resource_id = r.id)) AS ticked,
           bool_or(EXISTS (SELECT 1 FROM public.learner_resource_sections s
                           WHERE s.resource_id = r.id AND s.map_source = 'outline_match')) AS outline,
           bool_or(EXISTS (SELECT 1 FROM public.learner_resource_sections s
                           WHERE s.resource_id = r.id AND s.map_source = 'own_ai')) AS own_ai
    FROM public.learner_external_resources r
    JOIN consenting c ON c.user_id = r.user_id
    WHERE r.target_id = v_target
    GROUP BY r.user_id
  ),
  studying AS (
    SELECT DISTINCT p.user_id
    FROM public.learner_activity_progress p
    JOIN consenting c ON c.user_id = p.user_id
    JOIN public.curriculum_node_lessons cnl
      ON p.content_kind = 'legacy_lesson' AND p.content_id = cnl.lesson_id::text
    JOIN public.curriculum_nodes n ON n.id = cnl.curriculum_node_id
    WHERE n.target_version_id = p_target_version_id
  )
  SELECT (SELECT count(*) FROM (SELECT user_id FROM studying UNION SELECT user_id FROM per_learner) u),
         (SELECT count(*) FROM per_learner),
         (SELECT count(*) FROM per_learner l WHERE NOT l.ticked AND NOT l.outline AND NOT l.own_ai),
         (SELECT count(*) FROM per_learner l WHERE l.ticked AND NOT l.outline AND NOT l.own_ai),
         (SELECT count(*) FROM per_learner l WHERE l.outline AND NOT l.own_ai),
         (SELECT count(*) FROM per_learner l WHERE l.own_ai)
    INTO v_goal_learners, v_with_resource, v_listed, v_ticked, v_outline, v_own_ai;

  WITH consenting AS (
    SELECT pc.user_id FROM analytics.product_consents pc WHERE pc.consented
  ),
  -- The same independent checks the learner-signal report counts.
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
  -- (learner, objective) pairs marked studied on this goal, at the earliest
  -- mark, for objectives LearningApp can actually check.
  studied AS (
    SELECT o.user_id, n.id AS objective_id, min(o.studied_at) AS studied_at
    FROM public.learner_resource_objectives o
    JOIN public.learner_external_resources r ON r.id = o.resource_id AND r.target_id = v_target
    JOIN consenting c ON c.user_id = o.user_id
    JOIN public.curriculum_nodes n
      ON n.target_version_id = p_target_version_id
     AND (n.code = o.objective_key OR (coalesce(n.code, '') = '' AND n.title = o.objective_key))
    WHERE o.studied_at IS NOT NULL
      AND EXISTS (SELECT 1 FROM held_links hl WHERE hl.objective_id = n.id)
    GROUP BY o.user_id, n.id
  ),
  followed AS (
    SELECT s.user_id, s.objective_id, avg(l.score) AS mean_score
    FROM studied s
    JOIN held_links hl ON hl.objective_id = s.objective_id
    JOIN private.item_response_log l
      ON l.item_id = hl.item_id AND l.user_id = s.user_id
     AND l.responded_at >= s.studied_at
     AND l.responded_at < s.studied_at + c_follow_up
    GROUP BY s.user_id, s.objective_id
  )
  SELECT (SELECT count(*) FROM studied),
         (SELECT count(DISTINCT user_id) FROM studied),
         (SELECT count(*) FROM followed),
         (SELECT count(DISTINCT user_id) FROM followed),
         (SELECT round(avg(mean_score)::numeric, 3) FROM followed)
    INTO v_pairs, v_pair_learners, v_checked, v_checked_learners, v_mean;

  -- A figure is shown only if it, and whatever is left when it is taken
  -- from its total, each rest on no accounts or on at least c_min_group.
  v_share_ok := v_goal_learners >= c_min_group
            AND v_with_resource >= c_min_group
            AND (v_goal_learners - v_with_resource = 0
                 OR v_goal_learners - v_with_resource >= c_min_group);
  v_mapping_ok := v_with_resource >= c_min_group
              AND (v_listed = 0 OR v_listed >= c_min_group)
              AND (v_ticked = 0 OR v_ticked >= c_min_group)
              AND (v_outline = 0 OR v_outline >= c_min_group)
              AND (v_own_ai = 0 OR v_own_ai >= c_min_group);
  v_check_ok := v_pair_learners >= c_min_group
            AND v_checked_learners >= c_min_group
            AND (v_pair_learners - v_checked_learners = 0
                 OR v_pair_learners - v_checked_learners >= c_min_group);

  RETURN jsonb_build_object(
    'target_version_id', p_target_version_id,
    'population', 'learners who opted in to product analytics',
    'thresholds', jsonb_build_object('min_group', c_min_group, 'follow_up_days', 7),
    'goal_learners', CASE WHEN v_goal_learners >= c_min_group THEN v_goal_learners END,
    'goal_learners_status',
      CASE WHEN v_goal_learners >= c_min_group THEN 'ok' ELSE 'small_cohort_suppressed' END,
    'with_outside_resource', CASE WHEN v_share_ok THEN v_with_resource END,
    'outside_resource_share',
      CASE WHEN v_share_ok THEN round(v_with_resource::numeric / v_goal_learners, 3) END,
    'outside_resource_status', CASE WHEN v_share_ok THEN 'ok' ELSE 'small_cohort_suppressed' END,
    -- The furthest mapping rung each learner reached.
    'mapping', jsonb_build_object(
      'status', CASE WHEN v_mapping_ok THEN 'ok' ELSE 'small_cohort_suppressed' END,
      'listed_only', CASE WHEN v_mapping_ok THEN v_listed END,
      'ticked_objectives', CASE WHEN v_mapping_ok THEN v_ticked END,
      'outline_word_match', CASE WHEN v_mapping_ok THEN v_outline END,
      'outline_own_ai', CASE WHEN v_mapping_ok THEN v_own_ai END),
    'studied_then_checked', jsonb_build_object(
      'status', CASE WHEN v_check_ok THEN 'ok' ELSE 'small_cohort_suppressed' END,
      'studied_pairs', CASE WHEN v_check_ok THEN v_pairs END,
      'checked_within_7_days', CASE WHEN v_check_ok THEN v_checked END,
      'checked_share', CASE WHEN v_check_ok THEN round(v_checked::numeric / v_pairs, 3) END,
      'mean_check_score', CASE WHEN v_check_ok THEN v_mean END),
    'not_measured', jsonb_build_array(
      jsonb_build_object('measure', 'gap offers opened',
        'reason', 'needs a product event that is not collected'),
      jsonb_build_object('measure', 'return after a break',
        'reason', 'needs a session definition and events that are not collected'),
      jsonb_build_object('measure', 'readiness with and without outside resources',
        'reason', 'not defined yet; would be descriptive only, with no causal claim'),
      jsonb_build_object('measure', 'pages visited, watch time, resource names or links',
        'reason', 'never collected, by design')),
    'note', 'Descriptive only. Marked studied is self-report; this counts how often a real check followed it.'
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_companion_outcome_report(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_companion_outcome_report(uuid) TO authenticated, service_role;

COMMIT;
