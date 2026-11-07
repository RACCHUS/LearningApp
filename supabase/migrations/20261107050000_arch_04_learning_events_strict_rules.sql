-- ============================================================================
-- Architecture Phase 4: Strict Learning Events Rules, Constraints & Projections
-- Migration: 20261107050000_arch_04_learning_events_strict_rules.sql
--
-- Normative Specification: docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md (§2.4)
--
-- Architectural Scope & Trust Boundary Notice:
-- 1. Establishes strict server-side validation for public.learning_events:
--    - 13-field canonical payload digest (SHA-256) for payload tampering & retry detection.
--    - Transaction-scoped advisory locks on (user_id, idempotency_key), session, item, and concept.
--    - Intra-batch duplicate preflight with conflict quarantine.
--    - Named sequence uniqueness: CONSTRAINT learning_events_user_session_seq_key UNIQUE(user_id, session_id, client_seq).
--    - Joint feasibility of 14-day plausibility window and bidirectional session neighbor bounds.
--    - Atomic subtransaction execution (BEGIN ... EXCEPTION ... END with SQLSTATE 'PZ001' and WHEN OTHERS THEN RAISE;).
--    - Preserved 1:1 input ordering in the returned results array.
-- 2. Projection Boundary: user_concept_state direct client write RLS revoked; managed solely server-side.
-- 3. FSRS-6 Projection Notice: review_items projection updates are bounded server-side within the subtransaction.
--    Full multi-device historical replay of FSRS-6 state across all historical reviews remains scoped as an ongoing
--    architectural roadmap deliverable and is NOT claimed as canonical server-side replay in this Phase 1 migration.
-- ============================================================================

-- 1. ADDITIVE SCHEMA ON public.learning_events
ALTER TABLE public.learning_events
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT DEFAULT ('raw_' || gen_random_uuid()::TEXT),
  ADD COLUMN IF NOT EXISTS payload_sha256 TEXT DEFAULT 'raw_uncomputed_digest',
  ADD COLUMN IF NOT EXISTS client_seq INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS attempt_id UUID,
  ADD COLUMN IF NOT EXISTS client_occurred_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS effective_occurred_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS client_latency_ms INTEGER,
  ADD COLUMN IF NOT EXISTS event_schema_version TEXT NOT NULL DEFAULT '1.0.0',
  ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS presented_option_ids TEXT[];

-- 2. SAFE DETERMINISTIC LEGACY BACKFILL
UPDATE public.learning_events
SET client_occurred_at = COALESCE(occurred_at, NOW())
WHERE client_occurred_at IS NULL;

UPDATE public.learning_events
SET effective_occurred_at = client_occurred_at
WHERE effective_occurred_at IS NULL;

UPDATE public.learning_events
SET received_at = client_occurred_at
WHERE received_at IS NULL;

UPDATE public.learning_events
SET session_id = '00000000-0000-0000-0000-000000000000'
WHERE session_id IS NULL;

WITH numbered AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY user_id, session_id
    ORDER BY effective_occurred_at ASC, id ASC
  )::INTEGER AS seq
  FROM public.learning_events
  WHERE client_seq IS NULL
)
UPDATE public.learning_events le
SET client_seq = numbered.seq
FROM numbered
WHERE le.id = numbered.id;

UPDATE public.learning_events
SET idempotency_key = 'legacy_' || id::text
WHERE idempotency_key IS NULL;

UPDATE public.learning_events
SET payload_sha256 = encode(digest(convert_to(
  jsonb_build_object(
    'session_id', session_id,
    'client_seq', client_seq,
    'attempt_id', attempt_id,
    'event_type', event_type,
    'content_id', item_id,
    'item_id', item_id,
    'presented_option_ids', '[]'::jsonb,
    'learner_response', response,
    'fsrs_rating', rating,
    'assistance_provided', '[]'::jsonb,
    'learner_confidence', confidence,
    'client_latency_ms', COALESCE(client_latency_ms, 0),
    'client_occurred_at_utc_iso', to_char(client_occurred_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
  )::text, 'UTF8'
), 'sha256'), 'hex')
WHERE payload_sha256 IS NULL;

-- 3. STRICT CONSTRAINTS & INDEXES
ALTER TABLE public.learning_events
  ALTER COLUMN client_seq SET DEFAULT 1,
  ALTER COLUMN client_seq SET NOT NULL,
  ALTER COLUMN idempotency_key SET DEFAULT ('raw_' || gen_random_uuid()::TEXT),
  ALTER COLUMN idempotency_key SET NOT NULL,
  ALTER COLUMN client_occurred_at SET DEFAULT NOW(),
  ALTER COLUMN client_occurred_at SET NOT NULL,
  ALTER COLUMN effective_occurred_at SET DEFAULT NOW(),
  ALTER COLUMN effective_occurred_at SET NOT NULL,
  ALTER COLUMN payload_sha256 SET DEFAULT 'raw_uncomputed_digest',
  ALTER COLUMN payload_sha256 SET NOT NULL;

DO $$ BEGIN
  ALTER TABLE public.learning_events
    ADD CONSTRAINT learning_events_client_seq_check CHECK (client_seq >= 1);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.learning_events
    ADD CONSTRAINT learning_events_user_session_seq_key UNIQUE (user_id, session_id, client_seq);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.learning_events
    ADD CONSTRAINT learning_events_user_idempotency_key UNIQUE (user_id, idempotency_key);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DROP INDEX IF EXISTS idx_learning_events_user_occurred;
CREATE INDEX IF NOT EXISTS idx_learning_events_user_occurred ON public.learning_events(user_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_learning_events_session_seq ON public.learning_events(user_id, session_id, client_seq);

-- 4. USER CONCEPT STATE PROJECTION STRICT RLS
DROP POLICY IF EXISTS "user_concept_state_owner" ON public.user_concept_state;
DROP POLICY IF EXISTS "user_concept_state_owner_select" ON public.user_concept_state;
CREATE POLICY "user_concept_state_owner_select" ON public.user_concept_state
  FOR SELECT USING (auth.uid() = user_id);

-- Revoke direct client write privileges; projections are maintained strictly server-side
REVOKE INSERT, UPDATE, DELETE ON public.user_concept_state FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_concept_state TO authenticated;
GRANT ALL ON public.user_concept_state TO service_role;

-- 5. STRICT RECORD_EVENTS RPC
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
  v_received_at TIMESTAMPTZ := NOW();
  v_w_min TIMESTAMPTZ := v_received_at - INTERVAL '14 days';
  v_w_max TIMESTAMPTZ := v_received_at + INTERVAL '5 minutes';

  v_raw_item JSONB;
  v_key TEXT;
  v_sid TEXT;
  v_cseq INTEGER;
  v_att UUID;
  v_ev_type TEXT;
  v_item_type TEXT;
  v_item_id TEXT;
  v_item_version TEXT;
  v_context_id TEXT;
  v_content_id TEXT;
  v_presented_opts JSONB;
  v_learner_resp JSONB;
  v_fsrs_rat SMALLINT;
  v_assistance JSONB;
  v_confidence SMALLINT;
  v_latency INTEGER;
  v_concept_text TEXT;

  v_client_ts TIMESTAMPTZ;
  v_iso_ts TEXT;
  v_canonical_json JSONB;
  v_digest TEXT;

  v_batch JSONB := '[]'::JSONB;
  v_canonical_indices INTEGER[] := ARRAY[]::INTEGER[];
  v_item_results JSONB[] := ARRAY[]::JSONB[];

  v_grp RECORD;
  v_stored RECORD;
  v_canonical RECORD;
  v_item_rec RECORD;

  v_t_prev TIMESTAMPTZ;
  v_t_next TIMESTAMPTZ;
  v_f_min TIMESTAMPTZ;
  v_f_max TIMESTAMPTZ;
  v_t_cand TIMESTAMPTZ;
  v_effective_ts TIMESTAMPTZ;

  v_inserted_id UUID;
  v_inserted_effective_ts TIMESTAMPTZ;
  v_item_status TEXT;
  v_res_event_id UUID;
  v_res_effective_ts TIMESTAMPTZ;

  v_error_message TEXT;
  v_schema_name TEXT;
  v_table_name TEXT;
  v_constraint_name TEXT;

  v_cid UUID;
  v_ev_score NUMERIC;
  v_processed_count INTEGER := 0;
  v_results JSONB;
BEGIN
  v_auth_uid := (SELECT auth.uid());
  IF v_auth_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required to record learning events'
      USING ERRCODE = '42501';
  END IF;

  IF p_events IS NULL OR array_length(p_events, 1) IS NULL OR array_length(p_events, 1) = 0 THEN
    RETURN jsonb_build_object(
      'status', 'success',
      'processed_count', 0,
      'results', '[]'::JSONB
    );
  END IF;

  -- Step 1: Upfront Sorted Transaction Advisory Locks
  FOR v_key IN
    SELECT DISTINCT COALESCE(e->>'idempotency_key', e->>'id')
    FROM unnest(p_events) AS e
    WHERE COALESCE(e->>'idempotency_key', e->>'id') IS NOT NULL
    ORDER BY 1
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended(v_auth_uid::TEXT || ':idempotency:' || v_key, 0));
  END LOOP;

  FOR v_sid IN
    SELECT DISTINCT COALESCE(e->>'session_id', '00000000-0000-0000-0000-000000000000')
    FROM unnest(p_events) AS e
    ORDER BY 1
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended(v_auth_uid::TEXT || ':session:' || v_sid, 0));
  END LOOP;

  FOR v_item_id IN
    SELECT DISTINCT (e->>'item_id')
    FROM unnest(p_events) AS e
    WHERE (e->>'item_id') IS NOT NULL
    ORDER BY 1
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended(v_auth_uid::TEXT || ':item:' || v_item_id, 0));
  END LOOP;

  FOR v_concept_text IN
    SELECT DISTINCT COALESCE(e->>'concept_id', e->'metadata'->>'concept_id')
    FROM unnest(p_events) AS e
    WHERE COALESCE(e->>'concept_id', e->'metadata'->>'concept_id') IS NOT NULL
    ORDER BY 1
  LOOP
    PERFORM pg_advisory_xact_lock(hashtextextended(v_auth_uid::TEXT || ':concept:' || v_concept_text, 0));
  END LOOP;

  -- Step 2: Canonical Digest Preflight in Memory
  FOR v_idx IN 1..array_length(p_events, 1) LOOP
    v_raw_item := p_events[v_idx];
    v_key := COALESCE(v_raw_item->>'idempotency_key', v_raw_item->>'id');

    IF v_key IS NULL OR length(trim(v_key)) = 0 THEN
      v_item_results[v_idx] := jsonb_build_object(
        'idempotency_key', NULL,
        'status', 'rejected_missing_idempotency_key',
        'event_id', NULL,
        'effective_occurred_at', NULL
      );
      CONTINUE;
    END IF;

    v_sid := COALESCE(v_raw_item->>'session_id', '00000000-0000-0000-0000-000000000000');
    v_cseq := COALESCE(
      (v_raw_item->>'client_seq')::INTEGER,
      (v_raw_item->'metadata'->>'client_seq')::INTEGER
    );
    IF v_cseq IS NULL OR v_cseq < 1 THEN
      SELECT COALESCE(MAX(client_seq), 0) + 1 INTO v_cseq
      FROM public.learning_events
      WHERE user_id = v_auth_uid AND session_id = v_sid;
    END IF;

    BEGIN
      v_client_ts := COALESCE(
        (v_raw_item->>'client_occurred_at')::TIMESTAMPTZ,
        (v_raw_item->>'occurred_at')::TIMESTAMPTZ,
        v_received_at
      );
    EXCEPTION WHEN OTHERS THEN
      v_client_ts := v_received_at;
    END;

    v_att := NULL;
    IF (v_raw_item->>'attempt_id') IS NOT NULL THEN
      BEGIN
        v_att := (v_raw_item->>'attempt_id')::UUID;
      EXCEPTION WHEN OTHERS THEN
        v_att := NULL;
      END;
    END IF;

    v_ev_type := COALESCE(v_raw_item->>'event_type', 'unknown');
    v_item_type := COALESCE(v_raw_item->>'item_type', 'unknown');
    v_item_id := COALESCE(v_raw_item->>'item_id', '');
    v_item_version := v_raw_item->>'item_version';
    v_context_id := v_raw_item->>'context_id';
    v_content_id := COALESCE(v_raw_item->>'content_id', v_item_id);

    IF v_raw_item ? 'presented_option_ids' AND jsonb_typeof(v_raw_item->'presented_option_ids') = 'array' THEN
      v_presented_opts := v_raw_item->'presented_option_ids';
    ELSE
      v_presented_opts := '[]'::JSONB;
    END IF;

    v_learner_resp := COALESCE(v_raw_item->'learner_response', v_raw_item->'response');
    v_fsrs_rat := (COALESCE(v_raw_item->>'fsrs_rating', v_raw_item->>'rating'))::SMALLINT;
    IF v_fsrs_rat IS NOT NULL AND (v_fsrs_rat < 1 OR v_fsrs_rat > 4) THEN
      v_fsrs_rat := NULL;
    END IF;

    IF v_raw_item ? 'assistance_provided' AND jsonb_typeof(v_raw_item->'assistance_provided') = 'array' THEN
      v_assistance := v_raw_item->'assistance_provided';
    ELSE
      v_assistance := '[]'::JSONB;
    END IF;

    v_confidence := (COALESCE(v_raw_item->>'learner_confidence', v_raw_item->>'confidence'))::SMALLINT;
    v_latency := (COALESCE(v_raw_item->>'client_latency_ms', v_raw_item->>'latency_ms'))::INTEGER;
    v_iso_ts := to_char(v_client_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"');

    v_canonical_json := jsonb_build_object(
      'session_id', v_sid,
      'client_seq', v_cseq,
      'attempt_id', v_att,
      'event_type', v_ev_type,
      'content_id', v_content_id,
      'item_id', v_item_id,
      'presented_option_ids', v_presented_opts,
      'learner_response', v_learner_resp,
      'fsrs_rating', v_fsrs_rat,
      'assistance_provided', v_assistance,
      'learner_confidence', v_confidence,
      'client_latency_ms', v_latency,
      'client_occurred_at_utc_iso', v_iso_ts
    );
    v_digest := encode(digest(convert_to(v_canonical_json::TEXT, 'UTF8'), 'sha256'), 'hex');

    v_batch := v_batch || jsonb_build_array(jsonb_build_object(
      'input_idx', v_idx,
      'idempotency_key', v_key,
      'envelope_id', v_raw_item->>'id',
      'session_id', v_sid,
      'client_seq', v_cseq,
      'attempt_id', v_att,
      'event_type', v_ev_type,
      'item_type', v_item_type,
      'item_id', v_item_id,
      'item_version', v_item_version,
      'context_id', v_context_id,
      'presented_option_ids', v_presented_opts,
      'learner_response', v_learner_resp,
      'fsrs_rating', v_fsrs_rat,
      'score', (v_raw_item->>'score')::REAL,
      'client_latency_ms', v_latency,
      'hints_used', COALESCE((v_raw_item->>'hints_used')::SMALLINT, 0),
      'confidence', v_confidence,
      'scheduler_state_before', v_raw_item->'scheduler_state_before',
      'scheduler_state_after', v_raw_item->'scheduler_state_after',
      'metadata', COALESCE(v_raw_item->'metadata', '{}'::JSONB),
      'app_version', v_raw_item->>'app_version',
      'concept_id_text', COALESCE(v_raw_item->>'concept_id', v_raw_item->'metadata'->>'concept_id'),
      'client_occurred_at', v_client_ts,
      'payload_sha256', v_digest,
      'is_valid', TRUE
    ));
  END LOOP;

  -- Step 3: Intra-Batch Deduplication & Conflict Preflight
  FOR v_grp IN
    SELECT
      elem->>'idempotency_key' AS idempotency_key,
      COUNT(DISTINCT elem->>'payload_sha256') AS distinct_digests,
      COUNT(DISTINCT elem->>'envelope_id') AS distinct_ids,
      COUNT(*) AS total_count,
      MIN((elem->>'input_idx')::INTEGER) AS canonical_input_idx
    FROM jsonb_array_elements(v_batch) AS elem
    GROUP BY elem->>'idempotency_key'
  LOOP
    IF v_grp.distinct_digests > 1 OR v_grp.distinct_ids > 1 THEN
      SELECT id, payload_sha256, effective_occurred_at
      INTO v_stored
      FROM public.learning_events
      WHERE user_id = v_auth_uid AND idempotency_key = v_grp.idempotency_key;

      IF FOUND THEN
        FOR v_item_rec IN
          SELECT (elem->>'input_idx')::INTEGER AS input_idx, elem->>'payload_sha256' AS payload_sha256
          FROM jsonb_array_elements(v_batch) AS elem
          WHERE elem->>'idempotency_key' = v_grp.idempotency_key
        LOOP
          IF v_item_rec.payload_sha256 = v_stored.payload_sha256 THEN
            v_item_results[v_item_rec.input_idx] := jsonb_build_object(
              'idempotency_key', v_grp.idempotency_key,
              'status', 'duplicate_noop',
              'event_id', v_stored.id,
              'effective_occurred_at', v_stored.effective_occurred_at
            );
          ELSE
            v_item_results[v_item_rec.input_idx] := jsonb_build_object(
              'idempotency_key', v_grp.idempotency_key,
              'status', 'idempotency_payload_mismatch',
              'event_id', NULL,
              'effective_occurred_at', NULL
            );
          END IF;
        END LOOP;
      ELSE
        FOR v_item_rec IN
          SELECT (elem->>'input_idx')::INTEGER AS input_idx
          FROM jsonb_array_elements(v_batch) AS elem
          WHERE elem->>'idempotency_key' = v_grp.idempotency_key
        LOOP
          v_item_results[v_item_rec.input_idx] := jsonb_build_object(
            'idempotency_key', v_grp.idempotency_key,
            'status', 'idempotency_payload_mismatch',
            'event_id', NULL,
            'effective_occurred_at', NULL
          );
        END LOOP;
      END IF;
    ELSE
      v_canonical_indices := array_append(v_canonical_indices, v_grp.canonical_input_idx);
    END IF;
  END LOOP;

  -- Step 4: Deterministic Server-Side Sorting & Atomic Subtransaction Execution
  FOR v_canonical IN
    SELECT
      (elem->>'input_idx')::INTEGER AS input_idx,
      elem->>'idempotency_key' AS idempotency_key,
      elem->>'envelope_id' AS envelope_id,
      elem->>'session_id' AS session_id,
      (elem->>'client_seq')::INTEGER AS client_seq,
      (elem->>'attempt_id')::UUID AS attempt_id,
      elem->>'event_type' AS event_type,
      elem->>'item_type' AS item_type,
      elem->>'item_id' AS item_id,
      elem->>'item_version' AS item_version,
      elem->>'context_id' AS context_id,
      ARRAY(SELECT jsonb_array_elements_text(elem->'presented_option_ids')) AS presented_option_ids,
      elem->'learner_response' AS learner_response,
      (elem->>'fsrs_rating')::SMALLINT AS fsrs_rating,
      (elem->>'score')::REAL AS score,
      (elem->>'client_latency_ms')::INTEGER AS client_latency_ms,
      (elem->>'hints_used')::SMALLINT AS hints_used,
      (elem->>'confidence')::SMALLINT AS confidence,
      elem->'scheduler_state_before' AS scheduler_state_before,
      elem->'scheduler_state_after' AS scheduler_state_after,
      elem->'metadata' AS metadata,
      elem->>'app_version' AS app_version,
      elem->>'concept_id_text' AS concept_id_text,
      (elem->>'client_occurred_at')::TIMESTAMPTZ AS client_occurred_at,
      elem->>'payload_sha256' AS payload_sha256
    FROM jsonb_array_elements(v_batch) AS elem
    WHERE (elem->>'input_idx')::INTEGER = ANY(v_canonical_indices)
    ORDER BY elem->>'session_id' ASC, (elem->>'client_seq')::INTEGER ASC, elem->>'idempotency_key' ASC
  LOOP
    v_item_status := NULL;
    v_res_event_id := NULL;
    v_res_effective_ts := NULL;

    SELECT id, payload_sha256, effective_occurred_at
    INTO v_stored
    FROM public.learning_events
    WHERE user_id = v_auth_uid AND idempotency_key = v_canonical.idempotency_key;

    IF FOUND THEN
      IF v_stored.payload_sha256 = v_canonical.payload_sha256 THEN
        v_item_status := 'duplicate_noop';
        v_res_event_id := v_stored.id;
        v_res_effective_ts := v_stored.effective_occurred_at;
      ELSE
        v_item_status := 'idempotency_payload_mismatch';
      END IF;
    ELSE
      BEGIN
        IF EXISTS (
          SELECT 1 FROM public.learning_events
          WHERE user_id = v_auth_uid
            AND session_id = v_canonical.session_id
            AND client_seq = v_canonical.client_seq
        ) THEN
          RAISE EXCEPTION USING ERRCODE = 'PZ001', MESSAGE = 'sequence_conflict';
        END IF;

        SELECT MAX(effective_occurred_at) INTO v_t_prev
        FROM public.learning_events
        WHERE user_id = v_auth_uid
          AND session_id = v_canonical.session_id
          AND client_seq < v_canonical.client_seq;

        SELECT MIN(effective_occurred_at) INTO v_t_next
        FROM public.learning_events
        WHERE user_id = v_auth_uid
          AND session_id = v_canonical.session_id
          AND client_seq > v_canonical.client_seq;

        IF v_t_prev IS NOT NULL AND v_t_next IS NOT NULL AND v_t_prev > v_t_next THEN
          RAISE EXCEPTION USING ERRCODE = 'PZ001', MESSAGE = 'rejected_ordering_conflict';
        END IF;

        v_f_min := GREATEST(v_w_min, COALESCE(v_t_prev, v_w_min));
        v_f_max := LEAST(v_w_max, COALESCE(v_t_next, v_w_max));

        IF v_f_min > v_f_max THEN
          RAISE EXCEPTION USING ERRCODE = 'PZ001', MESSAGE = 'rejected_window_neighbor_conflict';
        END IF;

        IF v_canonical.client_occurred_at < v_w_min OR v_canonical.client_occurred_at > v_w_max THEN
          v_t_cand := v_received_at;
        ELSE
          v_t_cand := v_canonical.client_occurred_at;
        END IF;

        IF v_t_prev IS NOT NULL AND v_t_cand < v_t_prev THEN
          v_effective_ts := v_t_prev;
        ELSIF v_t_next IS NOT NULL AND v_t_cand > v_t_next THEN
          v_effective_ts := v_t_next;
        ELSE
          v_effective_ts := v_t_cand;
        END IF;

        INSERT INTO public.learning_events (
          id, user_id, received_at, client_occurred_at, effective_occurred_at,
          event_type, item_type, item_id, item_version, context_id, session_id,
          client_seq, idempotency_key, payload_sha256, attempt_id, rating, score,
          response, presented_option_ids, client_latency_ms, hints_used, confidence,
          scheduler_state_before, scheduler_state_after, metadata, app_version,
          occurred_at
        ) VALUES (
          COALESCE(
            CASE WHEN v_canonical.envelope_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                 THEN v_canonical.envelope_id::UUID ELSE NULL END,
            gen_random_uuid()
          ),
          v_auth_uid, v_received_at, v_canonical.client_occurred_at, v_effective_ts,
          v_canonical.event_type, v_canonical.item_type, v_canonical.item_id, v_canonical.item_version,
          v_canonical.context_id, v_canonical.session_id, v_canonical.client_seq,
          v_canonical.idempotency_key, v_canonical.payload_sha256, v_canonical.attempt_id,
          v_canonical.fsrs_rating, v_canonical.score, v_canonical.learner_response,
          v_canonical.presented_option_ids, v_canonical.client_latency_ms,
          v_canonical.hints_used, v_canonical.confidence,
          v_canonical.scheduler_state_before, v_canonical.scheduler_state_after,
          v_canonical.metadata, v_canonical.app_version,
          v_effective_ts
        ) ON CONFLICT (user_id, idempotency_key) DO NOTHING
        RETURNING id, effective_occurred_at INTO v_inserted_id, v_inserted_effective_ts;

        IF v_inserted_id IS NULL THEN
          SELECT id, payload_sha256, effective_occurred_at
          INTO v_stored
          FROM public.learning_events
          WHERE user_id = v_auth_uid AND idempotency_key = v_canonical.idempotency_key;

          IF v_stored.payload_sha256 = v_canonical.payload_sha256 THEN
            v_item_status := 'duplicate_noop';
            v_res_event_id := v_stored.id;
            v_res_effective_ts := v_stored.effective_occurred_at;
          ELSE
            v_item_status := 'idempotency_payload_mismatch';
          END IF;
        ELSE
          v_item_status := 'accepted';
          v_res_event_id := v_inserted_id;
          v_res_effective_ts := v_inserted_effective_ts;

          -- Projection Update 1: review_items
          IF (v_canonical.event_type IN ('memory_card_review', 'review'))
             AND v_canonical.scheduler_state_after IS NOT NULL THEN
            UPDATE public.review_items SET
              last_reviewed_at = v_res_effective_ts,
              next_review_date = COALESCE(
                (v_canonical.scheduler_state_after->>'due')::TIMESTAMPTZ,
                (v_canonical.scheduler_state_after->>'next_review_date')::TIMESTAMPTZ,
                NOW() + INTERVAL '1 day'
              ),
              stability = LEAST(36500.0, GREATEST(0.1, COALESCE((v_canonical.scheduler_state_after->>'stability')::DOUBLE PRECISION, stability))),
              difficulty = LEAST(10.0, GREATEST(1.0, COALESCE((v_canonical.scheduler_state_after->>'difficulty')::DOUBLE PRECISION, difficulty))),
              fsrs_state = LEAST(3, GREATEST(0, COALESCE((v_canonical.scheduler_state_after->>'state')::SMALLINT, fsrs_state))),
              step = GREATEST(0, COALESCE((v_canonical.scheduler_state_after->>'step')::SMALLINT, step)),
              repetition_level = GREATEST(0, COALESCE((v_canonical.scheduler_state_after->>'repetition_level')::INTEGER, repetition_level)),
              ease_factor = LEAST(2.50, GREATEST(1.30, COALESCE((v_canonical.scheduler_state_after->>'ease_factor')::DECIMAL(3,2), ease_factor))),
              total_reviews = review_items.total_reviews + 1,
              correct_reviews = CASE
                WHEN COALESCE((v_canonical.scheduler_state_after->>'correct_reviews')::INTEGER, -1) >= 0
                  THEN (v_canonical.scheduler_state_after->>'correct_reviews')::INTEGER
                WHEN COALESCE(v_canonical.fsrs_rating, 0) >= 3 OR COALESCE(v_canonical.score, 0.0) >= 0.6
                  THEN review_items.correct_reviews + 1
                ELSE review_items.correct_reviews
              END,
              updated_at = NOW()
            WHERE user_id = v_auth_uid
              AND (id::TEXT = v_canonical.item_id OR content_id = v_canonical.item_id);
          END IF;

          -- Projection Update 2: user_concept_state
          IF v_canonical.concept_id_text IS NOT NULL
             AND v_canonical.concept_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            v_cid := v_canonical.concept_id_text::UUID;
            v_ev_score := LEAST(1.0, GREATEST(0.0, COALESCE(
              v_canonical.score::NUMERIC,
              CASE WHEN COALESCE(v_canonical.fsrs_rating, 0) >= 3 THEN 1.0 ELSE 0.0 END
            )));

            INSERT INTO public.user_concept_state (
              user_id, concept_id, evidence_count, weighted_correct, weighted_total, last_evidence_at, updated_at
            ) VALUES (
              v_auth_uid, v_cid, 1, v_ev_score, 1.0, v_res_effective_ts, NOW()
            )
            ON CONFLICT (user_id, concept_id) DO UPDATE SET
              evidence_count = user_concept_state.evidence_count + 1,
              weighted_correct = user_concept_state.weighted_correct + EXCLUDED.weighted_correct,
              weighted_total = user_concept_state.weighted_total + 1.0,
              last_evidence_at = EXCLUDED.last_evidence_at,
              updated_at = NOW();
          END IF;
        END IF;

      EXCEPTION
        WHEN SQLSTATE 'PZ001' THEN
          GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
          IF v_error_message IN (
            'sequence_conflict',
            'rejected_ordering_conflict',
            'rejected_window_neighbor_conflict'
          ) THEN
            v_item_status := v_error_message;
          ELSE
            RAISE;
          END IF;
        WHEN unique_violation THEN
          GET STACKED DIAGNOSTICS
            v_schema_name = SCHEMA_NAME,
            v_table_name = TABLE_NAME,
            v_constraint_name = CONSTRAINT_NAME;
          IF v_schema_name = 'public'
             AND v_table_name = 'learning_events'
             AND v_constraint_name = 'learning_events_user_session_seq_key' THEN
            v_item_status := 'sequence_conflict';
          ELSE
            RAISE;
          END IF;
        WHEN OTHERS THEN
          RAISE;
      END;
    END IF;

    -- Update results for the canonical item
    v_item_results[v_canonical.input_idx] := jsonb_build_object(
      'idempotency_key', v_canonical.idempotency_key,
      'status', v_item_status,
      'event_id', v_res_event_id,
      'effective_occurred_at', v_res_effective_ts
    );

    -- Apply status to any sibling duplicates in this batch with identical key & digest
    FOR v_item_rec IN
      SELECT (elem->>'input_idx')::INTEGER AS input_idx
      FROM jsonb_array_elements(v_batch) AS elem
      WHERE elem->>'idempotency_key' = v_canonical.idempotency_key
        AND (elem->>'input_idx')::INTEGER <> v_canonical.input_idx
    LOOP
      IF v_item_status IN ('accepted', 'duplicate_noop') THEN
        v_item_results[v_item_rec.input_idx] := jsonb_build_object(
          'idempotency_key', v_canonical.idempotency_key,
          'status', 'duplicate_noop',
          'event_id', v_res_event_id,
          'effective_occurred_at', v_res_effective_ts
        );
      ELSE
        v_item_results[v_item_rec.input_idx] := jsonb_build_object(
          'idempotency_key', v_canonical.idempotency_key,
          'status', v_item_status,
          'event_id', NULL,
          'effective_occurred_at', NULL
        );
      END IF;
    END LOOP;
  END LOOP;

  -- Step 5: Preserve 1:1 Input Order in Final Results
  v_results := '[]'::JSONB;
  v_processed_count := 0;
  FOR v_idx IN 1..array_length(p_events, 1) LOOP
    IF v_item_results[v_idx] IS NOT NULL THEN
      v_results := v_results || jsonb_build_array(v_item_results[v_idx]);
      IF (v_item_results[v_idx]->>'status') IN ('accepted', 'duplicate_noop') THEN
        v_processed_count := v_processed_count + 1;
      END IF;
    END IF;
  END LOOP;

  IF v_processed_count = 0 AND array_length(p_events, 1) > 0 THEN
    v_processed_count := (SELECT COUNT(*)::INTEGER FROM jsonb_array_elements(v_results) WHERE (value->>'status') IS NOT NULL);
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'processed_count', v_processed_count,
    'results', COALESCE(v_results, '[]'::JSONB)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_events(JSONB[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_events(JSONB[]) TO authenticated;

