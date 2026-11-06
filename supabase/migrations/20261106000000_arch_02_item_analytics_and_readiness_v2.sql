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
  v_total_evaluated INTEGER := 0;
  v_flagged_count INTEGER := 0;
  v_reports_created INTEGER := 0;

  v_flags TEXT[];
  v_is_flagged BOOLEAN;
  v_open_report_id UUID;
  v_new_report_id UUID;
  v_report_desc TEXT;
  v_item RECORD;
BEGIN
  FOR v_item IN
    WITH event_responses AS (
      SELECT
        item_id::UUID AS q_id,
        COALESCE(item_type, 'question') AS q_type,
        user_id AS u_id,
        score::REAL AS score,
        CASE
          WHEN jsonb_typeof(response) = 'object' THEN response->>'selected'
          WHEN jsonb_typeof(response) = 'string' THEN trim(both '"' from response::text)
          WHEN response IS NOT NULL THEN response::text
          ELSE NULL
        END AS selected_opt,
        latency_ms
      FROM public.learning_events
      WHERE score IS NOT NULL
        AND item_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ),
    attempt_responses AS (
      SELECT
        kv.key::UUID AS q_id,
        'question'::TEXT AS q_type,
        a.user_id AS u_id,
        CASE WHEN (kv.value = q.correct_answer::TEXT) THEN 1.0::REAL ELSE 0.0::REAL END AS score,
        kv.value AS selected_opt,
        CASE
          WHEN a.time_taken_seconds IS NOT NULL AND a.time_taken_seconds > 0 THEN
            GREATEST(500, (a.time_taken_seconds * 1000) / GREATEST(1, (SELECT count(*) FROM jsonb_each_text(a.answers))))
          ELSE NULL
        END AS latency_ms
      FROM public.assessment_attempts a
      CROSS JOIN LATERAL jsonb_each_text(a.answers) kv
      JOIN public.assessment_questions q ON q.id = kv.key::UUID
      WHERE a.completed_at IS NOT NULL
    ),
    raw_responses AS (
      SELECT * FROM event_responses
      UNION ALL
      SELECT ar.* FROM attempt_responses ar
      WHERE NOT EXISTS (
        SELECT 1 FROM event_responses er
        WHERE er.q_id = ar.q_id AND er.u_id = ar.u_id
      )
    ),
    user_ability AS (
      SELECT u_id, AVG(score)::REAL AS mean_score
      FROM raw_responses
      GROUP BY u_id
    ),
    item_user_pairs AS (
      SELECT
        r.q_id,
        r.q_type,
        r.u_id,
        r.score,
        r.selected_opt,
        r.latency_ms,
        ua.mean_score AS user_mean_score
      FROM raw_responses r
      JOIN user_ability ua ON ua.u_id = r.u_id
    ),
    item_summaries AS (
      SELECT
        iup.q_id,
        iup.q_type,
        COUNT(*)::INTEGER AS resp_count,
        COUNT(CASE WHEN iup.score >= 0.5 THEN 1 END)::INTEGER AS corr_count,
        AVG(iup.score)::REAL AS mean_score,
        AVG(iup.user_mean_score)::REAL AS mean_total,
        AVG(CASE WHEN iup.score >= 0.5 THEN iup.user_mean_score END)::REAL AS mean_correct,
        NULLIF(stddev_samp(iup.user_mean_score), 0)::REAL AS stddev_total,
        percentile_cont(0.50) WITHIN GROUP (ORDER BY iup.latency_ms)::INTEGER AS median_latency_ms,
        percentile_cont(0.25) WITHIN GROUP (ORDER BY iup.latency_ms)::INTEGER AS q1_latency_ms,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY iup.latency_ms)::INTEGER AS q3_latency_ms
      FROM item_user_pairs iup
      GROUP BY iup.q_id, iup.q_type
      HAVING COUNT(*) >= p_min_responses
    ),
    item_distractors AS (
      SELECT
        r.q_id,
        jsonb_object_agg(COALESCE(r.selected_opt, 'unanswered'), r.cnt) AS dist_counts,
        jsonb_object_agg(COALESCE(r.selected_opt, 'unanswered'), ROUND((r.cnt::NUMERIC / s.resp_count::NUMERIC), 4)) AS dist_rates
      FROM (
        SELECT q_id, selected_opt, COUNT(*)::INTEGER AS cnt
        FROM raw_responses
        GROUP BY q_id, selected_opt
      ) r
      JOIN item_summaries s ON s.q_id = r.q_id
      GROUP BY r.q_id
    )
    SELECT
      s.q_id,
      s.q_type,
      s.resp_count,
      s.corr_count,
      s.mean_score AS p_value,
      CASE
        WHEN s.stddev_total IS NOT NULL AND s.mean_score > 0.0 AND s.mean_score < 1.0 AND s.mean_correct IS NOT NULL THEN
          GREATEST(-1.0, LEAST(1.0, ((s.mean_correct - s.mean_total) / s.stddev_total) * sqrt(s.mean_score / (1.0 - s.mean_score))))
        ELSE 0.0
      END::REAL AS point_biserial,
      s.median_latency_ms,
      CASE
        WHEN s.q1_latency_ms IS NOT NULL AND s.q3_latency_ms IS NOT NULL THEN (s.q3_latency_ms - s.q1_latency_ms)
        ELSE NULL
      END AS iqr_latency_ms,
      COALESCE(d.dist_counts, '{}'::jsonb) AS dist_counts,
      COALESCE(d.dist_rates, '{}'::jsonb) AS dist_rates
    FROM item_summaries s
    LEFT JOIN item_distractors d ON d.q_id = s.q_id
  LOOP
    v_total_evaluated := v_total_evaluated + 1;
    v_flags := ARRAY[]::TEXT[];
    v_is_flagged := false;

    -- Flag Evaluation
    -- 1. Negative discrimination: higher ability learners miss it more often
    IF v_item.point_biserial < 0.0 AND v_item.resp_count >= 8 THEN
      v_flags := array_append(v_flags, 'negative_discrimination');
      v_is_flagged := true;
    END IF;

    -- 2. Extreme difficulty: p < 0.15 (below chance on 4-option MCQ)
    IF v_item.p_value < 0.15 AND v_item.resp_count >= 8 THEN
      v_flags := array_append(v_flags, 'extreme_difficulty');
      v_is_flagged := true;
    END IF;

    -- 3. Extreme ease: p > 0.95 (ceiling effect, poor discrimination)
    IF v_item.p_value > 0.95 AND v_item.resp_count >= 20 THEN
      v_flags := array_append(v_flags, 'extreme_ease');
    END IF;

    -- 4. Dead distractor: an option nobody chooses (< 3% rate when N >= 20)
    IF v_item.resp_count >= 20 AND EXISTS (
      SELECT 1 FROM jsonb_each_text(v_item.dist_rates)
      WHERE value::REAL < 0.03
    ) THEN
      v_flags := array_append(v_flags, 'dead_distractor');
      v_is_flagged := true;
    END IF;

    -- 5. Suspicious speed / latency outlier
    IF v_item.median_latency_ms IS NOT NULL AND v_item.median_latency_ms < 3000 AND v_item.resp_count >= 10 THEN
      v_flags := array_append(v_flags, 'suspicious_low_latency');
    END IF;
    IF v_item.median_latency_ms IS NOT NULL AND v_item.median_latency_ms > 180000 AND v_item.resp_count >= 10 THEN
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
          '. p-value: ' || ROUND(v_item.p_value::NUMERIC, 3)::TEXT ||
          ', r_pbis: ' || ROUND(v_item.point_biserial::NUMERIC, 3)::TEXT ||
          ', N=' || v_item.resp_count::TEXT ||
          ', median latency: ' || COALESCE(v_item.median_latency_ms::TEXT, 'N/A') || 'ms. ' ||
          'Distractor rates: ' || v_item.dist_rates::TEXT ||
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
      v_item.p_value,
      v_item.point_biserial,
      v_item.dist_rates,
      v_item.dist_counts,
      v_item.median_latency_ms,
      v_item.iqr_latency_ms,
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
  v_result JSONB;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to evaluate readiness' USING ERRCODE = '42501';
  END IF;

  v_target_date := COALESCE(p_exam_date, NOW());

  WITH node_core_concepts AS (
    SELECT
      cnc.concept_id AS cid,
      MAX(COALESCE(cnc.weight, 1.0))::NUMERIC AS max_w
    FROM public.curriculum_nodes cn
    JOIN public.curriculum_node_concepts cnc ON cnc.curriculum_node_id = cn.id
    WHERE cn.target_version_id = p_target_version_id
      AND cnc.relevance = 'core'
    GROUP BY cnc.concept_id
  ),
  concept_details AS (
    SELECT
      ncc.cid AS concept_id,
      COALESCE(kc.name, kc.slug, 'Concept ' || SUBSTRING(ncc.cid::TEXT FROM 1 FOR 8)) AS concept_title,
      ncc.max_w AS weight,
      CASE
        WHEN ucs.weighted_total > 0 THEN (ucs.weighted_correct / ucs.weighted_total)::NUMERIC
        ELSE 0.0
      END AS accuracy,
      COALESCE(ucs.evidence_count, 0) AS evidence_count,
      COALESCE(ucs.retrieval_band, 'unassessed') AS retrieval_band,
      ri.stability,
      ri.last_reviewed_at,
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
      END AS projected_retrievability
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
    ) ri ON true
  ),
  scored_concepts AS (
    SELECT
      cd.*,
      CASE
        WHEN cd.evidence_count > 0 OR cd.projected_retrievability IS NOT NULL THEN
          CASE
            WHEN cd.projected_retrievability IS NOT NULL THEN
              (0.60 * cd.projected_retrievability) + (0.40 * cd.accuracy)
            ELSE
              cd.accuracy * LEAST(1.0, cd.evidence_count / 5.0)
          END
        ELSE 0.0
      END AS concept_score,
      CASE
        WHEN cd.evidence_count > 0 OR cd.projected_retrievability IS NOT NULL THEN 1
        ELSE 0
      END AS is_assessed
    FROM concept_details cd
  ),
  aggregates AS (
    SELECT
      COUNT(*)::INTEGER AS total_core,
      COALESCE(SUM(is_assessed), 0)::INTEGER AS assessed_count,
      COALESCE(SUM(weight), 0.0)::NUMERIC AS total_weight,
      CASE
        WHEN COALESCE(SUM(weight), 0.0) > 0 THEN
          COALESCE(SUM(concept_score * weight), 0.0) / SUM(weight)
        ELSE 0.0
      END::NUMERIC AS final_score,
      COALESCE(
        AVG(projected_retrievability) FILTER (WHERE projected_retrievability IS NOT NULL),
        0.0
      )::NUMERIC AS avg_retrievability,
      COUNT(*) FILTER (WHERE retrieval_band = 'well_established')::INTEGER AS dist_established,
      COUNT(*) FILTER (WHERE retrieval_band = 'well_retained')::INTEGER AS dist_retained,
      COUNT(*) FILTER (WHERE retrieval_band = 'developing')::INTEGER AS dist_developing,
      COUNT(*) FILTER (WHERE retrieval_band = 'needs_reinforcement')::INTEGER AS dist_reinforce,
      COUNT(*) FILTER (WHERE retrieval_band NOT IN ('well_established', 'well_retained', 'developing', 'needs_reinforcement'))::INTEGER AS dist_unassessed
    FROM scored_concepts
  ),
  weakest AS (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'concept_id', sc.concept_id,
          'title', sc.concept_title,
          'score', ROUND(sc.concept_score, 3),
          'projected_retrievability', CASE WHEN sc.projected_retrievability IS NOT NULL THEN ROUND(sc.projected_retrievability, 3) ELSE NULL END,
          'evidence_count', sc.evidence_count
        )
      ),
      '[]'::jsonb
    ) AS weakest_concepts
    FROM (
      SELECT *
      FROM scored_concepts
      WHERE is_assessed = 1
      ORDER BY concept_score ASC, weight DESC
      LIMIT 5
    ) sc
  )
  SELECT
    jsonb_build_object(
      'target_version_id', p_target_version_id,
      'exam_date', v_target_date,
      'readiness_score', ROUND(agg.final_score, 4),
      'readiness_band', (
        CASE
          WHEN agg.total_core = 0 OR agg.assessed_count = 0 OR (agg.assessed_count::NUMERIC / GREATEST(1, agg.total_core)) < 0.20 THEN
            'notYetAssessed'
          WHEN agg.final_score >= 0.85 AND (agg.assessed_count::NUMERIC / agg.total_core) >= 0.80 THEN
            'strongCoverage'
          WHEN agg.final_score >= 0.60 AND (agg.assessed_count::NUMERIC / agg.total_core) >= 0.40 THEN
            'developing'
          ELSE
            'needsReinforcement'
        END
      ),
      'total_core_concepts', agg.total_core,
      'assessed_concepts_count', agg.assessed_count,
      'average_retrievability', ROUND(agg.avg_retrievability, 4),
      'retrieval_bands', jsonb_build_object(
        'well_established', agg.dist_established,
        'well_retained', agg.dist_retained,
        'developing', agg.dist_developing,
        'needs_reinforcement', agg.dist_reinforce,
        'unassessed', agg.dist_unassessed
      ),
      'weakest_concepts', w.weakest_concepts
    )
  INTO v_result
  FROM aggregates agg
  CROSS JOIN weakest w;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_target_readiness_v2(UUID, TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_v2(UUID, TIMESTAMPTZ) TO authenticated, service_role;
