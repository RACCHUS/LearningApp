-- Duplicate and near-duplicate detection without model calls (master plan
-- v2.6 §6.4), for moderators reviewing community contributions.
--
-- Staged and explainable; each candidate carries its reason and a
-- confidence:
--   1. same_snapshot   identical content (same snapshot hash), 1.0
--   2. similar_title   a published lesson or another contribution with a
--                      close title (trigram similarity >= 0.6)
--   3. similar_content another contribution whose title, terms and ideas
--                      read alike (trigram similarity >= 0.5)
-- Earlier versions of the same lesson are not duplicates and are skipped.
-- Results are merge *suggestions* for a person; nothing is merged here.

CREATE OR REPLACE FUNCTION private.contribution_text(p_snapshot jsonb)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = ''
AS $$
  SELECT lower(left(
    coalesce(p_snapshot->>'title', '') || ' ' ||
    coalesce((p_snapshot->'terms')::text, '') || ' ' ||
    coalesce((p_snapshot->'concepts')::text, ''), 4000));
$$;

CREATE OR REPLACE FUNCTION public.contribution_duplicate_candidates(p_contribution_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_title text;
  v_text text;
  v_sha text;
  v_lesson uuid;
  v_rows jsonb;
BEGIN
  IF (SELECT auth.uid()) IS NULL OR NOT private.is_moderator() THEN
    RAISE EXCEPTION 'Moderator authorization required' USING ERRCODE = '42501';
  END IF;
  SELECT lower(coalesce(c.snapshot->>'title', '')), private.contribution_text(c.snapshot),
         c.snapshot_sha256, c.lesson_id
    INTO v_title, v_text, v_sha, v_lesson
  FROM public.content_contributions c WHERE c.id = p_contribution_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown contribution' USING ERRCODE = '22023';
  END IF;

  WITH others AS (
    SELECT c.id, c.lesson_id, coalesce(c.snapshot->>'title', '') AS title,
           c.snapshot_sha256, private.contribution_text(c.snapshot) AS body
    FROM public.content_contributions c
    WHERE c.id <> p_contribution_id
      AND c.status NOT IN ('withdrawn', 'rejected')
      AND (v_lesson IS NULL OR c.lesson_id IS DISTINCT FROM v_lesson)
  ),
  found AS (
    SELECT 'contribution' AS kind, o.id, o.title, 'same_snapshot' AS reason, 1.0::numeric AS confidence
    FROM others o WHERE o.snapshot_sha256 = v_sha
    UNION ALL
    SELECT 'contribution', o.id, o.title, 'similar_title',
           round(extensions.similarity(lower(o.title), v_title)::numeric, 2)
    FROM others o
    WHERE o.snapshot_sha256 <> v_sha AND extensions.similarity(lower(o.title), v_title) >= 0.6
    UNION ALL
    SELECT 'contribution', o.id, o.title, 'similar_content',
           round(extensions.similarity(o.body, v_text)::numeric, 2)
    FROM others o
    WHERE o.snapshot_sha256 <> v_sha AND extensions.similarity(o.body, v_text) >= 0.5
    UNION ALL
    SELECT 'lesson', l.id, l.title, 'similar_title',
           round(extensions.similarity(lower(l.title), v_title)::numeric, 2)
    FROM public.lessons l
    WHERE l.visibility = 'public'
      AND (v_lesson IS NULL OR l.id <> v_lesson)
      AND extensions.similarity(lower(l.title), v_title) >= 0.6
  ),
  best AS (
    -- One row per candidate: its strongest reason.
    SELECT DISTINCT ON (kind, id) kind, id, title, reason, confidence
    FROM found ORDER BY kind, id, confidence DESC
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'kind', kind, 'id', id, 'title', title, 'reason', reason, 'confidence', confidence)
         ORDER BY confidence DESC, title), '[]'::jsonb)
  INTO v_rows
  FROM (SELECT * FROM best ORDER BY confidence DESC, title LIMIT 10) b;
  RETURN v_rows;
END;
$$;
REVOKE ALL ON FUNCTION public.contribution_duplicate_candidates(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.contribution_duplicate_candidates(uuid) TO authenticated;
