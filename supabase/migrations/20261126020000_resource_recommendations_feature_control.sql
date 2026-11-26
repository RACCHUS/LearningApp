-- Companion to external resources, EX-5 (companion plan v1.0 §3.5, §7.4):
-- register the `content.resource_recommendations` gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed.
--
-- What the gate covers: the "Ways to study this" list on a goal, built from
-- the reviewed catalog bundled with the app (data/external_resources,
-- data/resource_maps). The list has no server read or write of its own;
-- "Use this" saves through the existing save_learner_external_resource and
-- outline functions behind `content.learner_resources`. This row switches a
-- client feature only and must not be read as a server gate.
--
-- Ranking rule (§3.5): learner benefit only. No field in the catalog can
-- carry a paid placement (tool/verify_external_resources.py), the best free
-- route is always shown first, and a paid resource is never shown without
-- the free route beside it.
--
-- Shutoff behavior: goals show LearningApp's own content only, as before.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.resource_recommendations', 'Ways to study this (outside resources)', 'Content', 'release', false, 'experimental', false,
  'Client feature: lists reviewed outside resources for a goal beside LearningApp''s own lessons, best free route first, with reasons and check dates; no paid placement; saves go through content.learner_resources')
ON CONFLICT (feature_key) DO NOTHING;
