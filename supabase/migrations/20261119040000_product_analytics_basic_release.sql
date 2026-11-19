-- Owner-approved basic release of opt-in product analytics (2026-11-19).
--
-- What this turns on:
-- * The database release gate (analytics.product_release_gate): policy
--   version "basic-2026-11-19" approved by the owner, collection enabled.
-- * The client switch analytics.product_events (the admin UI deliberately
--   refuses this key, so it is set here with an audit row).
--
-- What stays exactly as before (privacy gates are not weakened):
-- * Per-account eligibility (auth app metadata product_analytics_eligible)
--   is still off unless set for an account. Nobody is enrolled by this.
-- * Each person must still explicitly opt in; withdrawal deletes their
--   server events; ingestion keeps its allowlisted events and properties,
--   rate limits and 2 KB payload cap.
INSERT INTO analytics.product_release_gate
  (id, approved_policy_version, policy_approved_at, collection_enabled,
   reviewed_by, changed_at)
VALUES
  (1, 'basic-2026-11-19', now(), true,
   'owner (approved in chat, 2026-11-19)', now())
ON CONFLICT (id) DO UPDATE
  SET approved_policy_version = EXCLUDED.approved_policy_version,
      policy_approved_at = EXCLUDED.policy_approved_at,
      collection_enabled = true,
      reviewed_by = EXCLUDED.reviewed_by,
      changed_at = now();

WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'analytics.product_events' AND c.enabled = false
  FOR UPDATE
),
changed AS (
  UPDATE private.site_feature_controls c
  SET release_ready = true, enabled = true,
      revision = b.revision + 1, updated_at = now()
  FROM before b
  WHERE c.feature_key = b.feature_key
  RETURNING c.feature_key
)
INSERT INTO private.site_feature_change_audit
  (feature_key, actor_id, prior_enabled, next_enabled, prior_maturity,
   next_maturity, previous_revision, new_revision, reason)
SELECT b.feature_key, NULL, b.enabled, true, b.maturity, b.maturity,
       b.revision, b.revision + 1,
       'Owner-approved basic product analytics release 2026-11-19 (migration 20261119040000); per-account eligibility and opt-in unchanged'
FROM before b
JOIN changed USING (feature_key);
