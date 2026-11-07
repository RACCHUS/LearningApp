-- Software Learning Excel pilot: authenticated, server-issued synthetic attempts.
-- DRAFT FOUNDATION ONLY. No workbook upload/storage, grading, learning_events
-- projection, skill awards or user file handling is enabled by this migration.
-- Append-only; deploy only after the guarded release process and owner review.
BEGIN;

CREATE SCHEMA IF NOT EXISTS software_learning_private;
REVOKE ALL ON SCHEMA software_learning_private FROM PUBLIC, anon, authenticated;

CREATE TABLE public.software_learning_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  issued_session_id uuid NOT NULL,
  exercise_id text NOT NULL DEFAULT 'excel-budget-total-v1'
    CHECK (exercise_id = 'excel-budget-total-v1'),
  checker_version integer NOT NULL DEFAULT 1
    CHECK (checker_version = 1),
  issued_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'issued'
    CHECK (status = 'issued'),
  CONSTRAINT sl_excel_limited_expiration_check
    CHECK (expires_at > issued_at AND
      expires_at <= issued_at + interval '45 minutes')
);
CREATE INDEX sl_attempts_owner_issue_idx
  ON public.software_learning_attempts (owner_id,issued_at DESC);
CREATE INDEX sl_attempts_owner_expiry_idx
  ON public.software_learning_attempts (owner_id,expires_at)
  WHERE status='issued';

ALTER TABLE public.software_learning_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.software_learning_attempts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.software_learning_attempts TO authenticated;
CREATE POLICY sl_attempts_owner_read
  ON public.software_learning_attempts FOR SELECT TO authenticated
  USING (owner_id=(SELECT auth.uid()) AND expires_at > now());

CREATE TABLE software_learning_private.excel_attempt_inputs (
  attempt_id uuid PRIMARY KEY
    REFERENCES public.software_learning_attempts(id) ON DELETE CASCADE,
  expected_inputs jsonb NOT NULL CHECK (jsonb_typeof(expected_inputs)='object')
);
ALTER TABLE software_learning_private.excel_attempt_inputs ENABLE ROW LEVEL SECURITY;

-- Issuance accounting intentionally survives deleting an individual attempt,
-- otherwise a learner could evade the 12-in-24h quota by erasing each attempt.
-- Contains account ID and timestamp only, no workbook data or responses.
-- Account erasure cascades; periodic age-based pruning is a release gate.
CREATE TABLE software_learning_private.excel_issuance_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  issued_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sl_excel_issue_log_owner_window_idx
  ON software_learning_private.excel_issuance_log(owner_id,issued_at DESC);
ALTER TABLE software_learning_private.excel_issuance_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA software_learning_private
  FROM PUBLIC, anon, authenticated;

-- No user-controlled exercise ID, checker version, score, expected values or
-- owner ID parameters are accepted. This issuer returns only safe synthetic
-- transaction amounts; there is no file/assessment upload capability.
CREATE FUNCTION public.sl_issue_excel_budget_attempt()
RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $issue$
DECLARE
  v_actor uuid;
  v_session uuid;
  v_now timestamptz := now();
  v_id uuid;
  v_inputs jsonb := '{}'::jsonb;
  v_quota integer;
BEGIN
  v_actor := (SELECT auth.uid());
  IF v_actor IS NULL
     OR (auth.jwt()->>'role') IS DISTINCT FROM 'authenticated'
     OR (auth.jwt()->>'is_anonymous') IS DISTINCT FROM 'false'
     OR coalesce(auth.jwt()->>'session_id','') !~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  THEN
    RAISE EXCEPTION 'Permanent authenticated session required'
      USING ERRCODE='42501';
  END IF;
  v_session := (auth.jwt()->>'session_id')::uuid;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=v_session AND s.user_id=v_actor
      AND (s.not_after IS NULL OR s.not_after>v_now)
  ) THEN
    RAISE EXCEPTION 'Authentication session is no longer active'
      USING ERRCODE='42501';
  END IF;

  -- Serialize issuance by account so parallel requests cannot bypass quotas.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_actor::text, 61732));
  SELECT count(*)::integer INTO v_quota
  FROM software_learning_private.excel_issuance_log l
  WHERE l.owner_id=v_actor AND l.issued_at>v_now-interval '24 hours';
  IF v_quota >= 12 THEN
    RAISE EXCEPTION 'Excel practice issuance quota reached'
      USING ERRCODE='42501';
  END IF;

  SELECT count(*)::integer INTO v_quota
  FROM public.software_learning_attempts a
  WHERE a.owner_id=v_actor AND a.expires_at>v_now AND a.status='issued';
  IF v_quota >= 2 THEN
    RAISE EXCEPTION 'Finish or erase an existing Excel attempt first'
      USING ERRCODE='42501';
  END IF;

  -- New numeric inputs are generated server-side for each attempt.
  -- They are synthetic learning data, NOT anti-cheating secrets.
  FOR v_i IN 2..9 LOOP
    v_inputs := v_inputs || jsonb_build_object(
      'C' || v_i, (10+floor(random()*90)::integer)
    );
  END LOOP;

  INSERT INTO public.software_learning_attempts
    (owner_id,issued_session_id,issued_at,expires_at)
  VALUES (v_actor,v_session,v_now,v_now+interval '45 minutes')
  RETURNING id INTO v_id;
  INSERT INTO software_learning_private.excel_attempt_inputs
    (attempt_id,expected_inputs)
  VALUES (v_id,v_inputs);
  INSERT INTO software_learning_private.excel_issuance_log
    (owner_id,issued_at)
  VALUES (v_actor,v_now);

  RETURN jsonb_build_object(
    'attempt_id',v_id,
    'exercise_id','excel-budget-total-v1',
    'checker_version',1,
    'worksheet','Budget',
    'target_cell','C10',
    'inputs',v_inputs,
    'issued_at',v_now,
    'expires_at',v_now+interval '45 minutes',
    'status','issued',
    'upload_enabled',false,
    'evidence_trust','unverified'
  );
END
$issue$;

REVOKE ALL ON FUNCTION public.sl_issue_excel_budget_attempt()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sl_issue_excel_budget_attempt()
  TO authenticated;

-- Owner erasure of the synthetic attempt and its private numeric inputs.
-- No attempt contents or foreign-attempt existence is disclosed to callers.
CREATE FUNCTION public.sl_delete_excel_budget_attempt(p_attempt_id uuid)
RETURNS boolean
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path=pg_catalog
AS $erase$
DECLARE
  v_actor uuid;
  v_session uuid;
  v_deleted uuid;
BEGIN
  v_actor := (SELECT auth.uid());
  IF v_actor IS NULL
     OR (auth.jwt()->>'role') IS DISTINCT FROM 'authenticated'
     OR (auth.jwt()->>'is_anonymous') IS DISTINCT FROM 'false'
     OR coalesce(auth.jwt()->>'session_id','') !~
       '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  THEN
    RAISE EXCEPTION 'Permanent authenticated session required'
      USING ERRCODE='42501';
  END IF;
  v_session := (auth.jwt()->>'session_id')::uuid;
  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions s
    WHERE s.id=v_session AND s.user_id=v_actor
      AND (s.not_after IS NULL OR s.not_after>now())
  ) THEN
    RAISE EXCEPTION 'Authentication session is no longer active'
      USING ERRCODE='42501';
  END IF;

  DELETE FROM public.software_learning_attempts a
  WHERE a.id=p_attempt_id AND a.owner_id=v_actor
  RETURNING a.id INTO v_deleted;
  RETURN v_deleted IS NOT NULL;
END
$erase$;

REVOKE ALL ON FUNCTION public.sl_delete_excel_budget_attempt(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sl_delete_excel_budget_attempt(uuid)
  TO authenticated;

COMMENT ON TABLE public.software_learning_attempts IS
  'Excel pilot: owner-visible server-issued synthetic attempt metadata; no scoring or file submission enabled.';
COMMENT ON TABLE software_learning_private.excel_attempt_inputs IS
  'Server-owned synthetic transaction cells, never directly readable by clients.';
COMMENT ON FUNCTION public.sl_issue_excel_budget_attempt() IS
  'Live permanent-session, owner-bound and quota-limited issue of synthetic Excel budget practice; unverified only.';
COMMENT ON FUNCTION public.sl_delete_excel_budget_attempt(uuid) IS
  'Live-session owner deletion; atomically cascades to private Excel practice inputs.';
COMMIT;
