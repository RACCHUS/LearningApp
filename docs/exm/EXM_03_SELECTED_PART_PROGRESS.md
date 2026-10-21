# EXM-03 — Selected Exam Part Progress and Next Step (draft)

**Engineering-only milestone.** Never describe the values in this feature as an
official certification or licensure exam score, predicted pass, saved
exam-attempt history, or verified test-center conditions.

## What is built

- Current Context > Progress retains its existing **whole-target Knowledge
  Readiness** and All Knowledge view. It adds an optional **Exam-part knowledge
  progress** card for a target context with an exact target version.
- The learner must explicitly select a configured exam part. A part cannot be
  guessed from generic `activeFocusId`, the latest target version, a previous
  context selection, or a shared concept. Switching learner/context/version
  recreates the selection state. The selected part does not rewrite the
  normal Learn primary NextAction.
- `ExamPartProfileService` loads only exact published
  `target_versions` rows matching **target ID + target version ID** and parses
  the typed EXM-01 exam profile. Missing, unreviewed/malformed, foreign-target
  and retired/draft versions are not silently presented as exam parts.
- `examPartProgressProvider` uses **learner ID + target ID + target version ID
  + exam part key** as a scoped cache key, revalidates the selected
  `curriculum_root_node_id` in the actual version's curriculum tree and
  combines validated `TargetReadiness` with canonical published
  `DiagnosticAvailability`. A mismatched owner, version, root or part fails
  closed without substituting target-wide values.
- Only **part-scoped global concept knowledge** is counted in the qualitative
  coverage metrics; genuinely shared concepts can contribute to more than one
  part, but this does **not** prove part-specific question mastery.
- The card *explicitly* says that historical part-specific practice attempts
  are not available. It does not derive attempt counts, pass/fail percentages,
  practice streaks or scored past exams from `user_concept_state`. It only
  displays real knowledge concept counts and qualitative knowledge band.
- `ExamPartNextActionEngine` is a deterministic **secondary** recommendation
  (not the main NextAction precedence):
  - Missing concepts: review curriculum mappings.
  - No assessed evidence with enough reviewed diagnostic content: offer an
    explicit **part-specific** educational diagnostic.
  - Weak concepts: recommend targeted reinforcement; it outranks diagnostic.
  - Strong coverage with reviewed diagnostic content: practice diagnostic,
    **not** an official readiness/pass promise.
  - All other cases: continue studying.
  - No reviewed canonical coverage: never offer a diagnostic button.
- A diagnostic launch forwards the exact selected target ID/version/part to
  `DiagnosticAssessmentScreen`. Non-diagnostic actions open the **full target
  outline**, labeled as such; they never pretend that route is part-filtered.

## Automated tests

- Pure NextAction precedence, weak-concept priority, missing mapping,
  unsupported diagnostic, unassessed/strong/developing evidence, version
  mismatch, and explicit nonofficial language.
- Exact published version/target provenance, part root validation, foreign
  owner/cache key refusal, unknown part, and no fictitious attempt history.
- Widget A/B selection, distinct counts and next steps, no unsafely promoted
  shared history, account switch resetting selected part, absent profile
  hiding the section, and scope errors failing closed.

## Still open (NOT implemented in this milestone)

- Durable per-part historical diagnostic/mock events, attempt completion
  records, immutable question edition IDs and history-based score charts.
- Scored part-level progress indicators derived from reviewed, authenticated
  saved events (distinct from global concept knowledge).
- Context-aware direct navigation into a **part-filtered** curriculum outline,
  precedence of confirmed part-specific recommendations in the Learn primary
  action, or scheduling part-specific follow-up.
- Proven exam-version/administration-date reference rules, approved publishers,
  scoring, questions, room policy and official simulation equivalence.
- Final real-browser acceptance, cross-owner interruption and failed-network
  behavior validation; retention, portability, live DB writes, merges and
  deployments remain excluded.
