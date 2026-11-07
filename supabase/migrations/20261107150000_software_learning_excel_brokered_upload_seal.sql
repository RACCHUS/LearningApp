-- Excel pilot: broker-sealed upload; client Storage inserts stay denied.
-- Source-only feature; no hosted service or learner upload enabled.
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

DROP POLICY IF EXISTS sl_excel_insert_owner ON storage.objects;
DROP POLICY IF EXISTS sl_excel_insert_enforce ON storage.objects;
CREATE POLICY sl_excel_insert_client_denied ON storage.objects
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (bucket_id <> 'learningapp-excel-private');

-- Server-side broker locks attempt row for entire exclusive transaction;
-- no service-role privilege to auth.sessions is granted.
CREATE FUNCTION software_learning_private.sl_lock_excel_upload(
  p_attempt_id uuid, p_owner_id uuid, p_session_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $brokerlock$
DECLARE
  v_now timestamptz := now();
  v_attempt public.software_learning_attempts%ROWTYPE;
BEGIN
  IF p_attempt_id IS NULL OR p_owner_id IS NULL OR p_session_id IS NULL THEN
    RETURN NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after>v_now)
  ) THEN
    RETURN NULL;
  END IF;
  SELECT a.* INTO v_attempt
  FROM public.software_learning_attempts a
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=false
    AND a.upload_sha256 IS NULL AND a.upload_object_version IS NULL
    AND a.upload_committed_at IS NULL
    AND a.expires_at>v_now+interval '2 minutes'
  FOR UPDATE OF a NOWAIT;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object(
    'owner_id',v_attempt.owner_id,
    'session_id',v_attempt.issued_session_id,
    'attempt_id',v_attempt.id,
    'expires_at',v_attempt.expires_at
  );
END
$brokerlock$;

CREATE FUNCTION software_learning_private.sl_seal_excel_upload(
  p_attempt_id uuid, p_owner_id uuid, p_session_id uuid,
  p_digest text, p_version text
)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $brokerseal$
DECLARE
  v_updated uuid;
BEGIN
  IF (p_attempt_id IS NULL OR p_owner_id IS NULL OR p_session_id IS NULL
    OR p_digest IS NULL OR p_digest !~ '^[a-f0-9]{64}$'
    OR p_version IS NULL OR char_length(p_version) NOT BETWEEN 1 AND 256
    OR p_version !~ '^[a-zA-Z0-9._:-]+)
  THEN
    RETURN false;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RETURN false;
  END IF;
  UPDATE public.software_learning_attempts a
  SET upload_sha256=p_digest, upload_object_version=p_version,
      upload_committed_at=now(), upload_enabled=true
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=false
    AND a.upload_committed_at IS NULL
    AND a.upload_sha256 IS NULL AND a.upload_object_version IS NULL
    AND a.expires_at>now()
  RETURNING a.id INTO v_updated;
  RETURN v_updated IS NOT NULL;
END
$brokerseal$;

-- A sealed workbook, verified against the live session, is required before
-- any processing claim. Returned hash/revision are immutable trust inputs.
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
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after>v_now)
  ) THEN
    RETURN NULL;
  END IF;
  UPDATE public.software_learning_attempts a
  SET status='processing', upload_enabled=false,
      processing_lease_id=v_lease, processing_claimed_at=v_now
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=true
    AND a.upload_committed_at IS NOT NULL
    AND a.upload_sha256 ~ '^[a-f0-9]{64}$'
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
    'expected_sha256',v_attempt.upload_sha256,
    'object_version',v_attempt.upload_object_version,
    'evidence_trust','unverified_checker_only',
    'can_award_skill',false
  );
END
$claim$;

CREATE OR REPLACE FUNCTION software_learning_private.sl_complete_excel_processing(
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
  SET status='processed', artifact_sha256=p_digest,
      provisional_status=p_status, provisional_feedback=p_feedback
  WHERE a.processing_lease_id=p_lease_id
    AND a.upload_sha256=p_digest
    AND a.status='processing' AND a.upload_enabled=false
    AND a.expires_at>now()
  RETURNING a.id INTO v_completed;
  RETURN v_completed IS NOT NULL;
END
$complete$;

REVOKE ALL ON FUNCTION
  software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION
  software_learning_private.sl_seal_excel_upload(uuid,uuid,uuid,text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_seal_excel_upload(uuid,uuid,uuid,text,text)
  TO service_role;

COMMENT ON COLUMN public.software_learning_attempts.upload_sha256 IS
  'SHA-256 of authenticated broker readback, not evidence of learner mastery';
COMMENT ON COLUMN public.software_learning_attempts.upload_object_version IS
  'Private Storage version pinned by broker, checked again before grading';
COMMENT ON COLUMN public.software_learning_attempts.upload_committed_at IS
  'Broker commit timestamp; direct client Storage INSERT remains prohibited';
COMMENT ON FUNCTION software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid) IS
  'Atomic private claim for server-brokered SHA-sealed uploads; provisional only';
COMMIT;
)
  THEN
    RETURN false;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RETURN false;
  END IF;
  UPDATE public.software_learning_attempts a
  SET upload_sha256=p_digest, upload_object_version=p_version,
      upload_committed_at=now(), upload_enabled=true
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=false
    AND a.upload_committed_at IS NULL
    AND a.upload_sha256 IS NULL AND a.upload_object_version IS NULL
    AND a.expires_at>now()
  RETURNING a.id INTO v_updated;
  RETURN v_updated IS NOT NULL;
END
$brokerseal$;

-- A sealed workbook, verified against the live session, is required before
-- any processing claim. Returned hash/revision are immutable trust inputs.
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
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=p_session_id AND s.user_id=p_owner_id
      AND (s.not_after IS NULL OR s.not_after>v_now)
  ) THEN
    RETURN NULL;
  END IF;
  UPDATE public.software_learning_attempts a
  SET status='processing', upload_enabled=false,
      processing_lease_id=v_lease, processing_claimed_at=v_now
  WHERE a.id=p_attempt_id AND a.owner_id=p_owner_id
    AND a.issued_session_id=p_session_id
    AND a.status='issued' AND a.upload_enabled=true
    AND a.upload_committed_at IS NOT NULL
    AND a.upload_sha256 ~ '^[a-f0-9]{64}$'
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
    'expected_sha256',v_attempt.upload_sha256,
    'object_version',v_attempt.upload_object_version,
    'evidence_trust','unverified_checker_only',
    'can_award_skill',false
  );
END
$claim$;

CREATE OR REPLACE FUNCTION software_learning_private.sl_complete_excel_processing(
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
  SET status='processed', artifact_sha256=p_digest,
      provisional_status=p_status, provisional_feedback=p_feedback
  WHERE a.processing_lease_id=p_lease_id
    AND a.upload_sha256=p_digest
    AND a.status='processing' AND a.upload_enabled=false
    AND a.expires_at>now()
  RETURNING a.id INTO v_completed;
  RETURN v_completed IS NOT NULL;
END
$complete$;

REVOKE ALL ON FUNCTION
  software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION
  software_learning_private.sl_seal_excel_upload(uuid,uuid,uuid,text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_lock_excel_upload(uuid,uuid,uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION
  software_learning_private.sl_seal_excel_upload(uuid,uuid,uuid,text,text)
  TO service_role;

COMMENT ON COLUMN public.software_learning_attempts.upload_sha256 IS
  'SHA-256 of authenticated broker readback, not evidence of learner mastery';
COMMENT ON COLUMN public.software_learning_attempts.upload_object_version IS
  'Private Storage version pinned by broker, checked again before grading';
COMMENT ON COLUMN public.software_learning_attempts.upload_committed_at IS
  'Broker commit timestamp; direct client Storage INSERT remains prohibited';
COMMENT ON FUNCTION software_learning_private.sl_claim_excel_processing(uuid,uuid,uuid) IS
  'Atomic private claim for server-brokered SHA-sealed uploads; provisional only';
COMMIT;
