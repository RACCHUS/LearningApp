-- Question scratchpad (whiteboard under questions). UI-only gate: the
-- scratchpad is temporary, one per question, and is never saved or sent
-- anywhere, so there is no server write to guard. Learners must also opt in
-- under Settings. Default OFF until the deployed web build is checked.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.scratchpad', 'Question scratchpad', 'Learning', 'release', false, 'experimental', false,
  'Opt-in drawing scratchpad under questions; temporary per question, never stored or uploaded')
ON CONFLICT (feature_key) DO NOTHING;
