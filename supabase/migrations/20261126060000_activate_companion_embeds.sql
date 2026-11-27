-- Activation (2026-11-26, owner: "You can handle the YouTube too") of
-- content.companion_embeds (companion plan v1.0 EX-7; migration
-- 20261125090000): YouTube's own embedded player inside the companion
-- screen, loaded only after the learner taps play.
--
-- What the seed said had to come first: the provider wording. YouTube's API
-- Services developer policies (III.A.1, III.A.2) need the app's terms to say
-- users are bound by the YouTube Terms of Service, and a privacy policy that
-- says the app uses YouTube API Services, links the Google Privacy Policy and
-- explains what is collected. That wording (chosen at the owner's request,
-- #452) is published at /outside-study-privacy.html, which the player's offer
-- links beside the YouTube Terms and Google Privacy Policy links.
--
-- The player was verified in a real browser on the local stack, as a guest
-- and signed in, under the production CSP (frame-src
-- https://www.youtube-nocookie.com): nothing is requested from YouTube before
-- the tap, there is no autoplay, the frame is never smaller than 200 by 200
-- and nothing is drawn over it.
--
-- Client feature only: the player writes nothing to LearningApp, so there is
-- no server write to gate. Outline saves stay behind
-- content.learner_resources.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, and one audit row. actor_id is NULL because a migration
-- has no signed-in admin. Only a row still OFF is touched, so re-running is a
-- no-op. Turning it off again goes through the admin UI. The description is
-- brought up to date because its "before it is switched on" condition is met.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.companion_embeds'
    AND c.enabled = false
  FOR UPDATE
),
changed AS (
  UPDATE private.site_feature_controls c
  SET release_ready = true,
      enabled = true,
      revision = b.revision + 1,
      description = 'Client feature: plays an embeddable YouTube video from its provider inside the companion screen after the learner taps play; nothing is recorded; provider wording published at /outside-study-privacy.html and linked from the offer; Open (leaves LearningApp) stays available when OFF',
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
       'Owner-approved activation 2026-11-26 after the provider wording was published and local verification as guest and signed in (migration 20261126060000)'
FROM before b
JOIN changed USING (feature_key);
