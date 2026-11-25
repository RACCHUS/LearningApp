-- Consented response feed for question statistics, and readiness that
-- ignores unreliable checks (ingestion plan v1.2 §16.4, slice 12 part 2).
--
-- Server grading (grade_assessment_items) is read-only and recorded nothing,
-- so graded lesson and held-out answers never reached the statistics.
--
--   * private.item_response_log keeps ONE row per learner per item: their
--     first graded answer (score, and the option for single-choice items).
--     Only signed-in learners who opted in to product analytics are recorded;
--     no learner can read the log. Rows are deleted when consent is withdrawn
--     and when the account is deleted.
--   * grade_and_record_assessment_items grades exactly like
--     grade_assessment_items (it calls it) and returns the same result; it
--     records only for consenting learners. Guests and others are only graded.
--   * compute_item_analytics also reads the log.
--   * A held-out check flagged low_discrimination whose moderation report is
--     still open stops counting toward readiness coverage and readiness by
--     objective ("pull the item from readiness until fixed"). Nothing is
--     edited or retired: closing the report makes it count again.
BEGIN;

CREATE TABLE IF NOT EXISTS private.item_response_log (
  item_id uuid NOT NULL REFERENCES public.assessment_items(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score numeric NOT NULL CHECK (score >= 0 AND score <= 1),
  selected text CHECK (selected IS NULL OR selected ~ '^[0-9]{1,3}$'),
  responded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (item_id, user_id)
);
CREATE INDEX IF NOT EXISTS item_response_log_user_idx ON private.item_response_log (user_id);
ALTER TABLE private.item_response_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.item_response_log FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE private.item_response_log TO service_role;

CREATE OR REPLACE FUNCTION private.forget_item_responses_on_consent_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM private.item_response_log WHERE user_id = OLD.user_id;
    RETURN OLD;
  END IF;
  IF NOT NEW.consented THEN
    DELETE FROM private.item_response_log WHERE user_id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.forget_item_responses_on_consent_change() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_forget_item_responses ON analytics.product_consents;
CREATE TRIGGER trg_forget_item_responses
  AFTER UPDATE OF consented OR DELETE ON analytics.product_consents
  FOR EACH ROW EXECUTE FUNCTION private.forget_item_responses_on_consent_change();

CREATE OR REPLACE FUNCTION public.grade_and_record_assessment_items(p_responses jsonb)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
  v_results jsonb;
BEGIN
  v_results := public.grade_assessment_items(p_responses);
  IF v_uid IS NOT NULL AND EXISTS (
    SELECT 1 FROM analytics.product_consents pc WHERE pc.user_id = v_uid AND pc.consented
  ) THEN
    INSERT INTO private.item_response_log (item_id, user_id, score, selected)
    SELECT DISTINCT ON (ai.id) ai.id, v_uid,
           greatest(0, least(1, (r.value->>'score')::numeric)),
           CASE WHEN ai.interaction_type = 'single_choice'
                 AND (req.value->'response') #>> '{}' ~ '^\s*[0-9]{1,3}\s*$'
                THEN btrim((req.value->'response') #>> '{}') END
    FROM jsonb_array_elements(v_results) r
    JOIN public.assessment_items ai ON ai.id::text = r.value->>'item_id'
    JOIN LATERAL (
      SELECT q.value FROM jsonb_array_elements(p_responses) q
      WHERE q.value->>'item_id' = r.value->>'item_id' LIMIT 1
    ) req ON true
    WHERE r.value->>'error' IS NULL
      AND jsonb_typeof(r.value->'score') = 'number'
    ON CONFLICT (item_id, user_id) DO NOTHING;
  END IF;
  RETURN v_results;
END;
$$;
REVOKE ALL ON FUNCTION public.grade_and_record_assessment_items(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.grade_and_record_assessment_items(jsonb) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.held_out_item_unreliable(p_item_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.item_analytics ia
    JOIN public.moderation_reports mr ON mr.id = ia.moderation_report_id
    WHERE ia.item_id = p_item_id
      AND 'low_discrimination' = ANY (ia.flagged_reasons)
      AND mr.status IN ('pending', 'under_review')
  );
$$;
REVOKE ALL ON FUNCTION private.held_out_item_unreliable(uuid) FROM PUBLIC, anon, authenticated;

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
    log_responses AS (
      -- First graded answers recorded by grade_and_record_assessment_items
      -- (20261124120000); consenting learners only.
      SELECT l.item_id AS q_id, 'question'::text AS q_type, l.user_id AS u_id,
             l.score::real AS score, l.selected AS selected_opt,
             NULL::integer AS latency_ms, l.responded_at AS at
      FROM private.item_response_log l
      JOIN consenting c ON c.user_id = l.user_id
    ),
    all_responses AS (
      SELECT * FROM event_responses
      UNION ALL
      SELECT * FROM attempt_responses
      UNION ALL
      SELECT * FROM log_responses
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
      AND NOT private.held_out_item_unreliable(ai.id)
    UNION
    -- General held-out items (20261124020000): an approved review whose
    -- fingerprint still matches the live item.
    SELECT ai.id, ai.lesson_id
    FROM private.held_out_item_reviews r
    JOIN public.assessment_items ai ON ai.id = r.assessment_item_id
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(ai.id)
      AND NOT private.held_out_item_unreliable(ai.id)
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
      AND NOT private.held_out_item_unreliable(ai.id)
    UNION
    SELECT r.assessment_item_id, r.reviewer_kind
    FROM private.held_out_item_reviews r
    WHERE r.target_version_id = p_target_version_id
      AND r.review_status = 'approved'
      AND r.item_content_sha256 = public.exam_reference_item_fingerprint(r.assessment_item_id)
      AND NOT private.held_out_item_unreliable(r.assessment_item_id)
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

REVOKE ALL ON FUNCTION public.compute_item_analytics(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.compute_item_analytics(integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_target_readiness_coverage(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_target_readiness_coverage(uuid) TO anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.get_target_objective_readiness(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_target_objective_readiness(uuid) TO anon, authenticated, service_role;

COMMIT;
