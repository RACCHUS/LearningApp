-- Opt-in prompt-quality telemetry (master plan v2.6 §5.7.6, signal 1).
--
-- What is collected: for each AI reply a learner pastes into the generator,
-- the deterministic check outcome as codes and counts only (prompt pack
-- version, the AI label the learner picked, size tier, output mode,
-- outcome, first error code, slots requested and accepted, end marker
-- present). Never prompt or reply text, subjects, concepts or answers.
--
-- Gates, all required to record:
--   * feature switch analytics.prompt_quality (seeded OFF, not release
--     ready: switching it on needs the owner's privacy review),
--   * a permanent account with trusted product-analytics eligibility and
--     the base product-analytics consent,
--   * this feature's own extra opt-in.
-- Withdrawing either consent deletes the account's prompt-quality rows;
-- losing eligibility does too (via the base consent revocation trigger).
-- Rows expire after 90 days. Owner report: admins only, groups under 5
-- accounts suppressed.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('analytics.prompt_quality', 'Opt-in prompt-quality telemetry', 'Privacy', 'privacy_gate', false, 'experimental', false,
  'Codes and counts from generator reply checks, with a separate learner opt-in; no prompt or reply text')
ON CONFLICT (feature_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS analytics.prompt_quality_consents (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  consented boolean NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE analytics.prompt_quality_consents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.prompt_quality_consents FROM PUBLIC, anon, authenticated;
GRANT ALL ON analytics.prompt_quality_consents TO service_role;

CREATE TABLE IF NOT EXISTS analytics.prompt_quality_events (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_id uuid NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  pack_version text NOT NULL CHECK (pack_version ~ '^[a-z0-9][a-z0-9.-]{0,31}$'),
  ai_label text NOT NULL
    CHECK (ai_label IN ('chatgpt','gemini','claude','copilot','other','not_sure')),
  tier text NOT NULL CHECK (tier ~ '^[a-z_]{1,24}$'),
  mode text NOT NULL CHECK (mode ~ '^[a-z_]{1,24}$'),
  outcome text NOT NULL CHECK (outcome IN ('clean','partial','refused')),
  error_code text NOT NULL CHECK (error_code ~ '^[a-z_]{1,40}$'),
  requested smallint NOT NULL CHECK (requested BETWEEN 0 AND 50),
  accepted smallint NOT NULL CHECK (accepted BETWEEN 0 AND 50),
  sentinel boolean NOT NULL,
  PRIMARY KEY (user_id, event_id)
);
CREATE INDEX IF NOT EXISTS prompt_quality_events_received_idx
  ON analytics.prompt_quality_events (received_at DESC);
ALTER TABLE analytics.prompt_quality_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.prompt_quality_events FROM PUBLIC, anon, authenticated;
GRANT ALL ON analytics.prompt_quality_events TO service_role;

-- Base consent and eligibility, as the base analytics functions check them.
CREATE OR REPLACE FUNCTION analytics.prompt_quality_base_ok(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u
    JOIN analytics.product_consents c ON c.user_id = u.id AND c.consented
    WHERE u.id = p_user AND u.is_anonymous IS FALSE
      AND u.raw_app_meta_data->>'product_analytics_eligible' = 'true');
$$;
REVOKE ALL ON FUNCTION analytics.prompt_quality_base_ok(uuid) FROM PUBLIC, anon, authenticated;

-- What the generator needs to show the opt-in.
CREATE OR REPLACE FUNCTION public.get_prompt_quality_status()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_enabled boolean := private.site_feature_enabled('analytics.prompt_quality');
  v_base boolean;
  v_consent boolean;
BEGIN
  IF v_user IS NULL OR NOT v_enabled THEN
    RETURN jsonb_build_object('enabled', false, 'available', false, 'consented', false);
  END IF;
  v_base := analytics.prompt_quality_base_ok(v_user);
  SELECT c.consented INTO v_consent
  FROM analytics.prompt_quality_consents c WHERE c.user_id = v_user;
  RETURN jsonb_build_object(
    'enabled', true,
    'available', v_base,
    'consented', coalesce(v_consent, false) AND v_base);
END;
$$;
REVOKE ALL ON FUNCTION public.get_prompt_quality_status() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_prompt_quality_status() TO authenticated;

CREATE OR REPLACE FUNCTION public.set_prompt_quality_consent(p_consent boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
BEGIN
  IF v_user IS NULL OR p_consent IS NULL THEN
    RAISE EXCEPTION 'Authenticated user and explicit choice required'
      USING ERRCODE = '42501';
  END IF;
  -- Withdrawing always works; opting in needs the switch and base consent.
  IF p_consent AND (NOT private.site_feature_enabled('analytics.prompt_quality')
                    OR NOT analytics.prompt_quality_base_ok(v_user)) THEN
    RAISE EXCEPTION 'Prompt-quality sharing is not available for this account'
      USING ERRCODE = '42501';
  END IF;
  INSERT INTO analytics.prompt_quality_consents (user_id, consented, changed_at)
  VALUES (v_user, p_consent, now())
  ON CONFLICT (user_id) DO UPDATE
    SET consented = EXCLUDED.consented, changed_at = EXCLUDED.changed_at;
  IF NOT p_consent THEN
    DELETE FROM analytics.prompt_quality_events WHERE user_id = v_user;
  END IF;
  RETURN jsonb_build_object('consented', p_consent);
END;
$$;
REVOKE ALL ON FUNCTION public.set_prompt_quality_consent(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_prompt_quality_consent(boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.record_prompt_quality_events(p_events jsonb[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_item jsonb;
  v_count integer := 0;
  v_fields text[] := ARRAY['event_id','pack_version','ai_label','tier','mode',
                           'outcome','error_code','requested','accepted','sentinel'];
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Authenticated user required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.site_feature_enabled('analytics.prompt_quality')
     OR NOT analytics.prompt_quality_base_ok(v_user)
     OR NOT EXISTS (SELECT 1 FROM analytics.prompt_quality_consents c
                    WHERE c.user_id = v_user AND c.consented) THEN
    RAISE EXCEPTION 'Prompt-quality sharing is off for this account'
      USING ERRCODE = '42501';
  END IF;
  IF p_events IS NULL OR cardinality(p_events) < 1 OR cardinality(p_events) > 10 THEN
    RAISE EXCEPTION 'Batch must contain 1 to 10 events' USING ERRCODE = '22023';
  END IF;
  IF (SELECT count(*) FROM analytics.prompt_quality_events
      WHERE user_id = v_user AND received_at >= now() - interval '1 minute')
     + cardinality(p_events) > 30 THEN
    RAISE EXCEPTION 'Rate limit exceeded' USING ERRCODE = '22023';
  END IF;
  FOREACH v_item IN ARRAY p_events LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object'
       OR octet_length(v_item::text) > 512
       OR EXISTS (SELECT 1 FROM jsonb_object_keys(v_item) k(key) WHERE k.key <> ALL(v_fields))
       OR (SELECT count(*) FROM jsonb_object_keys(v_item)) <> cardinality(v_fields)
       OR jsonb_typeof(v_item->'requested') IS DISTINCT FROM 'number'
       OR jsonb_typeof(v_item->'accepted') IS DISTINCT FROM 'number'
       OR jsonb_typeof(v_item->'sentinel') IS DISTINCT FROM 'boolean' THEN
      RAISE EXCEPTION 'Invalid prompt-quality event' USING ERRCODE = '22023';
    END IF;
    BEGIN
      INSERT INTO analytics.prompt_quality_events
        (user_id, event_id, pack_version, ai_label, tier, mode, outcome,
         error_code, requested, accepted, sentinel)
      VALUES (v_user, (v_item->>'event_id')::uuid, v_item->>'pack_version',
              v_item->>'ai_label', v_item->>'tier', v_item->>'mode',
              v_item->>'outcome', v_item->>'error_code',
              (v_item->>'requested')::smallint, (v_item->>'accepted')::smallint,
              (v_item->>'sentinel')::boolean)
      ON CONFLICT (user_id, event_id) DO NOTHING;
    EXCEPTION WHEN check_violation OR invalid_text_representation
                OR numeric_value_out_of_range OR not_null_violation THEN
      RAISE EXCEPTION 'Invalid prompt-quality event values' USING ERRCODE = '22023';
    END;
    v_count := v_count + 1;
  END LOOP;
  RETURN jsonb_build_object('status', 'success', 'processed_count', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.record_prompt_quality_events(jsonb[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_prompt_quality_events(jsonb[]) TO authenticated;

-- Base consent withdrawn (or revoked on lost eligibility): this data goes too.
CREATE OR REPLACE FUNCTION analytics.on_product_consent_withdrawn()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT NEW.consented THEN
    DELETE FROM analytics.prompt_quality_events WHERE user_id = NEW.user_id;
    UPDATE analytics.prompt_quality_consents
      SET consented = false, changed_at = now()
      WHERE user_id = NEW.user_id AND consented;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION analytics.on_product_consent_withdrawn() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_product_consent_withdrawn_prompt_quality ON analytics.product_consents;
CREATE TRIGGER trg_product_consent_withdrawn_prompt_quality
  AFTER INSERT OR UPDATE OF consented ON analytics.product_consents
  FOR EACH ROW EXECUTE FUNCTION analytics.on_product_consent_withdrawn();

-- Owner report per pack x AI label x tier, with sample sizes; groups with
-- fewer than 5 accounts are suppressed (plan §5.7.6: disclose small samples).
CREATE OR REPLACE FUNCTION public.get_prompt_quality_overview(p_days integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_user uuid := (SELECT auth.uid());
  v_rows jsonb;
BEGIN
  IF v_user IS NULL OR NOT coalesce((SELECT public.is_admin()), false) THEN
    RAISE EXCEPTION 'Administrator authorization required' USING ERRCODE = '42501';
  END IF;
  IF p_days IS NULL OR p_days NOT IN (7, 30, 90) THEN
    RAISE EXCEPTION 'Unsupported window' USING ERRCODE = '22023';
  END IF;
  SELECT coalesce(jsonb_agg(g ORDER BY g->>'pack_version', g->>'ai_label', g->>'tier'), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT CASE WHEN count(DISTINCT e.user_id) < 5 THEN jsonb_build_object(
             'pack_version', e.pack_version, 'ai_label', e.ai_label, 'tier', e.tier,
             'status', 'small_cohort_suppressed')
           ELSE jsonb_build_object(
             'pack_version', e.pack_version, 'ai_label', e.ai_label, 'tier', e.tier,
             'status', 'measured',
             'accounts', count(DISTINCT e.user_id),
             'replies', count(*),
             'clean_first_pass_rate', round(avg((e.outcome = 'clean')::int)::numeric, 3),
             'refused_rate', round(avg((e.outcome = 'refused')::int)::numeric, 3),
             'slots_complete_rate', round(avg((e.accepted >= e.requested)::int)::numeric, 3),
             'end_marker_rate', round(avg(e.sentinel::int)::numeric, 3),
             'top_error', mode() WITHIN GROUP (ORDER BY e.error_code))
           END AS g
    FROM analytics.prompt_quality_events e
    WHERE e.received_at >= now() - make_interval(days => p_days)
    GROUP BY e.pack_version, e.ai_label, e.tier
  ) s;
  RETURN jsonb_build_object('window_days', p_days, 'as_of', now(),
    'coverage', 'opted_in_eligible_accounts_only', 'groups', v_rows);
END;
$$;
REVOKE ALL ON FUNCTION public.get_prompt_quality_overview(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_prompt_quality_overview(integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION analytics.purge_expired_prompt_quality_events()
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER SET search_path = ''
AS $$
DECLARE v_deleted integer;
BEGIN
  DELETE FROM analytics.prompt_quality_events
  WHERE received_at < now() - interval '90 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;
REVOKE ALL ON FUNCTION analytics.purge_expired_prompt_quality_events() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION analytics.purge_expired_prompt_quality_events() TO service_role;
