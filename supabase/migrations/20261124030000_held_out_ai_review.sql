-- Operating model D-16 (owner, 2026-11-24): one person runs LearningApp, AI
-- does most building and reviewing, and nothing costs money. Every paid or
-- people-dependent capability must be optional, switch-gated and ready to
-- add later.
--
-- So a held-out check item may be approved by an independent AI review, not
-- only by a person, and the record says which:
--   * reviewer_kind 'ai' | 'human'; an AI review also names the reviewing
--     model (reviewer_model). The reviewer must still differ from the author
--     (existing constraint), and reviewer_qualification holds the reviewer's
--     qualification or, for AI, the review method (checklist version and
--     independent SymPy verification).
--   * get_target_readiness_coverage reports review_basis (human / ai / mixed)
--     so the app never presents AI-reviewed checks as reviewed by a person.
--   * A qualified human review remains a drop-in upgrade: same table, kind
--     'human', no schema change needed.
--
-- Additive: two columns, and both functions re-created from 20261124020000
-- with only these changes. Existing rows (none in production) become
-- 'human', the stricter claim; the default is then dropped so every new row
-- must state its kind.

ALTER TABLE private.held_out_item_reviews
  ADD COLUMN reviewer_kind text NOT NULL DEFAULT 'human'
    CHECK (reviewer_kind IN ('ai', 'human')),
  ADD COLUMN reviewer_model text
    CHECK (reviewer_model IS NULL OR length(btrim(reviewer_model)) BETWEEN 2 AND 120);
ALTER TABLE private.held_out_item_reviews ALTER COLUMN reviewer_kind DROP DEFAULT;
ALTER TABLE private.held_out_item_reviews
  ADD CONSTRAINT held_out_ai_review_names_model
    CHECK (reviewer_kind <> 'ai' OR reviewer_model IS NOT NULL);

COMMENT ON COLUMN private.held_out_item_reviews.reviewer_kind IS
  'ai: independent AI review (different model or fresh session from the author, checklist, SymPy verification). human: a person. Shown to learners as such (D-16).';
COMMENT ON COLUMN private.held_out_item_reviews.reviewer_qualification IS
  'For a person, their qualification; for an AI review, the method (checklist version, independent verification).';

CREATE OR REPLACE FUNCTION public.ingest_held_out_items(p_target_version_id uuid, p_items jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_status text;
  v_item jsonb;
  v_review jsonb;
  v_key text;
  v_type text;
  v_options jsonb;
  v_index jsonb;
  v_value jsonb;
  v_item_id uuid;
  v_concept_slug text;
  v_concept_id uuid;
  v_links integer;
  v_count integer := 0;
BEGIN
  SELECT status INTO v_status FROM public.target_versions WHERE id = p_target_version_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Target version not found' USING ERRCODE = '22023';
  END IF;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Held-out items can only be added to a draft target version' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'No held-out items given' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
    v_key := v_item->>'key';
    v_type := v_item->>'interaction_type';
    v_review := v_item->'review';
    IF v_key IS NULL OR v_key !~ '^[a-z0-9]+(-[a-z0-9]+)*$' THEN
      RAISE EXCEPTION 'Held-out item key % is not a lowercase slug', coalesce(v_key, '(missing)') USING ERRCODE = '22023';
    END IF;
    IF coalesce(btrim(v_item->>'prompt'), '') = '' OR coalesce(btrim(v_item->>'explanation'), '') = '' THEN
      RAISE EXCEPTION 'Held-out item % needs a prompt and an explanation', v_key USING ERRCODE = '22023';
    END IF;
    IF v_type = 'single_choice' THEN
      v_options := v_item->'response_spec'->'options';
      v_index := v_item->'scoring_spec'->'correct_index';
      IF jsonb_typeof(v_options) <> 'array' OR jsonb_array_length(v_options) < 2
         OR jsonb_typeof(v_index) <> 'number'
         OR (v_index #>> '{}')::numeric <> trunc((v_index #>> '{}')::numeric)
         OR (v_index #>> '{}')::numeric < 0
         OR (v_index #>> '{}')::numeric >= jsonb_array_length(v_options) THEN
        RAISE EXCEPTION 'Held-out item % has an invalid answer key', v_key USING ERRCODE = '22023';
      END IF;
    ELSIF v_type = 'numeric_entry' THEN
      v_value := v_item->'scoring_spec'->'correct_value';
      IF jsonb_typeof(v_value) <> 'number'
         OR (v_item->'scoring_spec' ? 'tolerance'
             AND (jsonb_typeof(v_item->'scoring_spec'->'tolerance') <> 'number'
                  OR (v_item->'scoring_spec'->>'tolerance')::numeric < 0)) THEN
        RAISE EXCEPTION 'Held-out item % has an invalid answer key', v_key USING ERRCODE = '22023';
      END IF;
    ELSE
      RAISE EXCEPTION 'Held-out item % has unsupported type %', v_key, coalesce(v_type, '(missing)') USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(v_review) <> 'object'
       OR v_review->>'review_status' IS DISTINCT FROM 'approved'
       OR v_review->>'rights_review_status' IS DISTINCT FROM 'approved' THEN
      RAISE EXCEPTION 'Held-out item % is not approved; only approved items are ingested', v_key USING ERRCODE = '22023';
    END IF;
    IF coalesce(v_review->>'reviewer_kind', '') NOT IN ('ai', 'human') THEN
      RAISE EXCEPTION 'Held-out item % needs reviewer_kind ai or human', v_key USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(v_item->'concept_slugs') <> 'array' OR jsonb_array_length(v_item->'concept_slugs') = 0 THEN
      RAISE EXCEPTION 'Held-out item % needs concept_slugs', v_key USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.assessment_items (
      prompt, interaction_type, response_spec, scoring_spec, explanation,
      difficulty, cognitive_level, origin_target_version_id, metadata
    ) VALUES (
      v_item->>'prompt', v_type,
      coalesce(v_item->'response_spec', '{}'::jsonb),
      v_item->'scoring_spec',
      v_item->>'explanation',
      coalesce(v_item->>'difficulty', 'intermediate'),
      v_item->>'cognitive_level',
      p_target_version_id,
      jsonb_build_object('usage_role', 'held_out_check', 'held_out_key', v_key,
                         'citation', v_item->>'citation')
    ) RETURNING id INTO v_item_id;

    INSERT INTO public.content_import_artifacts (target_version_id, entity_type, entity_id)
    VALUES (p_target_version_id, 'assessment_item', v_item_id);

    v_links := 0;
    FOR v_concept_slug IN SELECT jsonb_array_elements_text(v_item->'concept_slugs') LOOP
      SELECT kc.id INTO v_concept_id
      FROM public.knowledge_concepts kc
      WHERE kc.slug = v_concept_slug
        AND EXISTS (
          SELECT 1 FROM public.curriculum_node_concepts cnc
          JOIN public.curriculum_nodes cn ON cn.id = cnc.curriculum_node_id
          WHERE cnc.concept_id = kc.id AND cn.target_version_id = p_target_version_id
        );
      IF v_concept_id IS NULL THEN
        RAISE EXCEPTION 'Held-out item % names concept % that is not in this target version', v_key, v_concept_slug
          USING ERRCODE = '22023';
      END IF;
      INSERT INTO public.assessment_item_concepts (assessment_item_id, concept_id)
      VALUES (v_item_id, v_concept_id) ON CONFLICT DO NOTHING;
      v_links := v_links + 1;
    END LOOP;

    INSERT INTO private.held_out_item_reviews (
      assessment_item_id, target_version_id, item_key, item_content_sha256,
      author_ref, ai_drafted, reviewer_ref, reviewer_qualification,
      reviewer_kind, reviewer_model,
      review_status, rights_review_status, reviewed_on
    ) VALUES (
      v_item_id, p_target_version_id, v_key, public.exam_reference_item_fingerprint(v_item_id),
      v_review->>'author_ref', (v_review->>'ai_drafted')::boolean,
      v_review->>'reviewer_ref', v_review->>'reviewer_qualification',
      v_review->>'reviewer_kind', nullif(btrim(coalesce(v_review->>'reviewer_model', '')), ''),
      'approved', 'approved', (v_review->>'reviewed_on')::date
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('target_version_id', p_target_version_id, 'held_out_items', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.ingest_held_out_items(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ingest_held_out_items(uuid, jsonb) TO service_role;

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

REVOKE ALL ON FUNCTION public.get_target_readiness_coverage(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_coverage(uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.get_target_readiness_coverage(uuid) IS
  'Aggregate share of a target version''s blueprint weight whose objectives have at least 6 held-out check items: approved, published EXM held_out_transfer bindings or approved general held-out reviews (ingestion plan D-14). review_basis says whether those were reviewed by AI, people or both (D-16). Counts only; returns {"enabled": false} while learning.readiness_coverage_gate is off.';
