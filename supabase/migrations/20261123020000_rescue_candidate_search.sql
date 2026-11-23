-- Rescue candidate search fed by coverage (master plan v2.6 §4.2 "the
-- matrix feeds ... rescue candidate search"; §10.0 no-AI fallback order:
-- Bridge -> other permitted material -> honest unavailability; §10.6
-- eligibleResources(target, ...)).
--
-- For a lesson the caller can read, other readable catalog lessons on the
-- same topic: they share at least one topic tag (provenance and level tags
-- excluded by private.is_generic_tag). Ranked by shared topics, then by
-- coverage (has a worked example, practice, a check), then reviewed before
-- imported. Only published or standalone public lessons are returned, and
-- nothing is revealed about a lesson the caller cannot read. Gated by the
-- same switch as Learning help (learning.quick_rescue).

CREATE OR REPLACE FUNCTION public.find_rescue_candidates(p_lesson_id uuid, p_limit integer DEFAULT 5)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_tags text[];
BEGIN
  IF NOT private.site_feature_enabled('learning.quick_rescue') THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT coalesce(array_agg(DISTINCT t) FILTER (WHERE NOT private.is_generic_tag(t)), '{}')
    INTO v_tags
  FROM public.lessons l
  CROSS JOIN LATERAL unnest(coalesce(l.tags, '{}')) t
  WHERE l.id = p_lesson_id
    AND (l.visibility = 'public' OR l.user_id = (SELECT auth.uid()));
  IF cardinality(v_tags) = 0 THEN
    RETURN '[]'::jsonb;
  END IF;

  RETURN coalesce((
    SELECT jsonb_agg(c ORDER BY (c->>'rank_shared')::int DESC, (c->>'rank_cover')::int DESC,
                                (c->>'reviewed')::boolean DESC, c->>'title')
    FROM (
      SELECT jsonb_build_object(
        'lesson_id', l.id,
        'title', l.title,
        'target_title', tg.title,
        'shared_tags', to_jsonb(ARRAY(SELECT x FROM (SELECT unnest(l.tags) INTERSECT SELECT unnest(v_tags)) i(x) ORDER BY x)),
        'reviewed', NOT ('unreviewed' = ANY (coalesce(l.tags, '{}'))),
        'has_example', ex.n > 0,
        'has_practice', pr.n > 0,
        'has_check', ck.n > 0,
        'rank_shared', cardinality(ARRAY(SELECT unnest(l.tags) INTERSECT SELECT unnest(v_tags))),
        'rank_cover', (ex.n > 0)::int + (pr.n > 0)::int + (ck.n > 0)::int) AS c
      FROM public.lessons l
      LEFT JOIN public.target_versions v ON v.id = l.origin_target_version_id
      LEFT JOIN public.learning_targets tg ON tg.id = v.target_id
      CROSS JOIN LATERAL (SELECT count(*) AS n FROM public.lesson_blocks b WHERE b.lesson_id = l.id
                          AND (b.block_type = 'example'
                               OR (b.block_type = 'markdown' AND b.content->>'text' ~ '^\*\*Example'))) ex
      CROSS JOIN LATERAL (SELECT count(*) AS n FROM public.lesson_blocks b WHERE b.lesson_id = l.id
                          AND b.block_type = 'practice_prompt') pr
      CROSS JOIN LATERAL (SELECT count(*) AS n FROM public.assessment_items a WHERE a.lesson_id = l.id) ck
      WHERE l.id <> p_lesson_id
        AND l.visibility = 'public'
        AND (l.origin_target_version_id IS NULL OR v.status = 'published')
        AND l.tags && v_tags
      ORDER BY cardinality(ARRAY(SELECT unnest(l.tags) INTERSECT SELECT unnest(v_tags))) DESC,
               (ex.n > 0)::int + (pr.n > 0)::int + (ck.n > 0)::int DESC,
               NOT ('unreviewed' = ANY (coalesce(l.tags, '{}'))) DESC, l.title
      LIMIT least(greatest(coalesce(p_limit, 5), 1), 10)
    ) s
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.find_rescue_candidates(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.find_rescue_candidates(uuid, integer) TO anon, authenticated;
