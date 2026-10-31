# EXM-03 — Authenticated submission and approved-answer read isolation

**Engineering draft; not enabled in Progress or the main Learn flow.**

## Trusted submission boundary

Migration `20261101150000_exm_03_authenticated_submit_protected_items.sql`
introduces `exm03_submit_assigned_practice(uuid,jsonb)`, limited to
authenticated permanent users. It does **not** grant `EXECUTE` on the
underlying service-role-only canonical scorer. Instead it verifies the
signed-in JWT account and live nonexpired Auth session, requires the
assignment to be issued to that exact account **and original session**,
and then invokes the scorer within the database transaction.

Existing assignments without a verified issuance session (including
test/service-created assignments) deliberately cannot use the learner RPC.
Identity, answer keys, score and curriculum information cannot be supplied
by caller arguments. Conflicting retries remain rejected; identical
responses recover the recorded result. Session checks occur before and
after the protected write.

This is an engineering endpoint only; no browser UI is wired to it while
account-wide history portability and erasure controls are incomplete.

## Legacy answer-key exposure finding and targeted mitigation

Prior to this patch, `assessment_items` could be selected directly by
learners under legitimate public/lesson policies; its `scoring_spec` column
could expose correct answers for published, reviewed items. A safe issuer
projection did not by itself close that alternate read path.

A **restrictive SELECT RLS policy** now excludes independently published
approved/rights-reviewed exam items from `anon` and `authenticated`
direct table reads, including broad `select('*')` queries. A narrowly
scoped, protected-bindings check reads private reviewer metadata under
server control and exposes only a boolean. The trusted issuer/scorer can
still read canonical content, and **legacy items without published EXM
bindings remain subject to their preexisting policies**.

A second guard runs before a practice assignment is inserted. Every
selected v1 question must have 2–10 nonempty, bounded **plain-text**
choices. This prevents embedded option objects such as
`{"text":"A","isCorrect":true}` from accidentally exposing answers through
the issuer's otherwise safe `response_spec.options` projection.

**Impact:** Client-side legacy mock/diagnostic query paths using
`assessment_items.select('*')` can no longer retrieve protected published
EXM questions. This is intentional fail-closed behavior. They must be
migrated to the safe issued-question flow before EXM saved attempts or
full exam-part simulation are enabled.

## Verification

The updated synthetic pgTAP integration verifies exact owner/session,
revoked session, foreign owner, full canonical scoring, repeat submission
and changed-answer replay; denies direct approved-item table reads and
object-encoded correct flags, while preserving the existing owner-erasure
and expiry tests. All tests use disposable local fixtures.

## Remaining release gates

- Browser-side delivery/submission UX with account-switch cancellation
- Complete owner-wide export, inventory, erasure confirmation and
  retention/recovery rules for EXM-03 history plus EXM-02B R1–R4
- Safe consumer integration for all current exam content experiences;
  no direct protected scoring-spec reads
- Privacy audit of ancillary content fields, grading feedback,
  editor/author identities, and issuer metadata
- Final browser/mobile integration, concurrency, logout and official
  examination-rule provenance tests before rollout
- No migration merge/deployment, hosted learner-data read or production SQL
  write has occurred in this draft
