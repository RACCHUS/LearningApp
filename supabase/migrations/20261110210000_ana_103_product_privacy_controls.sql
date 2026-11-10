-- ANA-103/105: make product-analytics opt-in observable, revocable,
-- exportable at scale, and fail closed when trusted eligibility changes.
-- Additive, no existing table rewrite; automatic client collection remains OFF.

CREATE FUNCTION public.get_my_product_analytics_privacy_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_eligible boolean;
  v_guest boolean;
  v_consent boolean := false;
  v_changed timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated account required' USING ERRCODE='42501';
  END IF;

  SELECT (u.is_anonymous IS FALSE
          AND u.raw_app_meta_data->>'product_analytics_eligible' = 'true'),
         u.is_anonymous
  INTO v_eligible, v_guest
  FROM auth.users u
  WHERE u.id=v_user;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Authenticated account unavailable' USING ERRCODE='42501';
  END IF;

  SELECT c.consented, c.changed_at INTO v_consent, v_changed
  FROM analytics.product_consents c WHERE c.user_id=v_user;

  RETURN jsonb_build_object(
    'schema_version',1,
    'eligible',coalesce(v_eligible,false),
    'consented',coalesce(v_consent,false) AND coalesce(v_eligible,false),
    'is_anonymous',coalesce(v_guest,true),
    'changed_at',v_changed,
    'collection_active',false
  );
END;
$$;
REVOKE ALL ON FUNCTION public.get_my_product_analytics_privacy_status()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_product_analytics_privacy_status()
  TO authenticated, service_role;

-- When an account is reclassified as a guest or loses trusted eligibility,
-- delete all previously accepted raw events AND revoke its stored consent.
-- Re-reviewing the account later must NOT silently restore consent.
CREATE FUNCTION analytics.revoke_ineligible_product_analytics()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NEW.is_anonymous IS DISTINCT FROM FALSE OR
     NEW.raw_app_meta_data->>'product_analytics_eligible' IS DISTINCT FROM 'true'
  THEN
    UPDATE analytics.product_consents
       SET consented=false, changed_at=now()
     WHERE user_id=NEW.id AND consented=true;
    DELETE FROM analytics.product_events WHERE user_id=NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.revoke_ineligible_product_analytics()
  FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_revoke_ineligible_product_analytics ON auth.users;
CREATE TRIGGER trg_revoke_ineligible_product_analytics
  AFTER UPDATE OF is_anonymous, raw_app_meta_data ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION analytics.revoke_ineligible_product_analytics();

-- A keyset cursor avoids OFFSET pagination gaps and prevents exports from
-- silently ending after 100 records. User identity never comes from inputs.
CREATE FUNCTION public.export_my_product_events_page(
  p_before_received_at timestamptz DEFAULT NULL,
  p_before_event_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 100
)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_record record;
  v_count integer := 0;
  v_has_more boolean := false;
  v_rows jsonb := '[]'::jsonb;
  v_last_received timestamptz;
  v_last_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated account required' USING ERRCODE='42501';
  END IF;
  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'Export page size must be 1..100' USING ERRCODE='22023';
  END IF;
  IF (p_before_received_at IS NULL) <> (p_before_event_id IS NULL) THEN
    RAISE EXCEPTION 'Both export cursor fields are required'
      USING ERRCODE='22023';
  END IF;
  FOR v_record IN
    SELECT event_id, session_id, event_name, schema_version,
           occurred_at_client, received_at, properties
      FROM analytics.product_events e
     WHERE e.user_id=v_user
       AND (p_before_received_at IS NULL OR
         (e.received_at,e.event_id) < (p_before_received_at,p_before_event_id))
     ORDER BY e.received_at DESC, e.event_id DESC
     LIMIT p_limit+1
  LOOP
    IF v_count >= p_limit THEN
      v_has_more := true;
      EXIT;
    END IF;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'event_id',v_record.event_id,
      'session_id',v_record.session_id,
      'event_name',v_record.event_name,
      'schema_version',v_record.schema_version,
      'occurred_at_client',v_record.occurred_at_client,
      'received_at',v_record.received_at,
      'properties',v_record.properties
    ));
    v_last_received := v_record.received_at;
    v_last_id := v_record.event_id;
    v_count := v_count+1;
  END LOOP;
  RETURN jsonb_build_object(
    'events',v_rows,
    'has_more',v_has_more,
    'next_before_received_at',CASE WHEN v_has_more THEN v_last_received END,
    'next_before_event_id',CASE WHEN v_has_more THEN v_last_id END,
    'as_of',now()
  );
END;
$$;
REVOKE ALL ON FUNCTION
  public.export_my_product_events_page(timestamptz,uuid,integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION
  public.export_my_product_events_page(timestamptz,uuid,integer)
  TO authenticated, service_role;

-- The prior count+batch check alone could race between concurrent requests.
-- Serialize writes per learner, then enforce the cap after acquiring the lock.
CREATE FUNCTION analytics.limit_product_event_insert_rate()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_recent integer;
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ana102:' || NEW.user_id::text, 217));
  SELECT count(*)::integer INTO v_recent
    FROM analytics.product_events e
    WHERE e.user_id=NEW.user_id
      AND e.received_at >= now()-interval '1 minute';
  IF v_recent >= 60 THEN
    RAISE EXCEPTION 'Product event rate limit exceeded'
      USING ERRCODE='22023';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.limit_product_event_insert_rate()
  FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_limit_product_event_insert_rate
  ON analytics.product_events;
CREATE TRIGGER trg_limit_product_event_insert_rate
  BEFORE INSERT ON analytics.product_events
  FOR EACH ROW EXECUTE FUNCTION analytics.limit_product_event_insert_rate();

-- Retention health is callable only from the privileged operations role.
-- Does not create a scheduler or authorize collection.
CREATE FUNCTION analytics.product_retention_health()
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'as_of',now(),
    'raw_events',count(*),
    'expired_events',count(*) FILTER
      (WHERE received_at < now()-interval '90 days'),
    'oldest_received_at',min(received_at)
  ) FROM analytics.product_events;
$$;
REVOKE ALL ON FUNCTION analytics.product_retention_health()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics.product_retention_health()
  TO service_role;
