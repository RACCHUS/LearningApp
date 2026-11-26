-- Activation (2026-11-26, owner: "finish everything that can be done on
-- your own"; Chrome Web Store fee approved) of content.companion_extension
-- (companion plan v1.0 EX-9; migration 20261125100000): the
-- /#/companion-for route the browser extension opens beside the page a
-- learner is studying.
--
-- Verified before this migration on the local stack in a real browser:
-- as a guest earlier (EX-9, matching and new-page cases) and now signed in.
-- Opening the route for a new https page showed the add form with the
-- page's name and link filled in and saved nothing; "Add to this goal"
-- saved it through the gated save_learner_external_resource; opening the
-- same page again opened its companion. That last step found a stale match
-- within one session (fixed in the same change, resourceForLinkProvider is
-- now autoDispose, with a widget test).
--
-- This switch controls a client route only. Saves stay behind
-- content.learner_resources on the server, and the extension itself asks
-- for activeTab only (test/widgets/companion_for_link_test.dart).
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.companion_extension'
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
       'Owner-approved activation 2026-11-26 after local verification as guest and signed in (migration 20261126040000)'
FROM before b
JOIN changed USING (feature_key);
