-- Owner-approved activation (2026-11-21) of two master-plan v2.6 features:
--   analytics.prompt_quality   opt-in prompt-quality telemetry (#347, #350).
--                              Privacy review: docs/privacy/
--                              PROMPT_QUALITY_PRIVACY_REVIEW.md. Learners
--                              still choose: nothing is shared until they
--                              opt in, on top of base analytics consent.
--   ai.local_experimental      on-device key points (#349, #350), verified in
--                              desktop Chrome 157 (no network requests).
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row per change. actor_id is NULL because a
-- migration has no signed-in admin; the reason records the owner's approval.
-- Only rows still OFF are touched, so re-running is a no-op.
WITH targets(feature_key) AS (
  VALUES ('analytics.prompt_quality'),
         ('ai.local_experimental')
),
before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  JOIN targets t USING (feature_key)
  WHERE c.enabled = false
  FOR UPDATE
),
changed AS (
  UPDATE private.site_feature_controls c
  SET release_ready = true,
      enabled = true,
      revision = b.revision + 1,
      updated_at = now()
  FROM before b
  WHERE c.feature_key = b.feature_key
  RETURNING c.feature_key
)
INSERT INTO private.site_feature_change_audit
  (feature_key, actor_id, prior_enabled, next_enabled, prior_maturity,
   next_maturity, previous_revision, new_revision, reason)
SELECT b.feature_key, NULL, b.enabled, true, b.maturity, b.maturity,
       b.revision, b.revision + 1,
       'Owner-approved activation 2026-11-21 after privacy review and Chrome verification (migration 20261121050000)'
FROM before b
JOIN changed USING (feature_key);
