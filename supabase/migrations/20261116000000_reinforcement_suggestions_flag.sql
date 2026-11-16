-- Progress "needs reinforcement" list (UI spec section 5.5). UI-only gate:
-- the list reads the learner's own concept states, concept names, the shared
-- concept-to-content mappings and their due review items through existing
-- RLS, and writes nothing (hiding a suggestion is stored on the device).
-- Default OFF until the deployed web build is checked.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.reinforcement_suggestions', 'Progress reinforcement suggestions', 'Learning', 'release', false, 'experimental', false,
  'Optional list of weakest concepts on Progress; each starts a targeted review of its due items; read-only')
ON CONFLICT (feature_key) DO NOTHING;
