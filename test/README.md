# LearningApp test suite

What must be tested, how skips, flaky tests and coverage are handled, and which CI checks are required: see [docs/testing/TEST_QUALITY_POLICY.md](../docs/testing/TEST_QUALITY_POLICY.md).

Tests are organized by the code or boundary they exercise. Do not maintain static test-count claims here; the suite changes continuously and CI is the authoritative result.

## Flutter tests

- `test/models/` — model serialization, compatibility, and domain behavior.
- `test/providers/` — Riverpod state and provider behavior.
- `test/services/` — service, sync, scheduling, and business logic.
- `test/widgets/` and `test/screens/` — widget and screen behavior.
- `test/mocks/` and `test/test_helpers/` — shared fakes and generated Mockito mocks.
- `test/integration/` — tests that need a local backend. They are collected by `flutter test` and skip with a reason when `LOCAL_SUPABASE_*` is not set; the required DB job runs them with `REQUIRE_LOCAL_SUPABASE=true`.

## Run checks

```bash
flutter test
flutter test test/services/
flutter test test/widgets/
flutter test --coverage
flutter analyze
```

## Other validation suites

- Python tooling tests: `python3 -m unittest discover -s tool/tests -v`
- Supabase pgTAP: `supabase test db` (use a disposable local Supabase instance)
- Curriculum manifest checks: `dart run tool/lint_manifest.dart --dir content/`
- Migration immutability: `dart run tool/verify_migration_history.dart --base-ref origin/main`

Never run `supabase db reset` or migration deployment commands against production. See `AGENTS.md` and `docs/HOSTED_MIGRATION_ROLLOUT.md` for database safety requirements.
