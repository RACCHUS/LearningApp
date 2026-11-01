-- Migration 82: Secure User XP Progression & Definer Hardening
-- Closes FIX-2: Prohibits direct client tampering with user_xp balances and xp_events.
-- Implements single authenticated, idempotent server-side award operation (record_xp_award)
-- and hardens increment_user_xp RPC.

-- 1. Drop old insecure function signature
DROP FUNCTION IF EXISTS public.increment_user_xp(UUID, INTEGER);

-- 2. Define hardened increment_user_xp function
CREATE OR REPLACE FUNCTION public.increment_user_xp(
  p_xp_amount INTEGER,
  p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_auth_uid UUID := (SELECT auth.uid());
  v_target_user_id UUID;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_user_id IS NOT NULL AND p_user_id <> v_auth_uid THEN
    RAISE EXCEPTION 'Cannot modify XP for another user';
  END IF;

  IF p_xp_amount <= 0 OR p_xp_amount > 1000 THEN
    RAISE EXCEPTION 'Invalid XP increment amount (must be 1..1000)';
  END IF;

  v_target_user_id := v_auth_uid;

  INSERT INTO public.user_xp (user_id, total_xp, created_at, updated_at)
  VALUES (v_target_user_id, p_xp_amount, NOW(), NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_xp = user_xp.total_xp + p_xp_amount,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

-- 3. Define transactional, idempotent record_xp_award RPC
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
  v_capped_xp INTEGER;
  v_current_total INTEGER;
  v_new_total INTEGER;
  v_existing_event UUID;
BEGIN
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 1. Idempotency guard: if this event id was already processed for this user, return without re-awarding
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

  -- 2. Validate event type and cap XP server-side to prevent tampering
  IF p_xp_amount <= 0 THEN
    RAISE EXCEPTION 'XP amount must be positive';
  END IF;

  CASE p_event_type
    WHEN 'questionCorrect', 'question_correct' THEN
      v_capped_xp := LEAST(p_xp_amount, 25);
    WHEN 'lessonComplete', 'lesson_complete' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    WHEN 'courseComplete', 'course_complete' THEN
      v_capped_xp := LEAST(p_xp_amount, 500);
    WHEN 'reviewSession', 'review_session' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    WHEN 'streakBonus', 'streak_bonus' THEN
      v_capped_xp := LEAST(p_xp_amount, 150);
    WHEN 'achievement' THEN
      v_capped_xp := LEAST(p_xp_amount, 250);
    WHEN 'dailyGoal', 'daily_goal' THEN
      v_capped_xp := LEAST(p_xp_amount, 100);
    ELSE
      v_capped_xp := LEAST(p_xp_amount, 50);
  END CASE;

  -- 3. Insert event in same transaction
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
    p_event_type,
    v_capped_xp,
    p_source_id,
    p_description,
    NOW()
  );

  -- 4. Increment user total XP atomically
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

-- 4. Revoke public/anon execute, grant to authenticated and service_role
REVOKE EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.increment_user_xp(INTEGER, UUID) TO service_role;

REVOKE EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) TO service_role;

-- 5. Revoke direct client write DML on user_xp and xp_events tables
-- Direct client writes are prohibited: awards MUST go through record_xp_award RPC.
DROP POLICY IF EXISTS "Users can insert own XP" ON public.user_xp;
DROP POLICY IF EXISTS "Users can update own XP" ON public.user_xp;
DROP POLICY IF EXISTS "Users can insert own XP events" ON public.xp_events;

-- Ensure SELECT policy uses optimized initplan (SELECT auth.uid())
DROP POLICY IF EXISTS "Users can view own XP" ON public.user_xp;
CREATE POLICY "Users can view own XP"
  ON public.user_xp FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can view own XP events" ON public.xp_events;
CREATE POLICY "Users can view own XP events"
  ON public.xp_events FOR SELECT
  USING ((SELECT auth.uid()) = user_id);
