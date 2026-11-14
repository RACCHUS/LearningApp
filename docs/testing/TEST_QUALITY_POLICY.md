# Test Quality Policy

**Status:** current policy (plan PR-9, *CI Efficiency and Test-Quality Improvement Plan v4.1*).
**Owner:** repository maintainer. Changes to this policy, to required checks, or to any registry below need maintainer review.

The goal is not more tests or a higher percentage. It is that **a green PR is trustworthy**: the right checks run, they would fail on a real bug, and nothing is silently skipped.

---

## 1. Required and advisory CI

| Check (exact name) | Workflow | Required | What it proves |
|---|---|---|---|
| `Analyze, test, and build` | `flutter-ci.yml` | **Yes** | A fail-closed gate job (`tool/ci/check_required_results.py`): passes only if both jobs below succeeded; skipped, cancelled or missing counts as failure |
| ↳ `Analyze and test` | `flutter-ci.yml` | via gate | Analysis, every Python/Dart tool suite, schema/registry/manifest contracts, full Flutter suite (`--concurrency 3`), log-noise and skip ratchets |
| ↳ `Build web releases (standard and simulation preview)` | `flutter-ci.yml` | via gate | Both web release builds (sequential, own runner, in parallel with the job above) and the spelling-asset size check |
| `Verify clean Supabase migrations and complete official taxonomy ingestion` | `flutter-ci.yml` | **Yes** | Incremental upgrade, hosted-ledger backfill, clean slate, post-ingestion pgTAP (parity enforced across all four), storage/broker races, local lesson import/readback, `db lint` |
| `Validate official taxonomy sources` | `taxonomy-official-data.yml` | **Yes** | Pinned official source files |
| `Early feedback (changed files)` | `flutter-ci.yml` | No | Fast first signal on checks related to the PR diff; never replaces a required check |
| `Browser smoke (Chromium guest journeys)` | `flutter-ci.yml` | No (candidate) | Real-browser guest journeys, a11y-tree selectors, host allow-list |
| `Run critical mutation seeds` | `mutation-seeds.yml`, weekly | No | Planted known bugs are caught |
| `Coverage and test-runtime audit` | `test-quality-audit.yml`, weekly | No | Coverage by risk area; dated timing/skip artifacts (90 days) |
| `Flutter Test Concurrency Benchmark` | `flutter-test-benchmark.yml`, on demand | No | Re-measure `--concurrency` when runners change |

Rules:

- **Never rename** a required check, add `paths` filters to a required workflow, or put `continue-on-error` on required work. `Analyze, test, and build` is now a gate job: any job added behind it must be listed in its `needs:` **and** in the gate script's arguments, and no other job may reuse that name (plan §9 E1).
- Superseded runs are cancelled on PR branches only; every push to `main` keeps its own run.
- An advisory job becomes required only after a sustained stable record (at least 30 consecutive non-cancelled green runs over at least 14 days, with no reruns needed to get there) and maintainer sign-off. Branch protection on `main` requires up-to-date branches and applies to admins, so a flaky required check blocks every merge.

## 2. Discovery: no test may silently stop running

- Every `tool/tests/test_*.py` (and other test files there) must be executed by a CI runner. `tool/ci/check_test_inventory.py --strict` fails otherwise, and fails on stale or unparseable entries.
- Flutter tests are discovered by `flutter test` from `test/**/*_test.dart`. Files not ending in `_test.dart` are not tests.
- Renaming, moving, deleting, loosening or skipping a test needs a stated replacement in the PR description.

## 3. Mandatory evidence by risk area

A change to one of these areas needs the listed evidence **in the same PR**, and at least one test that **fails on the old broken behavior**.

| Area | Minimum evidence |
|---|---|
| Answer keys, assessment content, grading | Unit truth table including missing/ambiguous keys (never default to option A); independent oracle for authored math (`tool/tests/clep_algebra_oracles.py`); pgTAP for server grading |
| CLEP simulation, protected fields | pgTAP auth/role tests; explicit absence of protected keys in client payloads; registration gate |
| Auth, roles, RLS, storage ownership | pgTAP negative paths (other user, wrong role, anonymous); local-Supabase test for cross-boundary flows |
| Feature controls, kill switches, BYOK | OFF-path test with zero external requests and no writes; real provider tested against controlled registry snapshots; BYOK latch stays hard-off |
| Lesson import / creation | Readback against local Supabase (`test/integration/lesson_import_local_supabase_test.dart` pattern); invalid input writes nothing; partial failure cleans up |
| Migrations | Append-only (never edit merged files); all four DB scenarios pass; guarded deployment only (see `AGENTS.md`) |
| UI interaction, pre-reader, accessibility | Widget test that taps/types like a user and asserts resulting state and semantics; browser journey for routing changes |
| Progress, offline, sync | State-machine unit tests plus persistence; no double award; user scoping |
| Privacy, analytics | pgTAP consent/retention/erasure; client outbox tests |

For high-risk logic, add or update a **mutation seed** in `tool/ci/mutation_seeds.py`: plant the representative bug, name the tests that must fail, and confirm with `python3 tool/ci/mutation_seeds.py --only <id>`. Every PR runs `--check` so seeds cannot silently stop applying.

## 4. Skips and quarantine

Every skipped Flutter test must be in `SKIP_REGISTRY` in `tool/ci/check_test_skips.py`. CI fails on any unregistered skip, on a registry entry that no longer matches a skip (stale), and on an expired quarantine.

- **`conditional`**: runs by design elsewhere or behind a release gate. Requires `reason` and `runs_in` (where it is actually covered). Current entries: the local-Supabase import test (DB job), the 50k synthetic load probe (dedicated step), and the BYOK provider tests (hard-off latch).
- **`quarantine`**: a flaky or broken test temporarily skipped. Requires `reason`, `tracking` (issue or PR), `protection` (what still guards the behavior) and `expires` (at most **30 days**). Fix or delete it with a stated replacement before expiry; extending it needs maintainer review.

Never quarantine a test protecting answer correctness, grading, auth/RLS, privacy, protected-field exposure or the BYOK latch. Fix it or block the change.

## 5. Flaky tests

- **No automatic retries** in required checks. A retry that passes hides a real race; required checks must expose flakiness.
- To diagnose, repeat the test in isolation (`flutter test <file> --plain-name '<name>'` in a loop, or with `--test-randomize-ordering-seed random`). Look first for shared Hive/SharedPreferences state, global providers, real timers, temp files and fixed user IDs.
- Use controllable clocks (`fakeAsync`), seeded randomness and injected fakes; never `sleep` to wait for state.
- If it cannot be fixed immediately and is not in a protected area (§4), quarantine it with tracking and an expiry.

## 6. Log noise

A passing test that logs `MissingPluginException`, `MissingStubError`, `LateInitializationError` or an uninitialized-Supabase error usually tested an error path by accident. `tool/ci/check_test_log_noise.py` fails on any such message. `KNOWN_NOISE` is empty: fix new noise rather than listing it. For offline behavior, use `test/test_helpers/offline_supabase_client.dart`; for text-to-speech, `installFakeTtsChannel`.

## 7. Coverage

- **Report-only, no percentage gate.** The weekly audit publishes line coverage per critical area (`tool/ci/summarize_coverage.py`) and the least-covered critical files. Generated code (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, generated l10n) is excluded.
- Use it to find untested critical code, then write tests that would fail on a real bug. Coverage never substitutes for functional review, and test counts are not a quality measure.
- Numerical floors may be introduced later only for critical areas, after a baseline and a false-positive review, and only by changing this policy.
- Python tooling coverage by subsystem is in the same weekly audit (`tool/ci/summarize_python_coverage.py`, pins in `requirements-python-coverage.txt`).
- pgTAP assertion counts are not SQL coverage. Database security evidence per area is in [DATABASE_SECURITY_MATRIX.md](DATABASE_SECURITY_MATRIX.md), generated from `supabase/tests/` by `tool/ci/pgtap_security_matrix.py --write`; CI fails if it is stale, so regenerate it whenever a pgTAP file changes.

## 8. Performance and timing

- Timing evidence must state the sample size and separate wall time from total runner time. Single runs are noisy (GitHub runners vary by ~25%).
- `flutter test --concurrency 3` in the required job was measured (PR-5: median 237 s vs 306 s for the default). Re-measure with the benchmark workflow before changing it.
- Load probes (the 50k export) are synthetic and are labeled as such; they are not product latency guarantees.

## 9. Running checks locally

```bash
flutter analyze
flutter test --concurrency 3
python3 tool/ci/check_test_inventory.py --strict
python3 -m unittest discover -s tool/tests -p 'test_<name>.py' -v
python3 tool/ci/mutation_seeds.py --check
```

Browser smoke (needs `requirements-e2e.txt` in a venv and `playwright install chromium`):

```bash
flutter build web --release
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
E2E_BASE_URL=http://127.0.0.1:8765/ python3 -m pytest tool/tests/test_browser_smoke.py -v
```

Build the web app from `.env.example` for browser tests. Never point any test at production or use real credentials.

## 10. Review checklist (every PR, human or AI)

- What user-visible or data-integrity behavior changed, and which test proves it?
- Does at least one test **fail on the old broken implementation**?
- For assessment content: was the authored answer independently validated?
- For DB/security: are unauthorized user, role and error paths tested in pgTAP or local DB?
- For UI: does the test interact like a real user and assert the resulting state?
- Was any test skipped, loosened, deleted, renamed or moved out of discovery? What replaces it?
- Did any test add nondeterminism, real network calls, secrets, shared mutable state or sleeps?
- Do all three required checks pass on the **final** commit SHA?
- Is every experimental or disabled feature still gated exactly as intended?

> A meaningful failing test is useful information. A passing test that cannot detect its target failure is false confidence.
