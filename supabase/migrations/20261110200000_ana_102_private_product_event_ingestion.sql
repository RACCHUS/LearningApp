-- ANA-102 / ANA-105: opt-in, privacy-gated product event ingestion.
-- Feature remains OFF in Flutter. Schema is intentionally NOT Data API exposed.
-- This migration does not collect events until trusted account eligibility AND
-- explicit server-stored user consent are present.
CREATE SCHEMA IF NOT EXISTS analytics;
REVOKE ALL ON SCHEMA analytics FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA analytics TO service_role;

CREATE TABLE analytics.product_consents (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  consented boolean NOT NULL DEFAULT false,
  changed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE analytics.product_consents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.product_consents FROM PUBLIC, anon, authenticated;
GRANT ALL ON analytics.product_consents TO service_role;

CREATE TABLE analytics.product_events (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id uuid NOT NULL,
  session_id uuid NOT NULL,
  event_name text NOT NULL,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version = 1),
  occurred_at_client timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  properties jsonb NOT NULL DEFAULT '{}'::jsonb,
  payload_sha256 text NOT NULL,
  PRIMARY KEY (user_id, event_id),
  CHECK (jsonb_typeof(properties) = 'object'),
  CHECK (octet_length(properties::text) <= 512),
  CHECK (event_name IN (
    'app_session_started', 'surface_viewed', 'goal_selected',
    'resource_search_submitted', 'resource_opened',
    'external_resource_clicked', 'lesson_engaged', 'feature_error_observed'))
);
CREATE INDEX product_events_received_at_idx
  ON analytics.product_events (received_at DESC);
CREATE INDEX product_events_user_received_idx
  ON analytics.product_events (user_id, received_at DESC);
ALTER TABLE analytics.product_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.product_events FROM PUBLIC, anon, authenticated;
GRANT ALL ON analytics.product_events TO service_role;

-- Privileged back-end must explicitly set auth.users.raw_app_meta_data
-- product_analytics_eligible=true AFTER an independent privacy/age review.
-- The user-editable raw_user_meta_data and browser flags are NEVER trusted.
CREATE FUNCTION public.set_product_analytics_consent(p_consent boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_eligible boolean;
BEGIN
  IF v_user IS NULL OR p_consent IS NULL THEN
    RAISE EXCEPTION 'Authenticated user and explicit consent choice required'
      USING ERRCODE = '42501';
  END IF;
  IF p_consent THEN
    SELECT (u.is_anonymous IS FALSE
            AND u.raw_app_meta_data->>'product_analytics_eligible' = 'true')
      INTO v_eligible FROM auth.users u WHERE u.id = v_user;
    IF v_eligible IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'Product analytics eligibility has not been verified'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  INSERT INTO analytics.product_consents(user_id, consented, changed_at)
    VALUES (v_user, p_consent, now())
    ON CONFLICT (user_id) DO UPDATE
      SET consented = excluded.consented, changed_at = excluded.changed_at;
  IF NOT p_consent THEN
    -- Opt-out also erases previously captured raw product events for this user.
    DELETE FROM analytics.product_events WHERE user_id = v_user;
  END IF;
  RETURN jsonb_build_object('consented', p_consent, 'changed_at', now());
END;
$$;
REVOKE ALL ON FUNCTION public.set_product_analytics_consent(boolean)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_product_analytics_consent(boolean)
  TO authenticated, service_role;

CREATE FUNCTION public.record_product_events(p_events jsonb[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_eligible boolean;
  v_consent boolean;
  v_item jsonb;
  v_props jsonb;
  v_name text;
  v_allowed text[];
  v_id uuid;
  v_session uuid;
  v_occurred timestamptz;
  v_digest text;
  v_existing text;
  v_inserted uuid;
  v_result jsonb := '[]'::jsonb;
  v_status text;
  v_count integer := 0;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user required' USING ERRCODE = '42501';
  END IF;
  SELECT (u.is_anonymous IS FALSE
          AND u.raw_app_meta_data->>'product_analytics_eligible' = 'true')
    INTO v_eligible FROM auth.users u WHERE u.id = v_user;
  IF v_eligible IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Product analytics account not eligible'
      USING ERRCODE = '42501';
  END IF;
  -- Lock consent row until the transaction finishes. A concurrent withdrawal
  -- must then delete prior events AFTER this batch, never before it.
  SELECT consented INTO v_consent
    FROM analytics.product_consents
    WHERE user_id = v_user FOR SHARE;
  IF v_consent IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Product analytics consent required'
      USING ERRCODE = '42501';
  END IF;
  IF p_events IS NULL OR cardinality(p_events) < 1
     OR cardinality(p_events) > 25 THEN
    RAISE EXCEPTION 'Product event batch must contain 1 to 25 items'
      USING ERRCODE = '22023';
  END IF;
  IF (SELECT count(*) FROM analytics.product_events
      WHERE user_id = v_user AND received_at >= now() - interval '1 minute')
      + cardinality(p_events) > 60 THEN
    RAISE EXCEPTION 'Product event rate limit exceeded'
      USING ERRCODE = '22023';
  END IF;
  FOREACH v_item IN ARRAY p_events LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object'
       OR octet_length(v_item::text) > 2048
       OR (SELECT count(*) FROM jsonb_object_keys(v_item)) <> 6
       OR EXISTS (
         SELECT 1 FROM jsonb_object_keys(v_item) AS k(key)
         WHERE k.key <> ALL(ARRAY[
           'event_id','session_id','event_name','schema_version',
           'occurred_at_client','properties'])
       ) THEN
      RAISE EXCEPTION 'Invalid product event envelope'
        USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(v_item->'event_id') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'session_id') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'event_name') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'occurred_at_client') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'schema_version') IS DISTINCT FROM 'number'
       OR v_item->>'schema_version' <> '1' THEN
      RAISE EXCEPTION 'Invalid product event field types or version'
        USING ERRCODE = '22023';
    END IF;
    BEGIN
      v_id := (v_item->>'event_id')::uuid;
      v_session := (v_item->>'session_id')::uuid;
      v_occurred := (v_item->>'occurred_at_client')::timestamptz;
    EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow THEN
      RAISE EXCEPTION 'Invalid event UUID or timestamp' USING ERRCODE = '22023';
    END;
    IF v_occurred < now() - interval '7 days'
       OR v_occurred > now() + interval '5 minutes' THEN
      RAISE EXCEPTION 'Event timestamp outside permitted window'
        USING ERRCODE = '22023';
    END IF;
    v_name := v_item->>'event_name';
    v_allowed := CASE v_name
      WHEN 'app_session_started' THEN ARRAY['surface']
      WHEN 'surface_viewed' THEN ARRAY['surface']
      WHEN 'goal_selected' THEN ARRAY['goal_type']
      WHEN 'resource_search_submitted' THEN ARRAY['source_type','query_category']
      WHEN 'resource_opened' THEN ARRAY['resource_id','resource_type','source_tier']
      WHEN 'external_resource_clicked'
        THEN ARRAY['resource_id','provider_category','referral_id']
      WHEN 'lesson_engaged' THEN ARRAY['resource_id','mode']
      WHEN 'feature_error_observed' THEN ARRAY['error_category','feature']
      ELSE NULL
    END;
    v_props := v_item->'properties';
    IF v_allowed IS NULL
       OR jsonb_typeof(v_props) IS DISTINCT FROM 'object'
       OR octet_length(v_props::text) > 512
       OR (SELECT count(*) FROM jsonb_object_keys(v_props)) > 5
       OR EXISTS (
         SELECT 1 FROM jsonb_each(v_props) AS p(key, value)
         WHERE p.key <> ALL(v_allowed)
           OR jsonb_typeof(p.value) IS DISTINCT FROM 'string'
           OR (v_props->>p.key) !~ '^[a-zA-Z0-9_.:-]{1,64}$'
       ) THEN
      RAISE EXCEPTION 'Unapproved or unbounded product event properties'
        USING ERRCODE = '22023';
    END IF;
    v_digest := encode(extensions.digest(v_item::text, 'sha256'), 'hex');
    v_inserted := NULL;
    INSERT INTO analytics.product_events(
      user_id,event_id,session_id,event_name,schema_version,
      occurred_at_client,properties,payload_sha256)
    VALUES (v_user,v_id,v_session,v_name,1,v_occurred,v_props,v_digest)
    ON CONFLICT (user_id,event_id) DO NOTHING
    RETURNING event_id INTO v_inserted;
    IF v_inserted IS NOT NULL THEN
      v_status := 'accepted';
    ELSE
      SELECT payload_sha256 INTO v_existing
        FROM analytics.product_events
        WHERE user_id = v_user AND event_id = v_id;
      v_status := CASE WHEN v_existing = v_digest
        THEN 'duplicate_noop' ELSE 'idempotency_payload_mismatch' END;
    END IF;
    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'event_id',v_id,'status',v_status));
    v_count := v_count + 1;
  END LOOP;
  RETURN jsonb_build_object('status','success',
    'processed_count',v_count,'results',v_result);
END;
$$;
REVOKE ALL ON FUNCTION public.record_product_events(jsonb[])
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_product_events(jsonb[])
  TO authenticated, service_role;

-- User portability/erasure: no global raw reads, even for admins. Exports are
-- explicitly limited to the caller's own events and capped at 100 rows.
CREATE FUNCTION public.export_my_product_events(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_data jsonb;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user required' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'Export page limit must be 1 to 100' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(jsonb_agg(x.event_row), '[]'::jsonb) INTO v_data
  FROM (
    SELECT jsonb_build_object(
      'event_id',e.event_id,'session_id',e.session_id,
      'event_name',e.event_name,'occurred_at_client',e.occurred_at_client,
      'received_at',e.received_at,'properties',e.properties) AS event_row
    FROM analytics.product_events e WHERE e.user_id = v_user
    ORDER BY e.received_at DESC LIMIT p_limit
  ) AS x;
  RETURN v_data;
END;
$$;
REVOKE ALL ON FUNCTION public.export_my_product_events(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.export_my_product_events(integer)
  TO authenticated, service_role;

-- Privacy-first administrative overview. Empty event store != zero DAU.
-- Small eligible cohorts are suppressed even for administrators.
CREATE FUNCTION public.get_product_analytics_overview(p_days integer DEFAULT 7)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_active integer;
  v_events integer;
  v_sessions integer;
  v_resource_opens integer;
  v_external_clicks integer;
  v_window timestamptz;
  v_asof timestamptz := now();
BEGIN
  IF v_user IS NULL OR NOT coalesce((SELECT public.is_admin()),false)
     OR NOT EXISTS (
       SELECT 1 FROM auth.users u WHERE u.id=v_user AND u.is_anonymous IS FALSE
     ) THEN
    RAISE EXCEPTION 'Administrator authorization required'
      USING ERRCODE='42501';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (1,7,30) THEN
    RAISE EXCEPTION 'Unsupported analytics window' USING ERRCODE='22023';
  END IF;
  v_window := v_asof - make_interval(days => p_days);
  SELECT count(DISTINCT user_id)::integer, count(*)::integer,
         count(*) FILTER (WHERE event_name='app_session_started')::integer,
         count(*) FILTER (WHERE event_name='resource_opened')::integer,
         count(*) FILTER (WHERE event_name='external_resource_clicked')::integer
  INTO v_active,v_events,v_sessions,v_resource_opens,v_external_clicks
  FROM analytics.product_events WHERE received_at >= v_window;
  RETURN jsonb_build_object(
    'status',CASE WHEN v_events=0 THEN 'not_measured'
                  WHEN v_active < 5 THEN 'small_cohort_suppressed'
                  ELSE 'measured' END,
    'window_days',p_days,'as_of',v_asof,'window_start',v_window,
    'coverage','opted_in_eligible_accounts_only',
    'unique_active_users',CASE WHEN v_active >= 5 THEN v_active END,
    'event_count',CASE WHEN v_active >= 5 THEN v_events END,
    'session_starts',CASE WHEN v_active >= 5 THEN v_sessions END,
    'resource_opens',CASE WHEN v_active >= 5 THEN v_resource_opens END,
    'external_clicks',CASE WHEN v_active >= 5 THEN v_external_clicks END);
END;
$$;
REVOKE ALL ON FUNCTION public.get_product_analytics_overview(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_product_analytics_overview(integer)
  TO authenticated, service_role;

-- No pg_cron is assumed installed. Invoke manually under privileged controlled
-- maintenance until retention scheduling has been separately approved.
CREATE FUNCTION analytics.purge_expired_product_events()
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE v_deleted integer;
BEGIN
  DELETE FROM analytics.product_events
  WHERE received_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;
REVOKE ALL ON FUNCTION analytics.purge_expired_product_events()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics.purge_expired_product_events()
  TO service_role;
