# EXM-03 — Part-scoped diagnostic session and report handoff

**Draft-only engineering checkpoint.** This is an explicitly opted-in practice
part. The target-wide diagnostic route continues to work unchanged when no part
is selected. No official simulation or release claims are authorized.

## Contract and defenses

- `DiagnosticAssessmentScreen(examPartKey: ...)` uses the previously validated
  part-scoped candidate provider. A selected part is **never** guessed from an
  unrelated Learn focus or inherited from another selected target.
- `scopedDiagnosticSessionProvider` isolates mutable answers, submitting state
  and returned reports by **target, version, part and current learner ID**.
  It rejects stale requested owner keys and refuses out-of-set item responses.
  Existing target-wide session provider remains independent.
- Repeat taps cannot issue a second submission while a first is in flight or
  after a report has returned. Attempts to change answers during submission
  are ignored. Disposed sessions cannot receive late result state.
- `evaluatePartDiagnosticSession` independently reloads the published,
  version-owned, part-scoped canonical question snapshot **before any scoring
  or evidence write**. It checks minimum reviewed coverage, exact unique
  IDs and responses, item prompt, interaction, scoring/response specs,
  explanations/difficulty and referenced concept/weight/role identity.
  Foreign, stale, missing, duplicate or modified question sets fail closed.
  Scoring uses the freshly loaded canonical items, not caller-supplied keys.
- `DiagnosticAssessmentReport` retains `examPartKey`,
  `curriculumRootNodeId`, and `learnerId` across remedial-set updates.
  `DiagnosticReportScreen` displays the educational part label and
  stops rendering private results once the current learner ID changes.
  An old scoped report clearly offers **Start Full Curriculum**, not a
  misleading part-specific learning-context promise. The existing
  target-wide report and route remain compatible.
- Part-scoped submissions invalidate part and whole-target readiness caches
  after the completed report, since globally shared concept evidence is
  independently useful. They **do not** yet update exam-specific Progress or
  NextAction, and they do not claim separate exam-scoped persistent history.

## Automated regressions

- Canonical synthetic Part A candidate succeeds and result metadata survives
  report copies.
- Modified scoring spec, foreign Part B item, duplicate ID, mixed concept,
  and now-insufficient reviewed coverage are rejected before evidence writes.
- Target/part/owner session separation; wrong-learner and repeat-submit
  rejection; no answer mutation while in flight; mismatched reports refused.
- Explicit part screen carries the key into a result, with no silent
  target-wide fallback. Report hides personal concept details on account
  switch. Existing unscoped widget tests continue to exercise the legacy path.

## Remaining EXM-03 release gates

- History/event persistence and official content version snapshots remain
  separate EXM-02B/EXM-03 contracts. The current canonical item check does not
  preserve a prior question edition automatically if source content changes;
  an old in-progress part session fails closed instead.
- A report can have `evidencePersisted == false`; this cannot be described
  as permanently stored Progress. Existing concept evidence is global, not a
  per-part official examination score.
- NextAction, Progress, account-wide portability/retention and authenticated
  session lifecycle integration are pending. Follow-up work must respect
  explicit selection, applicable date and reviewed question provenance.
- Final owner-controlled real-browser, sleep/wake, account switching and
  network interruption tests are postponed. No deployment, migration,
  production learner read/write, or independently verified issuer standards.
