-- On-device AI experiment (master plan v2.6 P4.1).
--
-- The app can offer "Key points (on this device)" for a lesson section
-- through the browser's built-in model (Chrome's Summarizer API, desktop
-- Chrome 138+). The model runs locally; the app sends no lesson text
-- anywhere and keeps only device-local timings. Nothing here touches the
-- server beyond this switch, which is seeded OFF: the owner decides when
-- to try it.

INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('ai.local_experimental', 'On-device AI experiment', 'AI', 'release', false, 'experimental', false,
  'Key points of a lesson section from the browser''s built-in on-device model; download disclosed; nothing sent by the app')
ON CONFLICT (feature_key) DO NOTHING;
