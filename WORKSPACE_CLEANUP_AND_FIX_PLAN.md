# Workspace Cleanup & Fix Plan

_Created: 2026-07-31 • Scope: full-workspace audit — failing tests, dead code, stale docs, file structure, error handling._

This is the single consolidated plan requested. It supersedes the ad-hoc TODO lists scattered
across the older root markdown files. Work top-to-bottom; each item has a checkbox so we can track
progress as we implement.

Status legend: ⬜ not started · 🔄 in progress · ✅ done
Severity: 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low

---

## ✅ Execution Summary (2026-07-31)

Phases 1–7 are **complete**. Final state: `flutter analyze` clean, **976 tests pass / 0 fail**
(was 943/4 at the start).

Key outcomes:
- Fixed the 4 failing tests (fake Supabase builder gained `range`/`limit`/`order` + a null-session
  fake `auth`); updated a stale guest-UUID test to match the current anonymous-auth behavior.
- Hardened error handling: typed `AppException`s now propagate instead of being masked as generic
  `DatabaseException` in `lesson_crud_service`; settings notifiers are dispose-safe; career-path
  creation validates title/slug/description.
- Corrected the Hive type-ID registry — it previously listed **wrong** ids (and two guard bugs);
  now documents the real persisted ids and the legacy id-3 landmine.
- Removed dead file `offline_content.dart` + stale `test_output.log`; archived two finished audits.
- **Correction to the audit:** `text_content.dart` is NOT orphaned (it is exported by
  `content_types.dart` and used in several widgets/providers), so it was kept.

---

## 0. Current Health Snapshot (measured during this audit)

| Check | Result |
|-------|--------|
| `flutter analyze lib test` | ✅ **No issues found** |
| `flutter test` | ✅ **976 passed, 0 failed** |
| Dead code from `DISCONNECT_AUDIT.md` | ✅ Already cleaned (11 files removed, routes wired) |
| `APP_REVIEW.md` phases A–C | ✅ All marked done and verified |
| `LEARNING_UI_PLAN.md` | ✅ Sprint items implemented and verified |

Bottom line: the codebase is stable with no analyzer issues or test regressions, and prior backlog
items in this cleanup scope are complete.

---

## Phase 1 — Fix the failing tests 🔴 (do first)

The pagination work from `APP_REVIEW.md` (item B3) added `.order('updated_at').range(offset, …)`
to `LessonCrudService.getLessonsForUser()`
([lib/services/lesson/lesson_crud_service.dart](lib/services/lesson/lesson_crud_service.dart#L49-L50)).
The test double never got a matching `range()` method, so it throws
`UnimplementedError: FakeListTransformBuilder - method Symbol("range") not implemented`.

Failing tests (all in [test/services/lesson/lesson_crud_service_test.dart](test/services/lesson/lesson_crud_service_test.dart)):
- `getLessonsForUser returns lessons for valid userId`
- `getLessonsForUser returns empty list when no lessons exist`
- `getLessonsForUser handles empty userId by using guest UUID`
- `addLesson handles empty userId with guest UUID`

- ✅ **P1.1** Added `range()`/`limit()`/`order()` to `FakeListTransformBuilder` and a null-session
  fake `auth` (`FakeGoTrueClient`) to `FakeSupabaseClient` in
  [test/test_helpers/fake_supabase_client.dart](test/test_helpers/fake_supabase_client.dart). Also
  updated the stale `addLesson` guest-UUID test to expect `AuthenticationException`, and added
  `if (e is AppException) rethrow;` to every catch block in `lesson_crud_service` so typed errors
  aren't masked.
- ✅ **P1.2** `flutter test` → **951 pass / 0 fail**.

---

## Phase 2 — Remove stale files 🟢 (safe cleanup)

### 2a. Stale root artifacts
- ✅ **P2.1** Deleted `test_output.log` (599 KB UTF-16 dump).
- ✅ **P2.2** No stray temp logs remain at root.

### 2b. Orphaned source modules (0 import references anywhere)
- ✅ **P2.3** Deleted [lib/models/offline_content.dart](lib/models/offline_content.dart) — plain model,
  no Hive adapter, zero imports.
- ✅ **P2.4** **Kept** `text_content.dart` — the earlier audit was wrong; `TextContent` is exported by
  `content_types.dart` and used in `lesson_provider`, `lesson_content_list_widget`, and
  `study_set_screen`. Do not delete.
- ✅ **P2.5** **Kept** `enhanced_lesson_creation_screen.dart` — a prior explicit user decision kept it
  for future wiring; leaving that decision intact.

> ⚠️ Before deleting any `.dart` file, run a final `grep` for the class/file name and re-run
> `flutter analyze` + `flutter test` to confirm nothing breaks.

---

## Phase 3 — Consolidate root documentation 🟡

The root has six overlapping markdown docs. Several are finished audits whose value is now historical.
Goal: keep living references, retire completed trackers.

| File | State | Action |
|------|-------|--------|
| APP_REVIEW.md | All phases ✅ done | ✅ **P3.1** Archived → `docs/history/APP_REVIEW.md`. |
| DISCONNECT_AUDIT.md | All actionable items ✅ done | ✅ **P3.2** Archived → `docs/history/DISCONNECT_AUDIT.md`. |
| [LEARNING_UI_PLAN.md](LEARNING_UI_PLAN.md) | ✅ Sprint backlog implemented | ✅ **P3.3** Kept as product reference. |
| [LEARNING_UI_RESEARCH.md](LEARNING_UI_RESEARCH.md) | Reference material | ✅ **P3.4** Kept. |
| [lesson_generation_prompt.md](lesson_generation_prompt.md) | Living reference | ✅ **P3.5** Kept. |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Accurate; build date stale | ✅ **P3.6** Kept; refresh date on next prod build. |
| WORKSPACE_CLEANUP_AND_FIX_PLAN.md (this file) | ✅ Completed tracker | Keep as historical completion record (or archive). |

> If you prefer a flat root, deleting the two "history" files instead of archiving is fine — git
> retains them. Archiving is the safer default; confirm your preference.

---

## Phase 4 — Error-handling hardening 🟠

Reduce silent failures on critical paths (aligns with the repo's robustness rule). None of these are
regressions; they are the remaining rough edges after the `APP_REVIEW` work.

- ✅ **P4.1** `lesson_crud_service` now rethrows typed `AppException`s (validation/auth/not-found)
  instead of masking them as `DatabaseException`. Verified `offline_provider` already surfaces sync
  errors via `state.copyWith(error: ...)` + `rethrow`.
- ✅ **P4.2** Fixed the used-after-dispose bug at its source: `BaseSettingsNotifier`
  ([lib/providers/base_settings_notifier.dart](lib/providers/base_settings_notifier.dart)) now guards
  every `state` read/write with `mounted`, so async load/save completing after disposal is a no-op.
  This covers all settings notifiers (audio, audio-lesson, theme).
- ✅ **P4.3** Confirmed `settings_screen`, `lesson_screen`, and `study_set_screen` all route errors
  through the shared [error_retry_view.dart](lib/widgets/error_retry_view.dart).
- ✅ **P4.4** Added length caps + slug-format validation to `createCareerPath`
  ([lib/services/career_path_service.dart](lib/services/career_path_service.dart)); lesson caps already
  enforced in `addLesson`.

---

## Phase 5 — File-structure & maintainability 🟡

- ✅ **P5.1** Corrected [lib/core/hive_type_ids.dart](lib/core/hive_type_ids.dart): the registry
  previously listed **wrong** ids (`mcq=2`, `termContent=4`, `concept=1`) that didn't match the real
  adapters, and the `concept`/`mcq`/`termContent` guards in `hive_service` were checking wrong ids
  (the `concept` guard collided with `UserProgress`=1, risking a skipped registration; `mcq`/
  `termContent` risked double-registration on re-init). The registry now reflects the real persisted
  ids and documents the legacy id-3 landmine (`ConceptAdapter` vs `QuestionAdapter`).
- 🔄 **P5.2** (optional) Oversized `build()` methods flagged in the old APP_REVIEW remain a
  nice-to-have refactor; not pursued in this pass to avoid churn. Revisit only files that still exceed
  the 400-line / 50-line thresholds.
- 🔄 **P5.3** (optional) Service-folder grouping — left as-is; the platform/Safari splits are
  legitimate.

---

## Phase 6 — Feature work completion (from LEARNING_UI_PLAN.md) 🟢

Not defects — deferred product features. Listed here so nothing is lost when the old plan is archived.

- ✅ **P6.1** Sprint 1.2 — `emoji` present on every concept/term in all 6 lesson JSONs in
  [assets/lessons/](assets/lessons/). (Verified already implemented.)
- ✅ **P6.2** Sprint 1.4 — study batch-size control done: `studyBatchSize` in
  [lib/models/settings_model.dart](lib/models/settings_model.dart), slider in
  [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart), slicing in
  [flashcard_screen.dart](lib/screens/study/flashcard_screen.dart) and
  [mcq_screen.dart](lib/screens/study/mcq_screen.dart).
- ✅ **P6.3** Sprint 2 — **complete.** Pomodoro break system (timer `breakEnabled/isOnBreak/
  blocksCompleted` + auto-transition in [timer_provider.dart](lib/providers/timer_provider.dart),
  [break_overlay.dart](lib/widgets/study/break_overlay.dart) wired into flashcard/mcq screens,
  toggle in [timer_widget.dart](lib/widgets/timer_widget.dart)); **recall-before-reveal** already
  present ([review_content_widgets.dart](lib/widgets/review_content_widgets.dart) `_QualityButtons`);
  **Quick Review batch mode** (`startSession({int? limit})` in
  [spaced_repetition_service.dart](lib/services/spaced_repetition_service.dart),
  [review_screen.dart](lib/screens/review_screen.dart) `limit`, `_startQuickReview` in
  [review_widgets.dart](lib/widgets/review_widgets.dart) using `SettingsModel.studyBatchSize`);
  **granular lesson mastery %** (`computeMastery` + `lessonMasteryProvider` in
  [lesson_progress_provider.dart](lib/providers/lesson_progress_provider.dart), shown on
  [lesson_card.dart](lib/widgets/lesson_card.dart)). Tests added.
- ✅ **P6.4** Sprint 3 — **complete.** `difficultyCategory` on
  [spaced_repetition.dart](lib/models/spaced_repetition.dart) + `DifficultyBadge` UI in
  [review_content_widgets.dart](lib/widgets/review_content_widgets.dart); **session summary duration**
  ([session_result.dart](lib/models/session_result.dart) `duration/formattedDuration`, shown
  in [session_results_screen.dart](lib/screens/study/session_results_screen.dart)); **category color
  stripe** already present via `DesignTokens.getTagColor` on
  [lesson_card.dart](lib/widgets/lesson_card.dart); **anti-cramming nudge**
  (`_maybeShowAntiCrammingNudge` in [lesson_screen.dart](lib/screens/study/lesson_screen.dart)).
  Tests added.

---

## Phase 7 — Backend reachability & keep-alive ✅

Added so users are told when Supabase (not just the device) is down, and so the free-tier
project does not auto-pause after inactivity.

- ✅ **P7.1** [lib/services/supabase_health_service.dart](lib/services/supabase_health_service.dart)
  — lightweight, timeout-bounded probe returning `SupabaseStatus {unknown, reachable, unreachable}`.
  A `PostgrestException` with a code counts as reachable (server answered); only timeouts/connection
  failures count as unreachable.
- ✅ **P7.2** [lib/providers/supabase_health_provider.dart](lib/providers/supabase_health_provider.dart)
  — polls every 2 min, skips probing while the device is offline, exposes `refresh()` for Retry.
- ✅ **P7.3** [lib/providers/connectivity_provider.dart](lib/providers/connectivity_provider.dart)
  — `ConnectivityAware` now shows: device-offline banner (orange) OR server-unreachable banner
  (red, with **Retry**) with an accessible `Semantics(liveRegion)` message.
- ✅ **P7.4** [.github/workflows/supabase-keepalive.yml](.github/workflows/supabase-keepalive.yml)
  — cron every 3 days pings the REST endpoint to keep the free-tier project awake. Requires repo
  secrets `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- ✅ Tests: [test/providers/supabase_health_provider_test.dart](test/providers/supabase_health_provider_test.dart) (3 passing).

---

## Completion status
All planned phases in this tracker are complete and validated.
