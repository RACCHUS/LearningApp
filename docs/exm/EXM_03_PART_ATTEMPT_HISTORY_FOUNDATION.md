# EXM-03 — Private exam-part attempt history foundation

This milestone establishes a *dormant* storage and privacy interface, not a
live product history feature. Automated database tests use ephemeral CI
Supabase. It never writes a historical attempt in the hosted project.

## Persistence guarantees

- `exam_part_practice_attempts` is keyed by immutable UUID, owner, exact
  target/version/part/root, practice kind, completed time and a fingerprint
  representing a question edition. Only bounded educational score summaries
  are stored, without question text, answer keys, or official passing results.
- The table has row-level owner SELECT and DELETE, and denies direct
  authenticated INSERT and UPDATE. No client can make their locally computed
  score into a verified permanent attempt; a reviewed canonical server
  transaction is a **prerequisite**.
- The store deliberately has no default TTL and no implicit retention promise.
  Deleting an owning auth account cascades history deletion.
- The typed model rejects owner/version/part mismatch and invalid counts or
  score bounds.
- The history service requires the signed-in, nonanonymous account to match
  `expectedOwnerId` before *and after* reads/exports or exact-part deletes.
  It uses bounded `limit <= 500`; exported JSON discloses when that page may
  be incomplete and never advertises completeness.
- Erasure is intentionally service-only, because UI confirmation and verified
  inventory audits are not present. It can only affect the exact authenticated
  owner and selected target-version/part.
- The existing EXM-02B reference-practice account export and erasure are NOT
  extended to these new rows. Neither those controls nor the Progress screen
  should claim this feature is covered by an R1–R4 archive.

## Mandatory next gates before users can create attempts

1. A single transactional, server-side canonical grader that validates
   authenticated owner, published exact target/version/part and root,
   question edition fingerprint and scoring rules; idempotency and replay
   protection must be enforced at the database boundary.
2. Complete, paginated, snapshot-consistent *account-wide* export and owner
   erasure that include this new table; verified counts and partial-failure
   semantics. Appropriate retention and portability documentation.
3. Race tests for login/logout, stale completion callbacks, failed writes,
   account switch, pagination gaps, interrupted deletions and cancellation.
4. Only then, connect the Progress card to real saved attempts; do not turn
   knowledge coverage into a pretend practice-attempt history.
5. Confirm exact exam publisher/version/administration-date rule provenance
   before promising official simulation parity, scoring or pass/fail outcomes.

No rollout/merge/deploy in this milestone.
