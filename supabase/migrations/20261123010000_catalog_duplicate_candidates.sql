-- Near-duplicate detection across the published catalog (master plan v2.6
-- §6.4), beyond community contributions.
--
-- Pairs of readable catalog lessons (public, from a published curriculum
-- version or not tied to one), staged and explainable, each with a reason
-- and a confidence:
--   1. same_content    identical normalized text (title + blocks), 1.0
--   2. similar_title   trigram similarity of titles >= 0.6
--   3. similar_content trigram similarity of the text >= 0.5
-- Same-book pairs are flagged (two sections of one book are rarely true
-- duplicates). Moderators can dismiss a pair as "not a duplicate" so it
-- stops appearing. Results are merge suggestions for a person: nothing is
-- merged, hidden or retired here, and different editions, languages or
-- exams are never merged automatically.

CREATE TABLE IF NOT EXISTS private.catalog_duplicate_dismissals (
  lesson_a uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  lesson_b uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  dismissed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  dismissed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (lesson_a, lesson_b),
  CHECK (lesson_a < lesson_b)
);
ALTER TABLE private.catalog_duplicate_dismissals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.catalog_duplicate_dismissals FROM PUBLIC, anon, authenticated;

-- Lowercased title and block text, bounded, for comparison.
CREATE OR REPLACE FUNCTION private.lesson_compare_text(p_lesson_id uuid)
RETURNS text LANGUAGE sql STABLE SET search_path = ''
AS $$
  SELECT lower(left(
    coalesce((SELECT l.title FROM public.lessons l WHERE l.id = p_lesson_id), '') || ' ' ||
    coalesce((SELECT string_agg(coalesce(b.content->>'text', b.content->>'prompt', b.content::text), ' '
                                ORDER BY b.sort_order)
              FROM public.lesson_blocks b WHERE b.lesson_id = p_lesson_id), ''),
    4000));
$$;
REVOKE ALL ON FUNCTION private.lesson_compare_text(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_catalog_duplicate_candidates(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;

  RETURN coalesce((
    WITH catalog AS (
      SELECT l.id, l.title, lower(l.title) AS ltitle, v.target_id,
             t.slug AS target_slug,
             private.lesson_compare_text(l.id) AS body
      FROM public.lessons l
      LEFT JOIN public.target_versions v ON v.id = l.origin_target_version_id
      LEFT JOIN public.learning_targets t ON t.id = v.target_id
      WHERE l.visibility = 'public'
        AND (l.origin_target_version_id IS NULL OR v.status = 'published')
    ),
    pairs AS (
      SELECT a.id AS a_id, a.title AS a_title, a.target_slug AS a_target,
             b.id AS b_id, b.title AS b_title, b.target_slug AS b_target,
             (a.target_id IS NOT NULL AND a.target_id = b.target_id) AS same_book,
             CASE WHEN a.body = b.body AND length(a.body) > 20 THEN 1.0 END AS same_content,
             extensions.similarity(a.ltitle, b.ltitle) AS title_sim,
             extensions.similarity(a.body, b.body) AS body_sim
      FROM catalog a
      JOIN catalog b ON a.id < b.id
      WHERE (a.ltitle OPERATOR(extensions.%) b.ltitle OR a.body = b.body
             OR extensions.similarity(a.body, b.body) >= 0.5)
        AND NOT EXISTS (SELECT 1 FROM private.catalog_duplicate_dismissals d
                        WHERE d.lesson_a = a.id AND d.lesson_b = b.id)
    ),
    scored AS (
      SELECT p.*,
        CASE WHEN p.same_content IS NOT NULL THEN 'same_content'
             WHEN p.title_sim >= 0.6 AND p.title_sim >= p.body_sim THEN 'similar_title'
             WHEN p.body_sim >= 0.5 THEN 'similar_content'
             WHEN p.title_sim >= 0.6 THEN 'similar_title' END AS reason,
        round(greatest(coalesce(p.same_content, 0), p.title_sim, p.body_sim)::numeric, 2) AS confidence
      FROM pairs p
    )
    SELECT jsonb_agg(jsonb_build_object(
             'a_id', s.a_id, 'a_title', s.a_title, 'a_target', s.a_target,
             'b_id', s.b_id, 'b_title', s.b_title, 'b_target', s.b_target,
             'same_book', s.same_book, 'reason', s.reason, 'confidence', s.confidence)
           ORDER BY s.confidence DESC, s.a_title)
    FROM (SELECT * FROM scored WHERE reason IS NOT NULL
          ORDER BY confidence DESC, a_title
          LIMIT least(greatest(coalesce(p_limit, 50), 1), 200)) s
  ), '[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.get_catalog_duplicate_candidates(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_catalog_duplicate_candidates(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.dismiss_catalog_duplicate(p_lesson_a uuid, p_lesson_b uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_lesson_a IS NULL OR p_lesson_b IS NULL OR p_lesson_a = p_lesson_b THEN
    RAISE EXCEPTION 'Two different lessons required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO private.catalog_duplicate_dismissals (lesson_a, lesson_b, dismissed_by)
  VALUES (least(p_lesson_a, p_lesson_b), greatest(p_lesson_a, p_lesson_b), (SELECT auth.uid()))
  ON CONFLICT DO NOTHING;
END;
$$;
REVOKE ALL ON FUNCTION public.dismiss_catalog_duplicate(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_catalog_duplicate(uuid, uuid) TO authenticated;
