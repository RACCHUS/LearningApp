# Word Learning W1 — implementation progress

**Status:** Draft implementation, not complete or deployed. Feature branch `feature/word-learning-w1-foundation-20261016`.  
**Baseline:** Word Learning Plan v1.3 and W0 Architecture Decision v1.1 (October 16, 2026).

## Implemented in this branch

- Append-only migration for private `word_lists` / `word_list_entries`, owner-only RLS and a `word_skill` extension to the existing `review_items` scheduler.
- Deterministic spelling scoring, explicit accepted forms, case-sensitive proper-name support, and stable form/skill keys independent of lists.
- Owner-scoped list creation, bulk word entry, removal and deletion. List deletion does not cascade into review state.
- Basic `/words` screen: entry from Library, paste words, dictation with the shared audio service, typed-answer checking and a review record.
- A separate account-linking method for upgrading Supabase anonymous users to Google while retaining the same identity when the provider/configuration permits it.
- Profile provisioning no longer signs out a valid anonymous session after transient database failures.
- Dart unit tests and pgTAP schema/RLS smoke tests (CI pending).

## Required before calling W1 complete

1. **Do not apply migration to production without owner approval.** Run clean database upgrade + RLS owner/other-user/anonymous tests in disposable local or CI database.
2. Verify Dart analyzer, Flutter tests, release web build, and interactive browser flow in CI/staging; code has not been tested in a running browser in this branch.
3. Add the licensed US-English spelling lexicon, advisory typo suggestions, override UI, exact compressed asset/bundle-size measurement, and proper attribution; do not ship with unverified dictionary claims.
4. Add fully signed-out local-guest persistence, migration to a Google account, and an opt-in, idempotent import path for an **existing** Google identity. Preserve source records and resolve list collisions without loss of progress.
5. Verify actual Supabase OAuth provider/redirect configuration and Manual Identity Linking status with authorized test identities before enabling any full rollout. No production Auth setting changes without approval.
6. Finish proper-name pronunciation correction, accepted variant editing, assisted-input browser behavior, signed-out and shared-device privacy, and end-to-end review semantics.
7. Run regression tests for existing lessons and Quick Review. The generic review queries now exclude word-skill items (so they cannot be incorrectly self-rated as flashcards); add properly scoped word-review entry points before the final W1 release. The dedicated /words screen is the only graded dictation experience in this slice.
8. Resolve detected implementation and CI problems before merge; preserve the locked Learn / Library / Progress architecture.

## Notes

This branch is an **implementation slice**, not a finished W1. Do not treat the migration being committed as evidence it has been applied or that any hosted data changed. User data and credentials must not be written to logs or committed.
