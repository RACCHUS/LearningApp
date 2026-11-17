-- Contributor (educator) profile pages and their entry points (Q&A answer
-- author link, Profile screen). UI gate: public reads are already gated on
-- the server by private.is_educator_profiles_public_enabled(), and writes
-- by the educator_profiles RLS policies (owner or moderator only).
-- Default OFF until the deployed web build is checked.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('learning.educator_profiles', 'Contributor profiles', 'Learning', 'release', false, 'experimental', false,
  'Contributor profile pages linked from Q&A answers and the Profile screen; public reads stay server-gated')
ON CONFLICT (feature_key) DO NOTHING;
