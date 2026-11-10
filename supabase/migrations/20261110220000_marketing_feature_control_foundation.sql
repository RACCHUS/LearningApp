-- FLAG-001..004: trusted, default-dark first-party feature controls.
-- Additive only. Do not deploy except via the owner-gated guarded migration path.
-- Existing TEL Fast and Overview remain ON as explicitly directed by owner.
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE private.site_feature_controls (
  feature_key text PRIMARY KEY
    CHECK (feature_key ~ '^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$'),
  label text NOT NULL,
  category text NOT NULL,
  kind text NOT NULL
    CHECK (kind IN ('release', 'kill_switch', 'operational', 'privacy_gate')),
  enabled boolean NOT NULL DEFAULT false,
  maturity text NOT NULL DEFAULT 'experimental'
    CHECK (maturity IN ('experimental','verified')),
  release_ready boolean NOT NULL DEFAULT false,
  revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
  description text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
ALTER TABLE private.site_feature_controls ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.site_feature_controls FROM PUBLIC, anon, authenticated;

CREATE TABLE private.site_feature_change_audit (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  feature_key text NOT NULL REFERENCES private.site_feature_controls(feature_key),
  changed_at timestamptz NOT NULL DEFAULT now(),
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  prior_enabled boolean NOT NULL,
  next_enabled boolean NOT NULL,
  prior_maturity text NOT NULL,
  next_maturity text NOT NULL,
  previous_revision bigint NOT NULL,
  new_revision bigint NOT NULL,
  reason text NOT NULL CHECK (length(btrim(reason)) >= 8)
);
ALTER TABLE private.site_feature_change_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.site_feature_change_audit FROM PUBLIC, anon, authenticated;

-- New capabilities cannot be activated merely because their code has merged.
-- release_ready requires separate reviewed code/migration approval; the panel
-- cannot edit it. This also prevents the panel from bypassing dedicated privacy
-- or BYOK credential remediation gates.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('tel.fast', 'Fast learning approach', 'Learning', 'release', true, 'experimental', true,
  'Owner-approved available Fast; learning outcome maturity remains experimental'),
 ('tel.overview', 'Quick overview', 'Learning', 'release', true, 'experimental', true,
  'Preserve merged Overview availability and existing target eligibility'),
 ('ai.byok', 'Bring Your Own Key AI', 'AI', 'release', false, 'experimental', false,
  'Hard-disabled pending security, privacy, provider, CSP and owner review'),
 ('ai.managed', 'Platform-funded AI', 'AI', 'operational', false, 'experimental', false,
  'Zero spend ceiling and explicit funding approval required'),
 ('ai.external_mcp', 'External AI via MCP', 'AI', 'release', false, 'experimental', false,
  'Parent of hosted MCP tools; never allow learner data by default'),
 ('mcp.remote', 'Remote MCP endpoint', 'MCP', 'kill_switch', false, 'experimental', false,
  'Authenticated endpoint must be verified before enabling'),
 ('mcp.personal_read', 'MCP personal learner read', 'MCP', 'release', false, 'experimental', false,
  'Requires token-derived user and revoked OAuth token handling'),
 ('mcp.write_review', 'MCP write reviews', 'MCP', 'release', false, 'experimental', false,
  'Requires idempotent write and cross-account negative tests'),
 ('analytics.product_events', 'Opt-in product analytics', 'Privacy', 'privacy_gate', false, 'experimental', false,
  'Additional brake; analytics.product_release_gate remains authoritative'),
 ('support.donations', 'Voluntary support', 'Commerce', 'release', false, 'experimental', false,
  'Provider approval, verified webhook and reconciliation required'),
 ('marketing.sponsor_cards', 'Public sponsor placements', 'Commerce', 'release', false, 'experimental', false,
  'Public pages only with editorial independence and disclosures'),
 ('marketing.affiliate_links', 'Disclosed affiliate links', 'Commerce', 'release', false, 'experimental', false,
  'Public pages only with disclosure and ranking independence'),
 ('marketing.display_ads', 'Public-page display ads', 'Commerce', 'release', false, 'experimental', false,
  'Never load advertising scripts in Flutter study views'),
 ('marketing.paid_acquisition', 'Paid acquisition', 'Commerce', 'operational', false, 'experimental', false,
  'Provider-side campaigns must be paused; server budget starts at zero'),
 ('seo.dynamic_endpoints', 'SEO dynamic endpoints', 'Discovery', 'operational', false, 'experimental', false,
  'Static public pages remain accessible independently'),
 ('ops.nonessential_background_jobs', 'Nonessential jobs', 'Operations', 'kill_switch', false, 'experimental', false,
  'Disabled until job admission is server-enforced'),
 ('learning.community_qa', 'Community Q&A rollout', 'Learning', 'release', false, 'experimental', false,
  'Registry does not replace existing community authorization or content gates'),
 ('learning.simulations', 'New simulation sessions', 'Learning', 'release', false, 'experimental', false,
  'Existing simulation behavior stays unchanged until parity and gate review')
ON CONFLICT (feature_key) DO NOTHING;

-- Server-side admission helper. Future RPC/Edge/MCP entry points MUST invoke
-- it at each side-effect boundary. No direct exposure to browser roles.
CREATE OR REPLACE FUNCTION private.site_feature_enabled(p_feature_key text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce((
    SELECT c.enabled AND c.release_ready
    FROM private.site_feature_controls AS c
    WHERE c.feature_key = p_feature_key
  ), false);
$$;
REVOKE ALL ON FUNCTION private.site_feature_enabled(text) FROM PUBLIC, anon, authenticated;

-- Public read-only snapshot contains no credentials, actors or audit reasons.
-- The browser never treats a returned "enabled" as backend authorization.
CREATE OR REPLACE FUNCTION public.get_site_feature_snapshot()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $$
  SELECT coalesce(jsonb_object_agg(
    c.feature_key,
    jsonb_build_object(
      'enabled', (c.enabled AND c.release_ready),
      'maturity', c.maturity,
      'revision', c.revision
    )
  ), '{}'::jsonb)
  FROM private.site_feature_controls AS c;
$$;
REVOKE ALL ON FUNCTION public.get_site_feature_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_site_feature_snapshot() TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_list_site_features()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'Not authorized to manage feature controls'
      USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'feature_key', c.feature_key,
      'label', c.label,
      'category', c.category,
      'kind', c.kind,
      'enabled', c.enabled,
      'maturity', c.maturity,
      'release_ready', c.release_ready,
      'revision', c.revision,
      'description', c.description,
      'updated_at', c.updated_at
    ) ORDER BY c.category, c.label), '[]'::jsonb)
    FROM private.site_feature_controls c
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_site_features() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_site_features() TO authenticated, service_role;

-- Optimistic CAS prevents stale operator panels from overwriting one another.
-- No change to the safety-reviewed release_ready column is permitted here.
CREATE OR REPLACE FUNCTION public.admin_set_site_feature(
  p_feature_key text, p_enabled boolean, p_maturity text,
  p_expected_revision bigint, p_reason text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_before private.site_feature_controls%ROWTYPE;
  v_next_revision bigint;
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'Not authorized to manage feature controls'
      USING ERRCODE = '42501';
  END IF;
  IF p_enabled IS NULL OR p_maturity NOT IN ('experimental', 'verified')
     OR p_maturity IS NULL OR p_expected_revision IS NULL
     OR length(btrim(coalesce(p_reason,''))) < 8 THEN
    RAISE EXCEPTION 'Invalid feature change parameters or audit reason'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_before FROM private.site_feature_controls
  WHERE feature_key = p_feature_key FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown feature key' USING ERRCODE = '22023';
  END IF;
  IF v_before.revision != p_expected_revision THEN
    RAISE EXCEPTION 'Feature revision has changed; reload and retry'
      USING ERRCODE = '40001';
  END IF;
  IF p_enabled AND NOT v_before.release_ready THEN
    RAISE EXCEPTION 'Feature activation requires a reviewed release gate'
      USING ERRCODE = '42501';
  END IF;

  -- Independent safety latches must never be overridden by a generic switch.
  IF p_enabled AND p_feature_key = 'ai.byok' THEN
    RAISE EXCEPTION 'BYOK is under owner-mandated remediation'
      USING ERRCODE = '42501';
  END IF;
  IF p_enabled AND p_feature_key = 'analytics.product_events' THEN
    RAISE EXCEPTION 'Analytics has a separate consent/policy release gate'
      USING ERRCODE = '42501';
  END IF;

  IF v_before.enabled = p_enabled AND v_before.maturity = p_maturity THEN
    RETURN jsonb_build_object('feature_key', v_before.feature_key,
      'enabled', v_before.enabled, 'maturity', v_before.maturity,
      'revision', v_before.revision);
  END IF;

  v_next_revision := v_before.revision + 1;
  UPDATE private.site_feature_controls
  SET enabled = p_enabled, maturity = p_maturity, revision = v_next_revision,
      updated_at = now(), updated_by = auth.uid()
  WHERE feature_key = p_feature_key;
  INSERT INTO private.site_feature_change_audit(
    feature_key, actor_id, prior_enabled, next_enabled,
    prior_maturity, next_maturity, previous_revision, new_revision, reason)
  VALUES (
    p_feature_key, auth.uid(), v_before.enabled, p_enabled,
    v_before.maturity, p_maturity, v_before.revision, v_next_revision, btrim(p_reason)
  );

  RETURN jsonb_build_object('feature_key', p_feature_key,
    'enabled', p_enabled, 'maturity', p_maturity,
    'revision', v_next_revision);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_set_site_feature(text,boolean,text,bigint,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_site_feature(text,boolean,text,bigint,text)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.admin_recent_site_feature_changes(
  p_limit integer DEFAULT 30)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT private.is_admin() THEN
    RAISE EXCEPTION 'Not authorized to view feature control history'
      USING ERRCODE = '42501';
  END IF;
  RETURN (
    SELECT coalesce(jsonb_agg(to_jsonb(a) ORDER BY a.changed_at DESC), '[]'::jsonb)
    FROM (
      SELECT id, feature_key, changed_at, actor_id,
             prior_enabled, next_enabled, prior_maturity, next_maturity,
             previous_revision, new_revision, reason
      FROM private.site_feature_change_audit
      ORDER BY changed_at DESC, id DESC
      LIMIT least(greatest(coalesce(p_limit, 30), 1), 100)
    ) AS a
  );
END;
$$;
REVOKE ALL ON FUNCTION public.admin_recent_site_feature_changes(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_recent_site_feature_changes(integer)
  TO authenticated, service_role;

-- Revoke browser table privileges again in case future inherited grants differ.
REVOKE ALL ON TABLE private.site_feature_controls,
  private.site_feature_change_audit FROM PUBLIC, anon, authenticated;
