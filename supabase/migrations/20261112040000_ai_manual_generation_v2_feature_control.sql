-- PR-C (master plan v2.6 §15.0): register the `ai.manual_generation_v2` gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed. Turning it
-- on requires a reviewed release_ready change and separate owner approval.
--
-- Shutoff behavior: the slot-based generator is hidden. The existing V1
-- Quick Generate, AI-Guided Generation, JSON Import and Manual Builder
-- routes never depend on this flag and stay available.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('ai.manual_generation_v2', 'Slot-based manual AI generator', 'AI', 'release', false, 'experimental', false,
  'Additive copy-paste wizard (la-gen/1.1); V1 manual generation stays available when OFF')
ON CONFLICT (feature_key) DO NOTHING;
