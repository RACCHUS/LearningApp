-- XP and achievements (UI_ARCHITECTURE_LOCKED.md §9; Progress §4 and the
-- session summary only).
--
-- * New gate `learning.xp_achievements`, default OFF, not release-ready.
-- * The browser never chooses an XP amount. claim_activity_xp takes only an
--   activity kind and a source id; the server fixes the amount, applies the
--   existing record_xp_award cooldowns, caps and 2000/24h ceiling, and adds
--   per-kind daily claim limits.
-- * XP is self-reported activity, rate-limited. It is a motivation metric and
--   is never presented as evidence of knowledge (§9). Verified assessment XP
--   from submit_assessment_attempt is unchanged.
-- * Achievements are derived on the server from the caller's own xp_events,
--   earned once per lifetime, and carry no XP of their own (one currency).
-- * No direct browser writes to user_achievements. Rows are removed with the
--   auth user (ON DELETE CASCADE).
-- Additive only.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.xp_achievements', 'XP and achievements', 'Learning', 'release', false, 'experimental', false,
  'Server-awarded activity XP and once-only achievements shown in Progress and session summaries')
ON CONFLICT (feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.user_achievements (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_key text NOT NULL CHECK (achievement_key IN (
    'first_lesson', 'lessons_10', 'lessons_50',
    'first_review', 'reviews_25',
    'active_days_7', 'active_days_30'
  )),
  earned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_key)
);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.user_achievements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.user_achievements TO authenticated;
GRANT ALL ON TABLE public.user_achievements TO service_role;

DROP POLICY IF EXISTS "Users can view own achievements" ON public.user_achievements;
CREATE POLICY "Users can view own achievements"
  ON public.user_achievements FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- Evaluates the fixed achievement catalog for one user and inserts any newly
-- met ones. Returns only the keys earned by this call.
CREATE OR REPLACE FUNCTION private.evaluate_user_achievements(p_user_id uuid)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_lessons integer;
  v_reviews integer;
  v_days integer;
  v_met text[] := ARRAY[]::text[];
  v_new text[];
BEGIN
  SELECT count(DISTINCT source_id) INTO v_lessons
    FROM public.xp_events
   WHERE user_id = p_user_id AND event_type = 'lesson_complete';
  SELECT count(*) INTO v_reviews
    FROM public.xp_events
   WHERE user_id = p_user_id AND event_type = 'review_session';
  SELECT count(DISTINCT (earned_at AT TIME ZONE 'UTC')::date) INTO v_days
    FROM public.xp_events
   WHERE user_id = p_user_id;

  IF v_lessons >= 1 THEN v_met := array_append(v_met, 'first_lesson'); END IF;
  IF v_lessons >= 10 THEN v_met := array_append(v_met, 'lessons_10'); END IF;
  IF v_lessons >= 50 THEN v_met := array_append(v_met, 'lessons_50'); END IF;
  IF v_reviews >= 1 THEN v_met := array_append(v_met, 'first_review'); END IF;
  IF v_reviews >= 25 THEN v_met := array_append(v_met, 'reviews_25'); END IF;
  IF v_days >= 7 THEN v_met := array_append(v_met, 'active_days_7'); END IF;
  IF v_days >= 30 THEN v_met := array_append(v_met, 'active_days_30'); END IF;

  WITH inserted AS (
    INSERT INTO public.user_achievements (user_id, achievement_key)
    SELECT p_user_id, k FROM unnest(v_met) AS k
    ON CONFLICT (user_id, achievement_key) DO NOTHING
    RETURNING achievement_key
  )
  SELECT coalesce(array_agg(achievement_key ORDER BY achievement_key), ARRAY[]::text[])
    INTO v_new FROM inserted;
  RETURN v_new;
END;
$$;
REVOKE ALL ON FUNCTION private.evaluate_user_achievements(uuid) FROM PUBLIC, anon, authenticated;

-- The only browser entry point for activity XP.
--   p_kind:      'lesson_complete' (50 XP) or 'review_session' (25 XP)
--   p_source_id: lesson id, or the review session id
-- Returns {status, awarded_xp, total_xp, new_achievements}. status is one of
-- 'awarded', 'already_processed' (cooldown or replay) or 'limit_reached'.
CREATE OR REPLACE FUNCTION public.claim_activity_xp(
  p_event_id uuid,
  p_kind text,
  p_source_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_amount integer;
  v_daily_claims integer;
  v_claims_today integer;
  v_xp_today integer;
  v_total integer;
  v_award jsonb;
  v_new text[];
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING errcode = '42501';
  END IF;
  IF NOT private.site_feature_enabled('learning.xp_achievements') THEN
    RAISE EXCEPTION 'feature_disabled' USING errcode = '42501';
  END IF;
  IF p_event_id IS NULL THEN
    RAISE EXCEPTION 'event_id_required' USING errcode = '22023';
  END IF;
  IF p_source_id IS NULL OR char_length(btrim(p_source_id)) = 0
     OR char_length(p_source_id) > 200 THEN
    RAISE EXCEPTION 'invalid_source_id' USING errcode = '22023';
  END IF;

  CASE p_kind
    WHEN 'lesson_complete' THEN v_amount := 50; v_daily_claims := 20;
    WHEN 'review_session' THEN v_amount := 25; v_daily_claims := 10;
    ELSE RAISE EXCEPTION 'invalid_kind' USING errcode = '22023';
  END CASE;

  -- Same per-user lock record_xp_award takes; transaction locks are re-entrant.
  PERFORM pg_advisory_xact_lock(hashtext(v_uid::text));

  -- Exact replay of this event id: report it, never re-award.
  IF EXISTS (SELECT 1 FROM public.xp_events WHERE id = p_event_id AND user_id = v_uid) THEN
    SELECT coalesce(max(total_xp), 0) INTO v_total FROM public.user_xp WHERE user_id = v_uid;
    RETURN jsonb_build_object('status', 'already_processed', 'awarded_xp', 0,
      'total_xp', v_total, 'new_achievements', '[]'::jsonb);
  END IF;

  SELECT count(*) INTO v_claims_today
    FROM public.xp_events
   WHERE user_id = v_uid AND event_type = p_kind
     AND earned_at > now() - interval '24 hours';
  SELECT coalesce(sum(xp_amount), 0) INTO v_xp_today
    FROM public.xp_events
   WHERE user_id = v_uid AND earned_at > now() - interval '24 hours';

  IF v_claims_today >= v_daily_claims OR v_xp_today >= 2000 THEN
    SELECT coalesce(max(total_xp), 0) INTO v_total FROM public.user_xp WHERE user_id = v_uid;
    RETURN jsonb_build_object('status', 'limit_reached', 'awarded_xp', 0,
      'total_xp', v_total, 'new_achievements', '[]'::jsonb);
  END IF;

  v_award := public.record_xp_award(p_event_id, p_kind, v_amount, p_source_id, NULL);
  v_new := private.evaluate_user_achievements(v_uid);

  RETURN jsonb_build_object(
    'status', v_award->>'status',
    'awarded_xp', coalesce((v_award->>'awarded_xp')::integer, 0),
    'total_xp', coalesce((v_award->>'total_xp')::integer, 0),
    'new_achievements', to_jsonb(v_new)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_activity_xp(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_activity_xp(uuid, text, text) TO authenticated;
