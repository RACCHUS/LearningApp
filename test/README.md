# LearningApp test suite

Tests are organized by the code or boundary they exercise. Do not maintain static test-count claims here; the suite changes continuously and CI is the authoritative result.

## Flutter tests

- `test/models/` — model serialization, compatibility, and domain behavior.
- `test/providers/` — Riverpod state and provider behavior.
- `test/services/` — service, sync, scheduling, and business logic.
- `test/widgets/` and `test/screens/` — widget and screen behavior.
- `test/mocks/` and `test/test_helpers/` — shared fakes and generated Mockito mocks.
- `test/integration/` — environment-dependent/manual integration scripts. These are not automatically included by `flutter test` unless named as Flutter test files.

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
