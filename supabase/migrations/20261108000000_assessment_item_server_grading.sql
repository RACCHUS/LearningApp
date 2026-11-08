-- Server-side grading for assessment items (follow-up to FIX-12).
--
-- FIX-12 (20261102140000) hid assessment_items.scoring_spec and explanation
-- from clients, but lessons, mock exams, and diagnostics still graded on the
-- client from scoring_spec. This RPC grades submitted responses on the server
-- and returns the answer key and explanation only for items the learner has
-- answered, so practice feedback works without exposing keys up front.
--
-- Visibility mirrors the assessment_items read policies exactly, including the
-- restrictive exm03 policy: items with an approved protected exam binding are
-- never graded or revealed here.

CREATE OR REPLACE FUNCTION public.grade_assessment_items(p_responses JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_entry JSONB;
  v_item_id UUID;
  v_response JSONB;
  v_item public.assessment_items%ROWTYPE;
  v_spec JSONB;
  v_correct_num NUMERIC;
  v_user_num NUMERIC;
  v_correct_set INTEGER[];
  v_user_set INTEGER[];
  v_mode TEXT;
  v_items TEXT[];
  v_order INTEGER[];
  v_expected TEXT[];
  v_user_order TEXT[];
  v_pairs JSONB;
  v_user_pairs JSONB;
  v_matched INTEGER;
  v_total INTEGER;
  v_hit INTEGER;
  v_miss INTEGER;
  v_score NUMERIC;
  v_is_correct BOOLEAN;
  v_is_partial BOOLEAN;
  v_supported BOOLEAN;
  v_results JSONB := '[]'::JSONB;
BEGIN
  IF p_responses IS NULL OR jsonb_typeof(p_responses) <> 'array' THEN
    RAISE EXCEPTION 'p_responses must be a JSON array' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_responses) > 250 THEN
    RAISE EXCEPTION 'At most 250 responses can be graded per call'
      USING ERRCODE = '54000';
  END IF;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(p_responses)
  LOOP
    v_item_id := NULL;
    BEGIN
      v_item_id := (v_entry->>'item_id')::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
      v_item_id := NULL;
    END;
    v_response := v_entry->'response';

    IF v_item_id IS NULL THEN
      CONTINUE;
    END IF;

    -- A response is required: keys are never revealed for unanswered items.
    IF v_response IS NULL OR jsonb_typeof(v_response) = 'null' THEN
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'response_required'));
      CONTINUE;
    END IF;

    SELECT ai.* INTO v_item
    FROM public.assessment_items ai
    WHERE ai.id = v_item_id
      AND NOT public.exm03_has_protected_binding(ai.id)
      AND (
        (v_uid IS NOT NULL AND ai.user_id = v_uid)
        OR (ai.lesson_id IS NOT NULL AND public.is_lesson_visible(ai.lesson_id))
        OR (ai.origin_target_version_id IS NOT NULL AND EXISTS (
          SELECT 1
          FROM public.target_versions tv
          JOIN public.learning_targets lt ON lt.id = tv.target_id
          WHERE tv.id = ai.origin_target_version_id
            AND (
              (tv.status = 'published' AND lt.status = 'published' AND lt.is_public = TRUE)
              OR (v_uid IS NOT NULL AND lt.created_by = v_uid)
              OR (tv.status = 'review_ready' AND public.is_target_reviewer(lt.id))
            )
        ))
      );

    IF NOT FOUND THEN
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'not_available'));
      CONTINUE;
    END IF;

    v_spec := COALESCE(v_item.scoring_spec, '{}'::JSONB);
    v_is_correct := FALSE;
    v_is_partial := FALSE;
    v_score := 0;
    v_supported := TRUE;

    CASE v_item.interaction_type
      WHEN 'single_choice' THEN
        v_correct_num := CASE
          WHEN jsonb_typeof(v_spec->'correct_index') = 'number' THEN (v_spec->>'correct_index')::NUMERIC
          WHEN jsonb_typeof(v_spec->'correct_answer') = 'number' THEN (v_spec->>'correct_answer')::NUMERIC
        END;
        v_user_num := CASE
          WHEN jsonb_typeof(v_response) = 'number' THEN (v_response#>>'{}')::NUMERIC
          WHEN jsonb_typeof(v_response) = 'string' AND (v_response#>>'{}') ~ '^\s*-?\d+\s*$'
            THEN trim(v_response#>>'{}')::NUMERIC
        END;
        v_is_correct := v_correct_num IS NOT NULL AND v_user_num IS NOT NULL
          AND trunc(v_user_num) = trunc(v_correct_num);
        v_score := CASE WHEN v_is_correct THEN 1 ELSE 0 END;

      WHEN 'multi_select' THEN
        SELECT COALESCE(array_agg(DISTINCT trunc(e::TEXT::NUMERIC)::INTEGER), '{}')
          INTO v_correct_set
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_spec->'correct_indices') = 'array'
            THEN v_spec->'correct_indices' ELSE '[]'::JSONB END) e
        WHERE jsonb_typeof(e) = 'number';

        SELECT COALESCE(array_agg(DISTINCT trunc(e::TEXT::NUMERIC)::INTEGER), '{}')
          INTO v_user_set
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_response) = 'array'
            THEN v_response ELSE jsonb_build_array(v_response) END) e
        WHERE jsonb_typeof(e) = 'number';

        v_mode := COALESCE(v_spec->>'scoring_method', v_spec->>'mode', 'all_or_nothing');
        v_total := COALESCE(array_length(v_correct_set, 1), 0);

        IF v_mode = 'partial_credit' AND v_total > 0 THEN
          SELECT count(*) FILTER (WHERE u = ANY (v_correct_set)),
                 count(*) FILTER (WHERE NOT (u = ANY (v_correct_set)))
            INTO v_hit, v_miss
          FROM unnest(v_user_set) u;
          v_score := GREATEST(0, LEAST(1, (v_hit - v_miss)::NUMERIC / v_total));
          v_is_correct := v_score >= 0.999;
          v_is_partial := v_score > 0 AND NOT v_is_correct;
        ELSE
          v_is_correct := v_total > 0
            AND COALESCE(array_length(v_user_set, 1), 0) = v_total
            AND v_user_set <@ v_correct_set;
          v_score := CASE WHEN v_is_correct THEN 1 ELSE 0 END;
        END IF;

      WHEN 'ordered_response' THEN
        SELECT COALESCE(array_agg(
                 CASE WHEN jsonb_typeof(e) = 'string' THEN e#>>'{}' ELSE e::TEXT END
                 ORDER BY ord), '{}')
          INTO v_items
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_item.response_spec->'items') = 'array'
            THEN v_item.response_spec->'items' ELSE '[]'::JSONB END)
          WITH ORDINALITY AS t(e, ord);

        SELECT COALESCE(array_agg(trunc(e::TEXT::NUMERIC)::INTEGER ORDER BY ord), '{}')
          INTO v_order
        FROM jsonb_array_elements(
          CASE WHEN jsonb_typeof(v_spec->'correct_order') = 'array'
            THEN v_spec->'correct_order' ELSE '[]'::JSONB END)
          WITH ORDINALITY AS t(e, ord)
        WHERE jsonb_typeof(e) = 'number';

        v_total := COALESCE(array_length(v_items, 1), 0);
        IF v_total > 0
           AND COALESCE(array_length(v_order, 1), 0) = v_total
           AND NOT EXISTS (SELECT 1 FROM unnest(v_order) i WHERE i < 0 OR i >= v_total) THEN
          SELECT array_agg(v_items[i + 1] ORDER BY ord) INTO v_expected
          FROM unnest(v_order) WITH ORDINALITY AS t(i, ord);

          SELECT COALESCE(array_agg(
                   CASE WHEN jsonb_typeof(e) = 'string' THEN e#>>'{}' ELSE e::TEXT END
                   ORDER BY ord), '{}')
            INTO v_user_order
          FROM jsonb_array_elements(
            CASE WHEN jsonb_typeof(v_response) = 'array' THEN v_response ELSE '[]'::JSONB END)
            WITH ORDINALITY AS t(e, ord);

          v_is_correct := v_user_order = v_expected;
        END IF;
        v_score := CASE WHEN v_is_correct THEN 1 ELSE 0 END;

      WHEN 'matching' THEN
        v_pairs := CASE WHEN jsonb_typeof(v_spec->'correct_pairs') = 'object'
          THEN v_spec->'correct_pairs' ELSE '{}'::JSONB END;
        v_user_pairs := CASE WHEN jsonb_typeof(v_response) = 'object'
          THEN v_response ELSE '{}'::JSONB END;

        SELECT count(*) INTO v_total FROM jsonb_object_keys(v_pairs);
        IF v_total > 0 THEN
          SELECT count(*) INTO v_matched
          FROM jsonb_each(v_pairs) c
          WHERE EXISTS (
            SELECT 1 FROM jsonb_each(v_user_pairs) u
            WHERE trim(u.key) = trim(c.key)
              AND trim(CASE WHEN jsonb_typeof(u.value) = 'string' THEN u.value#>>'{}' ELSE u.value::TEXT END)
                = trim(CASE WHEN jsonb_typeof(c.value) = 'string' THEN c.value#>>'{}' ELSE c.value::TEXT END)
          );
          v_score := v_matched::NUMERIC / v_total;
          v_is_correct := v_score >= 0.999;
          v_is_partial := v_score > 0 AND NOT v_is_correct;
        END IF;

      ELSE
        -- Unsupported interaction types fail closed and reveal nothing.
        v_supported := FALSE;
    END CASE;

    IF NOT v_supported THEN
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'item_id', v_item_id, 'error', 'unsupported_interaction_type',
        'is_correct', FALSE, 'is_partial', FALSE, 'score', 0));
      CONTINUE;
    END IF;

    v_results := v_results || jsonb_build_array(jsonb_build_object(
      'item_id', v_item_id,
      'is_correct', v_is_correct,
      'is_partial', v_is_partial,
      'score', round(v_score, 4),
      'scoring_spec', v_spec,
      'explanation', v_item.explanation
    ));
  END LOOP;

  RETURN v_results;
END;
$$;

COMMENT ON FUNCTION public.grade_assessment_items(JSONB) IS
  'Grades [{item_id, response}] for visible, non-protected assessment items and '
  'returns the grade with scoring_spec and explanation only for answered items.';

REVOKE ALL ON FUNCTION public.grade_assessment_items(JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grade_assessment_items(JSONB)
  TO anon, authenticated, service_role;
