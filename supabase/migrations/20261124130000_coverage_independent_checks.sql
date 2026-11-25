-- Coverage Matrix: Check means independent checks (ingestion plan v1.2
-- §8.2, slice 8).
--
-- The matrix counted the graded questions inside lessons as the Check role,
-- so a target with only lesson practice showed its checks as covered. Those
-- questions are practice. This version adds, per objective:
--   held_out_items         approved held-out checks (the readiness gate's
--                          sources and rules, minus checks flagged
--                          unreliable while their report is open);
--   graded_practice_items  graded lesson questions (assessment items, the
--                          old check_items, which keeps its value for older
--                          clients, plus lesson questions).
-- The reuse-value priority's deficit now treats Check as missing below 6
-- independent checks and Practice as present when either prompts or graded
-- questions exist. Everything else is unchanged.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_coverage_matrix(p_target_slug text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_version uuid;
  v_rows jsonb;
BEGIN
  SELECT v.id INTO v_version
  FROM public.learning_targets t
  JOIN public.target_versions v ON v.target_id = t.id AND v.status = 'published'
  WHERE t.slug = p_target_slug
  ORDER BY v.updated_at DESC
  LIMIT 1;
  IF v_version IS NULL THEN
    RETURN jsonb_build_object('target_slug', p_target_slug, 'objectives', '[]'::jsonb);
  END IF;

  WITH held AS (
    -- Independent checks for this version: the same sources and rules as
    -- get_target_readiness_coverage (approved, fingerprint-matching, not
    -- flagged unreliable while a report is open).
    SELECT DISTINCT ai.id, ai.lesson_id
    FROM public.assessment_item_reference_validity v
    JOIN public.exam_reference_manifest_revisions mr ON mr.id = v.manifest_revision_id
    JOIN public.assessment_items ai ON ai.id = v.assessment_item_id
    WHERE mr.target_version_id = v_version
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
    WHERE r.target_version_id = v_version
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
  base AS (
    SELECT n.id, n.code, n.title, coalesce(n.sort_order, 0) AS sort,
      count(DISTINCT l.id) AS lessons,
      coalesce((SELECT jsonb_agg(DISTINCT t) FROM public.curriculum_node_lessons c2
                JOIN public.lessons l2 ON l2.id = c2.lesson_id
                CROSS JOIN LATERAL unnest(l2.tags) t
                WHERE c2.curriculum_node_id = n.id), '[]'::jsonb) AS tags,
      coalesce((SELECT array_agg(DISTINCT t) FROM public.curriculum_node_lessons c2
                JOIN public.lessons l2 ON l2.id = c2.lesson_id
                CROSS JOIN LATERAL unnest(l2.tags) t
                WHERE c2.curriculum_node_id = n.id AND NOT private.is_generic_tag(t)), '{}') AS topic_tags,
      bool_or('unreviewed' = ANY (l.tags)) AS unreviewed,
      (SELECT count(*) FROM public.curriculum_node_lessons c3
       JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
       WHERE c3.curriculum_node_id = n.id AND b.block_type IN ('markdown','callout','formula','table')) AS teach_blocks,
      (SELECT count(*) FROM public.curriculum_node_lessons c3
       JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
       WHERE c3.curriculum_node_id = n.id
         AND (b.block_type = 'example'
              -- imported worked examples are reading blocks
              OR (b.block_type = 'markdown' AND b.content->>'text' ~ '^\*\*Example'))) AS example_blocks,
      (SELECT count(*) FROM public.curriculum_node_lessons c3
       JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
       WHERE c3.curriculum_node_id = n.id AND b.block_type = 'practice_prompt') AS practice_items,
      (SELECT count(*) FROM public.curriculum_node_lessons c3
       JOIN public.assessment_items a ON a.lesson_id = c3.lesson_id
       WHERE c3.curriculum_node_id = n.id) AS check_items,
      -- (20261124130000) check_items keeps its meaning (graded questions in
      -- the lessons, i.e. practice); independent checks are counted apart.
      (SELECT count(DISTINCT hl.item_id) FROM held_links hl
       WHERE hl.objective_id = n.id) AS held_out_items,
      (SELECT count(*) FROM public.curriculum_node_lessons c3
       JOIN public.questions q ON q.lesson_id = c3.lesson_id
       WHERE c3.curriculum_node_id = n.id) AS lesson_questions
    FROM public.curriculum_nodes n
    LEFT JOIN public.curriculum_node_lessons c ON c.curriculum_node_id = n.id
    LEFT JOIN public.lessons l ON l.id = c.lesson_id
    WHERE n.target_version_id = v_version AND n.node_type = 'objective'
    GROUP BY n.id
  ),
  terms AS (
    SELECT b.*,
      greatest(1, (SELECT count(DISTINCT v2.target_id)::integer
                   FROM public.lessons l2
                   JOIN public.target_versions v2 ON v2.id = l2.origin_target_version_id AND v2.status = 'published'
                   WHERE l2.tags && b.topic_tags)) AS fan_in,
      (SELECT coalesce(sum(CASE WHEN x.cnt >= private.wanted_vote_floor() THEN x.cnt ELSE 0 END), 0)::integer
       FROM (SELECT count(*) AS cnt FROM public.content_wanted_needs w
             JOIN public.content_wanted_votes vt ON vt.need_id = w.id
             WHERE w.status = 'open' AND w.subject_tag = ANY (b.topic_tags)
             GROUP BY w.id) x) AS gap_count,
      -- Practice counts reveal-the-answer prompts and graded questions;
      -- Check needs at least 6 independent checks (plan v1.2 §8.2, D-14).
      ((b.teach_blocks = 0)::int + (b.example_blocks = 0)::int
        + (b.practice_items + b.check_items + b.lesson_questions = 0)::int + (b.held_out_items < 6)::int)::numeric / 4 AS deficit
    FROM base b
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'objective_id', t.id,
      'code', t.code,
      'title', t.title,
      'sort', t.sort,
      'lessons', t.lessons,
      'tags', t.tags,
      'unreviewed', t.unreviewed,
      'teach_blocks', t.teach_blocks,
      'example_blocks', t.example_blocks,
      'practice_items', t.practice_items,
      'check_items', t.check_items,
      'graded_practice_items', t.check_items + t.lesson_questions,
      'held_out_items', t.held_out_items,
      'fan_in', t.fan_in,
      'gap_count', t.gap_count,
      'priority', round((t.fan_in * (1 + least(1.0, ln(1 + t.gap_count) / ln(101))) * t.deficit)::numeric, 3))
    ORDER BY t.sort, t.title), '[]'::jsonb)
  INTO v_rows
  FROM terms t;

  RETURN jsonb_build_object('target_slug', p_target_slug, 'objectives', v_rows);
END;
$$;

REVOKE ALL ON FUNCTION public.get_coverage_matrix(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_coverage_matrix(text) TO anon, authenticated;

COMMIT;
