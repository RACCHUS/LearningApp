-- Activation (2026-11-24, owner-delegated decision; see ingestion plan v1.2
-- D-14 progress note) of learning.readiness_coverage_gate.
--
-- Precondition met: College Algebra, Prealgebra and Excel each have full
-- held-out coverage in production (every objective has 6+ approved,
-- fingerprint-matching held-out checks, AI-reviewed and labelled so).
-- Targets without held-out checks show "Study progress" and "Not enough
-- checks yet" instead of an overall readiness band; concept counts and
-- per-concept bands stay visible. The client wiring has been live since the
-- web build of 9e35d20.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'learning.readiness_coverage_gate'
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
       'Owner-delegated activation 2026-11-24: three targets have full held-out coverage (migration 20261124050000)'
FROM before b
JOIN changed USING (feature_key);
