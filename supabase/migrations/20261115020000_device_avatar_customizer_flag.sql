-- Device-local avatar customizer. No user avatar data is stored in Supabase.
-- This additive operator flag controls whether avatar editing is offered
-- in the web UI. Default OFF until the new UI is validated and released.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
  ('learning.avatar_customizer', 'Device-local avatar customizer', 'Learning',
   'release', false, 'experimental', false,
   'Opt-in avatar personalization saved per signed-in account in this browser only; no upload or account synchronization')
ON CONFLICT (feature_key) DO NOTHING;
