-- Readiness coverage for signed-out guests (ingestion plan v1.2 D-14).
--
-- With learning.readiness_coverage_gate on (20261124050000), a signed-out
-- guest's call was refused, so the card failed closed with "couldn't
-- confirm" on every target, even ones with full held-out coverage. Coverage
-- is computed from published content (held-out approvals, blueprint weights)
-- and says nothing about a learner, so guests may now read it for published
-- or retired versions of public targets. Signed-in behaviour is unchanged.
-- The function body is otherwise identical to 20261124030000.
BEGIN;

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
  v_ai_items integer;
  v_human_items integer;
BEGIN
  -- Coverage describes published content, not a learner, so signed-out
  -- guests may read it for published or retired versions of public targets
  -- (20261124060000). Anything else still needs a signed-in user.
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
    -- Exam-reference held-out bindings made for this target version.
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
    -- General held-out items (20261124020000): an approved review whose
    -- fingerprint still matches the live item.
    SELECT ai.id, ai.lesson_id
    FROM private.held_out_item_reviews r
    JOIN public.assessment_items ai ON ai.id = r.assessment_item_id
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(ai.id)
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

  -- Who reviewed the held-out items that count (20261124030000, D-16).
  WITH objectives AS (
    SELECT o.id FROM public.curriculum_nodes o
    WHERE o.target_version_id = p_target_version_id AND o.node_type = 'objective'
  ),
  kinds AS (
    SELECT DISTINCT ai.id, 'human'::text AS kind
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
    SELECT r.assessment_item_id, r.reviewer_kind
    FROM private.held_out_item_reviews r
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(r.assessment_item_id)
  )
  SELECT count(*) FILTER (WHERE k.kind = 'ai')::integer,
         count(*) FILTER (WHERE k.kind = 'human')::integer
  INTO v_ai_items, v_human_items
  FROM kinds k
  WHERE EXISTS (
    SELECT 1 FROM public.assessment_item_concepts aic
    JOIN public.curriculum_node_concepts cnc ON cnc.concept_id = aic.concept_id
    JOIN objectives ob ON ob.id = cnc.curriculum_node_id
    WHERE aic.assessment_item_id = k.id
  ) OR EXISTS (
    SELECT 1 FROM public.assessment_items ai
    JOIN public.curriculum_node_lessons cnl ON cnl.lesson_id = ai.lesson_id
    JOIN objectives ob ON ob.id = cnl.curriculum_node_id
    WHERE ai.id = k.id
  );

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
    'weights_editorial', coalesce(v_editorial, true),
    'review_basis', CASE WHEN coalesce(v_ai_items, 0) + coalesce(v_human_items, 0) = 0 THEN NULL
                         WHEN coalesce(v_ai_items, 0) = 0 THEN 'human'
                         WHEN coalesce(v_human_items, 0) = 0 THEN 'ai'
                         ELSE 'mixed' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_readiness_coverage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_coverage(uuid) TO anon, authenticated, service_role;

COMMIT;
