# EXM-03 — Backend-only canonical scoring for assigned part practice

**Status:** Draft-only hardening. No learner-facing issuance or scored-history
display is enabled. This is *educational practice*, never an official examination.

## Database contract

Migration `20261031130000_exm_03_assigned_practice_scoring.sql`
extends the dormant attempt foundation with immutable
`exam_part_practice_assignments`. Only a trusted service-role backend can
issue an assignment containing the exact eligible question IDs and
**server-computed SHA-256 content fingerprints**, an owner, published target
version, configured exam part root, approved reference manifest and expiry.
The assignment table has RLS and no direct learner visibility or mutation.

`exm03_record_assigned_practice(uuid,jsonb)` is a **service-role-only**
security-definer transaction. It must never be called directly from the
learner browser or exposed through an unverified proxy. It row-locks its
assigned session for exactly-once recording. A same-payload retry returns the
stored result; a different-payload replay is rejected. The transaction
revalidates:

- A published, public exact target and version; typed `exam_preparation`
  profile with part key/root in version-owned curriculum nodes
- An approved, currently effective manifest for the exact version and part
- 6–50 unique server-assigned question IDs and a complete, bounded answer map
- A matching independent approved item-reference validity binding whose
  source SHA-256 still equals the current canonical question and scoring rule
- Every question mapped exclusively to core concepts in the exact exam-part
  subtree, with no shared/outside mappings; at least three core concepts
- Only `single_choice` for v1. Other interaction kinds fail closed until
  their grading semantics have independent server tests
- Canonical answer indices, valid response formats and available choices,
  using **database scoring specs**, not client-supplied correctness

Only exact part and version, question counts and educational score summaries
are returned. Official passing scores, prompts, editorial locations and
answer keys are not returned or promoted. This endpoint is not a probability
of passing a real examination.

## Atomic erasure and replay prevention

The prior owner DELETE grant is revoked. A guarded authenticated
`exm03_erase_part_attempts(uuid,text)` function requires a permanent owner
and exact version/part, deletes issued assignments, cascades scored summaries,
and verifies both stores are empty in the same transaction. Otherwise a
deletion followed by a retry would reconstruct previously erased history.
No client UPDATE/INSERT or direct DELETE is allowed.

The Dart history service now invokes the erasure RPC rather than deleting
attempt rows directly. User confirmation UI is not yet enabled.

## Automated tests

`exam_part_assigned_scoring_test.sql`: 16 pgTAP checks for private role
privileges, immutable append-only histories, permanently authenticated
erasure and malformed/unissued attempt rejection.

`exam_part_assigned_scoring_integration_test.sql`: synthetic (never hosted)
published reviewed manifest, six canonical items, three part-unique concepts,
approved item bindings; verifies correct scoring, idempotent retry, replay
conflict and complete owner erasure with irrecoverable assignment ID.

## Release blockers

- Trusted backend assignment issuer must verify the learner's real JWT
  server-side, not accept caller-submitted owner or question lists. No direct
  service-role key may be distributed to the browser.
- Edition-specific source policy and consent/retention details need human
  verification; this v1 scorer does not handle all Flutter assessment types.
- Account-wide complete inventory, paginated export, erasure confirmation,
  cancellations, forensic audit and recovery policy must cover BOTH new
  assignment and scored-attempt tables, as well as EXM-02B reference history.
- Real-device and browser tests, account switches, network retries, concurrent
  submissions and failures must run before learner-facing activation.
- No hosted SQL changes or production learner writes are authorized here.
