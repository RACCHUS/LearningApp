# EXM-03 — Durable part-specific reference-drill attempt history

**Status:** Draft implementation; local synthetic SQL/Flutter CI acceptance
required on the cumulative latest-main integration. No hosted SQL applied.

## Scope of what actually exists

EXM-02B already persists immutable owner-only R1–R4 events with a stable
`client_attempt_id`, selected `exam_part_key`, exact target-owned reference
manifest edition, item/content revisions and graded receipt where available.
This milestone adds an **RLS-invoker, permanent-owner, bounded read projection**
over those existing records, not another write store or a guessed score.

`exam_reference_drill_part_attempt_history(target_version_id, part_key,
limit, optional-keyset-cursor)` groups only the signed-in owner's existing
events for the exact version/part into up to **50 attempts per database page**,
most recent first. The learner UI starts with **20 attempts**, offers explicit
older-page loading, and stops at 500 displayed attempts with a clear message
about the existing bounded complete account export. Pagination is not a
single MVCC snapshot; concurrent additions/deletions can shift later pages.
A failed page cannot silently become an empty history.

The projection is intentionally limited to **currently published and
independently reviewed reference-manifest revisions**. Historical events from
retired/non-published revisions remain in EXM-02B's owner export and erasure
scope, but this dashboard does not claim to display every retired edition.

## What the learner can see

- Exactly the selected part's historical saved reference-drill attempts,
  separated from global concept Knowledge Readiness and part diagnostic/mock
  practice (which do not yet have a durable per-attempt ledger).
- Unique recorded R1, R2, R3 and R4 stage counts; a drill with all four
  recorded stages is labeled **four stages recorded**, not "passed".
  A skipped step can be one of those four observations.
- Server-graded correct/incorrect choices separate from awaiting/scored
  later and skipped/ungrounded observations, reference edition revision,
  and saved time. No raw responses, expected locations or reviewer scoring
  keys are selected by the RPC or accepted by its strict client parser.
- No official pass percentage, real book-use claim, official elapsed-time
  claim, readiness equivalence or prediction.

## Ownership, safety and lifecycle

- SQL requires a permanent authenticated user even though Supabase anonymous
  guests share the `authenticated` database role. SQL function is
  `SECURITY INVOKER`; SELECT remains limited by existing owner RLS. No
  `service_role` or cross-user read access is introduced. Invalid/cross-part
  identifiers, limits and incomplete cursor pairs fail closed.
- The Dart client checks the **current Supabase Auth ID before AND after every
  RPC await**, insists on exact owner, target version and part in *every row*,
  validates all expected fields/counts/timestamps, descending cursor order,
  duplicate IDs and accidental private field additions. UI checks active
  learner again before rendering; an old account's pending response cannot
  repaint a new account's card.
- Source events remain governed by the **existing EXM-02B whole-account
  reference-practice exports, owner-only deletion, and explicitly bounded
  erasure flow**. No new duplicate records, new retention timer or separate
  privacy/export workflow is created by this projection.
- User opts in by clicking **Load saved reference drills**. Error messaging
  distinguishes loading failure from genuinely empty saved history; accounts
  without a permanent sign-in cannot request the private server projection.

## Verification

- New pgTAP assertions extend the existing full historical EXM fixture for
  SQL grant hardening, security-invoker mode, exact version/part, guest/other
  account refusal, bounds, incomplete vs four-step completion, and correct
  vs unscored distinction.
- New Flutter service tests cover strict schema, private-field rejection,
  owner/part/version mismatch, guest isolation, identity changes during
  network waits, paging order/bounds and invalid cursors.
- New widget tests cover opt-in, truthful counts, redaction on account switch,
  late-response suppression, and malformed private rows.
- The existing explicit-part Progress widget tests are updated to distinguish
  **missing saved mock/diagnostic history** from **available saved reference
  drill history**.

## Follow-on gates

- Genuine durable canonical diagnostic and mock exam attempts require a
  *separately reviewed* owner-RLS append-only design, idempotent attempt
  identity, content-edition pinning, scoring provenance, account export and
  deletion within the same transaction boundaries. Do not backfill invented
  scores from `user_concept_state` or from R1–R4 drills.
- Manual browser acceptance, actual signed-in flow, interruptions/refresh,
  concurrent erasure and export/re-import correctness remain future owner
  testing gates. No merge, production migration or deployment is performed.
