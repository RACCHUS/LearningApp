-- Coverage Matrix source data (master plan v2.6 §4.2).
--
-- A derived, read-only view, not a new source of truth: for each
-- objective of a target's published version, the counts the client needs
-- to fill the Teach / Example / Practice / Check cells and whether the
-- content is reviewed or imported-and-unreviewed. Bridge and outside
-- resource cells come from the bundled Bridge and companion libraries on
-- the client; Access stays "not verified" until there is evidence.
-- Only published content is counted, so it reveals nothing private.

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

  SELECT coalesce(jsonb_agg(row ORDER BY (row->>'sort')::int, row->>'title'), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT jsonb_build_object(
      'objective_id', n.id,
      'code', n.code,
      'title', n.title,
      'sort', coalesce(n.sort_order, 0),
      'lessons', count(DISTINCT l.id),
      'tags', coalesce((SELECT jsonb_agg(DISTINCT t) FROM public.curriculum_node_lessons c2
                        JOIN public.lessons l2 ON l2.id = c2.lesson_id
                        CROSS JOIN LATERAL unnest(l2.tags) t
                        WHERE c2.curriculum_node_id = n.id), '[]'::jsonb),
      'unreviewed', bool_or('unreviewed' = ANY (l.tags)),
      'teach_blocks', (SELECT count(*) FROM public.curriculum_node_lessons c3
                       JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
                       WHERE c3.curriculum_node_id = n.id AND b.block_type IN ('markdown','callout','formula','table')),
      'example_blocks', (SELECT count(*) FROM public.curriculum_node_lessons c3
                         JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
                         WHERE c3.curriculum_node_id = n.id
                           AND (b.block_type = 'example'
                                -- imported worked examples are reading blocks
                                OR (b.block_type = 'markdown' AND b.content->>'text' ~ '^\*\*Example'))),
      'practice_items', (SELECT count(*) FROM public.curriculum_node_lessons c3
                         JOIN public.lesson_blocks b ON b.lesson_id = c3.lesson_id
                         WHERE c3.curriculum_node_id = n.id AND b.block_type = 'practice_prompt'),
      'check_items', (SELECT count(*) FROM public.curriculum_node_lessons c3
                      JOIN public.assessment_items a ON a.lesson_id = c3.lesson_id
                      WHERE c3.curriculum_node_id = n.id)
    ) AS row
    FROM public.curriculum_nodes n
    LEFT JOIN public.curriculum_node_lessons c ON c.curriculum_node_id = n.id
    LEFT JOIN public.lessons l ON l.id = c.lesson_id
    WHERE n.target_version_id = v_version AND n.node_type = 'objective'
    GROUP BY n.id
  ) s;

  RETURN jsonb_build_object('target_slug', p_target_slug, 'objectives', v_rows);
END;
$$;
REVOKE ALL ON FUNCTION public.get_coverage_matrix(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_coverage_matrix(text) TO anon, authenticated;
