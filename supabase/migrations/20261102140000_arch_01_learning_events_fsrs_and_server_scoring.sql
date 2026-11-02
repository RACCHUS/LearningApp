-- ============================================================================
-- Architecture Phase 1: Learning Events, FSRS Projections & Server-Side Scoring
-- Migration: 20261102140000_arch_01_learning_events_fsrs_and_server_scoring.sql
-- ============================================================================

-- 1. LEARNING EVENTS TABLE (ARCH-1, ARCH-3, FIX-2)
-- Append-only event log for all learner interactions (reviews, questions, lessons).
CREATE TABLE IF NOT EXISTS public.learning_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  event_type TEXT NOT NULL,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  item_version TEXT,
  context_id TEXT,
  session_id TEXT,
  rating SMALLINT, -- 1=Again, 2=Hard, 3=Good, 4=Easy
  score REAL,      -- 0.0 to 1.0
  response JSONB,
  presented_order SMALLINT[],
  latency_ms INTEGER,
  hints_used SMALLINT DEFAULT 0,
  confidence SMALLINT, -- 1=low, 2=med, 3=high
  scheduler_state_before JSONB,
  scheduler_state_after JSONB,
  metadata JSONB DEFAULT '{}'::jsonb,
  app_version TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_learning_events_user_occurred ON public.learning_events(user_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_learning_events_item ON public.learning_events(item_id, event_type);
CREATE INDEX IF NOT EXISTS idx_learning_events_context ON public.learning_events(user_id, context_id);

ALTER TABLE public.learning_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS learning_events_select_own ON public.learning_events;
CREATE POLICY learning_events_select_own ON public.learning_events
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS learning_events_insert_own ON public.learning_events;
CREATE POLICY learning_events_insert_own ON public.learning_events
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

-- Revoke blanket privileges; grant strictly necessary PostgREST Data API access
REVOKE ALL ON public.learning_events FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.learning_events TO authenticated;
GRANT ALL ON public.learning_events TO service_role;

-- 2. FSRS ATTRIBUTES ON REVIEW ITEMS (ARCH-1)
ALTER TABLE public.review_items
  ADD COLUMN IF NOT EXISTS stability DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS difficulty DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS fsrs_state SMALLINT DEFAULT 1,
  ADD COLUMN IF NOT EXISTS retrievability DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS step SMALLINT DEFAULT 0;

-- 3. CLOSE DIRECT READ OF PROTECTED ANSWER DATA (FIX-12)
-- A. assessment_items (scoring_spec contains answer keys and rubrics)
REVOKE ALL ON public.assessment_items FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, lesson_id, stimulus_id, interaction_type, prompt, response_spec,
  difficulty, cognitive_level, metadata, user_id, origin_target_version_id,
  created_at, updated_at
) ON public.assessment_items TO anon, authenticated;
GRANT ALL ON public.assessment_items TO service_role;

-- B. assessment_questions (correct_answer and explanation contain answer keys)
REVOKE ALL ON public.assessment_questions FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id, assessment_id, question_text, options, order_index, created_at
) ON public.assessment_questions TO anon, authenticated;
GRANT ALL ON public.assessment_questions TO service_role;

-- 4. RECORD_EVENTS TRANSACTIONAL RPC (ARCH-1, ARCH-3, FIX-2, FIX-4)
-- Atomically logs append-only events and updates review projections idempotently.
CREATE OR REPLACE FUNCTION public.record_events(
  p_events JSONB[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_auth_uid UUID;
  v_event JSONB;
  v_event_id UUID;
  v_occurred_at TIMESTAMPTZ;
  v_event_type TEXT;
  v_item_type TEXT;
  v_item_id TEXT;
  v_item_version TEXT;
  v_context_id TEXT;
  v_session_id TEXT;
  v_rating SMALLINT;
  v_score REAL;
  v_response JSONB;
  v_presented_order SMALLINT[];
  v_latency_ms INTEGER;
  v_hints_used SMALLINT;
  v_confidence SMALLINT;
  v_sched_before JSONB;
  v_sched_after JSONB;
  v_metadata JSONB;
  v_app_version TEXT;
  v_processed_count INTEGER := 0;
  v_inserted BOOLEAN := FALSE;
BEGIN
  v_auth_uid := (SELECT auth.uid());
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to record events';
  END IF;

  FOREACH v_event IN ARRAY p_events LOOP
    v_event_id := COALESCE((v_event->>'id')::UUID, gen_random_uuid());
    v_occurred_at := COALESCE((v_event->>'occurred_at')::TIMESTAMPTZ, NOW());
    v_event_type := LOWER(TRIM(COALESCE(v_event->>'event_type', '')));
    v_item_type := LOWER(TRIM(COALESCE(v_event->>'item_type', 'unknown')));
    v_item_id := TRIM(COALESCE(v_event->>'item_id', ''));
    v_item_version := v_event->>'item_version';
    v_context_id := v_event->>'context_id';
    v_session_id := v_event->>'session_id';
    v_rating := (v_event->>'rating')::SMALLINT;
    v_score := (v_event->>'score')::REAL;
    v_response := v_event->'response';
    v_latency_ms := (v_event->>'latency_ms')::INTEGER;
    v_hints_used := COALESCE((v_event->>'hints_used')::SMALLINT, 0);
    v_confidence := (v_event->>'confidence')::SMALLINT;
    v_sched_before := v_event->'scheduler_state_before';
    v_sched_after := v_event->'scheduler_state_after';
    v_metadata := COALESCE(v_event->'metadata', '{}'::JSONB);
    v_app_version := v_event->>'app_version';

    -- Parse presented_order array
    IF v_event->'presented_order' IS NOT NULL AND jsonb_typeof(v_event->'presented_order') = 'array' THEN
      SELECT array_agg(elem::SMALLINT)
      INTO v_presented_order
      FROM jsonb_array_elements_text(v_event->'presented_order') AS elem;
    ELSE
      v_presented_order := NULL;
    END IF;

    IF v_item_id = '' THEN
      CONTINUE; -- skip invalid event
    END IF;

    -- 1. Insert into learning_events (idempotent via ON CONFLICT DO NOTHING)
    v_inserted := FALSE;
    INSERT INTO public.learning_events (
      id, user_id, occurred_at, event_type, item_type, item_id, item_version,
      context_id, session_id, rating, score, response, presented_order,
      latency_ms, hints_used, confidence, scheduler_state_before,
      scheduler_state_after, metadata, app_version
    ) VALUES (
      v_event_id, v_auth_uid, v_occurred_at, v_event_type, v_item_type, v_item_id, v_item_version,
      v_context_id, v_session_id, v_rating, v_score, v_response, v_presented_order,
      v_latency_ms, v_hints_used, v_confidence, v_sched_before,
      v_sched_after, v_metadata, v_app_version
    ) ON CONFLICT (id) DO NOTHING
    RETURNING TRUE INTO v_inserted;

    v_processed_count := v_processed_count + 1;

    -- 2. Update review_items projection ONLY if the event was newly inserted (prevent replay duplication)
    IF v_inserted IS TRUE AND v_event_type = 'review' AND v_sched_after IS NOT NULL THEN
      UPDATE public.review_items SET
        last_reviewed_at = v_occurred_at,
        next_review_date = COALESCE(
          (v_sched_after->>'due')::TIMESTAMPTZ,
          (v_sched_after->>'next_review_date')::TIMESTAMPTZ,
          NOW() + INTERVAL '1 day'
        ),
        stability = (v_sched_after->>'stability')::DOUBLE PRECISION,
        difficulty = (v_sched_after->>'difficulty')::DOUBLE PRECISION,
        fsrs_state = COALESCE((v_sched_after->>'state')::SMALLINT, fsrs_state),
        step = COALESCE((v_sched_after->>'step')::SMALLINT, step),
        repetition_level = COALESCE((v_sched_after->>'repetition_level')::INTEGER, repetition_level),
        ease_factor = COALESCE((v_sched_after->>'ease_factor')::DECIMAL(3,2), ease_factor),
        total_reviews = COALESCE((v_sched_after->>'total_reviews')::INTEGER, total_reviews + 1),
        correct_reviews = COALESCE((v_sched_after->>'correct_reviews')::INTEGER, correct_reviews),
        updated_at = NOW()
      WHERE user_id = v_auth_uid AND (id::TEXT = v_item_id OR content_id = v_item_id);
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'success',
    'processed_count', v_processed_count
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_events(JSONB[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_events(JSONB[]) TO authenticated;

-- 5. SANITIZED ASSESSMENT QUESTIONS RPC (ARCH-1, FIX-12)
-- Returns assessment questions WITHOUT exposing correct_answer or explanation
CREATE OR REPLACE FUNCTION public.get_assessment_questions_for_taking(
  p_assessment_id UUID
)
RETURNS TABLE (
  id UUID,
  assessment_id UUID,
  question_text TEXT,
  options JSONB,
  order_index INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, extensions
STABLE
AS $$
  SELECT
    q.id,
    q.assessment_id,
    q.question_text,
    q.options,
    q.order_index
  FROM public.assessment_questions q
  JOIN public.skill_assessments sa ON sa.id = q.assessment_id
  WHERE q.assessment_id = p_assessment_id
    AND sa.is_active = TRUE
  ORDER BY q.order_index ASC, q.created_at ASC;
$$;

REVOKE ALL ON FUNCTION public.get_assessment_questions_for_taking(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_assessment_questions_for_taking(UUID) TO anon, authenticated;

-- 6. SERVER-SIDE ASSESSMENT ATTEMPT SUBMISSION & GRADING RPC (ARCH-1, FIX-12)
-- Evaluates submitted answers against actual correct answers on the server,
-- computes final score, records attempt with is_verified = TRUE, and recomputes stats.
CREATE OR REPLACE FUNCTION public.submit_and_grade_assessment(
  p_assessment_id UUID,
  p_answers JSONB,
  p_attempt_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id UUID;
  v_assessment public.skill_assessments%ROWTYPE;
  v_attempt public.assessment_attempts%ROWTYPE;
  v_attempt_id UUID;
  v_started_at TIMESTAMPTZ;
  v_time_spent_seconds INTEGER := 0;
  v_is_overtime BOOLEAN := FALSE;
  v_q RECORD;
  v_user_answer INTEGER;
  v_is_correct BOOLEAN;
  v_correct_count INTEGER := 0;
  v_total_questions INTEGER := 0;
  v_score INTEGER := 0;
  v_passed BOOLEAN := FALSE;
  v_prev_level INTEGER := 0;
  v_new_level INTEGER := 0;
  v_question_results JSONB := '[]'::JSONB;
  v_xp_awarded INTEGER := 0;
  v_xp_res JSONB;
BEGIN
  v_user_id := (SELECT auth.uid());
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to submit assessment';
  END IF;

  -- 1. Fetch and validate assessment
  SELECT * INTO v_assessment
  FROM public.skill_assessments
  WHERE id = p_assessment_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active assessment not found: %', p_assessment_id;
  END IF;

  -- 2. Validate or initialize attempt
  IF p_attempt_id IS NOT NULL THEN
    SELECT * INTO v_attempt
    FROM public.assessment_attempts
    WHERE id = p_attempt_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Assessment attempt not found: %', p_attempt_id;
    END IF;

    IF v_attempt.user_id <> v_user_id THEN
      RAISE EXCEPTION 'Attempt does not belong to authenticated user'
        USING ERRCODE = '42501';
    END IF;

    IF v_attempt.assessment_id <> p_assessment_id THEN
      RAISE EXCEPTION 'Attempt assessment ID mismatch: expected %, got %', p_assessment_id, v_attempt.assessment_id;
    END IF;

    IF v_attempt.completed_at IS NOT NULL THEN
      RAISE EXCEPTION 'Assessment attempt already completed: %', p_attempt_id;
    END IF;

    v_attempt_id := p_attempt_id;
    v_started_at := COALESCE(v_attempt.started_at, NOW());
    v_time_spent_seconds := GREATEST(1, EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER);

    -- Server-side time limit enforcement (with 30-second network latency grace window)
    IF v_assessment.time_limit_minutes IS NOT NULL AND v_assessment.time_limit_minutes > 0 THEN
      v_is_overtime := (v_time_spent_seconds > (v_assessment.time_limit_minutes * 60 + 30));
    ELSE
      v_is_overtime := FALSE;
    END IF;
  ELSE
    v_attempt_id := gen_random_uuid();
    v_started_at := NOW();
    v_time_spent_seconds := 0;
    v_is_overtime := FALSE;
  END IF;

  -- 3. Fetch previous level
  SELECT level INTO v_prev_level
  FROM public.user_skill_stats
  WHERE user_id = v_user_id AND skill_id = v_assessment.skill_id;
  IF v_prev_level IS NULL THEN
    v_prev_level := 0;
  END IF;

  -- 4. Server-Side Answer Key Grading
  FOR v_q IN
    SELECT id, question_text, options, correct_answer, explanation, order_index
    FROM public.assessment_questions
    WHERE assessment_id = p_assessment_id
    ORDER BY order_index ASC, created_at ASC
  LOOP
    v_total_questions := v_total_questions + 1;
    v_user_answer := (p_answers->>v_q.id::TEXT)::INTEGER;
    v_is_correct := (v_user_answer IS NOT NULL AND v_user_answer = v_q.correct_answer);

    IF v_is_correct THEN
      v_correct_count := v_correct_count + 1;
    END IF;

    -- Disclose answer key and explanation ONLY after server evaluation
    v_question_results := v_question_results || jsonb_build_object(
      'question_id', v_q.id,
      'question_text', v_q.question_text,
      'options', v_q.options,
      'user_answer', v_user_answer,
      'correct_answer', v_q.correct_answer,
      'is_correct', v_is_correct,
      'explanation', v_q.explanation
    );
  END LOOP;

  IF v_total_questions > 0 THEN
    v_score := ROUND((v_correct_count::NUMERIC / v_total_questions::NUMERIC) * 100);
  ELSE
    v_score := 0;
  END IF;

  v_passed := (v_score >= v_assessment.passing_score) AND (NOT v_is_overtime);

  -- 5. Authoritatively record or complete attempt with is_verified = TRUE
  IF p_attempt_id IS NOT NULL THEN
    UPDATE public.assessment_attempts SET
      completed_at = NOW(),
      score = v_score,
      correct_count = v_correct_count,
      total_questions = v_total_questions,
      time_taken_seconds = v_time_spent_seconds,
      was_overtime = v_is_overtime,
      is_verified = TRUE,
      answers = p_answers
    WHERE id = v_attempt_id;
  ELSE
    INSERT INTO public.assessment_attempts (
      id, assessment_id, user_id, started_at, completed_at, score,
      correct_count, total_questions, time_taken_seconds, was_overtime,
      is_verified, is_deleted, answers
    ) VALUES (
      v_attempt_id, p_assessment_id, v_user_id, v_started_at, NOW(), v_score,
      v_correct_count, v_total_questions, v_time_spent_seconds, v_is_overtime,
      TRUE, FALSE, p_answers
    );
  END IF;

  -- 6. Recompute skill statistics
  PERFORM public.recompute_user_skill_stat(v_user_id, v_assessment.skill_id);

  SELECT level INTO v_new_level
  FROM public.user_skill_stats
  WHERE user_id = v_user_id AND skill_id = v_assessment.skill_id;
  IF v_new_level IS NULL THEN
    v_new_level := 0;
  END IF;

  -- 7. Verified XP Award
  IF v_passed THEN
    BEGIN
      v_xp_res := public.record_xp_award(
        v_attempt_id,
        'course_complete',
        100,
        v_attempt_id::TEXT,
        'Passed verified skill assessment: ' || v_assessment.title
      );
      IF (v_xp_res->>'status') = 'awarded' THEN
        v_xp_awarded := COALESCE((v_xp_res->>'xp_awarded')::INTEGER, 100);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN jsonb_build_object(
    'attempt_id', v_attempt_id,
    'assessment_id', p_assessment_id,
    'skill_id', v_assessment.skill_id,
    'score', v_score,
    'correct_count', v_correct_count,
    'total_questions', v_total_questions,
    'passing_score', v_assessment.passing_score,
    'passed', v_passed,
    'is_verified', TRUE,
    'time_spent_seconds', v_time_spent_seconds,
    'is_overtime', v_is_overtime,
    'xp_awarded', v_xp_awarded,
    'previous_level', v_prev_level,
    'new_level', v_new_level,
    'question_results', v_question_results
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_and_grade_assessment(UUID, JSONB, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_and_grade_assessment(UUID, JSONB, UUID) TO authenticated;

-- 7. PREVENT DIRECT CLIENT FORGERY OF is_verified = TRUE ON assessment_attempts
CREATE OR REPLACE FUNCTION public.check_attempt_verified_write()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
  -- Unprivileged client direct writes attempting to set is_verified = TRUE are rejected with 42501.
  -- Trusted server functions (SECURITY DEFINER running as table owner) bypass this check.
  IF current_user IN ('authenticated', 'anon') AND NEW.is_verified = TRUE THEN
    RAISE EXCEPTION 'Cannot self-certify assessment attempt: is_verified must be false for direct client writes'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_attempt_verified_write ON public.assessment_attempts;
CREATE TRIGGER trg_check_attempt_verified_write
  BEFORE INSERT OR UPDATE OF is_verified ON public.assessment_attempts
  FOR EACH ROW
  EXECUTE FUNCTION public.check_attempt_verified_write();
