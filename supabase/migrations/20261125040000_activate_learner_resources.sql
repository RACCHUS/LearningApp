-- Activation (2026-11-25, owner said "Deploy and switch on") of
-- content.learner_resources (companion plan v1.0 EX-1; migration
-- 20261125030000): a learner's own outside resources on a goal.
--
-- Verified before this migration on the local stack, as a guest (device
-- storage, no server call) and signed in (gated server functions), and with
-- the switch off (card hidden, writes refused, delete still allowed).
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.learner_resources'
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
       'Owner-approved activation 2026-11-25 after local verification as guest and signed in (migration 20261125040000)'
FROM before b
JOIN changed USING (feature_key);
