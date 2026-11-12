-- PR-E (master plan v2.6 §15.0): register the `content.external_companion`
-- gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed. Turning it
-- on requires a reviewed release_ready change and separate owner approval.
--
-- Shutoff behavior: companion section pointers and their checks are hidden.
-- Bridge source links and ordinary external links stay available.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.external_companion', 'External resource companions', 'Content', 'release', false, 'experimental', false,
  'Link-only section pointers with independent LearningApp checks; normal source links stay available when OFF')
ON CONFLICT (feature_key) DO NOTHING;
