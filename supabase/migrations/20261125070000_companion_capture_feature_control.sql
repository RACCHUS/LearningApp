-- Companion to external resources, EX-6 (companion plan v1.0 §5.1 layer L2,
-- §7.4): register the `content.companion_capture` gate.
--
-- Additive and append-only: one new registry row, default OFF and NOT
-- release-ready. No existing row, function or policy is changed.
--
-- What the gate covers: the entry points that carry a link into LearningApp
-- from somewhere else (the "add from a link" route, the bookmarklet and the
-- Apple Shortcut that open it). The link travels in the URL fragment of the
-- hash-routed app, so it never reaches a server until the learner chooses to
-- save it.
--
-- Where the server gate is: capture has no write of its own. Saving the
-- captured resource is the existing `save_learner_external_resource`, which
-- checks `content.learner_resources` on the server. This row therefore
-- switches a client entry point only, and its description says so. It must
-- not be read as a second server gate.
--
-- Shutoff behavior: the capture route says it is not available and saves
-- nothing. Adding a resource from a goal, by typing or pasting a link, still
-- works.
INSERT INTO private.site_feature_controls
  (feature_key, label, category, kind, enabled, maturity, release_ready, description)
VALUES
 ('content.companion_capture', 'Companion link capture', 'Content', 'release', false, 'experimental', false,
  'Client entry points that carry a link from another page into the add-a-resource form (route, bookmarklet, Shortcut); the save itself stays behind content.learner_resources; pasting a link on a goal still works when OFF')
ON CONFLICT (feature_key) DO NOTHING;
