# Word Learning W1 — implementation progress

**Status:** Draft implementation, not complete or deployed. Feature branch `feature/word-learning-w1-foundation-20261016`.  
**Baseline:** Word Learning Plan v1.3 and W0 Architecture Decision v1.1 (October 16, 2026).

## Implemented in this branch

- Append-only migration for private `word_lists` / `word_list_entries`, owner-only RLS and a `word_skill` extension to the existing `review_items` scheduler.
- Deterministic spelling scoring, explicit accepted forms, case-sensitive proper-name support, and stable form/skill keys independent of lists.
- Owner-scoped list creation, bulk word entry, removal and deletion. List deletion does not cascade into review state.
- `/words` secondary screen: entry from Library, paste words, preview advisory corrections, manually change pronunciation/accepted forms, audio dictation and typed-answer scoring. Learners can practice the entire list or only unattempted/due words using the existing review schedule.
- A separate account-linking method for upgrading Supabase anonymous users to Google while retaining the same identity when the provider/configuration permits it. Ordinary Google sign-in is guarded against replacing an existing guest session; canceled launches restore a usable auth state.
- Profile provisioning no longer signs out a valid anonymous session after transient database failures, and LoginScreen offers an explicit retry.
- A lazy-loaded, 47,147-base-form US lexicon sourced from a SCOWL-derived Hunspell dictionary (415,662 bytes of source asset text, before web compression), with original source/license notices retained in `assets/lexicons/NOTICE.txt`.
- Advisory spelling suggestions with explicit per-word choices and the option to keep custom spellings; proper names bypass automatic dictionary checks. Editable TTS pronunciation text and accepted spelling variants.
- Dart unit tests and pgTAP schema/RLS smoke tests. Re-run CI after latest commits; do not infer all tests pass from earlier workflow runs.

## Guest-to-existing-Google transfer slice

- New `/words/transfer` screen provides an **explicit** private JSON backup (not credentials) and import UI for a Google account already in use.
- A guest can export a copy of their lists and spelling-review history before signing out. The switch-to-existing-account action requires a separate confirmation and an explicit copied backup.
- The new account imports its own data through existing RLS. A separate additive `import_origin` key prevents duplicate list creation on retries; `(list_id,form_key)` and `(user_id,content_id)` deduplicate words and reviews.
- Destination entries and review records win collisions. Import never overwrites the destination's existing mastery or the source guest account.
- Word backup parser enforces version, size, list/entry/review limits, stable identities, and review-counter sanity checks before issuing writes. It does not export refresh tokens or session IDs.
- Sensitive backup text can include names. Clipboard use is opt-in, with a clear-clipboard control. Users must keep their own private saved copy.
- **Scope:** This transfers Word Learning data only. General learning contexts, other legacy study sets, and other learner-owned tables are not migrated by this workflow. A complete cross-app account migration remains a separate project.
- This is a first usable transfer path, not an automatic OAuth account merge. It still needs browser integration and idempotency tests with two Supabase test identities.

## Required before calling W1 complete

1. **Do not apply migration to production without owner approval.** Run clean database upgrade + RLS owner/other-user/anonymous tests in disposable local or CI database.
2. Verify Dart analyzer, Flutter tests, release web build, and interactive browser flow in CI/staging; code has not been tested in a running browser in this branch.
3. **Dictionary work partially completed.** Measure the actual web-build compressed asset footprint, verify license packaging for this exact derived dataset, and test false-positive rates with ordinary inflections, names, school terms and contractor/insurance vocabulary. This is only a base-form list; no lack-of-entry verdict may block saving.
4. **Manual transfer is now implemented for Word Learning only:** validate across two test identities, real OAuth redirect, clipboard behavior, retry conflicts, and privacy. Fully signed-out local-guest persistence and safe transfer of non-Word-Learning progress remain incomplete. Do not claim seamless or whole-app guest migration.
5. Verify actual Supabase OAuth provider/redirect configuration and Manual Identity Linking status with authorized test identities before enabling any full rollout. No production Auth setting changes without approval.
6. Pronunciation override and accepted-form editing exist; verify TTS pronunciation in browsers and native builds, proper-name behavior, assisted-input browser behavior, signed-out/shared-device privacy, and review semantics before calling them production ready.
7. Run regression tests for existing lessons and Quick Review. The generic review queries now exclude word-skill items (so they cannot be incorrectly self-rated as flashcards); add properly scoped word-review entry points before the final W1 release. The dedicated /words screen is the only graded dictation experience in this slice.
8. Resolve detected implementation and CI problems before merge; preserve the locked Learn / Library / Progress architecture.

## Notes

This branch is an **implementation slice**, not a finished W1. Do not treat the migration being committed as evidence it has been applied or that any hosted data changed. User data and credentials must not be written to logs or committed.
