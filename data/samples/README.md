# Lesson sample fixture

`sample_lesson_valid.json` is a comprehensive mixed-content lesson (terms,
concepts and MCQs) in the personal-lesson import format.

- **Used by:** `test/services/lesson_import_sample_fixture_test.dart`, which
  proves it passes the production import preflight with every item kept, and
  `tool/mcp_server`, which serves it to agents as the example lesson format.
- **Must stay importable.** Free `"text"` items are not supported by personal
  lessons; use a `"concept"` with `concept_text` instead.
- **Ordering:** items keep their array order within each type. The `order`
  field is accepted but not used by the importer.
- **Fixed item ids:** importing this file twice for the same account fails
  on duplicate ids (the import reports it and removes the partial lesson).
- **Not bundled in the learner app:** this fixture is test data, not an app
  asset.

The old `assets/sample_lesson.json` demo file was removed during cleanup after
confirming it had no runtime consumers. Bundled lesson assets remain in
`assets/lessons/`.
