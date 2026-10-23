# EXM-03 — Combined practice portability (draft)

**Status:** Code committed for CI/local validation. No merge, hosted migration, learner-facing export/erasure UI or production data change.

## Coverage and privacy

The additive migration 20261031160000_exm_03_account_practice_portability.sql combines all owned EXM-02B R1–R4 saved reference-practice events and grading receipts with all owned EXM-03 issued assignments (including unanswered and expired assignments) and scored attempt summaries. It never returns hidden assessment scoring specifications, submitted answers, response fingerprints, assignment question lists/content hashes, session IDs, private reviewer evidence or private scoring tokens.

The owner must have a permanent account and a currently existing Auth session. The export uses one stable SQL statement snapshot; its inventory independently counts both stores and fingerprints event/grade and assignment/attempt status. The Dart facade validates owner and exact response schema before returning JSON; an account switch invalidates an in-flight result.

This is educational evidence, not an official exam result and **not an export of unrelated LearningApp account data**.

## Boundaries

The combined export and single-shot erasure deliberately fail closed when either reference practice exceeds 5,000 events or EXM-03 history exceeds 5,000 issued assignments. Oversized results must never be labeled complete. The older separate verified 50,000-step EXM-02B exporter is still available, but does not cover EXM-03; future work must provide multi-request two-store pagination and pre/post fingerprints before promising portable coverage of larger accounts.

## Deletion contract

The deletion function requires a fresh server preview, its four inventory counts, its exact fingerprint, and the literal confirmation phrase **DELETE ALL EXAM PRACTICE**. A per-owner advisory lock coordinates reference-event writes and assignment issuance. The transaction checks the preview fingerprint before deleting, verifies exact deletion row counts, then verifies zero remaining R1–R4 events and grades and EXM-03 assignments and attempts. Any mismatch rolls back. Assignments are deleted with attempts, so replay cannot recreate erased scores. New practice after successful deletion is still possible.

No automatic purge, retention policy, background task or destructive UI was added.

## Verification

- SQL: supabase/tests/exam_part_account_portability_test.sql
- Dart: test/services/assessment/exam_combined_practice_portability_service_test.dart
- Existing safe-presentation and canonical-grading integration tests must continue passing.

## Remaining release gates

1. Verify CI including clean-slate SQL migrations, pgTAP and Flutter tests; manual multi-account/browser checks.
2. Add paginated combined export and browser download safeguards for accounts beyond current bounds, with cancellation and postflight integrity checks.
3. Implement explicit owner-visible download and deletion preview/confirmation UI; test account-switch, logout, interrupted export and concurrent score/erasure cases.
4. Migrate legacy exam diagnostic/mock screens and providers away from direct protected assessment-item reads and client-side scoring; never weaken answer-key RLS.
5. Obtain separate approval for merge, guarded production deployment and learner rollout.

This remains an engineering draft, not a released learner capability.
