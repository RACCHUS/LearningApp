-- PR-B (master plan v2.6 §15.0): register the `learning.quick_rescue` gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed. Turning it
-- on requires the guarded deployment path, a reviewed release_ready change
-- and separate owner approval; the Feature Control Center cannot set
-- release_ready.
--
-- Shutoff behavior: no new learning-help interventions start. Returning to
-- the original lesson never depends on this flag.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.quick_rescue', 'Learning help (no-AI Bridges)', 'Learning', 'release', false, 'experimental', false,
  'Explicit Learning help with bundled no-AI Bridges; return navigation stays available when OFF')
ON CONFLICT (feature_key) DO NOTHING;
