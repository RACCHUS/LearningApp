-- Replacement lookup for lessons whose curriculum version was retired.
--
-- When a corrected import is published with retire_previous, the old
-- version's lessons stop being readable, but learners' saved learning
-- contexts may still point at them. The client asks this function and moves
-- the context to the replacement (same target, same lesson title, in the
-- target's published version), or archives it when there is none.
--
-- Reveals nothing beyond published content: for a lesson that is not from a
-- retired version (or does not exist) it answers retired=false, and the
-- only id it returns is a lesson in a published version.

CREATE OR REPLACE FUNCTION public.lesson_replacement(p_lesson_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_title text;
  v_target uuid;
  v_ids uuid[];
BEGIN
  SELECT l.title, v.target_id INTO v_title, v_target
  FROM public.lessons l
  JOIN public.target_versions v ON v.id = l.origin_target_version_id
  WHERE l.id = p_lesson_id AND v.status = 'retired';

  IF v_target IS NULL THEN
    RETURN jsonb_build_object('retired', false, 'replacement_id', NULL);
  END IF;

  SELECT array_agg(l.id) INTO v_ids
  FROM public.lessons l
  JOIN public.target_versions v ON v.id = l.origin_target_version_id
  WHERE v.target_id = v_target
    AND v.status = 'published'
    AND l.visibility = 'public'
    AND l.title = v_title;

  -- Only an unambiguous match counts; otherwise the client archives.
  RETURN jsonb_build_object(
    'retired', true,
    'replacement_id', CASE WHEN cardinality(v_ids) = 1 THEN v_ids[1] END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.lesson_replacement(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.lesson_replacement(uuid) TO anon, authenticated;
