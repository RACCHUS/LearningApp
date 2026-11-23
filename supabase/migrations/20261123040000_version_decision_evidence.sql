-- Evidence for champion/challenger decisions (master plan v2.6 §7.3:
-- "beats the champion on a defined rubric by a margin (clarity, accuracy,
-- accessibility, evidence of better downstream checks where sample size
-- allows)").
--
-- get_version_decision_candidates: catalog targets (owned by no learner,
-- or flagged official) with a published champion and at least one
-- review-ready challenger: the pairs a decision can be recorded for.
-- get_version_comparison: the same facts for both versions, side by side:
-- what each contains, review evidence recorded on its lessons (signal 3),
-- and, where enough learners used it, how their checks went (signal 4;
-- fewer than 5 accounts are suppressed). A challenger is unpublished, so it
-- has no learner evidence; that is shown as such, never as zero.
-- Admin only. Recording the decision stays record_content_version_decision.

CREATE OR REPLACE FUNCTION public.get_version_decision_candidates()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
             'target_slug', t.slug, 'target_title', t.title,
             'champion_id', ch.id, 'champion_code', ch.version_code,
             'challengers', (SELECT jsonb_agg(jsonb_build_object('id', c.id, 'code', c.version_code)
                                              ORDER BY c.updated_at DESC)
                             FROM public.target_versions c
                             WHERE c.target_id = t.id AND c.status = 'review_ready'))
           ORDER BY t.slug)
    FROM public.learning_targets t
    JOIN LATERAL (SELECT v.id, v.version_code FROM public.target_versions v
                  WHERE v.target_id = t.id AND v.status = 'published'
                  ORDER BY v.updated_at DESC LIMIT 1) ch ON true
    WHERE (t.created_by IS NULL OR t.is_official)
      AND EXISTS (SELECT 1 FROM public.target_versions c
                  WHERE c.target_id = t.id AND c.status = 'review_ready')
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.get_version_decision_candidates() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_version_decision_candidates() TO authenticated;

CREATE OR REPLACE FUNCTION private.version_evidence(p_version_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  WITH ls AS (
    SELECT DISTINCT l.id FROM public.lessons l
    WHERE l.origin_target_version_id = p_version_id
    UNION
    SELECT c.lesson_id FROM public.curriculum_node_lessons c
    JOIN public.curriculum_nodes n ON n.id = c.curriculum_node_id
    WHERE n.target_version_id = p_version_id
  ),
  learners AS (
    SELECT p.user_id, sum(p.questions_answered) AS answered, sum(p.correct_count) AS correct
    FROM public.user_progress p JOIN ls ON ls.id = p.lesson_id
    WHERE p.questions_answered > 0
    GROUP BY p.user_id
  )
  SELECT jsonb_build_object(
    'version_id', v.id, 'version_code', v.version_code, 'status', v.status,
    'lessons', (SELECT count(*) FROM ls),
    'teach_blocks', (SELECT count(*) FROM public.lesson_blocks b JOIN ls ON ls.id = b.lesson_id
                     WHERE b.block_type IN ('markdown','callout','formula','table')),
    'example_blocks', (SELECT count(*) FROM public.lesson_blocks b JOIN ls ON ls.id = b.lesson_id
                       WHERE b.block_type = 'example'
                          OR (b.block_type = 'markdown' AND b.content->>'text' ~ '^\*\*Example')),
    'practice_items', (SELECT count(*) FROM public.lesson_blocks b JOIN ls ON ls.id = b.lesson_id
                       WHERE b.block_type = 'practice_prompt'),
    'check_items', (SELECT count(*) FROM public.assessment_items a JOIN ls ON ls.id = a.lesson_id),
    'review', coalesce((SELECT jsonb_object_agg(x.aspect, jsonb_build_object('ok', x.ok, 'concern', x.concern))
                        FROM (SELECT e.aspect,
                                     count(*) FILTER (WHERE e.outcome = 'ok') AS ok,
                                     count(*) FILTER (WHERE e.outcome = 'concern') AS concern
                              FROM private.content_review_evidence e JOIN ls ON ls.id = e.lesson_id
                              GROUP BY e.aspect) x), '{}'::jsonb),
    'learner_accounts', CASE WHEN (SELECT count(*) FROM learners) >= 5
                             THEN (SELECT count(*) FROM learners) END,
    'check_accuracy', CASE WHEN (SELECT count(*) FROM learners) >= 5
                           THEN (SELECT round(sum(correct)::numeric / nullif(sum(answered), 0), 3) FROM learners) END,
    'learner_evidence', CASE WHEN v.status <> 'published' AND (SELECT count(*) FROM learners) = 0 THEN 'not_published'
                             WHEN (SELECT count(*) FROM learners) < 5 THEN 'too_few_learners'
                             ELSE 'measured' END)
  FROM public.target_versions v WHERE v.id = p_version_id;
$$;
REVOKE ALL ON FUNCTION private.version_evidence(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_version_comparison(p_champion_version_id uuid, p_challenger_version_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.target_versions a JOIN public.target_versions b
                 ON a.target_id = b.target_id AND a.id <> b.id
                 WHERE a.id = p_champion_version_id AND b.id = p_challenger_version_id) THEN
    RAISE EXCEPTION 'Champion and challenger must be two versions of one target' USING ERRCODE = '22023';
  END IF;
  RETURN jsonb_build_object(
    'champion', private.version_evidence(p_champion_version_id),
    'challenger', private.version_evidence(p_challenger_version_id),
    'margin_rule', 'replace on rubric needs challenger total >= champion total + 2 and accuracy not lower');
END;
$$;
REVOKE ALL ON FUNCTION public.get_version_comparison(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_version_comparison(uuid, uuid) TO authenticated;
