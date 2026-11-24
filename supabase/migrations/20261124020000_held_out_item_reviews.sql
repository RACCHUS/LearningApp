-- General held-out check items (ingestion plan v1.2 §8.6 / D-14; owner chose
-- option B of docs/content_intelligence/HELD_OUT_CHECKS_DESIGN.md on
-- 2026-11-24).
--
-- The readiness coverage gate (20261124010000) counted only exam-reference
-- (EXM) held_out_transfer bindings, which model answer locations in
-- exam-permitted reference books. This adds a general path for targets such
-- as College Algebra:
--
--   1. private.held_out_item_reviews: one immutable approval per held-out
--      item. It records the author, whether the item was AI-drafted, a
--      different reviewer and their qualification, rights approval, the date,
--      and a fingerprint of the exact item content. No client grants.
--   2. public.ingest_held_out_items(target_version_id, items): service role
--      only. Inserts APPROVED items into a DRAFT target version with no
--      lesson (so they never appear as lesson practice), links them to that
--      version's concepts, registers them as import artifacts (draft cleanup
--      removes them) and writes the approval rows. Unapproved items are
--      refused, never stored.
--   3. public.get_target_readiness_coverage: also counts items with an
--      approved review whose fingerprint still matches the live item.
--
-- Additive. Learners see held-out items only through the existing
-- diagnostic and mock-exam selection by target version; answer keys keep the
-- existing column protection.

CREATE TABLE private.held_out_item_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_item_id uuid NOT NULL UNIQUE
    REFERENCES public.assessment_items(id) ON DELETE CASCADE,
  target_version_id uuid NOT NULL
    REFERENCES public.target_versions(id) ON DELETE CASCADE,
  item_key text NOT NULL CHECK (item_key ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  item_content_sha256 text NOT NULL CHECK (item_content_sha256 ~ '^[a-f0-9]{64}$'),
  author_ref text NOT NULL CHECK (length(btrim(author_ref)) BETWEEN 2 AND 150),
  ai_drafted boolean NOT NULL,
  reviewer_ref text NOT NULL CHECK (length(btrim(reviewer_ref)) BETWEEN 2 AND 150),
  reviewer_qualification text NOT NULL
    CHECK (length(btrim(reviewer_qualification)) BETWEEN 3 AND 500),
  review_status text NOT NULL CHECK (review_status IN ('approved', 'retired')),
  rights_review_status text NOT NULL CHECK (rights_review_status = 'approved'),
  reviewed_on date NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT held_out_reviewer_is_not_author
    CHECK (lower(btrim(reviewer_ref)) <> lower(btrim(author_ref))),
  UNIQUE (target_version_id, item_key)
);
CREATE INDEX held_out_item_reviews_version_idx
  ON private.held_out_item_reviews (target_version_id, review_status);
ALTER TABLE private.held_out_item_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.held_out_item_reviews FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE private.held_out_item_reviews IS
  'Immutable approvals of general held-out check items (ingestion plan D-14, option B). Reviewer must differ from author. No client grants.';

-- Approvals are immutable. The only update is approved -> retired with
-- nothing else changed. Rows go away only with their item while the target
-- version is still a draft (draft cleanup); published history stays.
CREATE OR REPLACE FUNCTION private.guard_held_out_item_review()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_status text;
  v_item public.assessment_items%ROWTYPE;
BEGIN
  IF tg_op = 'DELETE' THEN
    SELECT tv.status INTO v_status FROM public.target_versions tv WHERE tv.id = old.target_version_id;
    IF v_status IS NOT NULL AND v_status <> 'draft' THEN
      RAISE EXCEPTION 'Held-out approvals of a non-draft version cannot be deleted' USING ERRCODE = '42501';
    END IF;
    RETURN old;
  END IF;
  IF tg_op = 'UPDATE' THEN
    IF old.review_status = 'approved' AND new.review_status = 'retired'
       AND (to_jsonb(new) - 'review_status') = (to_jsonb(old) - 'review_status') THEN
      RETURN new;
    END IF;
    RAISE EXCEPTION 'Held-out approvals are immutable; retire and re-review instead' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_item FROM public.assessment_items WHERE id = new.assessment_item_id;
  IF NOT FOUND OR v_item.lesson_id IS NOT NULL
     OR v_item.origin_target_version_id IS DISTINCT FROM new.target_version_id THEN
    RAISE EXCEPTION 'A held-out item must belong to the review''s target version and to no lesson'
      USING ERRCODE = '22023';
  END IF;
  IF new.review_status <> 'approved' THEN
    RAISE EXCEPTION 'Only approved reviews are recorded' USING ERRCODE = '22023';
  END IF;
  IF new.item_content_sha256 IS DISTINCT FROM public.exam_reference_item_fingerprint(new.assessment_item_id) THEN
    RAISE EXCEPTION 'The approval does not match the item''s current content' USING ERRCODE = '22023';
  END IF;
  RETURN new;
END;
$$;
REVOKE ALL ON FUNCTION private.guard_held_out_item_review() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER held_out_item_reviews_guard
  BEFORE INSERT OR UPDATE OR DELETE ON private.held_out_item_reviews
  FOR EACH ROW EXECUTE FUNCTION private.guard_held_out_item_review();

-- Service-role ingestion of approved held-out items into a draft version.
-- p_items: [{key, interaction_type, prompt, response_spec, scoring_spec,
--   explanation, difficulty, cognitive_level, citation, concept_slugs,
--   review: {author_ref, ai_drafted, reviewer_ref, reviewer_qualification,
--            reviewed_on, review_status, rights_review_status}}]
-- All items are written or none (the call is one transaction). Errors name
-- the item key, never the answer.
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
      review_status, rights_review_status, reviewed_on
    ) VALUES (
      v_item_id, p_target_version_id, v_key, public.exam_reference_item_fingerprint(v_item_id),
      v_review->>'author_ref', (v_review->>'ai_drafted')::boolean,
      v_review->>'reviewer_ref', v_review->>'reviewer_qualification',
      'approved', 'approved', (v_review->>'reviewed_on')::date
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object('target_version_id', p_target_version_id, 'held_out_items', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.ingest_held_out_items(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ingest_held_out_items(uuid, jsonb) TO service_role;

-- Coverage now counts both kinds of held-out approval. Unchanged otherwise.
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
  'Aggregate share of a target version''s blueprint weight whose objectives have at least 6 held-out check items: approved, published EXM held_out_transfer bindings or approved general held-out reviews (ingestion plan D-14). Counts only; returns {"enabled": false} while learning.readiness_coverage_gate is off.';
