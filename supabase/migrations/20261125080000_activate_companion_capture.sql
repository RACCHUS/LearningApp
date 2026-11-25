-- Activation (2026-11-25, owner said "Deploy and switch on") of
-- content.companion_capture (companion plan v1.0 EX-6; migration
-- 20261125070000): the entry points that carry a link from another page
-- into the add-a-resource form.
--
-- Verified before this migration on the local stack in a real browser: as a
-- guest (the cleaned link was saved on the device; no network request
-- carried the captured link), signed in (nothing was sent before Add; the
-- save went through the gated save_learner_external_resource), with no goal
-- (the form asks for one and cannot save), and with the switch off (the
-- route refuses and saves nothing). On production with the switch off the
-- released build was seen refusing the route.
--
-- This switch controls client entry points only. The save stays behind
-- content.learner_resources on the server.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.companion_capture'
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
       'Owner-approved activation 2026-11-25 after local verification as guest and signed in (migration 20261125080000)'
FROM before b
JOIN changed USING (feature_key);
