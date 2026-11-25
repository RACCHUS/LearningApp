-- Question statistics, made safe and aligned with ingestion plan v1.2 §16.4.
--
-- Before this migration (20261106000000) any signed-in learner could run
-- compute_item_analytics (a heavy job that writes moderation reports) and read
-- every item's statistics, including per-option answer counts, which would
-- reveal held-out answer keys once data exists. Production had no data yet.
--
-- Now:
--   * computing and reading statistics needs an admin or moderator, the
--     service role, or a direct database session (no API claims);
--   * only learners who opted in to product analytics count (honours
--     analytics.product_consents, opt-in);
--   * each learner counts once per item (their first response), so repeats
--     can't swing a statistic;
--   * an item is stored only with 5+ learners (small groups suppressed);
--   * flags follow §16.4 and each opens one revision item in the existing
--     moderation queue (nothing is auto-edited or auto-retired):
--       too_easy                p > 0.95 with 30+ learners
--       too_hard                p < 0.20 with 30+ learners
--       low_discrimination      point-biserial < 0.10 with 30+ learners
--       rarely_chosen_distractor an option chosen < 2% with 50+ learners
--   * latency is still stored but no longer raises flags (not in §16.4).
BEGIN;

CREATE OR REPLACE FUNCTION private.can_read_item_statistics()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT coalesce((SELECT auth.role()), '') = 'service_role'
      OR coalesce(nullif(current_setting('request.jwt.claims', true), ''), '') = ''
      OR private.is_admin()
      OR private.is_moderator();
$$;
REVOKE ALL ON FUNCTION private.can_read_item_statistics() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.can_read_item_statistics() TO authenticated, service_role;

DROP POLICY IF EXISTS item_analytics_select_policy ON public.item_analytics;
CREATE POLICY item_analytics_select_policy ON public.item_analytics
  FOR SELECT TO authenticated, service_role
  USING (private.can_read_item_statistics());

CREATE OR REPLACE FUNCTION public.get_item_analytics(p_item_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_rec record;
BEGIN
  IF NOT private.can_read_item_statistics() THEN
    RAISE EXCEPTION 'Question statistics are for moderators' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_rec FROM public.item_analytics WHERE item_id = p_item_id LIMIT 1;
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
REVOKE ALL ON FUNCTION public.get_item_analytics(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_item_analytics(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.compute_item_analytics(p_min_responses integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  c_min_learners constant integer := greatest(5, coalesce(p_min_responses, 5));
  c_flag_min constant integer := 30;
  c_distractor_min constant integer := 50;
  v_total integer := 0;
  v_flagged integer := 0;
  v_reports integer := 0;
  v_flags text[];
  v_open uuid;
  v_new uuid;
  v_item record;
  v_seen uuid[] := ARRAY[]::uuid[];
BEGIN
  IF NOT private.can_read_item_statistics() THEN
    RAISE EXCEPTION 'Question statistics are for moderators' USING ERRCODE = '42501';
  END IF;

  FOR v_item IN
    WITH consenting AS (
      SELECT pc.user_id FROM analytics.product_consents pc WHERE pc.consented
    ),
    event_responses AS (
      SELECT e.item_id::uuid AS q_id,
             coalesce(e.item_type, 'question') AS q_type,
             e.user_id AS u_id,
             e.score::real AS score,
             CASE
               WHEN jsonb_typeof(e.response) = 'object' THEN e.response->>'selected'
               WHEN jsonb_typeof(e.response) = 'string' THEN e.response #>> '{}'
               WHEN e.response IS NOT NULL THEN e.response::text
             END AS selected_opt,
             e.latency_ms,
             coalesce(e.effective_occurred_at, e.occurred_at, e.created_at) AS at
      FROM public.learning_events e
      JOIN consenting c ON c.user_id = e.user_id
      WHERE e.score IS NOT NULL
        AND e.item_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    ),
    attempt_responses AS (
      SELECT kv.key::uuid AS q_id,
             'question'::text AS q_type,
             a.user_id AS u_id,
             CASE WHEN kv.value = q.correct_answer::text THEN 1.0::real ELSE 0.0::real END AS score,
             kv.value AS selected_opt,
             CASE WHEN a.time_taken_seconds > 0 THEN
               greatest(500, (a.time_taken_seconds * 1000)
                             / greatest(1, (SELECT count(*) FROM jsonb_each_text(a.answers))))
             END::integer AS latency_ms,
             a.completed_at AS at
      FROM public.assessment_attempts a
      JOIN consenting c ON c.user_id = a.user_id
      CROSS JOIN LATERAL jsonb_each_text(a.answers) kv
      JOIN public.assessment_questions q ON q.id = kv.key::uuid
      WHERE a.completed_at IS NOT NULL
    ),
    all_responses AS (
      SELECT * FROM event_responses
      UNION ALL
      SELECT * FROM attempt_responses
    ),
    first_responses AS (
      -- One response per learner per item: their first.
      SELECT DISTINCT ON (r.q_id, r.u_id) r.*
      FROM all_responses r
      ORDER BY r.q_id, r.u_id, r.at NULLS LAST
    ),
    user_ability AS (
      SELECT u_id, avg(score)::real AS mean_score FROM first_responses GROUP BY u_id
    ),
    pairs AS (
      SELECT f.*, ua.mean_score AS user_mean
      FROM first_responses f JOIN user_ability ua ON ua.u_id = f.u_id
    ),
    summaries AS (
      SELECT p.q_id, min(p.q_type) AS q_type,
             count(*)::integer AS n,
             count(*) FILTER (WHERE p.score >= 0.5)::integer AS n_correct,
             avg(p.score)::real AS p_value,
             avg(p.user_mean)::real AS mean_total,
             avg(p.user_mean) FILTER (WHERE p.score >= 0.5)::real AS mean_correct,
             nullif(stddev_samp(p.user_mean), 0)::real AS sd_total,
             percentile_cont(0.50) WITHIN GROUP (ORDER BY p.latency_ms)::integer AS med_latency,
             percentile_cont(0.25) WITHIN GROUP (ORDER BY p.latency_ms)::integer AS q1_latency,
             percentile_cont(0.75) WITHIN GROUP (ORDER BY p.latency_ms)::integer AS q3_latency
      FROM pairs p
      GROUP BY p.q_id
      HAVING count(*) >= c_min_learners
    ),
    option_counts AS (
      SELECT f.q_id, coalesce(f.selected_opt, 'unanswered') AS opt, count(*)::integer AS cnt
      FROM first_responses f JOIN summaries s ON s.q_id = f.q_id
      GROUP BY f.q_id, coalesce(f.selected_opt, 'unanswered')
    ),
    keyed_options AS (
      -- Single-choice assessment items list their options, so an option
      -- nobody chose still counts (as 0); the keyed option is not a distractor.
      SELECT ai.id AS q_id, (g.i - 1)::text AS opt,
             (g.i - 1) = (ai.scoring_spec->>'correct_index')::integer AS keyed
      FROM public.assessment_items ai
      JOIN summaries s ON s.q_id = ai.id
      CROSS JOIN LATERAL generate_series(1, jsonb_array_length(coalesce(ai.response_spec->'options', '[]'::jsonb))) g(i)
      WHERE ai.interaction_type = 'single_choice'
    ),
    distractors AS (
      SELECT s.q_id,
             coalesce(jsonb_object_agg(o.opt, o.cnt) FILTER (WHERE o.opt IS NOT NULL), '{}'::jsonb) AS counts,
             coalesce(jsonb_object_agg(o.opt, round(o.cnt::numeric / s.n, 4)) FILTER (WHERE o.opt IS NOT NULL), '{}'::jsonb) AS rates,
             coalesce(min(o.cnt::numeric / s.n) FILTER (WHERE NOT o.keyed), 1) AS min_distractor_rate
      FROM summaries s
      LEFT JOIN (
        SELECT coalesce(k.q_id, c.q_id) AS q_id, coalesce(k.opt, c.opt) AS opt,
               coalesce(c.cnt, 0) AS cnt, coalesce(k.keyed, false) AS keyed
        FROM keyed_options k
        FULL JOIN option_counts c ON c.q_id = k.q_id AND c.opt = k.opt
      ) o ON o.q_id = s.q_id
      GROUP BY s.q_id
    )
    SELECT s.*,
           CASE
             WHEN s.sd_total IS NOT NULL AND s.p_value > 0 AND s.p_value < 1 AND s.mean_correct IS NOT NULL THEN
               greatest(-1.0, least(1.0, ((s.mean_correct - s.mean_total) / s.sd_total)
                                         * sqrt(s.p_value / (1.0 - s.p_value))))
             ELSE 0.0
           END::real AS r_pbis,
           d.counts, d.rates, d.min_distractor_rate,
           EXISTS (SELECT 1 FROM keyed_options k WHERE k.q_id = s.q_id) AS has_option_list
    FROM summaries s
    JOIN distractors d ON d.q_id = s.q_id
  LOOP
    v_total := v_total + 1;
    v_seen := array_append(v_seen, v_item.q_id);
    v_flags := ARRAY[]::text[];
    IF v_item.n >= c_flag_min AND v_item.p_value > 0.95 THEN
      v_flags := array_append(v_flags, 'too_easy');
    END IF;
    IF v_item.n >= c_flag_min AND v_item.p_value < 0.20 THEN
      v_flags := array_append(v_flags, 'too_hard');
    END IF;
    IF v_item.n >= c_flag_min AND v_item.r_pbis < 0.10 THEN
      v_flags := array_append(v_flags, 'low_discrimination');
    END IF;
    IF v_item.n >= c_distractor_min AND v_item.has_option_list AND v_item.min_distractor_rate < 0.02 THEN
      v_flags := array_append(v_flags, 'rarely_chosen_distractor');
    END IF;

    SELECT id INTO v_open
    FROM public.moderation_reports
    WHERE target_type = 'question' AND target_id = v_item.q_id
      AND status IN ('pending', 'under_review')
    LIMIT 1;

    IF cardinality(v_flags) > 0 THEN
      v_flagged := v_flagged + 1;
      IF v_open IS NULL THEN
        INSERT INTO public.moderation_reports (reporter_id, target_type, target_id, reason, description, status)
        VALUES (NULL, 'question', v_item.q_id, 'other',
          '[Item Analytics Auto-Flag] ' || array_to_string(v_flags, ', ')
          || '. Learners: ' || v_item.n
          || ', p-value: ' || round(v_item.p_value::numeric, 3)
          || ', point-biserial: ' || round(v_item.r_pbis::numeric, 3)
          || ', option rates: ' || v_item.rates::text || '. '
          || CASE WHEN 'low_discrimination' = ANY (v_flags)
                  THEN 'Review the key and distractors; treat it as unreliable for readiness until fixed. ' ELSE '' END
          || CASE WHEN 'too_easy' = ANY (v_flags) OR 'too_hard' = ANY (v_flags)
                  THEN 'Review the key, wording and placement. ' ELSE '' END
          || CASE WHEN 'rarely_chosen_distractor' = ANY (v_flags)
                  THEN 'Rewrite the distractor almost nobody chooses. ' ELSE '' END
          || 'Nothing has been changed automatically (plan §16.4).',
          'pending')
        RETURNING id INTO v_new;
        v_reports := v_reports + 1;
        v_open := v_new;
      END IF;
    END IF;

    INSERT INTO public.item_analytics (
      item_id, item_type, response_count, correct_count, p_value, point_biserial,
      distractor_rates, distractor_counts, median_latency_ms, iqr_latency_ms,
      flagged_reasons, auto_flagged, moderation_report_id, last_calculated_at)
    VALUES (
      v_item.q_id, v_item.q_type, v_item.n, v_item.n_correct, v_item.p_value, v_item.r_pbis,
      v_item.rates, v_item.counts, v_item.med_latency,
      CASE WHEN v_item.q1_latency IS NOT NULL AND v_item.q3_latency IS NOT NULL
           THEN v_item.q3_latency - v_item.q1_latency END,
      v_flags, cardinality(v_flags) > 0,
      CASE WHEN cardinality(v_flags) > 0 THEN v_open END, now())
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
      moderation_report_id = coalesce(EXCLUDED.moderation_report_id, item_analytics.moderation_report_id),
      last_calculated_at = now();
  END LOOP;

  -- Items that no longer meet the rules (fewer than 5 consenting learners,
  -- for example after a consent is withdrawn) keep no statistics.
  DELETE FROM public.item_analytics ia WHERE NOT (ia.item_id = ANY (v_seen));

  RETURN jsonb_build_object(
    'total_evaluated', v_total,
    'flagged_items', v_flagged,
    'moderation_reports_created', v_reports,
    'min_learners', c_min_learners
  );
END;
$$;
REVOKE ALL ON FUNCTION public.compute_item_analytics(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compute_item_analytics(integer) TO authenticated, service_role;

COMMIT;
