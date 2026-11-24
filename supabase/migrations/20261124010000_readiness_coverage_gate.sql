-- Readiness coverage gate (ingestion plan v1.2 §8.6, owner decision D-14,
-- accepted 2026-11-24).
--
-- A readiness estimate is only as good as the independent evidence behind
-- it. This adds a read-only, aggregate-only measure of how much of a target's
-- blueprint weight has enough held-out check items, so the app can:
--   * hide the readiness band below 60% of blueprint weight (show study
--     progress instead),
--   * label it provisional from 60% up to 90%,
--   * show it normally at 90% or more.
--
-- "Held-out check item" reuses the existing exam reference contract: an
-- assessment item with an assessment_item_reference_validity row for a
-- published manifest revision of this target version, where usage_role =
-- 'held_out_transfer', publication_status = 'published' and both
-- review_status and rights_review_status = 'approved'. The item reaches an
-- objective through its concepts (assessment_item_concepts to
-- curriculum_node_concepts) or its lesson. Items shown in lessons as practice
-- (including source-derived graded Try It items) do not count. An objective
-- is covered when it has at least 6 such items (D-14).
--
-- Blueprint weight: each domain's weight, normalised over the version; if any
-- domain lacks a positive weight, domains share equally (reported as
-- weights_editorial). Objectives split their domain's weight equally.
--
-- Switch learning.readiness_coverage_gate is seeded OFF. While it is off the
-- function returns {"enabled": false} without reading any curriculum data,
-- and the app does not call it. The function returns counts and ratios only:
-- no item ids, content, keys or learner data.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.readiness_coverage_gate', 'Readiness coverage gate', 'Learning', 'release', false, 'experimental', false,
  'Hide or qualify target readiness until held-out checks cover enough of the blueprint (60% provisional, 90% full)')
ON CONFLICT (feature_key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_target_readiness_coverage(p_target_version_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  c_min_items constant integer := 6;
  c_provisional constant numeric := 0.60;
  c_full constant numeric := 0.90;
  v_total integer;
  v_covered integer;
  v_weight_all numeric;
  v_weight_covered numeric;
  v_editorial boolean;
  v_ratio numeric;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.readiness_coverage_gate') THEN
    RETURN jsonb_build_object('enabled', false);
  END IF;

  WITH domains AS (
    SELECT n.id, n.weight
    FROM public.curriculum_nodes n
    WHERE n.target_version_id = p_target_version_id
      AND n.node_type = 'domain'
  ),
  flags AS (
    SELECT coalesce(bool_and(d.weight IS NOT NULL AND d.weight > 0), false) AS all_weighted
    FROM domains d
  ),
  domain_w AS (
    SELECT d.id,
           CASE WHEN f.all_weighted
                THEN d.weight / sum(d.weight) OVER ()
                ELSE 1.0 / count(*) OVER ()
           END AS w
    FROM domains d CROSS JOIN flags f
  ),
  objectives AS (
    SELECT o.id,
           dw.w / count(*) OVER (PARTITION BY o.parent_id) AS w
    FROM public.curriculum_nodes o
    JOIN domain_w dw ON dw.id = o.parent_id
    WHERE o.target_version_id = p_target_version_id
      AND o.node_type = 'objective'
  ),
  held AS (
    -- Approved, published held-out bindings made for this target version.
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
  ),
  links AS (
    -- An item reaches an objective through its concepts or its lesson.
    SELECT cnc.curriculum_node_id AS objective_id, h.id AS item_id
    FROM held h
    JOIN public.assessment_item_concepts aic ON aic.assessment_item_id = h.id
    JOIN public.curriculum_node_concepts cnc ON cnc.concept_id = aic.concept_id
    UNION
    SELECT cnl.curriculum_node_id, h.id
    FROM held h
    JOIN public.curriculum_node_lessons cnl ON cnl.lesson_id = h.lesson_id
  ),
  held_out AS (
    SELECT l.objective_id, count(DISTINCT l.item_id) AS n
    FROM links l
    JOIN objectives ob ON ob.id = l.objective_id
    GROUP BY l.objective_id
  )
  SELECT count(*)::integer,
         count(*) FILTER (WHERE coalesce(h.n, 0) >= c_min_items)::integer,
         coalesce(sum(ob.w), 0),
         coalesce(sum(ob.w) FILTER (WHERE coalesce(h.n, 0) >= c_min_items), 0),
         NOT (SELECT all_weighted FROM flags)
  INTO v_total, v_covered, v_weight_all, v_weight_covered, v_editorial
  FROM objectives ob
  LEFT JOIN held_out h ON h.objective_id = ob.id;

  v_ratio := CASE WHEN v_weight_all > 0 THEN round(v_weight_covered / v_weight_all, 4) ELSE 0 END;

  RETURN jsonb_build_object(
    'enabled', true,
    'state', CASE WHEN v_total > 0 AND v_ratio >= c_full THEN 'full'
                  WHEN v_total > 0 AND v_ratio >= c_provisional THEN 'provisional'
                  ELSE 'hidden' END,
    'covered_weight', v_ratio,
    'objectives_total', v_total,
    'objectives_covered', v_covered,
    'min_held_out_items', c_min_items,
    'provisional_threshold', c_provisional,
    'full_threshold', c_full,
    'weights_editorial', coalesce(v_editorial, true)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_readiness_coverage(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_coverage(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.get_target_readiness_coverage(uuid) IS
  'Aggregate share of a target version''s blueprint weight whose objectives have at least 6 approved, published held-out check items (ingestion plan D-14). Counts only; returns {"enabled": false} while learning.readiness_coverage_gate is off.';
