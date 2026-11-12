# Integration tests

Tests here exercise real components together against real services. Each one
must fail closed: a setup, connection or cleanup problem is a test failure,
never a silent skip or an early `return`.

## `lesson_import_local_supabase_test.dart`

End-to-end lesson import through the production code path
(`LessonImportService` → `LessonCrudService` / `LessonContentService`) against
a **local** Supabase stack, followed by readback through the production read
path and an independent service-role check of the persisted rows.

Covers:

- full fidelity of an imported lesson: title, description, tags, owner,
  private visibility, terms, concepts, and MCQ / true-false / short-answer
  questions with options, answer keys, accepted answers and grading method;
- an invalid answer key anywhere in the payload writes nothing;
- a failure after the lesson row exists is reported as
  `LessonImportIncompleteException` and the partial lesson is really removed
  from the database (simulated mid-import failure, and a genuine database
  rejection: a duplicate item id);
- another learner cannot read a private imported lesson (RLS).

It uses a pure-Dart `SupabaseClient`, so no Flutter platform channels are
needed. Synthetic `@example.test` users are created through the local admin
API and deleted afterwards. The test refuses any non-loopback URL and never
reads `.env`.

**In CI** it runs in the *Verify clean Supabase migrations and complete
official taxonomy ingestion* job with `REQUIRE_LOCAL_SUPABASE=true`, so
missing configuration fails the job. In the ordinary `flutter test` run it is
skipped with a reason, because that job has no database.

**Locally:**

```bash
supabase start
eval "$(supabase status -o env)"
LOCAL_SUPABASE_URL=$API_URL LOCAL_SUPABASE_ANON_KEY=$ANON_KEY \
LOCAL_SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY REQUIRE_LOCAL_SUPABASE=true \
flutter test test/integration/lesson_import_local_supabase_test.dart
```

## History

`test_lesson_creation.dart` (always skipped: it needed platform channels and
returned early on setup errors) and `test_import.dart` (a print-only script
that re-implemented order handling and never called the importer) were removed
in plan PR-3. Their coverage is replaced by the test above and by
`test/services/lesson_import_sample_fixture_test.dart`.
