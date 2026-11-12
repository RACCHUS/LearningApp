-- PR-D (master plan v2.6 §15.0): register the `learning.auto_gap_suggestions`
-- gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed. Turning it
-- on requires a reviewed release_ready change and separate owner approval.
--
-- Shutoff behavior: no proactive suggestions are shown. Learner-initiated
-- help (learning.quick_rescue) and return navigation are unaffected.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.auto_gap_suggestions', 'Proactive gap suggestions', 'Learning', 'release', false, 'experimental', false,
  'Rule-based, dismissible prerequisite suggestions; explicit Learning help stays available when OFF')
ON CONFLICT (feature_key) DO NOTHING;
