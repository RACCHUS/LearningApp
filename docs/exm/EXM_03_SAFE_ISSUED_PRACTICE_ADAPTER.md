# EXM-03 — Safe issued-practice client adapter (draft)

**Status:** Dormant, review-only Flutter client integration. No legacy mock/diagnostic screen uses this yet, and no learner-facing functionality is enabled. Stacked on cumulative draft PR #129; no merge, database migration, production write or deployment.

## Reviewed API contract

- `exm03_issue_assigned_practice(target_version_id, exam_part_key)` requires an authenticated permanent account with a live server Auth session; the database exclusively selects six independently reviewed part-specific single-choice questions. Only safe prompt/text options are delivered.
- `exm03_submit_assigned_practice(assignment_id, responses)` checks the same account AND original Auth session; the protected scorer computes the canonical result, not the browser. Responses map exactly six issued UUIDs to numeric option indices.
- The Dart `ExamAssignedPracticeService` checks the expected owner and the stable JWT `session_id` before and after each awaited call. It binds an issued assignment to that owner and session, and rejects logout, account switch, new-login session, guest access, mismatched targets/parts, duplicate IDs, unexpected response fields and embedded answer metadata.
- The issuer model contains no `scoring_spec`, correctness markers, internal item hashes or reviewer information. The receipt model exposes only bounded educational practice scores and explicitly rejects `official_exam_result=true`. Neither parser manufactures missing questions or trusts user-calculated scores.
- The token's locally decoded session ID is a UI privacy guard **only**. The database must continue checking the authenticated JWT and live `auth.sessions` record; no client parsing is used as authorization.

## Tests

`test/services/assessment/exam_assigned_practice_service_test.dart` verifies valid issuance/submission, exact-choice answer payloads, replay receipts, absent/guest/wrong-owner sessions, same-user session replacement, in-flight user switch, nested correctness-flag options, duplicate/extra fields and untrusted score receipts. Flutter full CI, database pgTAP, migration governance and official taxonomy checks must pass at the new exact branch head.

## Not yet done

1. Migrate all legacy protected assessment reads and any client-side mock/diagnostic grading to the issuer+submission contract. Keep unrelated learning questions and legacy content accessible where appropriate. No silent fallback to raw protected rows.
2. Complete comprehensive paginated EXM-02B/EXM-03 combined export, resumability and fingerprint review beyond the 5,000-per-store gate.
3. Add safe learner-visible practice and explicit preview/export/deletion UI, including confirmation and browser/multi-account acceptance. Do not enable until all privacy and official-content gates are satisfied.
4. Obtain separate permission for merging, controlled hosted database migration and any production rollout.
