-- Migration 82: Secure User XP Progression & Definer Hardening
-- Closes FIX-2: Prohibits direct client tampering with user_xp balances and xp_events.
-- Implements single authenticated, idempotent server-side award operation (record_xp_award)
-- with strict semantic deduplication, daily rate ceiling, and restricts increment_user_xp to service_role.

-- 1. Drop old insecure function signature
DROP FUNCTION IF EXISTS public.increment_user_xp(UUID, INTEGER);

-- 2. Define hardened increment_user_xp function (service_role only for admin/batch awards)
CREATE OR REPLACE FUNCTION public.increment_user_xp(
  p_xp_amount INTEGER,
  p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_auth_uid UUID := (SELECT auth.uid());
  v_target_user_id UUID;
BEGIN
  -- Determine target user: for authenticated callers, must be own uid; for service_role, p_user_id is required
  IF v_auth_uid IS NOT NULL THEN
    IF p_user_id IS NOT NULL AND p_user_id <> v_auth_uid THEN
      RAISE EXCEPTION 'Cannot modify XP for another user';
    END IF;
    v_target_user_id := v_auth_uid;
  ELSE
    IF p_user_id IS NULL THEN
      RAISE EXCEPTION 'Target user_id is required when calling increment_user_xp via service_role';
    END IF;
    v_target_user_id := p_user_id;
  END IF;

  IF p_xp_amount <= 0 OR p_xp_amount > 1000 THEN
    RAISE EXCEPTION 'Invalid XP increment amount (must be 1..1000)';
  END IF;

  INSERT INTO public.user_xp (user_id, total_xp, created_at, updated_at)
  VALUES (v_target_user_id, p_xp_amount, NOW(), NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_xp = user_xp.total_xp + p_xp_amount,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

-- 3. Define transactional, idempotent record_xp_award RPC with semantic deduplication
CREATE OR REPLACE FUNCTION public.record_xp_award(
  p_event_id UUID,
  p_event_type TEXT,
  p_xp_amount INTEGER,
  p_source_id TEXT DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  v_auth_uid UUID := (SELECT auth.uid());
  v_canonical_event_type TEXT;
  v_capped_xp INTEGER;
  v_current_total INTEGER;
  v_new_total INTEGER;
  v_existing_event UUID;
  v_today_xp INTEGER;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Advisory transaction lock to serialize concurrent calls per user
  PERFORM pg_advisory_xact_lock(hashtext(v_auth_uid::text));

  -- 1. Exact UUID Idempotency: if this exact event id was already processed, return current state
  SELECT id INTO v_existing_event
  FROM public.xp_events
  WHERE id = p_event_id AND user_id = v_auth_uid;

  IF v_existing_event IS NOT NULL THEN
    SELECT COALESCE(total_xp, 0) INTO v_current_total
    FROM public.user_xp
    WHERE user_id = v_auth_uid;

    RETURN jsonb_build_object(
      'status', 'already_processed',
      'event_id', p_event_id,
      'awarded_xp', 0,
      'total_xp', v_current_total
    );
  END IF;

  -- 2. Strict event type validation & canonicalization to snake_case (eliminates alias cooldown bypass)
  CASE p_event_type
    WHEN 'questionCorrect', 'question_correct' THEN v_canonical_event_type := 'question_correct';
    WHEN 'lessonComplete', 'lesson_complete' THEN v_canonical_event_type := 'lesson_complete';
    WHEN 'courseComplete', 'course_complete' THEN v_canonical_event_type := 'course_complete';
    WHEN 'reviewSession', 'review_session' THEN v_canonical_event_type := 'review_session';
    WHEN 'streakBonus', 'streak_bonus' THEN v_canonical_event_type := 'streak_bonus';
    WHEN 'achievement' THEN v_canonical_event_type := 'achievement';
    WHEN 'dailyGoal', 'daily_goal' THEN v_canonical_event_type := 'daily_goal';
    ELSE
      RAISE EXCEPTION 'Invalid XP event type: %', p_event_type;
  END CASE;

  IF p_xp_amount <= 0 THEN
    RAISE EXCEPTION 'XP amount must be positive';
  END IF;

  -- Require non-null source_id for event types that rely on source-based deduplication
  IF v_canonical_event_type IN ('achievement', 'lesson_complete', 'course_complete', 'question_correct', 'review_session') THEN
    IF p_source_id IS NULL OR TRIM(p_source_id) = '' THEN
      RAISE EXCEPTION 'source_id is required for event type: %', v_canonical_event_type;
    END IF;
  END IF;

  -- 3. Semantic deduplication:
  -- A. Permanent deduplication for achievements: an achievement can only be claimed once in a lifetime per source_id
  IF p_source_id IS NOT NULL AND v_canonical_event_type = 'achievement' THEN
    SELECT id INTO v_existing_event
    FROM public.xp_events
    WHERE user_id = v_auth_uid
      AND event_type = 'achievement'
      AND source_id = p_source_id;

    IF v_existing_event IS NOT NULL THEN
      SELECT COALESCE(total_xp, 0) INTO v_current_total
      FROM public.user_xp
      WHERE user_id = v_auth_uid;

      RETURN jsonb_build_object(
        'status', 'already_processed',
        'event_id', v_existing_event,
        'awarded_xp', 0,
        'total_xp', v_current_total
      );
    END IF;
  END IF;

  -- B. Lessons and courses: 24-hour cooldown on same source_id
  IF p_source_id IS NOT NULL AND v_canonical_event_type IN ('lesson_complete', 'course_complete') THEN
    SELECT id INTO v_existing_event
    FROM public.xp_events
    WHERE user_id = v_auth_uid
      AND event_type = v_canonical_event_type
      AND source_id = p_source_id
      AND earned_at > NOW() - INTERVAL '24 hours';

    IF v_existing_event IS NOT NULL THEN
      SELECT COALESCE(total_xp, 0) INTO v_current_total
      FROM public.user_xp
      WHERE user_id = v_auth_uid;

      RETURN jsonb_build_object(
        'status', 'already_processed',
        'event_id', v_existing_event,
        'awarded_xp', 0,
        'total_xp', v_current_total
      );
    END IF;
  END IF;

  -- C. Daily goals and streak bonuses: 20-hour cooldown
  IF v_canonical_event_type IN ('daily_goal', 'streak_bonus') THEN
    SELECT id INTO v_existing_event
    FROM public.xp_events
    WHERE user_id = v_auth_uid
      AND event_type = v_canonical_event_type
      AND earned_at > NOW() - INTERVAL '20 hours';

    IF v_existing_event IS NOT NULL THEN
      SELECT COALESCE(total_xp, 0) INTO v_current_total
      FROM public.user_xp
      WHERE user_id = v_auth_uid;

      RETURN jsonb_build_object(
        'status', 'already_processed',
        'event_id', v_existing_event,
        'awarded_xp', 0,
        'total_xp', v_current_total
      );
    END IF;
  END IF;

  -- D. Rapid question and review replay protection: 15-minute cooldown on same source_id
  IF p_source_id IS NOT NULL AND v_canonical_event_type IN ('question_correct', 'review_session') THEN
    SELECT id INTO v_existing_event
    FROM public.xp_events
    WHERE user_id = v_auth_uid
      AND event_type = v_canonical_event_type
      AND source_id = p_source_id
      AND earned_at > NOW() - INTERVAL '15 minutes';

    IF v_existing_event IS NOT NULL THEN
      SELECT COALESCE(total_xp, 0) INTO v_current_total
      FROM public.user_xp
      WHERE user_id = v_auth_uid;

      RETURN jsonb_build_object(
        'status', 'already_processed',
        'event_id', v_existing_event,
        'awarded_xp', 0,
        'total_xp', v_current_total
      );
    END IF;
  END IF;

  -- 4. Daily rate ceiling: max 2000 XP in any rolling 24-hour window
  SELECT COALESCE(SUM(xp_amount), 0) INTO v_today_xp
  FROM public.xp_events
  WHERE user_id = v_auth_uid AND earned_at > NOW() - INTERVAL '24 hours';

  IF v_today_xp >= 2000 THEN
    RAISE EXCEPTION 'Daily XP limit reached (maximum 2000 XP per 24 hours)';
  END IF;

  -- 5. Server-side capping per canonical event type
  CASE v_canonical_event_type
    WHEN 'question_correct' THEN
      v_capped_xp := LEAST(p_xp_amount, 25);
    WHEN 'lesson_complete' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    WHEN 'course_complete' THEN
      v_capped_xp := LEAST(p_xp_amount, 500);
    WHEN 'review_session' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    WHEN 'streak_bonus' THEN
      v_capped_xp := LEAST(p_xp_amount, 150);
    WHEN 'achievement' THEN
      v_capped_xp := LEAST(p_xp_amount, 250);
    WHEN 'daily_goal' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    ELSE
      RAISE EXCEPTION 'Unhandled XP event type: %', v_canonical_event_type;
  END CASE;

  -- Ensure award doesn't breach the daily ceiling
  IF v_today_xp + v_capped_xp > 2000 THEN
    v_capped_xp := 2000 - v_today_xp;
  END IF;

  -- 6. Insert event atomically with canonicalized event type
  INSERT INTO public.xp_events (
    id,
    user_id,
    event_type,
    xp_amount,
    source_id,
    description,
    earned_at
  ) VALUES (
    p_event_id,
    v_auth_uid,
    v_canonical_event_type,
    v_capped_xp,
    p_source_id,
    p_description,
    NOW()
  );

  -- 7. Increment user total XP atomically
  INSERT INTO public.user_xp (user_id, total_xp, created_at, updated_at)
  VALUES (v_auth_uid, v_capped_xp, NOW(), NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_xp = user_xp.total_xp + v_capped_xp,
    updated_at = NOW()
  RETURNING total_xp INTO v_new_total;

  RETURN jsonb_build_object(
    'status', 'awarded',
    'event_id', p_event_id,
    'awarded_xp', v_capped_xp,
    'total_xp', v_new_total
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

-- 4. Function execution permissions
-- increment_user_xp is strictly revoked from public, anon, AND authenticated (service_role only)
REVOKE EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) FROM anon;
REVOKE EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) TO service_role;

-- record_xp_award is granted to authenticated users (asserts auth.uid())
REVOKE EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) TO service_role;

-- 5. Revoke ALL direct client write DML on user_xp and xp_events tables
-- Revoke table-level DML privileges from public, anon, and authenticated
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE public.user_xp FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE public.xp_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.user_xp TO authenticated;
GRANT SELECT ON TABLE public.xp_events TO authenticated;

-- Drop policies from Migration 20250101000002_create_user_xp.sql AND 20260528000000_secure_rls_with_anonymous_guests.sql
DROP POLICY IF EXISTS "user_xp_owner_all" ON public.user_xp;
DROP POLICY IF EXISTS "Users can insert own XP" ON public.user_xp;
DROP POLICY IF EXISTS "Users can update own XP" ON public.user_xp;
DROP POLICY IF EXISTS "Users can delete own XP" ON public.user_xp;

DROP POLICY IF EXISTS "xp_events_owner_all" ON public.xp_events;
DROP POLICY IF EXISTS "Users can insert own XP events" ON public.xp_events;
DROP POLICY IF EXISTS "Users can update own XP events" ON public.xp_events;
DROP POLICY IF EXISTS "Users can delete own XP events" ON public.xp_events;

-- Ensure SELECT policy uses optimized initplan (SELECT auth.uid())
DROP POLICY IF EXISTS "Users can view own XP" ON public.user_xp;
CREATE POLICY "Users can view own XP"
  ON public.user_xp FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view own XP events" ON public.xp_events;
CREATE POLICY "Users can view own XP events"
  ON public.xp_events FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- 6. Backfill historical camelCase event types to canonical snake_case
UPDATE public.xp_events
SET event_type = CASE event_type
  WHEN 'questionCorrect' THEN 'question_correct'
  WHEN 'lessonComplete' THEN 'lesson_complete'
  WHEN 'courseComplete' THEN 'course_complete'
  WHEN 'reviewSession' THEN 'review_session'
  WHEN 'streakBonus' THEN 'streak_bonus'
  WHEN 'dailyGoal' THEN 'daily_goal'
  ELSE event_type
END
WHERE event_type IN ('questionCorrect', 'lessonComplete', 'courseComplete', 'reviewSession', 'streakBonus', 'dailyGoal');
