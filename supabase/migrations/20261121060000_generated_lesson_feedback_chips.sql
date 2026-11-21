-- Learner feedback chips on AI-generated lessons (master plan v2.6
-- §5.7.6, signal 2): "Too hard", "Too easy", "Confusing", "Wrong",
-- "Not what I needed", attached to the lesson version and the prompt-pack
-- version that produced it, aggregated with small-cohort suppression.
--
-- One choice per learner per lesson, changeable or clearable. Only for
-- lessons tagged ai-generated that the learner can read. The pack comes
-- from the lesson's prompt-pack-* tag. Account deletion and lesson
-- deletion remove rows. Switch content.feedback_chips is seeded OFF.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.feedback_chips', 'Feedback chips on generated lessons', 'Content', 'release', false, 'experimental', false,
  'Too hard / Too easy / Confusing / Wrong / Not what I needed on AI-generated lessons, per lesson and prompt-pack version')
ON CONFLICT (feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS private.generated_lesson_feedback (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  chip text NOT NULL
    CHECK (chip IN ('too_hard','too_easy','confusing','wrong','not_what_i_needed')),
  pack_version text NOT NULL CHECK (pack_version ~ '^[a-z0-9][a-z0-9.-]{0,39}$'),
  lesson_version timestamptz NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, lesson_id)
);
CREATE INDEX IF NOT EXISTS generated_lesson_feedback_pack_idx
  ON private.generated_lesson_feedback (pack_version, updated_at DESC);
ALTER TABLE private.generated_lesson_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.generated_lesson_feedback FROM PUBLIC, anon, authenticated;

-- Set, change or clear (p_chip NULL) the learner's chip for a lesson.
CREATE OR REPLACE FUNCTION public.set_generated_lesson_feedback(p_lesson_id uuid, p_chip text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_tags text[];
  v_owner uuid;
  v_visibility text;
  v_updated timestamptz;
  v_pack text;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user required' USING ERRCODE = '42501';
  END IF;
  IF p_chip IS NULL THEN
    DELETE FROM private.generated_lesson_feedback WHERE user_id = v_user AND lesson_id = p_lesson_id;
    RETURN jsonb_build_object('chip', NULL);
  END IF;
  IF NOT private.site_feature_enabled('content.feedback_chips') THEN
    RAISE EXCEPTION 'Feedback chips are off' USING ERRCODE = '42501';
  END IF;
  IF p_chip NOT IN ('too_hard','too_easy','confusing','wrong','not_what_i_needed') THEN
    RAISE EXCEPTION 'Unknown feedback chip' USING ERRCODE = '22023';
  END IF;
  SELECT l.tags, l.user_id, l.visibility, l.updated_at
    INTO v_tags, v_owner, v_visibility, v_updated
  FROM public.lessons l WHERE l.id = p_lesson_id;
  IF NOT FOUND OR (v_owner IS DISTINCT FROM v_user AND v_visibility IS DISTINCT FROM 'public') THEN
    RAISE EXCEPTION 'Lesson not found' USING ERRCODE = '42501';
  END IF;
  IF NOT ('ai-generated' = ANY (coalesce(v_tags, '{}'))) THEN
    RAISE EXCEPTION 'Feedback chips are only for AI-generated lessons' USING ERRCODE = '22023';
  END IF;
  SELECT substring(t FROM 13) INTO v_pack
  FROM unnest(v_tags) t
  WHERE t ~ '^prompt-pack-[a-z0-9][a-z0-9.-]{0,39}$'
  LIMIT 1;
  INSERT INTO private.generated_lesson_feedback (user_id, lesson_id, chip, pack_version, lesson_version, updated_at)
  VALUES (v_user, p_lesson_id, p_chip, coalesce(v_pack, 'unknown'), coalesce(v_updated, now()), now())
  ON CONFLICT (user_id, lesson_id) DO UPDATE
    SET chip = EXCLUDED.chip, pack_version = EXCLUDED.pack_version,
        lesson_version = EXCLUDED.lesson_version, updated_at = now();
  RETURN jsonb_build_object('chip', p_chip);
END;
$$;
REVOKE ALL ON FUNCTION public.set_generated_lesson_feedback(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_generated_lesson_feedback(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_generated_lesson_feedback(p_lesson_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT f.chip FROM private.generated_lesson_feedback f
  WHERE f.user_id = (SELECT auth.uid()) AND f.lesson_id = p_lesson_id;
$$;
REVOKE ALL ON FUNCTION public.get_my_generated_lesson_feedback(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_generated_lesson_feedback(uuid) TO authenticated;

-- Owner report per prompt-pack version: chip counts with sample sizes;
-- packs with fewer than 5 accounts are suppressed.
CREATE OR REPLACE FUNCTION public.get_generated_lesson_feedback_overview(p_days integer DEFAULT 90)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_rows jsonb;
BEGIN
  IF v_user IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (30, 90, 365) THEN
    RAISE EXCEPTION 'Unsupported window' USING ERRCODE = '22023';
  END IF;
  SELECT coalesce(jsonb_agg(g ORDER BY g->>'pack_version'), '[]'::jsonb) INTO v_rows
  FROM (
    SELECT CASE WHEN count(DISTINCT f.user_id) < 5
      THEN jsonb_build_object('pack_version', f.pack_version, 'status', 'small_cohort_suppressed')
      ELSE jsonb_build_object(
        'pack_version', f.pack_version, 'status', 'measured',
        'accounts', count(DISTINCT f.user_id), 'lessons', count(DISTINCT f.lesson_id),
        'too_hard', count(*) FILTER (WHERE f.chip = 'too_hard'),
        'too_easy', count(*) FILTER (WHERE f.chip = 'too_easy'),
        'confusing', count(*) FILTER (WHERE f.chip = 'confusing'),
        'wrong', count(*) FILTER (WHERE f.chip = 'wrong'),
        'not_what_i_needed', count(*) FILTER (WHERE f.chip = 'not_what_i_needed'))
      END AS g
    FROM private.generated_lesson_feedback f
    WHERE f.updated_at >= now() - make_interval(days => p_days)
    GROUP BY f.pack_version
  ) s;
  RETURN jsonb_build_object('window_days', p_days, 'as_of', now(), 'packs', v_rows);
END;
$$;
REVOKE ALL ON FUNCTION public.get_generated_lesson_feedback_overview(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_generated_lesson_feedback_overview(integer) TO authenticated, service_role;
