-- Owner-approved activation (2026-11-22) of content.feedback_chips:
-- Too hard / Too easy / Confusing / Wrong / Not what I needed on
-- AI-generated lessons (#353), attached to the lesson and prompt-pack
-- versions. Only signed-in permanent accounts see it, only on lessons
-- tagged ai-generated; choices never change the lesson.
--
-- Mirrors public.admin_set_site_feature: release-ready plus enabled, the
-- revision bumped, one audit row. Re-running is a no-op.
WITH before AS (
  SELECT c.feature_key, c.enabled, c.maturity, c.revision
  FROM private.site_feature_controls c
  WHERE c.feature_key = 'content.feedback_chips' AND c.enabled = false
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
       'Owner-approved activation 2026-11-22 (migration 20261122000000)'
FROM before b
JOIN changed USING (feature_key);
