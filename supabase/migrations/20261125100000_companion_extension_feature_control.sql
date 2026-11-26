-- Companion to external resources, EX-9 (companion plan v1.0 §5.4, §7.4):
-- register the `content.companion_extension` gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed.
--
-- What the gate covers: the route the browser extension opens
-- (`/#/companion-for?url=...&title=...`). The extension reads the address
-- and title of the current tab only when the learner clicks its button
-- (`activeTab`), and passes them in the URL fragment, which no server
-- receives. The route then shows the learner's companion for that page, or
-- offers to add the page as a resource.
--
-- Where the server gate is: like `content.companion_capture`, this row
-- switches a client entry point. Reading the learner's resources is the
-- existing owner-only read, and saving a new one is the existing
-- `save_learner_external_resource` behind `content.learner_resources`. This
-- row must not be read as a second server gate.
--
-- Shutoff behavior: the route says the extension is not available and saves
-- nothing. Everything else in the companion works as before.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.companion_extension', 'Companion browser extension route', 'Content', 'release', false, 'experimental', false,
  'Client entry point opened by the browser extension: shows the companion for the page the learner is on, or offers to add it; the link arrives in the URL fragment; reads and saves stay behind content.learner_resources')
ON CONFLICT (feature_key) DO NOTHING;
