-- Excel pilot: sealed server-brokered upload only, no direct client INSERT.
-- All file uploads remain off in production; no gateway or scheduler deployed.
BEGIN;

ALTER TABLE public.software_learning_attempts
  ADD COLUMN upload_sha256 text,
  ADD COLUMN upload_object_version text,
  ADD COLUMN upload_committed_at timestamptz,
  ADD CONSTRAINT sl_excel_upload_sha_check
    CHECK (upload_sha256 IS NULL OR upload_sha256 ~ '^[a-f0-9]{64}$'),
  ADD CONSTRAINT sl_excel_upload_revision_check
    CHECK (upload_object_version IS NULL OR
           (char_length(upload_object_version) BETWEEN 1 AND 256 AND
            upload_object_version ~ '^[a-zA-Z0-9._:-]+$')),
  ADD CONSTRAINT sl_excel_upload_attestation_complete_check
    CHECK (
      (upload_sha256 IS NULL AND upload_object_version IS NULL
       AND upload_committed_at IS NULL)
      OR
      (upload_sha256 IS NOT NULL AND upload_object_version IS NOT NULL
       AND upload_committed_at IS NOT NULL)
    ),
  ADD CONSTRAINT sl_excel_upload_enabled_requires_seal_check
    CHECK (NOT upload_enabled OR upload_committed_at IS NOT NULL);

-- Irrevocable-by-client RLS boundary, including any pre-existing permissive
-- policies on Storage objects. A future operator setting upload_enabled=true
-- MUST NOT re-enable direct uploads or signed client Storage mutations.
DROP POLICY IF EXISTS sl_excel_insert_owner ON storage.objects;
DROP POLICY IF EXISTS sl_excel_insert_enforce ON storage.objects;
CREATE POLICY sl_excel_insert_client_denied ON storage.objects
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (bucket_id <> 'learningapp-excel-private');
-- Separate restrictive anonymous policy from the preceding migration stays.

-- A trusted backend can keep using the existing upload_enabled bit as the
-- processing-claim readiness flag only after a SHA+revision seal is stored.
-- Supabase clients cannot call this private claim function.
CREATE OR REPLACE FUNCTION software_learning_private.sl_claim_excel_processing(
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
    AND a.upload_committed_at IS NOT NULL
    AND a.upload_sha256 ~ '^[a-f0-9]{64}
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
    'expected_sha256',v_attempt.upload_sha256,
    'object_version',v_attempt.upload_object_version,
    'evidence_trust','unverified_checker_only',
    'can_award_skill',false
  );
END
$claim$;
    AND a.upload_object_version IS NOT NULL
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

COMMENT ON COLUMN public.software_learning_attempts.upload_sha256 IS
 'SHA-256 of authenticated broker readback, not evidence of learner mastery';
COMMENT ON COLUMN public.software_learning_attempts.upload_object_version IS
 'Private Storage version pinned by broker, checked again before grading';
COMMENT ON COLUMN public.software_learning_attempts.upload_committed_at IS
 'Broker commit timestamp; direct client Storage INSERT remains prohibited';
COMMENT ON FUNCTION software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid) IS
 'Atomic private claim only for server-brokered, SHA-sealed workbook uploads; still provisional';
COMMIT;
