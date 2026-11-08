-- Excel pilot: service-only, single-use processing lease and provisional receipt.
-- No learner-facing upload/grade route. No learning_events or skill awards.
-- The owner/session-authenticated Storage admission remains default DISABLED.
-- This append-only migration is source-only pending guarded deployment review.
BEGIN;

ALTER TABLE public.software_learning_attempts
  DROP CONSTRAINT software_learning_attempts_status_check;
ALTER TABLE public.software_learning_attempts
  ADD CONSTRAINT software_learning_attempts_status_check
  CHECK (status IN ('issued','processing','processed','failed'));

ALTER TABLE public.software_learning_attempts
  ADD COLUMN processing_lease_id uuid UNIQUE,
  ADD COLUMN processing_claimed_at timestamptz,
  ADD COLUMN artifact_sha256 text,
  ADD COLUMN provisional_status text,
  ADD COLUMN provisional_feedback text,
  ADD CONSTRAINT sl_excel_artifact_sha_check
    CHECK (artifact_sha256 IS NULL OR artifact_sha256 ~ '^[a-f0-9]{64}$'),
  ADD CONSTRAINT sl_excel_provisional_status_check
    CHECK (provisional_status IS NULL OR
           provisional_status IN ('pass','fail','inconclusive')),
  ADD CONSTRAINT sl_excel_provisional_feedback_check
    CHECK (provisional_feedback IS NULL OR
           char_length(provisional_feedback) <= 300);

-- This schema is deliberately absent from the public Data API. Only the
-- trusted service role is permitted to invoke the state-machine methods.
GRANT USAGE ON SCHEMA software_learning_private TO service_role;

CREATE FUNCTION software_learning_private.sl_claim_excel_processing(
  p_attempt_id uuid, p_owner_id uuid, p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $claim$
DECLARE
  v_now timestamptz := now();
  v_lease uuid := gen_random_uuid();
  v_attempt public.software_learning_attempts%ROWTYPE;
  v_inputs jsonb;
BEGIN
  IF p_attempt_id IS NULL OR p_owner_id IS NULL OR p_session_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Additional live-session check in the DB; the invoking service MUST
  -- independently validate bearer JWT and permanence before passing IDs.
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after > v_now)
  ) THEN
    RETURN NULL;
  END IF;

  -- This UPDATE is atomic and single-use: simultaneous calls cannot both
  -- claim the same issued attempt. It also disables future upload INSERTs.
  UPDATE public.software_learning_attempts a
  SET status='processing',
      upload_enabled=false,
      processing_lease_id=v_lease,
      processing_claimed_at=v_now
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=true
    AND a.expires_at>v_now
  RETURNING a.* INTO v_attempt;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT i.expected_inputs INTO v_inputs
  FROM software_learning_private.excel_attempt_inputs i
  WHERE i.attempt_id=v_attempt.id;
  IF v_inputs IS NULL THEN
    RAISE EXCEPTION 'Server-issued workbook inputs missing'
      USING ERRCODE='55000';
  END IF;

  RETURN jsonb_build_object(
    'lease_id',v_lease,
    'attempt_id',v_attempt.id,
    'owner_id',v_attempt.owner_id,
    'session_id',v_attempt.issued_session_id,
    'exercise_id',v_attempt.exercise_id,
    'checker_version',v_attempt.checker_version,
    'expires_at',v_attempt.expires_at,
    'expected_inputs',v_inputs,
    'evidence_trust','unverified_checker_only',
    'can_award_skill',false
  );
END
$claim$;

CREATE FUNCTION software_learning_private.sl_complete_excel_processing(
  p_lease_id uuid, p_digest text, p_status text, p_feedback text
)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $complete$
DECLARE
  v_completed uuid;
BEGIN
  IF p_lease_id IS NULL OR p_digest IS NULL OR
     p_digest !~ '^[a-f0-9]{64}$' OR
     p_status NOT IN ('pass','fail','inconclusive') OR
     p_status IS NULL OR p_feedback IS NULL OR
     char_length(p_feedback) > 300
  THEN
    RETURN false;
  END IF;

  UPDATE public.software_learning_attempts a
  SET status='processed',
      artifact_sha256=p_digest,
      provisional_status=p_status,
      provisional_feedback=p_feedback
  WHERE a.processing_lease_id=p_lease_id
    AND a.status='processing'
    AND a.upload_enabled=false
    AND a.expires_at>now()
  RETURNING a.id INTO v_completed;

  RETURN v_completed IS NOT NULL;
END
$complete$;

CREATE FUNCTION software_learning_private.sl_fail_excel_processing(
  p_lease_id uuid
)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $fail$
DECLARE
  v_failed uuid;
BEGIN
  IF p_lease_id IS NULL THEN
    RETURN false;
  END IF;
  UPDATE public.software_learning_attempts a
  SET status='failed', upload_enabled=false
  WHERE a.processing_lease_id=p_lease_id AND a.status='processing'
  RETURNING a.id INTO v_failed;
  RETURN v_failed IS NOT NULL;
END
$fail$;

-- Never expose these security-definer functions to any learner role or
-- anonymous RPC. Only the trusted backend obtains the private expected data.
REVOKE ALL ON FUNCTION
  software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION
  software_learning_private.sl_complete_excel_processing(uuid,text,text,text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION
  software_learning_private.sl_fail_excel_processing(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_complete_excel_processing(uuid,text,text,text)
  TO service_role;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_fail_excel_processing(uuid)
  TO service_role;

COMMENT ON FUNCTION software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid)
 IS 'Atomic service-only Excel claim; freezes upload and exposes expected inputs solely to trusted processor.';
COMMENT ON FUNCTION software_learning_private.sl_complete_excel_processing(uuid,text,text,text)
 IS 'Provisional result only; never verified learning events or skill award.';
COMMENT ON FUNCTION software_learning_private.sl_fail_excel_processing(uuid)
 IS 'Finalizes a failed one-time claim without reopening upload access.';
COMMIT;
