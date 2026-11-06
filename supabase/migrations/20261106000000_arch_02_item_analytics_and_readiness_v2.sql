-- ============================================================================
-- Architecture Phase 1 Deliverable: Item Analytics & Readiness v2
-- Migration: 20261106000000_arch_02_item_analytics_and_readiness_v2.sql
-- ============================================================================

-- -----------------------------------------------------------------------------
-- 1. ITEM ANALYTICS & PSYCHOMETRICS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.item_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL DEFAULT 'question',
  response_count INTEGER NOT NULL DEFAULT 0,
  correct_count INTEGER NOT NULL DEFAULT 0,
  p_value REAL,                    -- Classical Test Theory difficulty/facility: correct / total
  point_biserial REAL,             -- Item discrimination: correlation between item score and total score
  distractor_rates JSONB DEFAULT '{}'::jsonb, -- e.g. {"0": 0.65, "1": 0.05, "2": 0.30}
  distractor_counts JSONB DEFAULT '{}'::jsonb,
  median_latency_ms INTEGER,       -- Median learner response time
  iqr_latency_ms INTEGER,          -- Interquartile range of response time
  flagged_reasons TEXT[] DEFAULT ARRAY[]::TEXT[], -- e.g. ['negative_discrimination', 'dead_distractor']
  auto_flagged BOOLEAN NOT NULL DEFAULT false,
  moderation_report_id UUID REFERENCES public.moderation_reports(id) ON DELETE SET NULL,
  last_calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_item_analytics_item UNIQUE (item_id, item_type)
);

CREATE INDEX IF NOT EXISTS idx_item_analytics_flagged
  ON public.item_analytics(auto_flagged, last_calculated_at DESC);
CREATE INDEX IF NOT EXISTS idx_item_analytics_item_id
  ON public.item_analytics(item_id);

ALTER TABLE public.item_analytics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS item_analytics_select_policy ON public.item_analytics;
CREATE POLICY item_analytics_select_policy ON public.item_analytics
  FOR SELECT TO authenticated, service_role
  USING (true);

-- Direct client DML denied: calculations must flow through compute_item_analytics or service_role
REVOKE ALL ON public.item_analytics FROM PUBLIC, anon;
GRANT SELECT ON public.item_analytics TO authenticated;
GRANT ALL ON public.item_analytics TO service_role;

-- -----------------------------------------------------------------------------
-- 2. COMPUTE ITEM ANALYTICS & AUTO-FLAG MODERATION RPC
-- -----------------------------------------------------------------------------
-- Analyzes empirical learner responses from learning_events and completed assessment_attempts,
-- computes CTT p-value, point-biserial discrimination (r_pbis), distractor selection rates,
-- and median latency. Items violating quality bounds (negative discrimination, extreme difficulty,
-- dead distractors, extreme latency) are auto-flagged into public.moderation_reports.
CREATE OR REPLACE FUNCTION public.compute_item_analytics(
  p_min_responses INTEGER DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_item RECORD;
  v_total_evaluated INTEGER := 0;
  v_flagged_count INTEGER := 0;
  v_reports_created INTEGER := 0;

  v_p_value REAL;
  v_point_biserial REAL;
  v_mean_total REAL;
  v_mean_correct REAL;
  v_stddev_total REAL;
  v_median_lat INTEGER;
  v_q1_lat INTEGER;
  v_q3_lat INTEGER;
  v_iqr_lat INTEGER;
  v_dist_counts JSONB;
  v_dist_rates JSONB;
  v_flags TEXT[];
  v_is_flagged BOOLEAN;
  v_open_report_id UUID;
  v_new_report_id UUID;
  v_report_desc TEXT;
BEGIN
  -- Temporary table aggregating combined responses per question/item
  CREATE TEMP TABLE IF NOT EXISTS tmp_item_responses (
    q_id UUID,
    q_type TEXT,
    u_id UUID,
    score REAL,
    selected_opt TEXT,
    latency_ms INTEGER
  ) ON COMMIT DROP;

  TRUNCATE tmp_item_responses;

  -- 1. Extract from learning_events
  INSERT INTO tmp_item_responses (q_id, q_type, u_id, score, selected_opt, latency_ms)
  SELECT
    item_id::UUID,
    COALESCE(item_type, 'question'),
    user_id,
    score,
    CASE
      WHEN jsonb_typeof(response) = 'object' THEN response->>'selected'
      WHEN jsonb_typeof(response) = 'string' THEN trim(both '"' from response::text)
      WHEN response IS NOT NULL THEN response::text
      ELSE NULL
    END,
    latency_ms
  FROM public.learning_events
  WHERE score IS NOT NULL
    AND item_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  -- 2. Extract from completed assessment_attempts
  INSERT INTO tmp_item_responses (q_id, q_type, u_id, score, selected_opt, latency_ms)
  SELECT
    kv.key::UUID,
    'question',
    a.user_id,
    CASE WHEN (kv.value = q.correct_answer::TEXT) THEN 1.0::REAL ELSE 0.0::REAL END,
    kv.value,
    CASE
      WHEN a.time_taken_seconds IS NOT NULL AND a.time_taken_seconds > 0 THEN
        GREATEST(500, (a.time_taken_seconds * 1000) / GREATEST(1, (SELECT count(*) FROM jsonb_each_text(a.answers))))
      ELSE NULL
    END
  FROM public.assessment_attempts a
  CROSS JOIN LATERAL jsonb_each_text(a.answers) kv
  JOIN public.assessment_questions q ON q.id = kv.key::UUID
  WHERE a.completed_at IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM tmp_item_responses tir
      WHERE tir.q_id = kv.key::UUID AND tir.u_id = a.user_id
    );

  -- 3. Calculate learner overall mean score (for point-biserial benchmark)
  CREATE TEMP TABLE IF NOT EXISTS tmp_user_ability (
    u_id UUID PRIMARY KEY,
    mean_score REAL
  ) ON COMMIT DROP;

  TRUNCATE tmp_user_ability;

  INSERT INTO tmp_user_ability (u_id, mean_score)
  SELECT u_id, AVG(score)::REAL
  FROM tmp_item_responses
  GROUP BY u_id;

  -- 4. Iterate over items with at least p_min_responses
  FOR v_item IN
    SELECT
      r.q_id,
      r.q_type,
      COUNT(*)::INTEGER AS resp_count,
      COUNT(CASE WHEN r.score >= 0.5 THEN 1 END)::INTEGER AS corr_count,
      AVG(r.score)::REAL AS mean_score
    FROM tmp_item_responses r
    GROUP BY r.q_id, r.q_type
    HAVING COUNT(*) >= p_min_responses
  LOOP
    v_total_evaluated := v_total_evaluated + 1;
    v_flags := ARRAY[]::TEXT[];
    v_is_flagged := false;
    v_p_value := v_item.mean_score;

    -- Point-Biserial Discrimination:
    -- r_pbis = ((mean_correct - mean_total) / stddev_total) * sqrt(p / (1 - p))
    SELECT
      AVG(ua.mean_score)::REAL,
      AVG(CASE WHEN r.score >= 0.5 THEN ua.mean_score END)::REAL,
      NULLIF(stddev_samp(ua.mean_score), 0)::REAL
    INTO v_mean_total, v_mean_correct, v_stddev_total
    FROM tmp_item_responses r
    JOIN tmp_user_ability ua ON ua.u_id = r.u_id
    WHERE r.q_id = v_item.q_id;

    IF v_stddev_total IS NOT NULL AND v_p_value > 0.0 AND v_p_value < 1.0 AND v_mean_correct IS NOT NULL THEN
      v_point_biserial := ((v_mean_correct - v_mean_total) / v_stddev_total) * sqrt(v_p_value / (1.0 - v_p_value));
      v_point_biserial := GREATEST(-1.0, LEAST(1.0, v_point_biserial));
    ELSE
      v_point_biserial := 0.0;
    END IF;

    -- Latency statistics (median, Q1, Q3, IQR)
    SELECT
      percentile_cont(0.50) WITHIN GROUP (ORDER BY r.latency_ms)::INTEGER,
      percentile_cont(0.25) WITHIN GROUP (ORDER BY r.latency_ms)::INTEGER,
      percentile_cont(0.75) WITHIN GROUP (ORDER BY r.latency_ms)::INTEGER
    INTO v_median_lat, v_q1_lat, v_q3_lat
    FROM tmp_item_responses r
    WHERE r.q_id = v_item.q_id AND r.latency_ms IS NOT NULL;

    IF v_q1_lat IS NOT NULL AND v_q3_lat IS NOT NULL THEN
      v_iqr_lat := v_q3_lat - v_q1_lat;
    ELSE
      v_iqr_lat := NULL;
    END IF;

    -- Distractor counts and rates
    SELECT
      jsonb_object_agg(opt, cnt),
      jsonb_object_agg(opt, ROUND((cnt::NUMERIC / v_item.resp_count::NUMERIC), 4))
    INTO v_dist_counts, v_dist_rates
    FROM (
      SELECT
        COALESCE(r.selected_opt, 'unanswered') AS opt,
        COUNT(*)::INTEGER AS cnt
      FROM tmp_item_responses r
      WHERE r.q_id = v_item.q_id
      GROUP BY COALESCE(r.selected_opt, 'unanswered')
    ) dist;

    IF v_dist_counts IS NULL THEN
      v_dist_counts := '{}'::jsonb;
      v_dist_rates := '{}'::jsonb;
    END IF;

    -- Flag Evaluation
    -- 1. Negative discrimination: higher ability learners miss it more often
    IF v_point_biserial < 0.0 AND v_item.resp_count >= 8 THEN
      v_flags := array_append(v_flags, 'negative_discrimination');
      v_is_flagged := true;
    END IF;

    -- 2. Extreme difficulty: p < 0.15 (below chance on 4-option MCQ)
    IF v_p_value < 0.15 AND v_item.resp_count >= 8 THEN
      v_flags := array_append(v_flags, 'extreme_difficulty');
      v_is_flagged := true;
    END IF;

    -- 3. Extreme ease: p > 0.95 (ceiling effect, poor discrimination)
    IF v_p_value > 0.95 AND v_item.resp_count >= 20 THEN
      v_flags := array_append(v_flags, 'extreme_ease');
    END IF;

    -- 4. Dead distractor: an option nobody chooses (< 3% rate when N >= 20)
    IF v_item.resp_count >= 20 AND EXISTS (
      SELECT 1 FROM jsonb_each_text(v_dist_rates)
      WHERE value::REAL < 0.03
    ) THEN
      v_flags := array_append(v_flags, 'dead_distractor');
      v_is_flagged := true;
    END IF;

    -- 5. Suspicious speed / latency outlier
    IF v_median_lat IS NOT NULL AND v_median_lat < 3000 AND v_item.resp_count >= 10 THEN
      v_flags := array_append(v_flags, 'suspicious_low_latency');
    END IF;
    IF v_median_lat IS NOT NULL AND v_median_lat > 180000 AND v_item.resp_count >= 10 THEN
      v_flags := array_append(v_flags, 'high_latency_outlier');
      v_is_flagged := true;
    END IF;

    -- Check for existing open moderation report
    SELECT id INTO v_open_report_id
    FROM public.moderation_reports
    WHERE target_type = 'question'
      AND target_id = v_item.q_id
      AND status IN ('pending', 'under_review')
    LIMIT 1;

    -- Auto-flag into moderation queue if critical defect identified and not already reported
    IF v_is_flagged THEN
      v_flagged_count := v_flagged_count + 1;

      IF v_open_report_id IS NULL THEN
        v_report_desc := '[Item Analytics Auto-Flag] Defects: ' || array_to_string(v_flags, ', ') ||
          '. p-value: ' || ROUND(v_p_value::NUMERIC, 3)::TEXT ||
          ', r_pbis: ' || ROUND(v_point_biserial::NUMERIC, 3)::TEXT ||
          ', N=' || v_item.resp_count::TEXT ||
          ', median latency: ' || COALESCE(v_median_lat::TEXT, 'N/A') || 'ms. ' ||
          'Distractor rates: ' || v_dist_rates::TEXT ||
          '. Requires psychometric content review for miskeying or ambiguity.';

        INSERT INTO public.moderation_reports (
          reporter_id,
          target_type,
          target_id,
          reason,
          description,
          status
        ) VALUES (
          NULL,
          'question',
          v_item.q_id,
          'other',
          v_report_desc,
          'pending'
        ) RETURNING id INTO v_new_report_id;

        v_reports_created := v_reports_created + 1;
        v_open_report_id := v_new_report_id;
      END IF;
    END IF;

    -- Upsert into public.item_analytics
    INSERT INTO public.item_analytics (
      item_id,
      item_type,
      response_count,
      correct_count,
      p_value,
      point_biserial,
      distractor_rates,
      distractor_counts,
      median_latency_ms,
      iqr_latency_ms,
      flagged_reasons,
      auto_flagged,
      moderation_report_id,
      last_calculated_at
    ) VALUES (
      v_item.q_id,
      v_item.q_type,
      v_item.resp_count,
      v_item.corr_count,
      v_p_value,
      v_point_biserial,
      v_dist_rates,
      v_dist_counts,
      v_median_lat,
      v_iqr_lat,
      v_flags,
      v_is_flagged,
      v_open_report_id,
      NOW()
    )
    ON CONFLICT (item_id, item_type) DO UPDATE SET
      response_count = EXCLUDED.response_count,
      correct_count = EXCLUDED.correct_count,
      p_value = EXCLUDED.p_value,
      point_biserial = EXCLUDED.point_biserial,
      distractor_rates = EXCLUDED.distractor_rates,
      distractor_counts = EXCLUDED.distractor_counts,
      median_latency_ms = EXCLUDED.median_latency_ms,
      iqr_latency_ms = EXCLUDED.iqr_latency_ms,
      flagged_reasons = EXCLUDED.flagged_reasons,
      auto_flagged = EXCLUDED.auto_flagged,
      moderation_report_id = COALESCE(EXCLUDED.moderation_report_id, item_analytics.moderation_report_id),
      last_calculated_at = NOW();

  END LOOP;

  RETURN jsonb_build_object(
    'total_evaluated', v_total_evaluated,
    'flagged_items', v_flagged_count,
    'moderation_reports_created', v_reports_created
  );
END;
$$;

REVOKE ALL ON FUNCTION public.compute_item_analytics(INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compute_item_analytics(INTEGER) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 3. GET ITEM ANALYTICS RPC
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_item_analytics(
  p_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_rec RECORD;
BEGIN
  SELECT * INTO v_rec
  FROM public.item_analytics
  WHERE item_id = p_item_id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  RETURN jsonb_build_object(
    'item_id', v_rec.item_id,
    'item_type', v_rec.item_type,
    'response_count', v_rec.response_count,
    'correct_count', v_rec.correct_count,
    'p_value', v_rec.p_value,
    'point_biserial', v_rec.point_biserial,
    'distractor_rates', v_rec.distractor_rates,
    'distractor_counts', v_rec.distractor_counts,
    'median_latency_ms', v_rec.median_latency_ms,
    'iqr_latency_ms', v_rec.iqr_latency_ms,
    'flagged_reasons', v_rec.flagged_reasons,
    'auto_flagged', v_rec.auto_flagged,
    'moderation_report_id', v_rec.moderation_report_id,
    'last_calculated_at', v_rec.last_calculated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_item_analytics(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_item_analytics(UUID) TO authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 4. SERVER-SIDE READINESS V2 WITH FSRS CALIBRATION RPC (FIX-9, ARCH-4)
-- -----------------------------------------------------------------------------
-- Evaluates learner exam readiness for a Learning Target Version without client inFilter
-- query truncation (FIX-9). Synthesizes:
--   1. Authoritative core concept curriculum blueprint coverage
--   2. Projected FSRS retrievability R(t) at target exam date
--   3. Empirical assessment evidence and confidence discounting
-- Returns structured readiness payload with qualitative bands.
CREATE OR REPLACE FUNCTION public.get_target_readiness_v2(
  p_target_version_id UUID,
  p_exam_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id UUID;
  v_target_date TIMESTAMPTZ;
  v_total_core INTEGER := 0;
  v_assessed_count INTEGER := 0;
  v_total_weight NUMERIC := 0.0;
  v_weighted_score_sum NUMERIC := 0.0;
  v_avg_retrievability NUMERIC := 0.0;
  v_retrievability_sum NUMERIC := 0.0;
  v_retrievability_count INTEGER := 0;
  v_final_score NUMERIC := 0.0;
  v_band TEXT;

  v_dist_established INTEGER := 0;
  v_dist_retained INTEGER := 0;
  v_dist_developing INTEGER := 0;
  v_dist_reinforce INTEGER := 0;
  v_dist_unassessed INTEGER := 0;

  v_weakest JSONB := '[]'::jsonb;
  v_row RECORD;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to evaluate readiness' USING ERRCODE = '42501';
  END IF;

  v_target_date := COALESCE(p_exam_date, NOW());

  -- Temporary table of core concepts mapped to this target version
  CREATE TEMP TABLE IF NOT EXISTS tmp_target_core_concepts (
    concept_id UUID PRIMARY KEY,
    concept_title TEXT,
    weight NUMERIC,
    accuracy NUMERIC,
    evidence_count INTEGER,
    retrieval_band TEXT,
    stability DOUBLE PRECISION,
    last_reviewed_at TIMESTAMPTZ,
    projected_retrievability NUMERIC,
    concept_score NUMERIC
  ) ON COMMIT DROP;

  TRUNCATE tmp_target_core_concepts;

  -- 1. Gather all core concepts mapped to curriculum nodes in this target version
  INSERT INTO tmp_target_core_concepts (
    concept_id,
    concept_title,
    weight,
    accuracy,
    evidence_count,
    retrieval_band,
    stability,
    last_reviewed_at,
    projected_retrievability,
    concept_score
  )
  WITH node_core_concepts AS (
    SELECT
      cnc.concept_id AS cid,
      MAX(COALESCE(cnc.weight, 1.0))::NUMERIC AS max_w
    FROM public.curriculum_nodes cn
    JOIN public.curriculum_node_concepts cnc ON cnc.curriculum_node_id = cn.id
    WHERE cn.target_version_id = p_target_version_id
      AND cnc.relevance = 'core'
    GROUP BY cnc.concept_id
  )
  SELECT
    ncc.cid,
    COALESCE(kc.name, kc.slug, 'Concept ' || SUBSTRING(ncc.cid::TEXT FROM 1 FOR 8)),
    ncc.max_w,
    CASE
      WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total)::NUMERIC
      ELSE 0.0
    END,
    COALESCE(ucs.evidence_count, 0),
    COALESCE(ucs.retrieval_band, 'unassessed'),
    ri.stability,
    ri.last_reviewed_at,
    -- Projected FSRS Retrievability at target exam date:
    -- R(Δt, S) = (1 + 19 * (Δt / (9 * S))) ^ (-0.5)
    CASE
      WHEN ri.stability IS NOT NULL AND ri.stability > 0 THEN
        GREATEST(0.0, LEAST(1.0,
          POWER(
            1.0 + 19.0 * (
              GREATEST(0.0, EXTRACT(EPOCH FROM (v_target_date - COALESCE(ri.last_reviewed_at, NOW()))) / 86400.0)
              / (9.0 * ri.stability)
            ),
            -0.5
          )::NUMERIC
        ))
      ELSE NULL
    END,
    0.0 -- Computed below
  FROM node_core_concepts ncc
  LEFT JOIN public.knowledge_concepts kc ON kc.id = ncc.cid
  LEFT JOIN public.user_concept_state ucs ON ucs.concept_id = ncc.cid AND ucs.user_id = v_user_id
  LEFT JOIN LATERAL (
    SELECT r.stability, r.last_reviewed_at
    FROM public.review_items r
    WHERE r.user_id = v_user_id
      AND r.content_id = ncc.cid::TEXT
      AND r.stability IS NOT NULL
    ORDER BY r.last_reviewed_at DESC NULLS LAST
    LIMIT 1
  ) ri ON true;

  -- 2. Compute individual concept readiness scores
  FOR v_row IN SELECT * FROM tmp_target_core_concepts LOOP
    v_total_core := v_total_core + 1;
    v_total_weight := v_total_weight + v_row.weight;

    -- Update band distributions
    CASE v_row.retrieval_band
      WHEN 'well_established' THEN v_dist_established := v_dist_established + 1;
      WHEN 'well_retained' THEN v_dist_retained := v_dist_retained + 1;
      WHEN 'developing' THEN v_dist_developing := v_dist_developing + 1;
      WHEN 'needs_reinforcement' THEN v_dist_reinforce := v_dist_reinforce + 1;
      ELSE v_dist_unassessed := v_dist_unassessed + 1;
    END CASE;

    -- Evidence existence check
    IF v_row.evidence_count > 0 OR v_row.projected_retrievability IS NOT NULL THEN
      v_assessed_count := v_assessed_count + 1;

      -- FSRS-calibrated synthesis:
      -- If card retrievability at exam date is available, blend retrievability (60%) with assessment accuracy (40%).
      -- If only assessment evidence is available, apply evidence confidence discount.
      IF v_row.projected_retrievability IS NOT NULL THEN
        v_retrievability_sum := v_retrievability_sum + v_row.projected_retrievability;
        v_retrievability_count := v_retrievability_count + 1;

        UPDATE tmp_target_core_concepts
        SET concept_score = (0.60 * v_row.projected_retrievability) + (0.40 * v_row.accuracy)
        WHERE concept_id = v_row.concept_id;
      ELSE
        UPDATE tmp_target_core_concepts
        SET concept_score = v_row.accuracy * LEAST(1.0, v_row.evidence_count / 5.0)
        WHERE concept_id = v_row.concept_id;
      END IF;
    END IF;
  END LOOP;

  -- 3. Calculate weighted aggregate readiness score
  IF v_total_weight > 0 THEN
    SELECT COALESCE(SUM(concept_score * weight), 0.0) / v_total_weight
    INTO v_final_score
    FROM tmp_target_core_concepts;
  ELSE
    v_final_score := 0.0;
  END IF;

  IF v_retrievability_count > 0 THEN
    v_avg_retrievability := v_retrievability_sum / v_retrievability_count;
  ELSE
    v_avg_retrievability := 0.0;
  END IF;

  -- 4. Calibrated Qualitative Band Assignment
  -- High confidence: requires both high score and substantial core concept coverage
  IF v_total_core = 0 OR v_assessed_count = 0 OR (v_assessed_count::NUMERIC / GREATEST(1, v_total_core)) < 0.20 THEN
    v_band := 'notYetAssessed';
  ELSIF v_final_score >= 0.85 AND (v_assessed_count::NUMERIC / v_total_core) >= 0.80 THEN
    v_band := 'strongCoverage';
  ELSIF v_final_score >= 0.60 AND (v_assessed_count::NUMERIC / v_total_core) >= 0.40 THEN
    v_band := 'developing';
  ELSE
    v_band := 'needsReinforcement';
  END IF;

  -- 5. Collect up to 5 weakest concepts for focused learner guidance
  SELECT jsonb_agg(
    jsonb_build_object(
      'concept_id', concept_id,
      'title', concept_title,
      'score', ROUND(concept_score, 3),
      'projected_retrievability', CASE WHEN projected_retrievability IS NOT NULL THEN ROUND(projected_retrievability, 3) ELSE NULL END,
      'evidence_count', evidence_count
    )
  ) INTO v_weakest
  FROM (
    SELECT concept_id, concept_title, concept_score, projected_retrievability, evidence_count
    FROM tmp_target_core_concepts
    WHERE evidence_count > 0 OR projected_retrievability IS NOT NULL
    ORDER BY concept_score ASC, weight DESC
    LIMIT 5
  ) w;

  IF v_weakest IS NULL THEN
    v_weakest := '[]'::jsonb;
  END IF;

  RETURN jsonb_build_object(
    'target_version_id', p_target_version_id,
    'exam_date', v_target_date,
    'readiness_score', ROUND(v_final_score, 4),
    'readiness_band', v_band,
    'total_core_concepts', v_total_core,
    'assessed_concepts_count', v_assessed_count,
    'average_retrievability', ROUND(v_avg_retrievability, 4),
    'retrieval_bands', jsonb_build_object(
      'well_established', v_dist_established,
      'well_retained', v_dist_retained,
      'developing', v_dist_developing,
      'needs_reinforcement', v_dist_reinforce,
      'unassessed', v_dist_unassessed
    ),
    'weakest_concepts', v_weakest
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_readiness_v2(UUID, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_v2(UUID, TIMESTAMPTZ) TO authenticated, service_role;
