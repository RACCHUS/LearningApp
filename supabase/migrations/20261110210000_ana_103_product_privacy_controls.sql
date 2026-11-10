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
    'policy_ready',coalesce((
      SELECT g.approved_policy_version IS NOT NULL
         AND g.policy_approved_at IS NOT NULL
        FROM analytics.product_release_gate g WHERE g.id=1),false),
    'policy_version',(
      SELECT g.approved_policy_version
        FROM analytics.product_release_gate g WHERE g.id=1),
    'collection_active',coalesce((
      SELECT g.collection_enabled
        FROM analytics.product_release_gate g WHERE g.id=1),false)
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


-- CRITICAL FAIL-CLOSED RELEASE LATCH: user consent and a browser feature
-- flag are not authorization to capture events. The privacy owner must
-- explicitly approve a versioned disclosure and release at the DATABASE
-- before either opt-in or event storage is possible.
CREATE TABLE analytics.product_release_gate (
  id integer PRIMARY KEY CHECK (id=1),
  approved_policy_version text,
  policy_approved_at timestamptz,
  collection_enabled boolean NOT NULL DEFAULT false,
  reviewed_by text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  CHECK (NOT collection_enabled OR
    (approved_policy_version IS NOT NULL AND
     approved_policy_version ~ '^[a-zA-Z0-9_.:-]{1,80}$'
     AND policy_approved_at IS NOT NULL
     AND reviewed_by IS NOT NULL AND length(reviewed_by) >= 3))
);
INSERT INTO analytics.product_release_gate(id,collection_enabled)
  VALUES (1,false) ON CONFLICT(id) DO NOTHING;
ALTER TABLE analytics.product_release_gate ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.product_release_gate
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON analytics.product_release_gate TO service_role;

ALTER TABLE analytics.product_consents
  ADD COLUMN policy_version text;

CREATE FUNCTION analytics.check_product_consent_release()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
  v_approved text;
BEGIN
  IF NEW.consented THEN
    IF NOT EXISTS (
      SELECT 1 FROM auth.users u WHERE u.id=NEW.user_id
        AND u.is_anonymous IS FALSE
        AND u.raw_app_meta_data->>'product_analytics_eligible' = 'true'
    ) THEN
      RAISE EXCEPTION 'Unreviewed or guest accounts cannot consent'
        USING ERRCODE='42501';
    END IF;
    SELECT approved_policy_version INTO v_approved
    FROM analytics.product_release_gate
    WHERE id=1 AND collection_enabled
      AND policy_approved_at IS NOT NULL
      AND reviewed_by IS NOT NULL
    FOR SHARE;
    IF v_approved IS NULL THEN
      RAISE EXCEPTION 'Analytics release policy not approved'
        USING ERRCODE='42501';
    END IF;
    NEW.policy_version := v_approved;
  ELSE
    NEW.policy_version := NULL;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.check_product_consent_release()
  FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_check_product_consent_release
  BEFORE INSERT OR UPDATE ON analytics.product_consents
  FOR EACH ROW EXECUTE FUNCTION analytics.check_product_consent_release();

CREATE FUNCTION analytics.check_product_event_release()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
  v_approved text;
BEGIN
  SELECT approved_policy_version INTO v_approved
  FROM analytics.product_release_gate
  WHERE id=1 AND collection_enabled
    AND policy_approved_at IS NOT NULL AND reviewed_by IS NOT NULL
  FOR SHARE;
  IF v_approved IS NULL OR NOT EXISTS (
    SELECT 1 FROM analytics.product_consents c
    JOIN auth.users u ON u.id=c.user_id
    WHERE c.user_id=NEW.user_id AND c.consented
      AND c.policy_version=v_approved
      AND u.is_anonymous IS FALSE
      AND u.raw_app_meta_data->>'product_analytics_eligible'='true'
  ) THEN
    RAISE EXCEPTION 'Analytics release or matching consent not active'
      USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.check_product_event_release()
  FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_check_product_event_release
  BEFORE INSERT ON analytics.product_events
  FOR EACH ROW EXECUTE FUNCTION analytics.check_product_event_release();

-- A changed privacy notice invalidates prior consent. Explicit consent must
-- be gathered again under the newly approved notice before any new event.
CREATE FUNCTION analytics.invalidate_old_product_policy()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
BEGIN
  IF NEW.approved_policy_version IS DISTINCT FROM
      OLD.approved_policy_version THEN
    UPDATE analytics.product_consents
       SET consented=false, changed_at=now()
     WHERE consented=true;
    -- Conservative privacy default: discard raw events collected under the
    -- previous policy when the release notice changes.
    DELETE FROM analytics.product_events;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.invalidate_old_product_policy()
  FROM PUBLIC,anon,authenticated;
CREATE TRIGGER trg_invalidate_old_product_policy
  AFTER UPDATE OF approved_policy_version
  ON analytics.product_release_gate
  FOR EACH ROW EXECUTE FUNCTION analytics.invalidate_old_product_policy();

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
