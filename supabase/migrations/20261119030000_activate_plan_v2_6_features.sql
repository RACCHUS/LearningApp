-- Owner-approved activation (2026-11-19) of four master-plan v2.6 features
-- that were built, tested and verified in a real browser against a local
-- stack:
--   learning.quick_rescue        no-AI Bridges from Excel lessons (#233, #256, #327)
--   learning.check_disputes      send a disputed Bridge question for review (#317)
--   ai.manual_generation_v2      slot-based generator with your own AI chat
--                                (#236, #254, #255, #316, #318, #319, #326)
--   content.parametric_practice  server-scored practice with new numbers (#324)
--
-- Left OFF on purpose: learning.auto_gap_suggestions (misconception tags not
-- yet reviewed by a person), content.external_companion (not re-verified),
-- and content.public_contribution / content.refresh_proposals /
-- content.wanted_board (public user content: owner moderation decision).
--
-- This mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one row per change in private.site_feature_change_audit.
-- actor_id is NULL because a migration has no signed-in admin; the reason
-- records the owner's approval. Any later change goes through the admin UI.
-- Only rows still OFF are touched, so re-running is a no-op.
WITH targets(feature_key) AS (
  VALUES ('learning.quick_rescue'),
         ('learning.check_disputes'),
         ('ai.manual_generation_v2'),
         ('content.parametric_practice')
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
       'Owner-approved activation 2026-11-19 after browser verification (migration 20261119030000)'
FROM before b
JOIN changed USING (feature_key);
