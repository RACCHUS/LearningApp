-- Coverage fill list (master plan v2.6 §4.2 "the matrix feeds ... the
-- generation priority queue" and §6.5 "the maintainer seeding list").
--
-- Every objective of a published curriculum version that is missing a
-- content role (Teach, Example, Practice, Check), ranked by the same
-- reuse-value formula as the Wanted Board:
--
--   priority = max(1, fan_in) * frequency_boost * coverage_deficit / work_units
--
--   fan_in           distinct published targets whose lessons share one of
--                    this objective's topic tags (floors at 1)
--   gap_count        "I need this too" votes on open Wanted needs with one
--                    of those topic tags, counted only from the public
--                    small-cohort floor up (0 below it)
--   frequency_boost  1 + min(1, ln(1 + gap_count) / ln(101))
--   coverage_deficit missing content roles / 4
--   work_units       1 until work is estimated
--
-- Topic tags exclude provenance and level tags (private.is_generic_tag),
-- so "openstax" or "unreviewed" never inflate fan-in. Only published
-- content is read; moderators and admins see every term for auditing.
-- The list orders work; it never publishes, generates or bypasses review.

CREATE OR REPLACE FUNCTION private.is_generic_tag(p_tag text)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT p_tag IS NULL
      OR p_tag IN ('unreviewed', 'ai-generated', 'open-textbook', 'openstax', 'math',
                   'beginner', 'intermediate', 'advanced', 'fundamentals', 'programming')
      OR p_tag ~ '^(cc-|prompt-pack-)';
$$;
REVOKE ALL ON FUNCTION private.is_generic_tag(text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_coverage_fill_list(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;

  RETURN coalesce((
    WITH obj AS (
      SELECT n.id, n.code, n.title, t.slug AS target_slug, t.id AS target_id,
        (SELECT count(*) FROM public.curriculum_node_lessons c JOIN public.lesson_blocks b ON b.lesson_id = c.lesson_id
          WHERE c.curriculum_node_id = n.id AND b.block_type IN ('markdown','callout','formula','table')) AS teach,
        (SELECT count(*) FROM public.curriculum_node_lessons c JOIN public.lesson_blocks b ON b.lesson_id = c.lesson_id
          WHERE c.curriculum_node_id = n.id
            AND (b.block_type = 'example' OR (b.block_type = 'markdown' AND b.content->>'text' ~ '^\*\*Example'))) AS example,
        (SELECT count(*) FROM public.curriculum_node_lessons c JOIN public.lesson_blocks b ON b.lesson_id = c.lesson_id
          WHERE c.curriculum_node_id = n.id AND b.block_type = 'practice_prompt') AS practice,
        (SELECT count(*) FROM public.curriculum_node_lessons c JOIN public.assessment_items a ON a.lesson_id = c.lesson_id
          WHERE c.curriculum_node_id = n.id) AS checks,
        coalesce((SELECT array_agg(DISTINCT tg) FROM public.curriculum_node_lessons c
                  JOIN public.lessons l ON l.id = c.lesson_id
                  CROSS JOIN LATERAL unnest(l.tags) tg
                  WHERE c.curriculum_node_id = n.id AND NOT private.is_generic_tag(tg)), '{}') AS tags
      FROM public.curriculum_nodes n
      JOIN public.target_versions v ON v.id = n.target_version_id AND v.status = 'published'
      JOIN public.learning_targets t ON t.id = v.target_id
      WHERE n.node_type = 'objective'
    ),
    gaps AS (
      SELECT o.*,
        array_remove(ARRAY[
          CASE WHEN o.teach = 0 THEN 'teach' END,
          CASE WHEN o.example = 0 THEN 'example' END,
          CASE WHEN o.practice = 0 THEN 'practice' END,
          CASE WHEN o.checks = 0 THEN 'check' END], NULL) AS missing
      FROM obj o
    ),
    terms AS (
      SELECT g.*,
        greatest(1, (
          SELECT count(DISTINCT v2.target_id)::integer
          FROM public.lessons l2
          JOIN public.target_versions v2 ON v2.id = l2.origin_target_version_id AND v2.status = 'published'
          WHERE l2.tags && g.tags)) AS fan_in,
        (SELECT coalesce(sum(CASE WHEN x.cnt >= private.wanted_vote_floor() THEN x.cnt ELSE 0 END), 0)::integer
         FROM (SELECT count(*) AS cnt FROM public.content_wanted_needs w
               JOIN public.content_wanted_votes vt ON vt.need_id = w.id
               WHERE w.status = 'open' AND w.subject_tag = ANY (g.tags)
               GROUP BY w.id) x) AS gap_count,
        cardinality(g.missing)::numeric / 4 AS coverage_deficit,
        1 AS work_units
      FROM gaps g
      WHERE cardinality(g.missing) > 0
    ),
    scored AS (
      SELECT t.*,
        round(1 + least(1.0, ln(1 + t.gap_count) / ln(101))::numeric, 3) AS frequency_boost,
        round((t.fan_in * (1 + least(1.0, ln(1 + t.gap_count) / ln(101))) * t.coverage_deficit / t.work_units)::numeric, 3) AS priority
      FROM terms t
    )
    SELECT jsonb_agg(jsonb_build_object(
             'target_slug', s.target_slug, 'objective_id', s.id, 'code', s.code, 'title', s.title,
             'missing', to_jsonb(s.missing), 'tags', to_jsonb(s.tags),
             'priority', s.priority, 'fan_in', s.fan_in, 'gap_count', s.gap_count,
             'frequency_boost', s.frequency_boost, 'coverage_deficit', round(s.coverage_deficit, 3),
             'work_units', s.work_units)
           ORDER BY s.priority DESC, s.target_slug, s.code)
    FROM (SELECT * FROM scored ORDER BY priority DESC, target_slug, code
          LIMIT least(greatest(coalesce(p_limit, 100), 1), 500)) s
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.get_coverage_fill_list(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_coverage_fill_list(integer) TO authenticated;
