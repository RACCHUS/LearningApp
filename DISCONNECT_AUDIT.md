# Disconnect Audit & Remediation Plan

Comprehensive audit of unused code, broken wiring, and underused features in the LearningApp codebase, with concrete fixes for each.

**Audit date:** 2026-05-23
**Scope:** `lib/`, `database/schema/`, route definitions, provider/widget usage

---

## Summary

| Category | Count | Priority |
|----------|-------|----------|
| Broken wiring (silent bugs) | 4 | 🔴 High — fix first |
| Underused features (data exists, not surfaced) | 4 | 🟡 Medium — quick wins |
| Dead code (unreachable files) | 13 | 🟢 Low — cleanup |

**Total estimated effort:** ~4–6 hours

---

## 🔴 Category 1: Broken Wiring (Silent Bugs)

These will silently fail or crash at runtime. Fix first.

### Issue #1 — `study_time_seconds` column does not exist in DB

**Symptom:** Daily goal ring on home screen always shows 0 minutes studied.

**Root cause:**
- DB schema: [`database/schema/schema.sql`](database/schema/schema.sql) line 68 defines `study_time_minutes INTEGER` on `user_progress`.
- App code: [`lib/providers/daily_goal_provider.dart`](lib/providers/daily_goal_provider.dart#L29) queries `.select('study_time_seconds')` — a column that **does not exist** in Supabase.
- [`lib/providers/study_provider.dart`](lib/providers/study_provider.dart#L245) writes `'study_time_seconds'` to the same nonexistent column.
- Local Hive models use `studyTimeSeconds`, so the local app appears to work; remote sync is silently broken.

**Fix:** Add `study_time_seconds INTEGER DEFAULT 0` column to `user_progress` table via a new migration, and update all upserts to write both columns (keeping `_minutes` as derived value for backward compat). The `lesson_progress` / `user_progress` model `toJson()` already writes both — make daily_goal_provider read the correct one.

**Files to change:**
- `database/migrations/` — new migration `add_study_time_seconds_to_user_progress.sql`
- `lib/providers/daily_goal_provider.dart` — confirm query column name post-migration

---

### Issue #2 — Missing `emoji` columns in Supabase schema

**Symptom:** Emojis added in Sprint 1 to `Lesson`, `Term`, `Concept` survive in Hive but are stripped on any Supabase round-trip (sync, multi-device).

**Root cause:** [`database/schema/schema.sql`](database/schema/schema.sql) tables for `lessons`, `terms`, `concepts` have no `emoji` column. Models serialize emoji via `toJson()` but Supabase silently drops unknown columns.

**Fix:** Migration to add `emoji TEXT` (nullable) to `lessons`, `terms`, `concepts` tables.

**Files to change:**
- `database/migrations/` — new migration `add_emoji_columns.sql`
- `database/schema/schema.sql` — update reference schema

---

### Issue #3 — Dead navigation routes

**Symptom:** App crashes with route-not-found when user taps certain buttons.

**Root cause:** Two `context.go`/`context.push` calls target routes never defined in [`lib/providers/router_provider.dart`](lib/providers/router_provider.dart):

| Caller | Target Route | Status |
|--------|--------------|--------|
| [`career_paths_screen.dart`](lib/screens/careers/career_paths_screen.dart#L87) FAB | `/careers/create` | ❌ Not defined |
| [`content_picker_screen.dart`](lib/screens/study_sets/content_picker_screen.dart#L378) | `/study-sets` | ❌ Not defined |

**Investigation result:** Both routes are legitimate, useful features with full backend support:
- `CareerPathService.createCareerPath()` is fully implemented ([`lib/services/career_path_service.dart`](lib/services/career_path_service.dart#L82))
- `StudySetNotifier` + `HomeStudySetsList` widget already exist ([`lib/screens/home/home_study_sets_list.dart`](lib/screens/home/home_study_sets_list.dart)) — just need a Scaffold wrapper

**Fix:** Build the missing screens and register the routes:

1. **Create `SavedStudySetsScreen`** at `lib/screens/study_sets/saved_study_sets_screen.dart` — Scaffold wrapping `HomeStudySetsList` with AppBar and "Create" FAB pointing to `/content-picker`.
2. **Create `CareerPathCreateScreen`** at `lib/screens/careers/career_path_create_screen.dart` — simple form (title, slug, description, estimated months, is_public toggle) calling `careerPathService.createCareerPath()`.
3. **Register both routes** in `lib/providers/router_provider.dart`.

---

### Issue #4 — `connectivityProvider` defined but never consumed

**Symptom:** App tracks online/offline state but no UI reacts to it. Users get no feedback when offline.

**Root cause:** Provider defined and tested, but `grep_search` shows zero usage in `lib/screens/**` or `lib/widgets/**` (other than `SyncStatusIndicator`, which itself isn't placed anywhere).

**Fix:** Combined with Issue #8 below (place `SyncStatusIndicator` somewhere visible).

---

## 🟡 Category 2: Underused Features (Surface Existing Data)

Data exists in models and is generated/imported correctly, but never shown to the user.

### Issue #5 — Emoji not shown on lesson cards

**Symptom:** Users only see lesson emojis after opening a lesson (in flashcards). Home/list view is plain text.

**Fix:** Add emoji display to [`lib/widgets/lesson_card.dart`](lib/widgets/lesson_card.dart) — show `lesson.emoji` (24–32px) before the title text. Fall back gracefully when null.

---

### Issue #6 — Difficulty not shown on lesson cards ⚠️ Requires model change

**Symptom:** Courses display difficulty chips, but individual lessons don't.

**Investigation finding:** `difficulty` is **not** a field on the `Lesson` model — it only exists on `LessonTemplate` (creation helper) and `Course`. Surfacing it on lesson cards requires:
1. Adding `String? difficulty` to `Lesson`, `BaseLesson`, generation prompts, and Hive adapter (new `@HiveField(11)`).
2. Migrating `lessons` table in Supabase.
3. Backfilling existing lesson JSONs.

**Decision:** Defer to a separate model-evolution task. Not part of this disconnect audit.

---

### Issue #7 — `estimatedDuration` never displayed ⚠️ Requires model change

**Symptom:** Templates and courses have `estimated_duration_minutes`, but lessons don't display it.

**Investigation finding:** Same as #6 — `estimatedDuration` exists on `LessonTemplate` but **not** on the `Lesson` model. Lesson JSON files have no duration field. Adding it requires model + schema + prompt changes.

**Decision:** Defer to a separate model-evolution task. Not part of this disconnect audit.

---

### Issue #8 — `SyncStatusIndicator` widget built but never placed

**Symptom:** Users have no visibility into sync state. Tapping doesn't exist as a discoverable action.

**Fix:** Place [`SyncStatusIndicator`](lib/widgets/progress/sync_status_indicator.dart) in the home screen app bar (or settings screen header). This also resolves Issue #4 by making connectivity visible.

---

## 🟢 Category 3: Dead Code (Safe to Delete)

These files have zero usage outside their own definition and (sometimes) their tests. Deleting them reduces cognitive load.

| # | File | Verification |
|---|------|--------------|
| 1 | [`lib/widgets/content_creation_widget.dart`](lib/widgets/content_creation_widget.dart) | 6 self-refs only |
| 2 | [`lib/widgets/content_management_panel.dart`](lib/widgets/content_management_panel.dart) | 6 self-refs only |
| 3 | [`lib/widgets/lesson_json_import_widget.dart`](lib/widgets/lesson_json_import_widget.dart) | Replaced by `EnhancedJsonImportWidget` |
| 4 | [`lib/services/career_skills_cache.dart`](lib/services/career_skills_cache.dart) | Zero imports |
| 5 | [`lib/services/lesson_flow_controller.dart`](lib/services/lesson_flow_controller.dart) | Zero imports |
| 6 | [`lib/services/import_export_service.dart`](lib/services/import_export_service.dart) | Only in tests |
| 7 | [`lib/services/data_sync_service.dart`](lib/services/data_sync_service.dart) | Only in tests |
| 8 | [`lib/services/voice_debug_service.dart`](lib/services/voice_debug_service.dart) | Zero imports |
| 9 | [`lib/services/audio_queue_manager.dart`](lib/services/audio_queue_manager.dart) | Zero imports |
| 10 | [`lib/services/audio_lesson/audio_queue_manager.dart`](lib/services/audio_lesson/audio_queue_manager.dart) | Zero imports (duplicate) |
| 11 | ~~`lib/screens/enhanced_lesson_creation_screen.dart`~~ | **KEEP** — may wire later (user decision) |
| 12 | [`lib/providers/lesson_creation_provider.dart`](lib/providers/lesson_creation_provider.dart) | Only consumer is dead `ContentManagementPanel` |

**Notes:**
- Also delete corresponding test files for items 6, 7 (`import_export_service_test.dart`, `data_sync_service_test.dart` if they exist).
- Do NOT delete `SyncStatusIndicator` — it's being placed in Issue #8.
- Do NOT delete `enhanced_lesson_creation_screen.dart` — kept for future wiring.

---

## Implementation Order

### Phase 1: Fix Broken Wiring (🔴 High Priority)
1. **Issue #1** — Add `study_time_seconds` migration + verify daily_goal query
2. **Issue #2** — Add `emoji` columns migration
3. **Issue #3** — Build `SavedStudySetsScreen`, `CareerPathCreateScreen`, register routes

### Phase 2: Surface Underused Data (🟡 Quick Wins)
4. **Issue #5** — Emoji on lesson cards
5. ~~**Issue #6**~~ — Deferred (requires model change)
6. ~~**Issue #7**~~ — Deferred (requires model change)
7. **Issue #8** — Place `SyncStatusIndicator` in home app bar (resolves #4)

### Phase 3: Cleanup Dead Code (🟢 Low Priority)
8. Delete 11 dead files (keeping `enhanced_lesson_creation_screen.dart`)
9. Run full test suite to confirm nothing breaks
10. Delete corresponding orphaned tests

---

## Testing Strategy

- **Phase 1:** Manual verification of daily goal ring after Phase 1.1; sync round-trip test for emoji after Phase 1.2.
- **Phase 2:** Visual check of lesson card; existing widget tests should still pass.
- **Phase 3:** `flutter test` after each batch of deletions; check `flutter analyze` for unused-import warnings.

---

## Decisions Made

- **Issue #3:** Build the missing screens — both backends exist and the features are useful.
- **Phase 3:** Delete 11 of 12 files. Keep `enhanced_lesson_creation_screen.dart` for future wiring.

---

## Implementation Status (2026-05-23)

| # | Issue | Status | Notes |
|---|-------|--------|-------|
| 1 | `study_time_seconds` column missing | ✅ Done | Migration `20260523_add_study_time_seconds.sql` + schema updated |
| 2 | Emoji not persisted to DB | ✅ Done | Migration `20260523_add_emoji_columns.sql` + schema updated |
| 3a | `SavedStudySetsScreen` missing | ✅ Done | Created + route `/study-sets` registered |
| 3b | `CareerPathCreateScreen` missing | ✅ Done | Created + route `/careers/create` registered (literal before `/:careerPathId`) |
| 4 | `connectivityProvider` not surfaced | ✅ Done | Via `SyncStatusIndicator` in home AppBar `bottom` |
| 5 | Emoji on `LessonCard` | ✅ Done | Prefix in title + menu row, guarded by null/empty check |
| 6 | Surface `difficulty` | ⏸️ Deferred | Field exists only on `LessonTemplate`/`Course`, not `Lesson`. Requires model evolution. |
| 7 | Surface `estimatedDuration` | ⏸️ Deferred | Same — needs model evolution. |
| 8 | `SyncStatusIndicator` placement | ✅ Done | In home AppBar `bottom` (idle = SizedBox.shrink) |
| 9–13 | Dead-code files | ✅ Done | Deleted 11 lib files + 6 orphaned tests. Kept `enhanced_lesson_creation_screen.dart` per user. |

**Validation:** `flutter analyze` clean (1 pre-existing unrelated warning). `flutter test` run after deletions.

**Files deleted:**
- `lib/widgets/content_creation_widget.dart`
- `lib/widgets/content_management_panel.dart`
- `lib/widgets/lesson_json_import_widget.dart`
- `lib/services/career_skills_cache.dart`
- `lib/services/lesson_flow_controller.dart`
- `lib/services/import_export_service.dart` (+ test)
- `lib/services/data_sync_service.dart` (+ 2 tests + 2 mock files)
- `lib/services/voice_debug_service.dart`
- `lib/services/audio_queue_manager.dart`
- `lib/services/audio_lesson/audio_queue_manager.dart`
- `lib/providers/lesson_creation_provider.dart` (+ test)
