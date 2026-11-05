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

-- Revoke direct client UPDATE on review_items projection table (ARCH-1, ARCH-3)
-- All scheduler updates must flow through record_events or reset RPC
REVOKE UPDATE ON public.review_items FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "Users can update own review items" ON public.review_items;

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

-- 4. REVOKE DIRECT AUTHENTICATED EXECUTION OF RECORD_XP_AWARD (FIX-2)
-- Authoritative XP awards are strictly executed from trusted server functions.
REVOKE EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_xp_award(UUID, TEXT, INTEGER, TEXT, TEXT) TO service_role;

-- 5. RECORD_EVENTS TRANSACTIONAL RPC (ARCH-1, ARCH-3, FIX-2, FIX-4)
-- Atomically logs append-only events, updates review projections idempotently,
-- and updates user_concept_state evidence projections.
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
  v_inserted BOOLEAN;
  v_processed_count INTEGER := 0;
  v_concept_id_text TEXT;
BEGIN
  v_auth_uid := (SELECT auth.uid());
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to record learning events'
      USING ERRCODE = '42501';
  END IF;

  FOREACH v_event IN ARRAY p_events LOOP
    v_event_id := COALESCE((v_event->>'id')::UUID, gen_random_uuid());
    v_occurred_at := COALESCE((v_event->>'occurred_at')::TIMESTAMPTZ, NOW());
    v_event_type := COALESCE(v_event->>'event_type', 'unknown');
    v_item_type := COALESCE(v_event->>'item_type', 'unknown');
    v_item_id := COALESCE(v_event->>'item_id', '');
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

    -- Parse presented_order array safely if supplied
    v_presented_order := NULL;
    IF v_event ? 'presented_order' AND jsonb_typeof(v_event->'presented_order') = 'array' THEN
      v_presented_order := ARRAY(
        SELECT elem::SMALLINT
        FROM jsonb_array_elements_text(v_event->'presented_order') AS elem
      );
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
        total_reviews = review_items.total_reviews + 1,
        correct_reviews = CASE 
          WHEN COALESCE((v_sched_after->>'correct_reviews')::INTEGER, -1) >= 0 
            THEN (v_sched_after->>'correct_reviews')::INTEGER
          WHEN COALESCE(v_rating, 0) >= 3 OR COALESCE(v_score, 0.0) >= 0.6 
            THEN review_items.correct_reviews + 1 
          ELSE review_items.correct_reviews 
        END,
        updated_at = NOW()
      WHERE user_id = v_auth_uid AND (id::TEXT = v_item_id OR content_id = v_item_id);
    END IF;

    -- 3. Update user_concept_state projection when concept evidence is provided
    v_concept_id_text := COALESCE(v_event->>'concept_id', v_metadata->>'concept_id');
    IF v_inserted IS TRUE AND v_concept_id_text IS NOT NULL AND v_concept_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      DECLARE
        v_cid UUID := v_concept_id_text::UUID;
        v_ev_score NUMERIC := COALESCE(v_score::NUMERIC, CASE WHEN COALESCE(v_rating, 0) >= 3 THEN 1.0 ELSE 0.0 END);
      BEGIN
        INSERT INTO public.user_concept_state (
          user_id, concept_id, evidence_count, weighted_correct, weighted_total, last_evidence_at, updated_at
        ) VALUES (
          v_auth_uid, v_cid, 1, v_ev_score, 1.0, v_occurred_at, NOW()
        )
        ON CONFLICT (user_id, concept_id) DO UPDATE SET
          evidence_count = user_concept_state.evidence_count + 1,
          weighted_correct = user_concept_state.weighted_correct + EXCLUDED.weighted_correct,
          weighted_total = user_concept_state.weighted_total + 1.0,
          last_evidence_at = EXCLUDED.last_evidence_at,
          updated_at = NOW();
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;
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

-- 6. RESET REVIEW ITEM PROGRESS RPC (ARCH-1, ARCH-3)
CREATE OR REPLACE FUNCTION public.reset_review_item_progress(
  p_item_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_item RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to reset review item' USING ERRCODE = '42501';
  END IF;

  UPDATE public.review_items SET
    repetition_level = 0,
    ease_factor = 2.5,
    next_review_date = NOW() + INTERVAL '1 day',
    total_reviews = 0,
    correct_reviews = 0,
    stability = 2.0,
    difficulty = 5.0,
    fsrs_state = 1,
    retrievability = 1.0,
    step = 0,
    updated_at = NOW()
  WHERE id = p_item_id AND user_id = v_user_id
  RETURNING * INTO v_item;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Review item not found: %', p_item_id USING ERRCODE = 'P0002';
  END IF;

  RETURN to_jsonb(v_item);
END;
$$;

REVOKE ALL ON FUNCTION public.reset_review_item_progress(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reset_review_item_progress(UUID) TO authenticated;

-- 7. SANITIZED ASSESSMENT QUESTIONS RPC (ARCH-1, FIX-12)
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

-- 8. SERVER-SIDE START ATTEMPT RPC (ARCH-1, FIX-12)
-- Authoritatively starts an assessment attempt with server-owned start timestamp.
CREATE OR REPLACE FUNCTION public.start_assessment_attempt(
  p_assessment_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user_id UUID := (SELECT auth.uid());
  v_attempt_id UUID := gen_random_uuid();
  v_total_questions INTEGER := 0;
  v_attempt public.assessment_attempts%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to start assessment' USING ERRCODE = '42501';
  END IF;

  PERFORM 1
  FROM public.skill_assessments
  WHERE id = p_assessment_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active assessment not found: %', p_assessment_id;
  END IF;

  SELECT count(id)::INTEGER INTO v_total_questions
  FROM public.assessment_questions
  WHERE assessment_id = p_assessment_id;

  INSERT INTO public.assessment_attempts (
    id, assessment_id, user_id, started_at, total_questions, is_verified, is_deleted
  ) VALUES (
    v_attempt_id, p_assessment_id, v_user_id, NOW(), v_total_questions, FALSE, FALSE
  )
  RETURNING * INTO v_attempt;

  RETURN to_jsonb(v_attempt);
END;
$$;

REVOKE ALL ON FUNCTION public.start_assessment_attempt(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_assessment_attempt(UUID) TO authenticated;

-- 9. SERVER-SIDE ASSESSMENT ATTEMPT SUBMISSION & GRADING RPC (ARCH-1, FIX-12)
-- Evaluates submitted answers against actual correct answers on the server,
-- requires a valid started attempt, locks it atomically against concurrent submissions,
-- enforces server timing, marks verified (if not overtime), and awards verified XP.
CREATE OR REPLACE FUNCTION public.submit_and_grade_assessment(
  p_assessment_id UUID,
  p_answers JSONB,
  p_attempt_id UUID
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
  v_started_at TIMESTAMPTZ;
  v_time_spent_seconds INTEGER := 0;
  v_is_overtime BOOLEAN := FALSE;
  v_is_verified BOOLEAN := FALSE;
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
    RAISE EXCEPTION 'Authentication required to submit assessment' USING ERRCODE = '42501';
  END IF;

  IF p_attempt_id IS NULL THEN
    RAISE EXCEPTION 'A valid assessment attempt ID is required to submit and grade answers'
      USING ERRCODE = '42501';
  END IF;

  -- 1. Fetch and validate assessment
  SELECT * INTO v_assessment
  FROM public.skill_assessments
  WHERE id = p_assessment_id AND is_active = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active assessment not found: %', p_assessment_id;
  END IF;

  -- 2. Atomically lock and validate the attempt against concurrent completion
  SELECT * INTO v_attempt
  FROM public.assessment_attempts
  WHERE id = p_attempt_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assessment attempt not found: %', p_attempt_id USING ERRCODE = 'P0002';
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

  v_started_at := COALESCE(v_attempt.started_at, NOW());
  v_time_spent_seconds := GREATEST(1, EXTRACT(EPOCH FROM (NOW() - v_started_at))::INTEGER);

  -- Server-side time limit enforcement (with 30-second network latency grace window)
  IF v_assessment.time_limit_minutes IS NOT NULL AND v_assessment.time_limit_minutes > 0 THEN
    v_is_overtime := (v_time_spent_seconds > (v_assessment.time_limit_minutes * 60 + 30));
  ELSE
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

    -- Disclose answer key and explanation ONLY upon legitimate attempt completion
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
  v_is_verified := (NOT v_is_overtime);

  -- 5. Authoritatively complete attempt with conditional atomic update
  UPDATE public.assessment_attempts SET
    completed_at = NOW(),
    score = v_score,
    correct_count = v_correct_count,
    total_questions = v_total_questions,
    time_taken_seconds = v_time_spent_seconds,
    was_overtime = v_is_overtime,
    is_verified = v_is_verified,
    answers = p_answers
  WHERE id = p_attempt_id AND completed_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assessment attempt already completed: %', p_attempt_id;
  END IF;

  -- 6. Recompute skill statistics
  PERFORM public.recompute_user_skill_stat(v_user_id, v_assessment.skill_id);

  SELECT level INTO v_new_level
  FROM public.user_skill_stats
  WHERE user_id = v_user_id AND skill_id = v_assessment.skill_id;
  IF v_new_level IS NULL THEN
    v_new_level := 0;
  END IF;

  -- 7. Authoritative XP Award (issued exclusively for passed, non-overtime attempts)
  IF v_passed THEN
    BEGIN
      v_xp_res := public.record_xp_award(
        p_attempt_id,
        'course_complete',
        100,
        p_attempt_id::TEXT,
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
    'attempt_id', p_attempt_id,
    'assessment_id', p_assessment_id,
    'skill_id', v_assessment.skill_id,
    'score', v_score,
    'correct_count', v_correct_count,
    'total_questions', v_total_questions,
    'passing_score', v_assessment.passing_score,
    'passed', v_passed,
    'is_verified', v_is_verified,
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

-- 10. PREVENT DIRECT CLIENT TAMPERING WITH ASSESSMENT ATTEMPTS
CREATE OR REPLACE FUNCTION public.check_attempt_client_dml()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.is_verified = TRUE THEN
        RAISE EXCEPTION 'Cannot self-certify assessment attempt: is_verified must be false'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.completed_at IS NOT NULL OR NEW.score IS NOT NULL THEN
        RAISE EXCEPTION 'Direct insertion of completed assessment attempt is forbidden'
          USING ERRCODE = '42501';
      END IF;
      NEW.started_at := NOW();
      NEW.was_overtime := FALSE;
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.started_at <> OLD.started_at THEN
        RAISE EXCEPTION 'Cannot modify started_at of an assessment attempt'
          USING ERRCODE = '42501';
      END IF;
      IF OLD.completed_at IS NOT NULL THEN
        RAISE EXCEPTION 'Cannot modify already completed assessment attempt'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.completed_at IS NOT NULL 
         OR NEW.score IS NOT NULL 
         OR NEW.correct_count <> OLD.correct_count 
         OR NEW.total_questions <> OLD.total_questions 
         OR NEW.time_taken_seconds IS NOT NULL 
         OR NEW.was_overtime <> OLD.was_overtime 
         OR NEW.is_verified = TRUE THEN
        RAISE EXCEPTION 'Cannot directly modify completion or scoring fields of an assessment attempt'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.assessment_id <> OLD.assessment_id OR NEW.user_id <> OLD.user_id THEN
        RAISE EXCEPTION 'Cannot reassign attempt identity'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_attempt_verified_write ON public.assessment_attempts;
DROP TRIGGER IF EXISTS trg_check_attempt_client_dml ON public.assessment_attempts;
CREATE TRIGGER trg_check_attempt_client_dml
  BEFORE INSERT OR UPDATE ON public.assessment_attempts
  FOR EACH ROW
  EXECUTE FUNCTION public.check_attempt_client_dml();

-- 11. EXCLUDE OVERTIME ATTEMPTS FROM VERIFIED SKILL METRICS
CREATE OR REPLACE FUNCTION public.calculate_skill_level(p_user_id UUID, p_skill_id UUID) 
RETURNS INTEGER AS $$
DECLARE
  v_level INTEGER;
BEGIN
  SELECT COALESCE(AVG(score)::INTEGER, 0) INTO v_level
  FROM (
    SELECT aa.score
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.was_overtime = FALSE
      AND aa.is_deleted = FALSE
      AND aa.score IS NOT NULL
    ORDER BY aa.score DESC
    LIMIT 3
  ) best_attempts;
  
  RETURN v_level;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

CREATE OR REPLACE FUNCTION public.recompute_user_skill_stat(p_user_id UUID, p_skill_id UUID) 
RETURNS VOID AS $$
DECLARE
  v_new_level INTEGER := 0;
  v_best_score INTEGER := 0;
  v_avg_score NUMERIC(5,2) := 0;
  v_total INTEGER := 0;
  v_has_verified BOOLEAN := FALSE;
BEGIN
  IF p_user_id IS NULL OR p_skill_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_user_id::text), hashtext(p_skill_id::text));

  SELECT COUNT(*) INTO v_total
  FROM public.assessment_attempts aa
  JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
  WHERE aa.user_id = p_user_id
    AND sa.skill_id = p_skill_id
    AND aa.is_deleted = FALSE
    AND aa.completed_at IS NOT NULL
    AND aa.score IS NOT NULL;

  IF v_total = 0 THEN
    DELETE FROM public.user_skill_stats
    WHERE user_id = p_user_id
      AND skill_id = p_skill_id;
    RETURN;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.was_overtime = FALSE
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL
  ) INTO v_has_verified;

  IF v_has_verified THEN
    v_new_level := public.calculate_skill_level(p_user_id, p_skill_id);
    
    SELECT 
      MAX(score),
      AVG(score)::NUMERIC(5,2),
      COUNT(*)
    INTO v_best_score, v_avg_score, v_total
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_verified = TRUE
      AND aa.was_overtime = FALSE
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL;
  ELSE
    SELECT COALESCE(AVG(score)::INTEGER, 0) INTO v_new_level
    FROM (
      SELECT aa.score
      FROM public.assessment_attempts aa
      JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
      WHERE aa.user_id = p_user_id
        AND sa.skill_id = p_skill_id
        AND aa.is_deleted = FALSE
        AND aa.completed_at IS NOT NULL
        AND aa.score IS NOT NULL
      ORDER BY aa.score DESC
      LIMIT 3
    ) recent_attempts;

    SELECT 
      MAX(score),
      AVG(score)::NUMERIC(5,2)
    INTO v_best_score, v_avg_score
    FROM public.assessment_attempts aa
    JOIN public.skill_assessments sa ON sa.id = aa.assessment_id
    WHERE aa.user_id = p_user_id
      AND sa.skill_id = p_skill_id
      AND aa.is_deleted = FALSE
      AND aa.completed_at IS NOT NULL
      AND aa.score IS NOT NULL;
  END IF;

  INSERT INTO public.user_skill_stats (
    user_id, skill_id, level, best_score, average_score, total_assessments, is_verified, last_assessed_at, updated_at
  ) VALUES (
    p_user_id, p_skill_id, v_new_level, v_best_score, v_avg_score, v_total, v_has_verified, NOW(), NOW()
  )
  ON CONFLICT (user_id, skill_id) DO UPDATE SET
    level = EXCLUDED.level,
    best_score = EXCLUDED.best_score,
    average_score = EXCLUDED.average_score,
    total_assessments = EXCLUDED.total_assessments,
    is_verified = EXCLUDED.is_verified,
    last_assessed_at = EXCLUDED.last_assessed_at,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
