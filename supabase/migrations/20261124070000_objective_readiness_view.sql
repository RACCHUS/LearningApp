-- Readiness by objective (ingestion plan v1.2 §8.7): a per-domain view of a
-- target's objectives, each marked strong, building, not started or not yet
-- available in LearningApp, with each domain's blueprint weight.
--
-- Switch learning.objective_readiness_view (default OFF). While it is off the
-- function returns only {"enabled": false} and computes nothing.
--
-- Scoring matches get_target_readiness_v2 (20261106000000): a concept's score
-- is 0.6 * FSRS retrievability now + 0.4 * accuracy when it has been
-- reviewed, otherwise accuracy scaled by evidence (up to 5 items). An
-- objective is:
--   not_available  no lesson in LearningApp yet;
--   not_started    no evidence on its core concepts;
--   strong         80%+ of its core concepts assessed, weighted score 0.85+,
--                  AND 6+ approved held-out checks (D-14: practice alone can't
--                  show strength);
--   building       anything else.
-- A domain is not_available when none of its objectives (or, without
-- objectives, the domain itself) has lessons; strong when every available
-- objective is strong; not_started when none has evidence; else building.
--
-- Guests: like get_target_readiness_coverage (20261124060000), a signed-out
-- caller may read published or retired versions of public targets. With no
-- learner, every available objective is not_started.
BEGIN;

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.objective_readiness_view', 'Readiness by objective', 'Learning', 'release', false, 'experimental', false,
  'Per-domain view of a target''s objectives: strong, building, not started or not yet available, with blueprint weights')
ON CONFLICT (feature_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_target_objective_readiness(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  c_min_held_out constant integer := 6;
  c_strong_score constant numeric := 0.85;
  c_strong_assessed constant numeric := 0.80;
  v_uid uuid := (SELECT auth.uid());
  v_result jsonb;
BEGIN
  IF v_uid IS NULL AND NOT EXISTS (
    SELECT 1
    FROM public.target_versions tv
    JOIN public.learning_targets lt ON lt.id = tv.target_id
    WHERE tv.id = p_target_version_id
      AND tv.status IN ('published', 'retired')
      AND lt.is_public
  ) THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.objective_readiness_view') THEN
    RETURN jsonb_build_object('enabled', false);
  END IF;

  WITH domains AS (
    SELECT n.id, n.code, n.title, n.weight, n.sort_order
    FROM public.curriculum_nodes n
    WHERE n.target_version_id = p_target_version_id
      AND n.node_type = 'domain'
  ),
  flags AS (
    SELECT coalesce(bool_and(d.weight IS NOT NULL AND d.weight > 0), false) AS all_weighted
    FROM domains d
  ),
  domain_w AS (
    SELECT d.*,
           CASE WHEN f.all_weighted
                THEN d.weight / sum(d.weight) OVER ()
                ELSE 1.0 / count(*) OVER ()
           END AS share
    FROM domains d CROSS JOIN flags f
  ),
  objectives AS (
    SELECT o.id, o.parent_id AS domain_id, o.code, o.title, o.sort_order
    FROM public.curriculum_nodes o
    JOIN domains d ON d.id = o.parent_id
    WHERE o.target_version_id = p_target_version_id
      AND o.node_type = 'objective'
  ),
  held AS (
    -- Same held-out sources as get_target_readiness_coverage.
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
    UNION
    SELECT ai.id, ai.lesson_id
    FROM private.held_out_item_reviews r
    JOIN public.assessment_items ai ON ai.id = r.assessment_item_id
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(ai.id)
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
  held_counts AS (
    SELECT l.objective_id, count(DISTINCT l.item_id) AS n
    FROM held_links l
    JOIN objectives o ON o.id = l.objective_id
    GROUP BY l.objective_id
  ),
  obj_concepts AS (
    SELECT cnc.curriculum_node_id AS objective_id, cnc.concept_id,
           coalesce(cnc.weight, 1.0)::numeric AS w
    FROM public.curriculum_node_concepts cnc
    JOIN objectives o ON o.id = cnc.curriculum_node_id
    WHERE cnc.relevance = 'core'
  ),
  concept_scores AS (
    SELECT oc.objective_id, oc.concept_id, oc.w,
           (coalesce(ucs.evidence_count, 0) > 0 OR ri.stability IS NOT NULL) AS assessed,
           CASE
             WHEN ri.stability IS NOT NULL AND ri.stability > 0 THEN
               0.60 * greatest(0.0, least(1.0, power(
                 1.0 + 19.0 * (greatest(0.0, extract(epoch FROM (now() - coalesce(ri.last_reviewed_at, now()))) / 86400.0)
                               / (9.0 * ri.stability)),
                 -0.5)::numeric))
               + 0.40 * CASE WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total)::numeric ELSE 0.0 END
             WHEN coalesce(ucs.evidence_count, 0) > 0 THEN
               CASE WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total)::numeric ELSE 0.0 END
               * least(1.0, ucs.evidence_count / 5.0)
             ELSE 0.0
           END AS score
    FROM obj_concepts oc
    LEFT JOIN public.user_concept_state ucs
      ON v_uid IS NOT NULL AND ucs.concept_id = oc.concept_id AND ucs.user_id = v_uid
    LEFT JOIN LATERAL (
      SELECT r.stability, r.last_reviewed_at
      FROM public.review_items r
      WHERE v_uid IS NOT NULL
        AND r.user_id = v_uid
        AND r.content_id = oc.concept_id::text
        AND r.stability IS NOT NULL
      ORDER BY r.last_reviewed_at DESC NULLS LAST
      LIMIT 1
    ) ri ON true
  ),
  obj_rollup AS (
    SELECT o.id, o.domain_id, o.code, o.title, o.sort_order,
           EXISTS (SELECT 1 FROM public.curriculum_node_lessons cnl
                   WHERE cnl.curriculum_node_id = o.id) AS has_lessons,
           coalesce(max(h.n), 0) AS held_out,
           count(cs.concept_id) AS concepts,
           count(cs.concept_id) FILTER (WHERE cs.assessed) AS assessed,
           CASE WHEN sum(cs.w) > 0 THEN sum(cs.score * cs.w) / sum(cs.w) END AS score
    FROM objectives o
    LEFT JOIN held_counts h ON h.objective_id = o.id
    LEFT JOIN concept_scores cs ON cs.objective_id = o.id
    GROUP BY o.id, o.domain_id, o.code, o.title, o.sort_order
  ),
  obj_status AS (
    SELECT r.*,
           r.held_out >= c_min_held_out AS checked,
           CASE
             WHEN NOT r.has_lessons THEN 'not_available'
             WHEN r.assessed = 0 THEN 'not_started'
             WHEN r.held_out >= c_min_held_out
                  AND r.concepts > 0
                  AND r.assessed::numeric / r.concepts >= c_strong_assessed
                  AND r.score >= c_strong_score THEN 'strong'
             ELSE 'building'
           END AS status
    FROM obj_rollup r
  ),
  domain_status AS (
    SELECT d.id,
           CASE
             WHEN NOT EXISTS (SELECT 1 FROM obj_status s WHERE s.domain_id = d.id) THEN
               CASE WHEN EXISTS (SELECT 1 FROM public.curriculum_node_lessons cnl
                                 WHERE cnl.curriculum_node_id = d.id)
                    THEN 'not_started' ELSE 'not_available' END
             WHEN NOT EXISTS (SELECT 1 FROM obj_status s
                              WHERE s.domain_id = d.id AND s.status <> 'not_available') THEN 'not_available'
             WHEN NOT EXISTS (SELECT 1 FROM obj_status s
                              WHERE s.domain_id = d.id AND s.status NOT IN ('strong', 'not_available')) THEN 'strong'
             WHEN NOT EXISTS (SELECT 1 FROM obj_status s
                              WHERE s.domain_id = d.id AND s.status IN ('strong', 'building')) THEN 'not_started'
             ELSE 'building'
           END AS status
    FROM domains d
  )
  SELECT jsonb_build_object(
    'enabled', true,
    'signed_in', v_uid IS NOT NULL,
    'weights_editorial', NOT (SELECT all_weighted FROM flags),
    'min_held_out_items', c_min_held_out,
    'domains', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'code', d.code,
               'title', d.title,
               'weight_share', round(d.share, 4),
               'status', ds.status,
               'objectives', coalesce((
                 SELECT jsonb_agg(jsonb_build_object(
                          'code', s.code,
                          'title', s.title,
                          'status', s.status,
                          'checked', s.checked,
                          'concepts', s.concepts,
                          'assessed', s.assessed
                        ) ORDER BY s.sort_order, s.code)
                 FROM obj_status s
                 WHERE s.domain_id = d.id
               ), '[]'::jsonb)
             ) ORDER BY d.sort_order, d.code)
      FROM domain_w d
      JOIN domain_status ds ON ds.id = d.id
    ), '[]'::jsonb)
  )
  INTO v_result;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_objective_readiness(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_target_objective_readiness(uuid) TO anon, authenticated, service_role;

COMMIT;
