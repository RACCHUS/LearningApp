# Lesson sample fixture

`sample_lesson_valid.json` is a comprehensive mixed-content fixture for the lesson import integration script.

- **Purpose:** exercise lesson parsing and content-order handling.
- **Used by:** `test/integration/test_import.dart`.
- **Content types:** terms, concepts, MCQs, and text blocks.
- **Not bundled in the learner app:** this fixture is test data, not an app asset.

Run the integration script only in a configured development environment:

```bash
dart run test/integration/test_import.dart
```

The old `assets/sample_lesson.json` demo file was removed during cleanup after confirming it had no runtime consumers. Bundled lesson assets remain in `assets/lessons/`.
