-- TEL-01B / TEL-04A: Dedicated per-context Fast preference storage and atomic
-- compare-and-set RPC.
--
-- Architectural guarantees (§6.3 of TEL v0.5 Master Specification):
-- 1. Strictly separated from public.learning_contexts.scope_config and
--    whole-context last_active_at upserts.
-- 2. One row per learning_context (context_id PK + FK ON DELETE CASCADE).
-- 3. Owner-scoped RLS (user_id = auth.uid()); no direct client INSERT/UPDATE
--    grants so all writes must pass through the atomic compare-and-set RPC.
-- 4. Atomic compare-and-set via public.update_context_fast_preferences with
--    per-context transaction advisory lock, idempotency replay via
--    p_mutation_id, and explicit conflict reporting without clobbering.

CREATE TABLE IF NOT EXISTS public.context_fast_preferences (
  context_id uuid PRIMARY KEY
    REFERENCES public.learning_contexts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL
    REFERENCES auth.users(id) ON DELETE CASCADE,
  schema_version integer NOT NULL DEFAULT 1
    CHECK (schema_version >= 1),
  strategy text NOT NULL DEFAULT 'standard'
    CHECK (strategy IN ('standard', 'fast')),
  revision integer NOT NULL DEFAULT 0
    CHECK (revision >= 0),
  last_mutation_id text
    CHECK (last_mutation_id IS NULL OR char_length(btrim(last_mutation_id)) BETWEEN 1 AND 160),
  optional_total_minutes integer
    CHECK (optional_total_minutes IS NULL OR optional_total_minutes BETWEEN 1 AND 60000),
  optional_deadline timestamptz,
  manual_skipped_activity_ids text[] NOT NULL DEFAULT ARRAY[]::text[],
  updated_at_server timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS context_fast_preferences_user_idx
  ON public.context_fast_preferences (user_id, updated_at_server DESC);

ALTER TABLE public.context_fast_preferences ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.context_fast_preferences FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.context_fast_preferences TO authenticated;
GRANT ALL ON TABLE public.context_fast_preferences TO service_role;

DROP POLICY IF EXISTS context_fast_preferences_select_own
  ON public.context_fast_preferences;
CREATE POLICY context_fast_preferences_select_own
  ON public.context_fast_preferences
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS context_fast_preferences_delete_own
  ON public.context_fast_preferences;

CREATE OR REPLACE FUNCTION public.update_context_fast_preferences(
  p_context_id uuid,
  p_expected_revision integer,
  p_mutation_id text,
  p_strategy text,
  p_optional_total_minutes integer DEFAULT NULL,
  p_optional_deadline timestamptz DEFAULT NULL,
  p_manual_skipped_activity_ids text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_context_owner uuid;
  v_now timestamptz := pg_catalog.now();
  v_clean_mutation_id text;
  v_skipped text[];
  v_existing public.context_fast_preferences%ROWTYPE;
  v_has_existing boolean := false;
BEGIN
  v_user := (SELECT auth.uid());
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated learner required'
      USING ERRCODE = '42501';
  END IF;

  IF p_context_id IS NULL THEN
    RAISE EXCEPTION 'p_context_id is required'
      USING ERRCODE = '22023';
  END IF;

  IF p_expected_revision IS NULL OR p_expected_revision < 0 THEN
    RAISE EXCEPTION 'p_expected_revision must be a non-negative integer'
      USING ERRCODE = '22023';
  END IF;

  v_clean_mutation_id := pg_catalog.btrim(COALESCE(p_mutation_id, ''));
  IF pg_catalog.char_length(v_clean_mutation_id) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'p_mutation_id must be between 1 and 160 characters'
      USING ERRCODE = '22023';
  END IF;

  IF p_strategy IS NULL OR p_strategy NOT IN ('standard', 'fast') THEN
    RAISE EXCEPTION 'p_strategy must be standard or fast'
      USING ERRCODE = '22023';
  END IF;

  IF p_optional_total_minutes IS NOT NULL
     AND (p_optional_total_minutes <= 0 OR p_optional_total_minutes > 60000) THEN
    RAISE EXCEPTION 'p_optional_total_minutes must be between 1 and 60000'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize concurrent compare-and-set calls for the same context across
  -- tabs and devices even before the initial row in context_fast_preferences exists.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('fast-pref:' || p_context_id::text, 0)
  );

  SELECT lc.user_id
    INTO v_context_owner
    FROM public.learning_contexts AS lc
   WHERE lc.id = p_context_id
     FOR SHARE;

  IF v_context_owner IS NULL OR v_context_owner <> v_user THEN
    RAISE EXCEPTION 'Learning context not found or not owned by caller'
      USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(
           pg_catalog.array_agg(DISTINCT s.trimmed ORDER BY s.trimmed),
           ARRAY[]::text[]
         )
    INTO v_skipped
    FROM (
      SELECT pg_catalog.btrim(elem) AS trimmed
        FROM pg_catalog.unnest(
          COALESCE(p_manual_skipped_activity_ids, ARRAY[]::text[])
        ) AS elem
    ) AS s
   WHERE pg_catalog.char_length(s.trimmed) > 0;

  IF COALESCE(pg_catalog.array_length(v_skipped, 1), 0) > 500 THEN
    RAISE EXCEPTION 'manual_skipped_activity_ids exceeds maximum length of 500'
      USING ERRCODE = '22023';
  END IF;

  SELECT cfp.*
    INTO v_existing
    FROM public.context_fast_preferences AS cfp
   WHERE cfp.context_id = p_context_id
     FOR UPDATE;

  v_has_existing := FOUND;

  IF NOT v_has_existing THEN
    -- Implicit baseline when no row exists yet is revision 0, strategy 'standard'.
    -- A first write with p_expected_revision <> 0 is a stale/invalid CAS expectation.
    IF p_expected_revision <> 0 THEN
      RETURN pg_catalog.jsonb_build_object(
        'conflict', true,
        'status', 'conflict',
        'expected_revision', p_expected_revision,
        'actual_revision', 0,
        'preference', pg_catalog.jsonb_build_object(
          'schema_version', 1,
          'context_id', p_context_id::text,
          'user_id', v_user::text,
          'strategy', 'standard',
          'revision', 0,
          'updated_at_server', pg_catalog.to_char(
            v_now AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          ),
          'last_mutation_id', NULL,
          'optional_total_minutes', NULL,
          'optional_deadline', NULL,
          'manual_skipped_activity_ids', '[]'::jsonb
        )
      );
    END IF;

    INSERT INTO public.context_fast_preferences (
      context_id,
      user_id,
      schema_version,
      strategy,
      revision,
      last_mutation_id,
      optional_total_minutes,
      optional_deadline,
      manual_skipped_activity_ids,
      updated_at_server
    )
    VALUES (
      p_context_id,
      v_user,
      1,
      p_strategy,
      1,
      v_clean_mutation_id,
      p_optional_total_minutes,
      p_optional_deadline,
      v_skipped,
      v_now
    )
    RETURNING * INTO v_existing;

    RETURN pg_catalog.jsonb_build_object(
      'conflict', false,
      'status', 'updated',
      'expected_revision', 0,
      'actual_revision', v_existing.revision,
      'preference', pg_catalog.jsonb_build_object(
        'schema_version', v_existing.schema_version,
        'context_id', v_existing.context_id::text,
        'user_id', v_existing.user_id::text,
        'strategy', v_existing.strategy,
        'revision', v_existing.revision,
        'updated_at_server', pg_catalog.to_char(
          v_existing.updated_at_server AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
        ),
        'last_mutation_id', v_existing.last_mutation_id,
        'optional_total_minutes', v_existing.optional_total_minutes,
        'optional_deadline', CASE
          WHEN v_existing.optional_deadline IS NULL THEN NULL
          ELSE pg_catalog.to_char(
            v_existing.optional_deadline AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          )
        END,
        'manual_skipped_activity_ids', pg_catalog.to_jsonb(
          v_existing.manual_skipped_activity_ids
        )
      )
    );
  END IF;

  -- Idempotent replay check: if the exact mutation was already applied, return
  -- the current authoritative record without incrementing revision.
  IF v_existing.last_mutation_id IS NOT NULL
     AND v_existing.last_mutation_id = v_clean_mutation_id THEN
    RETURN pg_catalog.jsonb_build_object(
      'conflict', false,
      'status', 'idempotent_replay',
      'expected_revision', p_expected_revision,
      'actual_revision', v_existing.revision,
      'preference', pg_catalog.jsonb_build_object(
        'schema_version', v_existing.schema_version,
        'context_id', v_existing.context_id::text,
        'user_id', v_existing.user_id::text,
        'strategy', v_existing.strategy,
        'revision', v_existing.revision,
        'updated_at_server', pg_catalog.to_char(
          v_existing.updated_at_server AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
        ),
        'last_mutation_id', v_existing.last_mutation_id,
        'optional_total_minutes', v_existing.optional_total_minutes,
        'optional_deadline', CASE
          WHEN v_existing.optional_deadline IS NULL THEN NULL
          ELSE pg_catalog.to_char(
            v_existing.optional_deadline AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          )
        END,
        'manual_skipped_activity_ids', pg_catalog.to_jsonb(
          v_existing.manual_skipped_activity_ids
        )
      )
    );
  END IF;

  -- Atomic compare-and-set check: reject stale expected_revision without overwriting.
  IF v_existing.revision <> p_expected_revision THEN
    RETURN pg_catalog.jsonb_build_object(
      'conflict', true,
      'status', 'conflict',
      'expected_revision', p_expected_revision,
      'actual_revision', v_existing.revision,
      'preference', pg_catalog.jsonb_build_object(
        'schema_version', v_existing.schema_version,
        'context_id', v_existing.context_id::text,
        'user_id', v_existing.user_id::text,
        'strategy', v_existing.strategy,
        'revision', v_existing.revision,
        'updated_at_server', pg_catalog.to_char(
          v_existing.updated_at_server AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
        ),
        'last_mutation_id', v_existing.last_mutation_id,
        'optional_total_minutes', v_existing.optional_total_minutes,
        'optional_deadline', CASE
          WHEN v_existing.optional_deadline IS NULL THEN NULL
          ELSE pg_catalog.to_char(
            v_existing.optional_deadline AT TIME ZONE 'UTC',
            'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
          )
        END,
        'manual_skipped_activity_ids', pg_catalog.to_jsonb(
          v_existing.manual_skipped_activity_ids
        )
      )
    );
  END IF;

  UPDATE public.context_fast_preferences AS cfp
     SET strategy = p_strategy,
         revision = v_existing.revision + 1,
         last_mutation_id = v_clean_mutation_id,
         optional_total_minutes = p_optional_total_minutes,
         optional_deadline = p_optional_deadline,
         manual_skipped_activity_ids = v_skipped,
         updated_at_server = v_now
   WHERE cfp.context_id = p_context_id
   RETURNING * INTO v_existing;

  RETURN pg_catalog.jsonb_build_object(
    'conflict', false,
    'status', 'updated',
    'expected_revision', p_expected_revision,
    'actual_revision', v_existing.revision,
    'preference', pg_catalog.jsonb_build_object(
      'schema_version', v_existing.schema_version,
      'context_id', v_existing.context_id::text,
      'user_id', v_existing.user_id::text,
      'strategy', v_existing.strategy,
      'revision', v_existing.revision,
      'updated_at_server', pg_catalog.to_char(
        v_existing.updated_at_server AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      ),
      'last_mutation_id', v_existing.last_mutation_id,
      'optional_total_minutes', v_existing.optional_total_minutes,
      'optional_deadline', CASE
        WHEN v_existing.optional_deadline IS NULL THEN NULL
        ELSE pg_catalog.to_char(
          v_existing.optional_deadline AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
        )
      END,
      'manual_skipped_activity_ids', pg_catalog.to_jsonb(
        v_existing.manual_skipped_activity_ids
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.update_context_fast_preferences(
  uuid, integer, text, text, integer, timestamptz, text[]
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.update_context_fast_preferences(
  uuid, integer, text, text, integer, timestamptz, text[]
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.update_context_fast_preferences(
  uuid, integer, text, text, integer, timestamptz, text[]
) TO service_role;
