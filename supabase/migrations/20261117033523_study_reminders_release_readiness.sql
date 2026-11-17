-- Allow the admin UI to activate study reminders after production validation.
-- The operator still controls the enabled state through the audited admin RPC.
UPDATE private.site_feature_controls
SET release_ready = true
WHERE feature_key = 'learning.study_reminders'
  AND release_ready = false;
