-- Activation (2026-11-26, owner said "switch it on") of
-- content.resource_recommendations (companion plan v1.0 EX-5; migration
-- 20261126020000): "Other ways to study this" on a goal, built from the
-- reviewed catalog bundled with the app.
--
-- Verified before this migration on the local stack in a real browser with
-- the CLEP College Algebra goal ingested: as a guest (the card listed the
-- OpenStax 1st edition as the best free route with its reasons, check date
-- and "Not affiliated"; "Use this" saved it on the device with 20 objectives
-- ticked and nothing studied) and signed in (the save went through the gated
-- save_learner_external_resource and set_learner_resource_sections: 20
-- objectives, 38 parts, none studied; the goal then showed "In your list").
-- The released build was seen on production with the switch off.
--
-- This switch controls a client feature only. Saves stay behind
-- content.learner_resources on the server; the catalog lists only resources
-- whose record and map are both approved, and carries no paid placement.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.resource_recommendations'
    AND c.enabled = false
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
       'Owner-approved activation 2026-11-26 after local verification as guest and signed in (migration 20261126030000)'
FROM before b
JOIN changed USING (feature_key);
