-- Lesson tags from curriculum manifests.
--
-- ingest_curriculum_manifest stores each lesson's title and description
-- but not its tags, so topic tags such as "percent" or "exponents" (which
-- decide where "Learning help" Bridges are offered) never reached the
-- database. Rather than replace that large function, the ingestion tool
-- calls this one right after --apply, while the version is still a draft.
--
-- Service role only. Draft versions only (published content stays
-- immutable). Tags are lowercase slugs, at most 12 per lesson.

CREATE OR REPLACE FUNCTION public.set_curriculum_lesson_tags(
  p_target_version_id uuid,
  p_lessons jsonb
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_status text;
  v_item jsonb;
  v_tags text[];
  v_updated integer := 0;
  v_rows integer;
BEGIN
  SELECT status INTO v_status FROM public.target_versions WHERE id = p_target_version_id;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Unknown target version' USING ERRCODE = '22023';
  END IF;
  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Lesson tags can only be set on a draft version' USING ERRCODE = '22023';
  END IF;
  IF jsonb_typeof(p_lessons) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lessons) > 500 THEN
    RAISE EXCEPTION 'p_lessons must be an array of at most 500 items' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_lessons) LOOP
    IF jsonb_typeof(v_item->'title') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'tags') IS DISTINCT FROM 'array'
       OR jsonb_array_length(v_item->'tags') > 12
       OR EXISTS (
         SELECT 1 FROM jsonb_array_elements(v_item->'tags') t
         WHERE jsonb_typeof(t) IS DISTINCT FROM 'string'
            OR (t #>> '{}') !~ '^[a-z0-9][a-z0-9.-]{0,39}$'
       ) THEN
      RAISE EXCEPTION 'Each item needs a title and up to 12 lowercase tags' USING ERRCODE = '22023';
    END IF;
    SELECT array_agg(DISTINCT t #>> '{}') INTO v_tags
    FROM jsonb_array_elements(v_item->'tags') t;
    UPDATE public.lessons
      SET tags = coalesce(v_tags, '{}'), updated_at = now()
      WHERE origin_target_version_id = p_target_version_id
        AND title = v_item->>'title';
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 1 THEN
      RAISE EXCEPTION 'Lesson "%" matched % rows in this version', v_item->>'title', v_rows
        USING ERRCODE = '22023';
    END IF;
    v_updated := v_updated + 1;
  END LOOP;

  RETURN jsonb_build_object('updated', v_updated);
END;
$$;
REVOKE ALL ON FUNCTION public.set_curriculum_lesson_tags(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_curriculum_lesson_tags(uuid, jsonb) TO service_role;
