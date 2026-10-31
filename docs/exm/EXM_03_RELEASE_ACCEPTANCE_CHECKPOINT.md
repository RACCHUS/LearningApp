# EXM-03 — Consolidation, large portability, and release acceptance (draft)

**Status:** Draft implementation only. No production SQL, hosted learner-data access, release, merge, or editorial publication. This document records verification boundaries, not a production signoff.

## Integration lineage

Cumulative development PR #135 starts with the existing EXM-02B/EXM-03 account-history UI from #134, then transfers the exact safe assigned-question adapter and tests from #133. Earlier focused and cumulative PRs overlap; **do not merge multiple ancestor stacks into main independently**. Run full CI on the exact latest main-targeting cumulative commit after every change.

## Large combined history (new 50,000-per-store hard bound)

- Forward migration `20261101170000_exm_03_verified_large_combined_export.sql` increases the owner-only inventory limit from 5,000 to **50,000 EXM-02B R1–R4 events and 50,000 EXM-03 assignments**; older single-statement combined export still applies only to <=5,000 per store. The verified client automatically chooses paged collection for larger histories.
- Forward migration `20261101180000_exm_03_release_hardening_and_date_eligibility.sql` (Migration 81) completes the EXM-03 consolidation:
  1. Carries actual exam administration date through assignment issuance, scoring, and portability exports.
  2. Permanently protects retired approved items under restrictive RLS `exm03_has_protected_binding` (`published` or `retired`).
  3. Restricts unconfirmed `exm03_erase_part_attempts` execution to `service_role`.
  4. Enforces technical separation between practice pool items and held-out transfer / nonproduction selection probes via `usage_role = 'practice_pool'`.
- New `exm03_account_part_export_page` returns at most 250 private assignment summaries in a descending `(issued_at,id)` keyset, checks a permanent account and a live matching Supabase Auth session, and never returns responses, scoring specs, assigned item hashes/lists, issue-session IDs or review tokens.
- Existing owner-RLS `exam_reference_drill_export_page` supplies the R1–R4 side. The client validates every page's owner, row count, descending cursor, uniqueness and expected total; snapshots spanning multiple HTTP requests **are not atomic**. It compares preflight and postflight counts and the private server fingerprint (including newly graded evidence), discards all assembled data on any change, and never labels an incomplete collection complete.
- Large client archives are assembled in memory, verified again against the exact parser schema, and downloaded only after an explicit gesture. JSON generation is chunked; the browser still rejects files beyond **64 MiB**, rather than offering a truncated download.
- The existing fingerprint-confirmed account erasure contract is atomic and account-scoped, with the new 50k inventory bound. Its explicit phrase, second confirmation, owner advisory lock and post-delete zero checks remain intact. No automatic cleanup or scheduled purge.
- The UI can display progress and cancel further client RPCs. Cancellation cannot undo an already-running database read; no archive is presented after cancellation.

**Not unlimited:** More than 50,000 entries in either store, unsupported browsers, files above 64 MiB, a changing server inventory, or a failed page remain **unavailable**, not silently shortened. Do not claim a full LearningApp account export: only educational EXM-02B/03 records are covered.

## Protected part diagnostics and mock practice

Both the exact-part diagnostic surface (`DiagnosticAssessmentScreen`) and the exact-part practice surface (`MockExamScreen`) now route directly to `SecureExamPartPracticeScreen`, which uses only the safe `exm03_issue_assigned_practice` and `exm03_submit_assigned_practice` APIs. Neither screen loads answer-bearing `assessment_items.select('*')` or grades locally when an exam part is specified. Guest accounts fail closed with a clear sign-in requirement. Owner-keyed state and after-await guards discard stale questions/scores when an account changes. Whole-target legacy study practice retains its separate existing behavior without exposing protected items (which are excluded by database RLS policy `exm03_no_direct_read_of_approved_answers`). Ordinary and diagnostic scores are never labeled as official exam results.

## Exact-head automated checks required

1. Flutter static analyzer, full unit and widget tests including protected issuer client/screen and account switching.
2. Existing EXM 50,000-step reference export probe, new >5,000 combined pages/cancellation/change-detection tests, and the 64 MiB chunked browser payload guard.
3. Incremental append-only Supabase upgrade from current main; clean-slate migrations; pgTAP authentication, RLS, canonical scorer, keyset pagination, fingerprint/erasure, and answer-key isolation.
4. Full taxonomy ingestion/source integrity and web release build.

Record **latest** CI run and exact SHA before any next approval; older green runs do not establish the new branch is green.

## Release acceptance tasks not claimable from CI

- Real Chromium/Firefox/Safari browser user-gesture downloads of a bounded archive; inspect saved JSON, 64 MiB refusal, cancellation and error states; verify no partial file.
- Manual account A -> B -> A, logout, guest, same-owner new Auth session, slow-network/in-flight response, 90-minute expiry, retry/replay and revoked-session cases across real devices.
- Confirm parity of direct navigation, timer/revisit/refresh, protected part diagnostic, ordinary learning/whole-target diagnostic and mock presentation; do not publish any official simulation-fidelity label for sparse/unmapped banks.
- Independent security/privacy review of RLS, JWT, SECURITY DEFINER, retention policy, erasure/backup semantics, privacy wording and full account-data boundary.
- Actual published source manifest/official part and reference edition verification; qualified independent item authors/reviewers; licensed rights and real pilot item approvals before enabling.
- **Separately authorized** migration/merge/release and a staged post-deploy smoke test. No automated fixture substitutes for real content approvals.

## Stop/go verdict

**NO-GO for learner rollout** until independent content approvals, on-device acceptance, retention decisions and explicit owner authorization are completed (mock transport routing migration completed in commit `7736185`). A green branch remains eligible for engineering review only.
