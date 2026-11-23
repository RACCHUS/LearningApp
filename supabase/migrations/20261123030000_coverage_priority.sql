-- Reuse-value priority per objective in the Coverage Matrix (master plan
-- v2.6 §6.5: the score orders "the prompt cart, the maintainer seeding
-- list and the Wanted board"; §5.5 M-06 prompt cart: "highest reuse-value
-- first").
--
-- get_coverage_matrix keeps every field it returned and adds, per
-- objective, the same terms as the moderator fill list:
--   fan_in    published targets whose lessons share a topic tag (floor 1)
--   gap_count Wanted votes on those tags, counted only from the public
--             floor up (the board already shows counts at that level)
--   priority  max(1, fan_in) * (1 + min(1, ln(1 + gap_count) / ln(101)))
--             * coverage_deficit, with deficit = missing content roles / 4
-- Only published content and floor-suppressed vote totals are read, so it
-- reveals nothing private.

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

  WITH base AS (
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
       WHERE c3.curriculum_node_id = n.id) AS check_items
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
      ((b.teach_blocks = 0)::int + (b.example_blocks = 0)::int
        + (b.practice_items = 0)::int + (b.check_items = 0)::int)::numeric / 4 AS deficit
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
