-- Activation (2026-11-24, owner-delegated decision) of
-- learning.objective_readiness_view (readiness by objective, plan v1.2 §8.7;
-- migration 20261124070000). The app card has been live since the web build
-- of e0c342d; guests read published public versions without learner data.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'learning.objective_readiness_view'
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
       'Owner-delegated activation 2026-11-24 after release verification (migration 20261124080000)'
FROM before b
JOIN changed USING (feature_key);
