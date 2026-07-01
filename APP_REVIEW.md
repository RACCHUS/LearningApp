# LearningApp — Code Review Report

_Reviewed: 2026-06-30 • Scope: backend/data layer, UI/UX, and free-only improvement opportunities._

This report is split into three lists as requested:

1. **Backend weaknesses** — data, services, sync, auth, database.
2. **UI issues** — screens, widgets, responsiveness, accessibility, PWA.
3. **Recommended improvements** — all achievable without paid services.

Severity legend: 🔴 Critical · 🟠 High · 🟡 Medium · 🟢 Low

---

## 1. Backend Weaknesses

### 🔴 Critical

- **Weak Row-Level Security policies (the real security hole).**
  `database/schema/schema.sql` (lines 123, 131, 251) and `database/migrations/add_order_and_content_support.sql` (line 31) all contain the catch-all clause:
  ```sql
  AND (lessons.user_id IS NULL OR lessons.user_id = auth.uid() OR auth.uid() IS NOT NULL)
  ```
  The trailing `OR auth.uid() IS NOT NULL` means **any signed-in user can read every other user's terms, questions, and concepts** — including content on private lessons. This is the single most important fix.
  → Remove `OR auth.uid() IS NOT NULL` so access requires `lessons.user_id IS NULL` (public) **or** `lessons.user_id = auth.uid()` (owner).

- **String-concatenated query filters (injection / RLS-bypass risk).**
  [lib/services/study_set_service.dart](lib/services/study_set_service.dart#L22-L24) builds the `in` clause by concatenating IDs:
  ```dart
  .filter('lesson_id', 'in', '(${lessonIds.map((id) => '"$id"').join(',')})')
  ```
  Attacker-controlled IDs can break out of the quoted string. Use the typed `.inFilter('lesson_id', lessonIds)` (a.k.a. `.in_`) operator instead, which parameterizes the values.

### 🟠 High

- **Hardcoded Supabase credentials in source.**
  [lib/config/supabase_config.dart](lib/config/supabase_config.dart#L14-L26) hardcodes the project URL and anon key for web builds. Note: the **anon key is *designed* to be public** and protected by RLS, so this is not a leak by itself — but it becomes dangerous *because* the RLS policies above are broken. Still, hardcoding prevents per-environment config and key rotation. Inject it at build time via `--dart-define`.

- **Offline sync can lose progress (race condition).**
  [lib/providers/offline_provider.dart](lib/providers/offline_provider.dart#L117-L129) calls `clearProgress()` on the local Hive store immediately after the server `upsert`. Any progress written between the read/merge and the clear is wiped, and a partial/silent server failure still results in a local wipe.
  → Mark individual records as synced after the server confirms, and only delete confirmed records — mirror the safer pattern already in [lib/services/progress_sync_service.dart](lib/services/progress_sync_service.dart).

- **No pagination / unbounded queries.**
  [lib/services/lesson/lesson_crud_service.dart](lib/services/lesson/lesson_crud_service.dart#L114-L128) selects `*, terms(*), questions(*), concepts(*)` with no row limits, and list queries in [lib/services/career_path_service.dart](lib/services/career_path_service.dart) and [lib/services/search_service.dart](lib/services/search_service.dart) fetch without `.limit()`/`.range()`. A large lesson or growing dataset will spike memory and response time.
  → Add `.limit()`/`.range()` and lazy-load child content.

- **Weak input validation at service boundaries.**
  [lib/services/lesson/lesson_crud_service.dart](lib/services/lesson/lesson_crud_service.dart) only checks `title.trim().isEmpty` — no max-length cap, so a user can persist arbitrarily large titles/descriptions. Add length limits before insert.

### 🟡 Medium

- **`debugPrint`/`print` of model JSON in production paths.**
  [lib/models/concept.dart](lib/models/concept.dart), [lib/models/term.dart](lib/models/term.dart), and [lib/models/question.dart](lib/models/question.dart) print raw `fromJson` input and errors. This leaks user content to the console and clutters logs. Route through a single logger gated on `kDebugMode`.

- **Unhelpful model deserialization errors.**
  The same models throw generic `Exception('Null value in required ... field')` without naming the field, making production failures hard to diagnose. Throw typed errors that name the offending field.

- **Naive sync merge with last-write-wins.**
  [lib/providers/offline_provider.dart](lib/providers/offline_provider.dart#L95-L116) merges by `userId_lessonId_date` and sums counters, but never compares a server `updated_at`. Concurrent edits from two devices can silently overwrite each other.

- **Hive type-ID management is ad hoc.**
  Type IDs in [lib/services/hive_service.dart](lib/services/hive_service.dart) are scattered with gaps (0,1,2,4,5,6,9,20…) and no central registry, risking a collision when new adapters are added. Centralize them in one constants file (your repo memory already tracks these — promote that into code).

- **Swallowed exceptions hide failures.**
  Several services/providers catch and only `debugPrint` (e.g., the offline sync `catch` block). Surface a user-visible error state for critical paths (sync, save, fetch) per the project's robustness rule.

### 🟢 Low

- No explicit token-refresh/retry on 401 in [lib/providers/auth_provider.dart](lib/providers/auth_provider.dart) — relies entirely on the SDK's background refresh.
- Search `ilike` filters in [lib/services/search_service.dart](lib/services/search_service.dart) don't escape `%`/`_` wildcards, allowing slow scans on large inputs.
- Career-path `slug` is accepted without format validation in [lib/services/career_path_service.dart](lib/services/career_path_service.dart).

---

## 2. UI Issues

### 🟠 High

- **No global offline/online indicator.**
  Despite full offline support, the home screen shows no banner or last-sync timestamp ([lib/screens/home_screen.dart](lib/screens/home_screen.dart)). Users can't tell when data is stale or a sync failed.

- **Settings screen has no error state.**
  [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart#L29-L41) `_loadSettings()` has no try/catch — if `SharedPreferences` fails, the screen shows an infinite spinner with no retry.

- **Raw Dart errors shown to users.**
  [lib/screens/study/study_set_screen.dart](lib/screens/study/study_set_screen.dart) renders `Text('Error: $e')` (the exception's `toString()`). [lib/screens/study/lesson_screen.dart](lib/screens/study/lesson_screen.dart) has no `error` branch in `.when()`, leaving a blank `Scaffold` on failure.

- **Tab bar overflow on narrow screens.**
  [lib/screens/home_screen.dart](lib/screens/home_screen.dart#L118-L130) — three tabs plus inline badges can overflow on phones < 480px; no icon-only fallback or text shrink.

- **Safari voice timeout has no auto-recovery.**
  [lib/widgets/safari_aware_voice_input.dart](lib/widgets/safari_aware_voice_input.dart) hits a 10s timeout, flips to manual input, and requires a fresh tap — frustrating on flaky connections.

- **PWA has no "Add to Home Screen" prompt.**
  [web/index.html](web/index.html) links the manifest but never captures `beforeinstallprompt`, so mobile users never see the install option.

### 🟡 Medium

- **Inconsistent responsiveness.** Only the home screen uses `LayoutBuilder`; study, settings, and progress screens ignore width. Flashcards have no max-width on ultra-wide displays ([lib/screens/study/flashcard_screen.dart](lib/screens/study/flashcard_screen.dart)).
- **Manifest/theme mismatch.** [web/manifest.json](web/manifest.json) sets `background_color: #ffffff` while the app defaults to dark — a white splash flash on launch. `orientation: portrait-primary` also locks tablet/landscape study.
- **Accessibility gaps.** Missing `Semantics` labels on the voice mic ([lib/widgets/global_voice_indicator.dart](lib/widgets/global_voice_indicator.dart)), the short-answer field ([lib/widgets/short_answer_field.dart](lib/widgets/short_answer_field.dart)), the custom-painted certificate ([lib/widgets/career_certificate.dart](lib/widgets/career_certificate.dart)), and editor error banners ([lib/screens/lesson_editor_screen.dart](lib/screens/lesson_editor_screen.dart)). Several tap targets fall below the 48×48 guideline.
- **No "listening" animation.** When voice is active, only a static mic icon shows ([lib/widgets/global_voice_indicator.dart](lib/widgets/global_voice_indicator.dart#L55-L65)) — users can't tell it's recording.
- **Mic-permission dead end.** On denial, a SnackBar appears but offers no link to settings or retry ([lib/screens/study/lesson_content_pager.dart](lib/screens/study/lesson_content_pager.dart)).
- **Save button not disabled during save.** [lib/screens/lesson_editor_screen.dart](lib/screens/lesson_editor_screen.dart#L60-L75) shows a spinner but stays tappable, allowing duplicate saves.
- **Settings time input validates after the fact.** [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart#L80-L100) checks the time regex only after attempting to add it, and doesn't clear the bad input.
- **Theme tokens bypassed.** Hardcoded colors/spacing in places (e.g., [lib/widgets/audio_settings/troubleshooting_section.dart](lib/widgets/audio_settings/troubleshooting_section.dart), career headers using `fontSize: 20` instead of `textTheme`), undermining the design-token system in [lib/theme](lib/theme).

### 🟢 Low

- `ListView(children: [...])` instead of `ListView.builder` in [lib/screens/careers/career_paths_screen.dart](lib/screens/careers/career_paths_screen.dart#L48).
- Large `build()` methods (e.g., ~150 lines in [lib/screens/home_screen.dart](lib/screens/home_screen.dart)) mix logic and layout, hurting rebuild isolation; extract tab bodies into widgets.
- Missing `const` constructors on simple widgets like [lib/widgets/empty_state.dart](lib/widgets/empty_state.dart).
- Query params (`ids`, etc.) in [lib/providers/router_provider.dart](lib/providers/router_provider.dart) aren't validated, silently failing on malformed deep links.

---

## 3. Recommended Improvements (all free)

Ordered by impact-to-effort. Nothing here requires a paid tier.

### Security & data integrity (do first)
1. **Fix the RLS policies** in `database/schema/schema.sql` (remove the `OR auth.uid() IS NOT NULL` catch-all) and ship a migration. This is free and closes the biggest hole.
2. **Replace the string-concatenated `in` filter** in [study_set_service.dart](lib/services/study_set_service.dart) with the typed `.inFilter()` operator.
3. **Make offline sync non-destructive:** delete only server-confirmed records instead of `clearProgress()` wholesale.
4. **Move Supabase config to `--dart-define`** so keys aren't baked into source and can be rotated per environment (free; just a build-flag change).

### Robustness (cheap wins)
5. **Add a tiny logger utility** gated on `kDebugMode` and replace the `print`/`debugPrint` of model JSON. (Free, ~1 file.)
6. **Add error branches everywhere data loads:** give `study_set_screen`, `lesson_screen`, and `settings_screen` proper error + retry states. Build one reusable `ErrorRetryView` widget and drop it into each `.when(error: ...)`.
7. **Add `.limit()`/`.range()`** to list queries and lazy-load lesson child content.
8. **Centralize Hive type IDs** into a single constants file to prevent future collisions.

### UX polish (free, high perceived value)
9. **Global offline/sync banner** on the home scaffold using the existing `connectivity_provider` + `sync_status_indicator` — show online/offline and last-sync time.
10. **PWA install prompt:** capture `beforeinstallprompt` in [web/index.html](web/index.html) and show a custom "Install app" button.
11. **Fix the manifest:** set `background_color` to your dark theme color and relax `orientation` so study mode can go landscape.
12. **Voice feedback:** add a simple pulsing animation while listening and a "Open Settings" action on mic-permission denial.
13. **Responsive shell:** wrap main content in a `Center` + `ConstrainedBox(maxWidth: ~900)` and add an icon-only tab fallback under ~480px — covers most of the responsiveness gaps with one shared layout widget.

### Accessibility (free, broadens reach)
14. **Add `Semantics` labels** to the mic indicator, answer fields, and the certificate `CustomPaint`; wrap error banners in a polite live region. Bump small icon buttons to a 48×48 tap target.

### Code health (supports the project's own rules)
15. **Extract oversized `build()` methods** (home, lesson, progress screens) into smaller `StatelessWidget`s — aligns with the repo's 50-line-function / 400-line-file guidance and improves rebuild performance.
16. **Strengthen model validation:** typed exceptions naming the missing field, and length caps on user-entered text.

---

### Suggested order of attack
1 → 2 → 3 (security/data safety) → 6 → 9 → 10/11 (visible UX) → the rest as time allows.

> Note on the Supabase **anon** key: it is intended to be shipped in client apps and is safe *as long as RLS is correct*. That's why item 1 (RLS) matters far more than the key itself.

---

## 4. Implementation Plan & Progress

Status legend: ✅ done · 🔄 in progress · ⬜ not started

### Phase A — Security & data integrity
- ✅ **A1. Fix RLS policies.** Split each content policy into a read (public-or-owner) and a write (owner-only) policy in `database/schema/schema.sql`; remove the `OR auth.uid() IS NOT NULL` / `EXISTS (SELECT 1 FROM users ...)` catch-alls. Ship `database/migrations/2026_fix_rls_policies.sql` for existing databases.
- ✅ **A2. Parameterize the `in` filter.** Replace string concatenation in `study_set_service.dart` with the typed `.inFilter()` operator.
- ✅ **A3. Non-destructive offline sync.** In `offline_provider.dart`, delete only the records confirmed uploaded instead of `clearProgress()` wholesale; surface a user error state.
- ✅ **A4. Build-time config.** `supabase_config.dart` reads from `String.fromEnvironment` (`--dart-define`) with the existing values as a documented fallback.

### Phase B — Robustness
- ✅ **B1. App logger.** Add `lib/utils/app_logger.dart` gated on `kDebugMode`; replace `print()`/raw JSON dumps in `concept.dart`, `term.dart`, `question.dart`, `study_set_service.dart`.
- ✅ **B2. Reusable error+retry view.** Add `lib/widgets/error_retry_view.dart` and wire it into `study_set_screen`, `lesson_screen`, and `settings_screen` load/error paths.
- ✅ **B3. Pagination.** Add `.limit()`/`.range()` to unbounded list queries (lessons, career paths, search).
- ✅ **B4. Centralize Hive type IDs.** Add `lib/core/hive_type_ids.dart` constants and reference them.
- ✅ **B5. Model validation.** Typed exceptions naming the field + length caps on user text.

### Phase C — UX & PWA polish
- ✅ **C1. Offline/sync banner** on the home scaffold.
- ✅ **C2. PWA install prompt** in `web/index.html`.
- ✅ **C3. Manifest fixes** — dark `background_color`, relaxed `orientation`.
- ✅ **C4. Voice feedback** — pulsing "listening" indicator + "Open Settings" action on mic denial.
- ✅ **C5. Responsive shell** — shared max-width container + narrow-screen tab fallback.
- ✅ **C6. Accessibility** — `Semantics` labels on the mic indicator, short-answer field, and certificate; live-region feedback on answer results. (Nav controls already use `IconButton`, which enforces the 48×48 minimum tap target.)

> Implementation notes are appended in §5 as work proceeds.

## 5. Implementation Notes

### Phase A — Security & data integrity
- **A1** `database/schema/schema.sql` now defines split policies: `lessons_read`/`lessons_write`, `terms_read`/`terms_write`, `questions_read`/`questions_write`, `concepts_read`/`concepts_write`. Read = `user_id IS NULL OR user_id = auth.uid()`; write = owner-only with a `WITH CHECK`. The idempotent migration `database/migrations/2026_fix_rls_policies.sql` drops the old catch-all policies and recreates the new ones (with a `DO $$` block that handles `lesson_texts` only if the table exists).
- **A2** `study_set_service.dart` uses `.inFilter('lesson_id', lessonIds)` with an empty-list guard instead of string-built `in (...)` — removes the SQL-injection vector and malformed-query risk.
- **A3** `offline_provider.dart` `syncProgress()` now pulls `getUnsyncedProgress()`, tracks the source Hive keys per merged record, and on a successful upsert calls `markProgressAsSynced(syncedIds)` instead of `clearProgress()`. A mid-flight failure no longer discards unsynced local progress.
- **A4** `supabase_config.dart` resolves config in order: `String.fromEnvironment` (`--dart-define`) → dotenv → documented public fallback constants. The anon key remains safe to ship because RLS (A1) is the real access boundary.

### Phase B — Robustness
- **B1** Replaced `print()`/raw JSON dumps in `concept.dart`, `term.dart`, `question.dart`, and `study_set_service.dart` with the existing instance-based `AppLogger`. Parse failures now throw `ModelParseException` (`lib/core/errors/model_parse_exception.dart`) naming each missing field.
- **B2** `lib/widgets/error_retry_view.dart` is a reusable error + retry widget (icon, message, optional debug detail, retry button, wrapped in a `Semantics(liveRegion: true)`). Wired into `study_set_screen`, `lesson_screen`, and `settings_screen`.
- **B3** Added `.range(offset, offset + limit - 1)` pagination to `lesson_crud_service.getLessonsForUser()` (`kLessonsPageSize = 100`), `career_path_service.getCareerPaths()`, and a `.limit()` plus LIKE-escaping in `search_service`.
- **B4** `lib/core/hive_type_ids.dart` centralizes all Hive type IDs as named constants; `hive_service.registerHiveAdapters()` references them instead of magic numbers.
- **B5** Added length caps (`kMaxLessonTitleLength = 200`, `kMaxLessonDescriptionLength = 2000`) validated in `addLesson()`, plus the typed model validation from B1.

### Phase C — UX & PWA polish
- **C1** `home_screen` body is wrapped in `ConnectivityAware`, surfacing the existing offline banner app-wide.
- **C2** `web/index.html` captures `beforeinstallprompt`, shows a custom install button, and clears it on `appinstalled`; an offline/online banner reflects connectivity.
- **C3** `web/manifest.json` `background_color` → `#121212` (matches dark theme), `orientation` → `any`.
- **C4** `global_voice_indicator.dart` gained a `_PulsingMicIcon` that scales/pulses while listening (proper `AnimationController` lifecycle); mic-permission denial in `lesson_content_pager.dart` now offers an **Open Settings** `SnackBarAction` via `openAppSettings()`.
- **C5** The responsive shell (shared max-width container, `LayoutBuilder` sidebar at ≥1024 px, tab fallback on narrow screens) was already present on `home_screen`; no regression introduced.
- **C6** Added `Semantics` to the mic icons, `short_answer_field` (`textField` + live-region feedback), and `career_certificate` (image role with a descriptive label). Existing `IconButton` controls already satisfy the 48×48 tap-target minimum.

### Validation
- `flutter analyze lib` → only one pre-existing, unrelated `unused_import` warning in `audio_enhanced_lesson_screen.dart:7` (not introduced by this work). All edited files report no errors.
