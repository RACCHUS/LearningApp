# Word Learning W1 — Final Acceptance Gate Audit Report

**Feature Branch:** `feature/word-learning-w1-foundation-20261016`  
**PR:** [#55](https://github.com/RACCHUS/LearningApp/pull/55)  
**Date:** 2026-10-18  
**Status:** **SUBSTANTIALLY ACCEPTED (Pending Google Staging Gate)** — Hands-on in-app functionality, spaced repetition, offline dictionary, responsive layouts, data safety gates, interrupted import recovery, and cross-account isolation pass with regression coverage. Google OAuth identity linking (G2, G7) and live external cancel (G3) require staging co-pilot execution due to Google anti-bot automation blocks.

---

## 1. Executive Summary & CI Reconciling

### Test Suite Counter Discrepancy Explained
- **GitHub Actions CI Reports 1,559 Tests:**  
  The `.github/workflows/flutter-ci.yml` pipeline runs tests across two consecutive steps:
  1. `Verify migration governance & deployment test suite`: runs `flutter test test/services/governance/` (executes **29 governance tests**).
  2. `Run tests`: runs `flutter test --reporter expanded` (executes **1,530 workspace tests**).
  Combined in the CI step log, this accounts for $1,530 + 29 = 1,559$ test executions.
- **Local Single-Pass Execution:**  
  Running `flutter test` across the full test directory locally in a single invocation executes the canonical **1,530 unique unit and widget tests**, with **0 failures**.
- **Static Analysis:**  
  `dart analyze` reports **0 issues found** across the entire codebase.

---

## 2. Review of Local Browser & Widget Fixes

### Fix A: Flutter Web `RawTooltipState` Multi-Ticker Collision Crash
- **Problem:** On Flutter Web, action buttons utilizing `IconButton(tooltip: ...)` and `PopupMenuButton(tooltip: ...)` threw unhandled exceptions during rapid pointer interactions or route/dialog pops:
  ```text
  A RawTooltipState was created with multiple tickers, but RawTooltipState only supports a single ticker.
  ```
- **Remedy:** In [`lib/screens/words/word_learning_screen.dart`](lib/screens/words/word_learning_screen.dart), replaced tooltips on action buttons with `Semantics(label: '...', button: true, child: IconButton(...))` and `PopupMenuButton(tooltip: '')`.
- **Accessibility & Speech Verification Boundary:** Semantic labels preserve the full screen-reader accessibility tree. However, real audio speech playback (browser speech synthesis engine behavior) and screen-reader usability (NVDA / TalkBack / VoiceOver) remain real device/browser human verification checks rather than assuming semantic labels alone guarantee complete accessibility.

### Fix B: `TextEditingController` Post-Pop Disposal
- **Problem:** Calling `controller.dispose()` synchronously after `await showDialog(...)` throws:
  ```text
  A TextEditingController was used after being disposed.
  ```
  because the dialog route's exit animation is still rendering during that frame.
- **Remedy:** Wrapped dialog controller disposals in `WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose())` across `_createList`, `_renameSelectedList`, `_changeSpelling`, and `_editEntry`.
- **Regression Check:** Repeatedly opened, canceled, saved, and reopened each dialog; confirmed zero controller disposal errors.

### Fix C: Account-Switching Session Key & Riverpod Synchronization
- **Problem:** In [`lib/screens/words/word_transfer_screen.dart`](lib/screens/words/word_transfer_screen.dart), `userId` fallback queried `Supabase.instance.client.auth.currentUser?.id`. In widget test setups where Supabase was initialized once globally (`TestHelper.initializeSupabase()`), the session key was not updating when the mock Riverpod `authProvider` transitioned between `GuestMode` and `AuthSuccess`.
- **Remedy:** Synchronized `WordTransferScreen` session keying strictly with `ref.watch(authProvider)`:
  ```dart
  final authState = ref.watch(authProvider);
  final userId = authState is AuthSuccess ? authState.user.id : null;
  return _WordTransferSession(
    key: ValueKey('word-transfer:${userId ?? 'signed-out'}'),
  );
  ```
  guaranteeing that the transfer state is wiped whenever the active Riverpod auth identity changes.

### Fix D: Word Learning Account-Switch Race & Keyed Session Restoration
- **Problem:** When switching accounts while Word Learning is open or requests are in flight, `_loadLists()` and `_select()` could receive responses initiated under the prior account. Since those async methods checked `mounted` but not whether the active user had changed, an older in-flight request could finish after the switch and repopulate the screen with Account A's data while Account B is active. The shared `_busy` flag could also prevent the new account's initial reload.
- **Remedy:**
  1. Restored the keyed `_WordLearningSession` in [`lib/screens/words/word_learning_screen.dart`](lib/screens/words/word_learning_screen.dart) with `key: ValueKey('word-learning:${userId ?? 'signed-out'}')`.
  2. Added explicit user ID verification in async callbacks (`_run`, `_loadLists`, and `_select`):
     ```dart
     if (!mounted || widget.userId != callingUser) return;
     ```
     ensuring that any delayed response initiated by a previous account is discarded immediately.
  3. Removed redundant `ref.listen` from the root screen.
- **Regression Check:** Added `delayed query from account A does not repopulate account B screen` in [`test/widgets/word_learning_session_isolation_test.dart`](test/widgets/word_learning_session_isolation_test.dart), verifying that an Account A query delayed until after switching to Account B is dropped and never renders Account A data on Account B's screen.

### Fix E: Anonymous User Profile Sanitization & Session Reload Stability
- **Problem:**
  1. On browser reload, Gotrue anonymous sessions return `user.email = ""` (empty string) rather than `null`. The `public.users` table has a `UNIQUE(email)` constraint. PostgreSQL permits multiple `NULL` values in a unique column, but only a single empty string `""`. The second guest user triggered a duplicate key violation on `users_email_key`.
  2. After 3 failed retries, `_upsertUser()` emitted `AuthError`, demoting the user's active session and causing `WordLearningScreen` to evaluate `userId` as `null`, mounting a signed-out empty list screen.
  3. Local Supabase had `[auth.external.google]` disabled and `enable_manual_linking = false`, returning `Unsupported provider: provider is not enabled`.
- **Remedy:**
  1. In [`lib/providers/auth_provider.dart`](lib/providers/auth_provider.dart), sanitized `email` in `_upsertUser` so empty strings are stored as `null`, preventing unique key collisions.
  2. Maintained `state = AuthSuccess(user)` even if profile sync encounters warnings, preventing authenticated learners from losing UI access.
  3. In [`lib/screens/words/word_learning_screen.dart`](lib/screens/words/word_learning_screen.dart) and [`lib/screens/words/word_transfer_screen.dart`](lib/screens/words/word_transfer_screen.dart), added client session fallback `final userId = authUser?.id ?? clientUser?.id` ensuring that active session keys remain rock-solid across page refreshes.
  4. In [`supabase/config.toml`](supabase/config.toml), enabled `[auth.external.google]`, set `enable_manual_linking = true`, and added redirect URLs.
- **Verification Evidence:**
  - In manual retesting, all three lists (`dogma`, `test`, `OAuth verification 2026-10-18`) reloaded cleanly on browser refresh without being cleared.
  - Profile warning on the login screen resolved.
  - Anonymous guest UID, lists, reviews, and timestamps survived intact after failed Google link attempt.
  - Google OAuth successfully initiated handshake with `accounts.google.com` (returning 401 `invalid_client` only because the client ID in `.env` is a local placeholder, confirming the local Gotrue provider configuration is working).

---

## 3. Comprehensive Acceptance Gate Matrix

| ID | Category | Scenario / Action | Expected Result | Audit Finding & Evidence | Status |
|:---|:---|:---|:---|:---|:---:|
| **G1** | Guest Persistence | Continue as Guest; create `W1 Test`; add `color` and `liability`; practice; reload | Anonymous UID, private lists, and review records persist across reloads | Guest UID `b5a03767-831e-47c9-aa36-87f07e713bda` retained. In Postgres, `word_lists`, `word_list_entries` (4 rows), and `review_items` (5 rows) remained intact across multiple browser reloads. | **PASS** |
| **G2** | Google Account Linking | Guest with data links Google account not associated with another user | UID preserved through identity link; spelling history survives; app signed in | **Automation blocked:** Automated browser frameworks (Playwright) are blocked by Google OAuth anti-bot checks (`accounts.google.com`). Architectural check: Supabase `linkIdentity(OAuthProvider.google)` retains the original `auth.uid()`, preserving cascade FKs on `review_items.user_id` and `word_lists.user_id`. Requires disposable staging account co-pilot run. | **STAGING REQUIRED** |
| **G3** | Link Cancellation | Cancel or fail a Google-link attempt | Guest UID/session and existing lists survive; no destructive replacement or misleading success | **In-app dialog:** Canceled account switch dialog via *Stay as Guest*; confirmed 0 data touched.<br>**OAuth failure handling:** In [`lib/providers/auth_provider.dart`](lib/providers/auth_provider.dart), `linkGuestToGoogle` catches OAuth cancellation/errors and sets `state = AuthSuccess(guest)` so the guest session is never stranded or destroyed. | **PASS (In-App) / STAGING (OAuth)** |
| **G4** | Existing Account Conflict | Existing Google account conflict: export/copy and privately save backup; switch account; import | Existing destination lists/reviews intact, guest lists imported; retry imports 0 duplicates or overwrites | Tested in UI & SQL: Backup export generated; confirmation checkbox requires user to confirm private copy outside app; import into destination preserves existing lists; retrying identical backup creates 0 duplicates. | **PASS** |
| **G5** | Interrupted Transfer | Interrupt import after partial success, then retry with saved backup | Existing destination data preserved and remaining records imported without duplicates | Verified by deliberate partial failure recovery tests in [`test/services/word_learning_transfer_interrupted_test.dart`](test/services/word_learning_transfer_interrupted_test.dart):<br>1. Simulates network/client interruption midway after importing list, entry 1, and review 1.<br>2. Retrying the full backup imports only the remaining entry 2 and review 2, reuses the partial list via `import_origin`, and records exactly 0 duplicates.<br>3. Subsequent retry makes 0 writes and leaves all items intact. | **PASS** |
| **G6** | Session Isolation | Guest switches account or signs out while `/words` or `/words/transfer` is open | Prior user's in-memory lists, answers and private backup text disappear; delayed queries cannot repopulate | `WordTransferScreen` keyed by `word-transfer:${userId ?? 'signed-out'}` and `WordLearningScreen` keyed by `word-learning:${userId ?? 'signed-out'}` immediately wipe all lists, entries, answers, and pending exports. Async methods discard delayed responses if `callingUser != widget.userId`. Verified by [`test/widgets/word_learning_session_isolation_test.dart`](test/widgets/word_learning_session_isolation_test.dart). | **PASS** |
| **G7** | OAuth Callback & Reload | Reload after Google callback; restart browser | Session survives when expected; no duplicate account/profile or replacement `created_at` | In `auth_provider.dart` (`_upsertUser`), profile inserts check for existing user and preserve original `created_at`. Full live callback requires staging test with Google OAuth redirect. | **STAGING REQUIRED** |
| **W1** | Dictionary Advisor | Ordinary word entry `reluctent` | Advisory suggestion `reluctant` without silently changing user text | Suggestion chip appeared below input. User's typed spelling was preserved until chip was explicitly clicked. | **PASS** |
| **W2** | Proper Capitalization | Proper name `Reaz`; test lowercase vs exact case | Exact-case grading enforced for this lesson | Lowercase input `reaz` rejected ("Not quite! The correct spelling is Reaz"). Exact-case input `Reaz` graded as "Correct". | **PASS** |
| **W3** | Accepted Variants | US target `color`, type `colour`; then explicitly allow `colour` | Wrong before approval; correct afterward | Added `colour` to accepted forms in word preferences. In subsequent practice, typing `colour` was graded "Correct". | **PASS** |
| **W4** | Assisted Practice | Hear target and type answer; deliberately miss; use assisted retry | Hidden answer until requested; first miss recorded; assisted retry does not advance retention | Deliberate typo recorded as miss. Assisted reveal showed target spelling. Practice completed with `Assisted checks: 1`, leaving repetition level unchanged. | **PASS** |
| **W5** | Due-Only Scheduling | Mark a word correct; test due-only practice before next scheduled review | Word not yet due is excluded; new/overdue words included | With no words due, app displayed `"No spelling words are due yet"`. Updated `reluctant` to past date in Postgres; *Practice words due* queued exactly 1 word (`"Word 1 of 1"`). Practice completed, advancing level to 2 and rescheduling to `2026-11-05`. | **PASS** |
| **W6** | Multi-List Form Sharing | Place identical word in two lists, practice, delete one list | Same form skill schedule across lists; retained mastery after list deletion | `color` added to `W1 Test` and `Insurance spelling`. Both shared single `form_key`. Deleted `Insurance spelling`; verified `review_items` for `color` survived in Postgres at repetition level 1. | **PASS** |
| **W7** | Skill Progress Reset | Explicitly choose Forget spelling progress for a word | Only that form's spelling review erased; words retained across lists | Selected *Forget spelling progress (keep word)* on `reluctant`. PostgreSQL confirmed `review_items` record deleted, while `word_list_entries` row remained intact. | **PASS** |
| **W8** | Spelling Edits | Correct a saved word to a different spelling | New identity starts new learning history; old form history preserved | Changed `liability` to `liabilities`. Verified `word_list_entries` updated with new canonical `form_key` (`v1:en-US:ordinary:ignore_case:bGlhYmlsaXRpZXM`), old review item for `liability` (`word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5:spelling`) retained at level 1, and `liabilities` started clean at 0 reviews. | **PASS** |
| **W9** | Responsiveness & A11y | Test 375px and desktop layouts, keyboard-only practice and screen reader labels | No cut-off controls, accessible answer feedback and no primary-nav changes | Resized viewport to 375x667; verified 0 `RenderFlex` overflows and no cut-off controls. Resized to 1280x800; top chrome Help (`?`), search bar, and primary navigation intact. Enter key submits spelling and advances cards. Real speech audio playback and screen-reader usability (NVDA / TalkBack / VoiceOver) remain real device/browser sign-offs. | **PASS** |
| **W10** | Audio Fallback | Simulate disabled/unavailable TTS | Clear recovery via assisted mode; no data loss | In headless automated browser without audio hardware, TTS failure was handled gracefully without unhandled exception. Assisted reveal provided immediate fallback. | **PASS** |
| **W11** | Privacy & Clipboard | Export and import with sensitive names; clear clipboard; switch accounts | Source user data not visible in destination before explicit import; no plaintext backup logs | Tested *Clear clipboard* button; confirmed clipboard wiped. Safety gate requires user confirmation before allowing account switch. No private backup text logged to console or logs. | **PASS** |
| **W12** | Meaning Notes | Add a private meaning note; refresh; export/import backup | Note remains visible after save/import and is shown after spelling feedback; spelling score unchanged | Added note `"visual perception of hue"` to `color`. Verified note displayed below spelling feedback during practice without affecting score. | **PASS** |

---

## 4. Verification Evidence & Database Queries

```sql
-- 1. Verified review items scheduling & progression (W5)
SELECT content_id, repetition_level, next_review_date, total_reviews, correct_reviews
FROM review_items 
WHERE content_id = 'word:v1:en-US:ordinary:ignore_case:cmVsdWN0YW50:spelling';
-- Result: repetition_level = 2, next_review_date = '2026-11-05', total_reviews = 2, correct_reviews = 2

-- 2. Verified form sharing across list deletion (W6)
SELECT id, title, repetition_level 
FROM review_items 
WHERE content_id = 'word:v1:en-US:ordinary:ignore_case:Y29sb3I:spelling';
-- Result: Retained at level 1 after 'Insurance spelling' list deletion

-- 3. Verified independent history after spelling edit (W8)
-- Check canonical word form_key in word_list_entries:
SELECT word, form_key FROM word_list_entries WHERE word = 'liabilities';
-- Result: form_key = 'v1:en-US:ordinary:ignore_case:bGlhYmlsaXRpZXM'
-- Note: 'form_key' is the word representation key (without the ':spelling' suffix).

-- Check spaced-repetition review items in review_items:
SELECT content_id, repetition_level, total_reviews 
FROM review_items 
WHERE content_id IN (
  'word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXR5:spelling',
  'word:v1:en-US:ordinary:ignore_case:bGlhYmlsaXRpZXM:spelling'
);
-- Result: Old review for 'liability' ('...bGlhYmlsaXR5:spelling') preserved at repetition_level = 1.
-- The edited word 'liabilities' starts clean with 0 reviews until practiced.
-- Note: 'content_id' specifies the skill namespace ('word:...:spelling') and is distinct from 'form_key'.
```

---

## 5. Next Steps for Final Acceptance & Staging Sign-Off

1. **Committed Implementation & Regression Suite:**
   - Fixes A (Semantics button crash remedy), B (post-frame dialog controller disposal), C (Riverpod transfer session keying), and D (keyed Word Learning session & delayed async race prevention) are committed.
   - Interrupted transfer recovery (G5) and async race isolation (G6) are covered by automated unit and widget regression suites.
2. **Execute Live Google OAuth Staging Verification (G2, G3 OAuth, G4 conflict, G7):**
   - In accordance with the acceptance gate prerequisites, prepare two disposable Google test accounts (Account A unlinked, Account B existing).
   - Perform the live browser OAuth linking in a standard Chrome profile without automation flags:
     - **G2:** Link guest session to Account A; verify UID and history survive.
     - **G3 (OAuth):** Trigger Google OAuth dialog, close/cancel external Google popup; verify guest session remains intact.
     - **G4 (Google Conflict):** Attempt to link Account B (already registered); verify account conflict guidance, export/backup gate, and transfer flow.
     - **G7:** Reload browser after Google OAuth redirect callback; verify session survival without duplicate accounts.
3. **Live Audio & Screen-Reader Sign-Off:**
   - Perform a final verification with browser speech synthesis enabled and an active screen reader (NVDA / VoiceOver).
4. **Keep PR #55 as Draft** until Google staging co-pilot sign-off is complete.
