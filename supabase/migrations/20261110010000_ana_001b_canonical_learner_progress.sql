-- ANA-001B: canonical learner progress storage, separate from scored evidence.
-- Additive only. Never mutate public.learning_events or the legacy user_progress.
-- Learner identity comes from auth.uid(); no direct client DML is granted.
-- Source of truth: private append-only events, projected by this vetted RPC.
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.learner_progress_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key text NOT NULL CHECK (char_length(idempotency_key) BETWEEN 1 AND 150),
  payload_sha256 text NOT NULL CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
  event_type text NOT NULL CHECK (event_type IN
    ('lesson_completed', 'lesson_uncompleted', 'active_study_interval')),
  content_kind text NOT NULL CHECK (content_kind IN
    ('legacy_lesson', 'bundled_asset_lesson', 'curriculum_node_lesson')),
  content_id text NOT NULL CHECK (char_length(content_id) BETWEEN 1 AND 128),
  version_key text NOT NULL CHECK (char_length(version_key) BETWEEN 1 AND 128),
  occurred_at timestamptz NOT NULL,
  interval_start timestamptz,
  interval_end timestamptz,
  reporting_date_utc date NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT learner_progress_events_user_key UNIQUE (user_id, idempotency_key),
  CONSTRAINT learner_progress_events_interval_shape CHECK (
    (event_type = 'active_study_interval'
      AND interval_start IS NOT NULL AND interval_end IS NOT NULL
      AND interval_end > interval_start)
    OR
    (event_type <> 'active_study_interval'
      AND interval_start IS NULL AND interval_end IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS learner_progress_events_lookup_idx
  ON private.learner_progress_events
  (user_id, content_kind, content_id, version_key, occurred_at DESC);

ALTER TABLE private.learner_progress_events ENABLE ROW LEVEL SECURITY;
-- Do not modify grants on the preexisting private schema: other features use it.
REVOKE ALL ON TABLE private.learner_progress_events FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;
GRANT ALL ON TABLE private.learner_progress_events TO service_role;

-- Daily event projection is intentionally not a score or proof of learning.
CREATE TABLE IF NOT EXISTS public.learner_activity_progress (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content_kind text NOT NULL CHECK (content_kind IN
    ('legacy_lesson', 'bundled_asset_lesson', 'curriculum_node_lesson')),
  content_id text NOT NULL CHECK (char_length(content_id) BETWEEN 1 AND 128),
  version_key text NOT NULL CHECK (char_length(version_key) BETWEEN 1 AND 128),
  reporting_date_utc date NOT NULL,
  completed boolean NOT NULL DEFAULT false,
  active_seconds integer CHECK (active_seconds IS NULL OR active_seconds BETWEEN 0 AND 86400),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT learner_activity_progress_owner_content_day_key
    UNIQUE (user_id, content_kind, content_id, version_key, reporting_date_utc)
);

CREATE INDEX IF NOT EXISTS learner_activity_progress_owner_day_idx
  ON public.learner_activity_progress (user_id, reporting_date_utc DESC);
ALTER TABLE public.learner_activity_progress ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.learner_activity_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.learner_activity_progress TO authenticated;
GRANT ALL ON TABLE public.learner_activity_progress TO service_role;
DROP POLICY IF EXISTS learner_activity_progress_select_own
  ON public.learner_activity_progress;
CREATE POLICY learner_activity_progress_select_own
  ON public.learner_activity_progress FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.record_learner_progress(p_events jsonb[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user uuid;
  v_received timestamptz := now();
  v_item jsonb;
  v_key text;
  v_type text;
  v_kind text;
  v_content text;
  v_version text;
  v_ts timestamptz;
  v_start timestamptz;
  v_end timestamptz;
  v_day date;
  v_day_from date;
  v_day_to date;
  v_begin timestamptz;
  v_finish timestamptz;
  v_digest text;
  v_existing_digest text;
  v_canonical jsonb;
  v_id uuid;
  v_status text;
  v_completed boolean;
  v_active_seconds integer;
  v_results jsonb := '[]'::jsonb;
  v_accepted integer := 0;
  v_replayed integer := 0;
BEGIN
  v_user := (SELECT auth.uid());
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated learner required'
      USING ERRCODE = '42501';
  END IF;
  IF p_events IS NULL OR coalesce(array_length(p_events, 1), 0) = 0 THEN
    RETURN jsonb_build_object('status','success','processed_count',0,
      'accepted_count',0,'replayed_count',0,'results','[]'::jsonb);
  END IF;
  IF array_length(p_events, 1) > 25 THEN
    RAISE EXCEPTION 'Progress batch exceeds 25 events'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize per-user projections across tabs and devices. This prevents
  -- concurrent recomputation from publishing stale duration totals.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('learner-progress:' || v_user::text, 0));

  FOR v_i IN 1..array_length(p_events, 1) LOOP
    v_item := p_events[v_i];
    IF v_item IS NULL OR jsonb_typeof(v_item) <> 'object'
       OR pg_catalog.octet_length(v_item::text) > 2048 THEN
      RAISE EXCEPTION 'Malformed or oversized progress event'
        USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_catalog.jsonb_object_keys(v_item) AS k(name)
      WHERE k.name <> ALL(ARRAY[
        'idempotency_key','event_type','content_kind','content_id',
        'version_key','occurred_at','interval_start','interval_end'
      ])
    ) THEN
      RAISE EXCEPTION 'Unknown progress event field'
        USING ERRCODE = '22023';
    END IF;
    v_key := v_item->>'idempotency_key';
    v_type := v_item->>'event_type';
    v_kind := v_item->>'content_kind';
    v_content := v_item->>'content_id';
    v_version := v_item->>'version_key';
    IF coalesce(char_length(v_key),0) NOT BETWEEN 1 AND 150
       OR v_type IS NULL OR v_type NOT IN ('lesson_completed','lesson_uncompleted','active_study_interval')
       OR v_kind IS NULL OR v_kind NOT IN ('legacy_lesson','bundled_asset_lesson','curriculum_node_lesson')
       OR coalesce(char_length(v_content),0) NOT BETWEEN 1 AND 128
       OR coalesce(char_length(v_version),0) NOT BETWEEN 1 AND 128
       OR v_content !~ '^[A-Za-z0-9_-]+$'
       OR v_version !~ '^[A-Za-z0-9_.:-]+$'
       OR v_item->>'occurred_at' IS NULL THEN
      RAISE EXCEPTION 'Invalid progress event fields'
        USING ERRCODE = '22023';
    END IF;
    -- Reject UUID-looking IDs that do not correspond to an actual legacy
    -- lesson, without requiring bundled lessons to exist in public.lessons.
    IF v_kind='legacy_lesson' THEN
      IF v_content !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         OR NOT EXISTS (SELECT 1 FROM public.lessons WHERE id=v_content::uuid) THEN
        RAISE EXCEPTION 'Unknown legacy lesson id' USING ERRCODE='22023';
      END IF;
    END IF;
    BEGIN
      v_ts := (v_item->>'occurred_at')::timestamptz;
      IF v_type='active_study_interval' THEN
        v_start := (v_item->>'interval_start')::timestamptz;
        v_end := (v_item->>'interval_end')::timestamptz;
      ELSE
        v_start := NULL;
        v_end := NULL;
      END IF;
    EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow
        OR invalid_text_representation THEN
      RAISE EXCEPTION 'Invalid progress timestamp' USING ERRCODE='22023';
    END;
    IF v_ts IS NULL OR v_ts < v_received - interval '7 days'
       OR v_ts > v_received + interval '5 minutes' THEN
      RAISE EXCEPTION 'Progress timestamp outside permitted window'
        USING ERRCODE='22023';
    END IF;
    IF v_type='active_study_interval' THEN
      IF v_start IS NULL OR v_end IS NULL OR v_end <= v_start
         OR v_end - v_start > interval '120 seconds'
         OR v_start < v_received - interval '7 days'
         OR v_end > v_received + interval '5 minutes'
         OR v_ts <> v_end THEN
        RAISE EXCEPTION 'Invalid or unbounded active-study interval'
          USING ERRCODE='22023';
      END IF;
      v_day_from := (v_start AT TIME ZONE 'UTC')::date;
      v_day_to := ((v_end - interval '1 microsecond')
        AT TIME ZONE 'UTC')::date;
    ELSE
      IF v_item ? 'interval_start' OR v_item ? 'interval_end' THEN
        RAISE EXCEPTION 'Completion must not claim active seconds'
          USING ERRCODE='22023';
      END IF;
      v_day_from := (v_ts AT TIME ZONE 'UTC')::date;
      v_day_to := v_day_from;
    END IF;

    v_canonical := pg_catalog.jsonb_build_object(
      'event_type',v_type,'content_kind',v_kind,'content_id',v_content,
      'version_key',v_version,
      'occurred_at',pg_catalog.to_char(v_ts AT TIME ZONE 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
      'interval_start',CASE WHEN v_start IS NULL THEN NULL ELSE
        pg_catalog.to_char(v_start AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END,
      'interval_end',CASE WHEN v_end IS NULL THEN NULL ELSE
        pg_catalog.to_char(v_end AT TIME ZONE 'UTC',
          'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') END
    );
    v_digest := pg_catalog.encode(
      extensions.digest(pg_catalog.convert_to(v_canonical::text,'UTF8'),'sha256'),'hex');

    v_id := NULL;
    INSERT INTO private.learner_progress_events
      (user_id,idempotency_key,payload_sha256,event_type,
       content_kind,content_id,version_key,occurred_at,
       interval_start,interval_end,reporting_date_utc)
    VALUES (v_user,v_key,v_digest,v_type,v_kind,v_content,v_version,
      v_ts,v_start,v_end,v_day_from)
    ON CONFLICT (user_id,idempotency_key) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      SELECT e.payload_sha256 INTO v_existing_digest
        FROM private.learner_progress_events AS e
       WHERE e.user_id=v_user AND e.idempotency_key=v_key;
      v_status := CASE WHEN v_existing_digest=v_digest
        THEN 'duplicate_noop' ELSE 'idempotency_payload_mismatch' END;
      IF v_status='duplicate_noop' THEN
        v_replayed := v_replayed+1;
      END IF;
    ELSE
      v_status := 'accepted';
      v_accepted := v_accepted+1;

      -- Recompute the affected event days AND any later existing day rows.
      -- A late completion/reversal must not leave later projections stale.
      FOR v_day IN
        SELECT affected.day FROM (
          SELECT d::date AS day
          FROM pg_catalog.generate_series(v_day_from::timestamp,
            v_day_to::timestamp, interval '1 day') AS d
          UNION
          SELECT p.reporting_date_utc
          FROM public.learner_activity_progress AS p
          WHERE p.user_id=v_user AND p.content_kind=v_kind
            AND p.content_id=v_content AND p.version_key=v_version
            AND p.reporting_date_utc >= v_day_from
        ) AS affected
        ORDER BY affected.day
      LOOP
        v_begin := (v_day::timestamp AT TIME ZONE 'UTC');
        v_finish := ((v_day + 1)::timestamp AT TIME ZONE 'UTC');

        SELECT (e.event_type='lesson_completed') INTO v_completed
          FROM private.learner_progress_events AS e
         WHERE e.user_id=v_user AND e.content_kind=v_kind
           AND e.content_id=v_content AND e.version_key=v_version
           AND e.event_type IN ('lesson_completed','lesson_uncompleted')
           AND e.occurred_at < v_finish
         ORDER BY e.occurred_at DESC,e.received_at DESC,e.id DESC
         LIMIT 1;

        WITH slices AS (
          SELECT pg_catalog.tstzrange(
            greatest(e.interval_start,v_begin),
            least(e.interval_end,v_finish),'[)') AS span
          FROM private.learner_progress_events AS e
          WHERE e.user_id=v_user AND e.content_kind=v_kind
            AND e.content_id=v_content AND e.version_key=v_version
            AND e.event_type='active_study_interval'
            AND e.interval_start < v_finish AND e.interval_end > v_begin
        ), merged AS (
          SELECT pg_catalog.unnest(pg_catalog.range_agg(span)) AS span
          FROM slices
        )
        SELECT pg_catalog.sum(
          extract(epoch FROM (upper(span)-lower(span))))::integer
          INTO v_active_seconds
          FROM merged;

        INSERT INTO public.learner_activity_progress
          (user_id,content_kind,content_id,version_key,
           reporting_date_utc,completed,active_seconds,updated_at)
        VALUES (v_user,v_kind,v_content,v_version,v_day,
          coalesce(v_completed,false),v_active_seconds,v_received)
        ON CONFLICT (user_id,content_kind,content_id,version_key,
                     reporting_date_utc) DO UPDATE
        SET completed=excluded.completed,
            active_seconds=excluded.active_seconds,
            updated_at=excluded.updated_at;
      END LOOP;
    END IF;
    v_results := v_results || jsonb_build_array(
      jsonb_build_object('idempotency_key',v_key,'status',v_status,
        'event_id',v_id));
  END LOOP;
  RETURN jsonb_build_object('status','success',
    'processed_count',v_accepted+v_replayed,
    'accepted_count',v_accepted,'replayed_count',v_replayed,
    'results',v_results);
END;
$$;

-- Function creation grants EXECUTE to PUBLIC by default. Close it explicitly.
REVOKE ALL ON FUNCTION public.record_learner_progress(jsonb[])
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_learner_progress(jsonb[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_learner_progress(jsonb[]) TO service_role;
