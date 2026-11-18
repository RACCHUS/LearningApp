-- Owner-approved activation (2026-11-17) of four learner features that were
-- built, tested and verified in the deployed web build:
--   learning.xp_achievements          XP and achievements in Progress (#282)
--   learning.scratchpad               opt-in drawing pad under questions (#286)
--   learning.avatar_customizer        device-local avatar editing (#284)
--   learning.reinforcement_suggestions  "needs reinforcement" list (#289)
--
-- This mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one row per change in private.site_feature_change_audit.
-- actor_id is NULL because a migration has no signed-in admin; the reason
-- records the owner's approval. Any later change goes through the admin UI.
-- Only rows still OFF are touched, so re-running is a no-op.
WITH targets(feature_key) AS (
  VALUES ('learning.xp_achievements'),
         ('learning.scratchpad'),
         ('learning.avatar_customizer'),
         ('learning.reinforcement_suggestions')
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
       'Owner-approved activation 2026-11-17 after release verification (migration 20261117230000)'
FROM before b
JOIN changed USING (feature_key);
