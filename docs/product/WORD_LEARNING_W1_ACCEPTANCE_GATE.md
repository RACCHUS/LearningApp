# Word Learning W1 — Final acceptance gate

**Feature branch:** `feature/word-learning-w1-foundation-20261016`  
**PR:** [#55](https://github.com/RACCHUS/LearningApp/pull/55)  
**State:** Code and automated tests are maintained in the feature PR. **Do not merge or deploy** until the applicable hands-on acceptance cases pass. No production Supabase migration or OAuth setting change is authorized by this file.

## W1 scope

W1 ships private, user-editable spelling lists; optional proper-name capitalization; nonbinding, offline dictionary suggestions; dictation with an independently typed answer; assisted retries; shared form-specific spaced review; two independent operations for deleting a list vs. forgetting a skill; and Word Learning-only guest transfer.

**Not W1:** Vocabulary-definition/sense assessment and Combined mode (W2/W3), creator publishing, public sharing, fully signed-out offline authoring, or migration of unrelated legacy learning data. Do not confuse private Word Learning backup with a complete account merge.

## Automated release gate

On the final feature commit, require **both** GitHub workflows to succeed:

- **Flutter CI:** analyzer, complete Flutter test suite, web release build, 47,147-entry local spelling asset (raw and estimated gzip budget), curriculum governance checks.
- **Database CI:** append-only migration history; upgrade from `main`; clean-slate Supabase migrations; owner/other-user/anonymous-user pgTAP isolation; list deletion preserving `word_skill` reviews; post-ingestion integrity.
- Source-level regression tests must cover stable form identity, proper-name case, US/UK alternatives, accepted variants, unassisted vs. assisted success, explicit progress forgetting, due words, large export pagination, import validation, safe word spelling changes, and cleared private UI after account transitions.

Automation passing **does not prove** real Google OAuth or browser TTS.

## Staging-only prerequisites

1. Use a **separate local or staging Supabase instance** with the W1 migrations. Never point `flutter run` at the production project for this test.
2. Enable anonymous sign-ins. For direct guest Google linking, enable **Manual Identity Linking** *only in the test project*.
3. Configure the test Google OAuth client and the exact browser redirect origin/allowlist. The local repository's `supabase/config.toml` has `enable_manual_linking = false` by default; explicit test configuration is required. Do not copy secrets to a Flutter web `.env`.
4. Prepare **two disposable Google test accounts**: A unlinked identity and B an already-existing identity. Record only the public test user IDs in your private acceptance notes.
5. Use a fresh Chrome profile for each scenario and clear any shared clipboard after transferring private data.
6. Confirm the app's injected `SUPABASE_URL` points to the **test** backend, never the source-code fallback to the hosted project.

## Manual browser acceptance cases

| ID | Action | Expected |
|---|---|---|
| G1 | Continue as Guest; create `Spelling A`; add `color` and `liability`; practice; reload | Same anonymous UID, private lists, and review records |
| G2 | Guest with data selects Google account **A** not associated with another user; complete OAuth | UID preserved through identity link; spelling history survives; app signed in |
| G3 | Cancel or fail a Google-link attempt | Guest UID/session and existing lists survive; no destructive replacement or misleading success |
| G4 | Existing Google account **B** conflict: guest exports/copies **and privately saves** backup; switch to B; import | Existing B lists/reviews intact, guest lists imported; retry imports no duplicates or overwrites |
| G5 | Interrupt import after partial success, then retry with saved backup | Existing destination data preserved and remaining records imported without duplicates |
| G6 | Guest switches account or signs out while `/words` or `/words/transfer` is open | Prior user's in-memory lists, answers and private backup text disappear |
| G7 | Reload after Google callback; restart browser | Session survives when expected; no duplicate account/profile or replacement `created_at` |
| W1 | Ordinary word entry `reluctent` | Advisory suggestion `reluctant` without silently changing user text |
| W2 | Proper name `Reaz`; change typed capitalization | Exact-case grading enforced for this lesson |
| W3 | US target `color`, type `colour`; then explicitly allow `colour` | Wrong before approval; correct afterward |
| W4 | Hear target and type answer; deliberately miss; use assisted retry | Hidden answer until requested; first miss recorded; assisted retry does not advance independent retention |
| W5 | Mark a word correct; test due-only practice before its next scheduled review | Word not yet due is excluded; new/overdue words included |
| W6 | Place identical word in two lists, practice, delete one list | Same form skill schedule across lists; retained mastery after list deletion |
| W7 | Explicitly choose Forget spelling progress for a word | Only that form's spelling review erased; words retained across lists |
| W8 | Correct a saved word to a different spelling | New identity starts new learning history; old form history preserved |
| W9 | Test 375px and desktop layouts, keyboard-only practice and screen reader labels | No cut-off controls, accessible answer feedback and no primary-nav changes |
| W10 | Simulate disabled/unavailable TTS | Clear recovery via assisted mode; no data loss |
| W11 | Export and import with sensitive names; clear clipboard; switch accounts | Source user data not visible in destination before explicit import; no plaintext backup logs |

For each case record PASS / FAIL / BLOCKED, browser/OS, date, test account initials, console/network symptoms, and steps to reproduce. Never paste a real session token, Google credential, or unredacted private export into GitHub.

## Go/no-go

- **Go to review/merge** only after current CI is green, G1–G7 and W1–W11 are either PASS or have explicit, documented out-of-scope decisions and no privacy/data-loss blocker.
- If G2 fails due to Google or Manual Identity Linking configuration, correct the **test** environment first; do not weaken account-preservation logic.
- No production rollout until an authorized deployment review of pending append-only migrations and Auth settings.
- Any later Vocabulary/Combined-mode work belongs to the approved W2/W3 roadmap, not this W1 sign-in acceptance run.
