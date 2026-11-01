# LearningApp — Platform Vision, Trust Architecture & Full-Scope Execution Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Branch:** `feature/arch-review-phase-0` (PR `#136`, tracked separately)
**Related Plan:** [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md) · **Status:** Reconciled Platform Strategy (v2.3 — Merge-Ready Revision)

---

## 1. Strategic Position: Broad Reusable Platform + Strict Scientific & Security Boundaries

1. **Preserve the Full Multi-Domain Platform Architecture**
   - LearningApp builds on the substantial foundations already present on `main` (`e538585`): **Learning Architecture V2**, **Canonical Taxonomy v2.4**, **Curriculum Manifests**, **Audio-First Literacy**, **EXM-01..03**, and **ECO-00..04**.
2. **Distinguish Implemented Foundations from Proposed Specifications & Validated Claims**
   - Specifications for `LearningTaskProfile`, `ContentComplexityProfile`, `public.learning_events` (`record_events`), three-representation answer-key isolation (`FIX-12`), and FSRS-6 (`package:fsrs` v2.0.1, `v2_fsrs6`) are explicitly documented as **proposed phased extensions** requiring versioned schema and migration changes before activation.
   - Only claims backed by empirical validation in the relevant population and assessment context are presented to learners as proven.

---

## 2. Decomposed Content Provenance, Measurement Quality & Readiness Eligibility

Rather than collapsing origin, review status, and statistical calibration into a single enum, the platform tracks them independently ([`docs/learning_science/07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)):

### A. Six Orthogonal Content Provenance Properties
1. **`origin`**: `official_source` | `curated_editorial` | `community_contribution` | `user_import` | `ai_generated`
2. **`visibility`**: `private` | `shared_unlisted` | `public_catalog`
3. **`rights_status`**: `verified_permissive_or_public_domain` | `licensed_embed_or_link` | `rights_review_required` | `restricted_or_unknown` *(note: private visibility does not automatically constitute fair use; unverified imports default to `rights_review_required`)*
4. **`review_status`**: `unreviewed` | `automated_checks_passed` | `editorially_reviewed` | `authoritatively_verified`
5. **`source_authority`**: `primary_regulator_or_statute` | `accredited_publisher_or_standard` | `secondary_educational` | `user_supplied_unverified`
6. **`version_validity`**: `{ effective_from, effective_to, superseded_by_version_id, status: 'active' | 'expired' | 'superseded' }`

### B. Separated Complexity Status, Item Psychometric Status & Readiness Validation
Rather than conflating a cold-start `ContentComplexityProfile` or a single empirical observation ($N=1$) with calibrated item parameters, the platform separates them into three distinct status fields:
- **`complexity_assessment_status`** (Cold-start `ContentComplexityProfile` status): `unassessed` | `deterministic_profile` | `expert_reviewed_profile`.
- **`item_psychometric_status`** (Empirical item measurement status): `unobserved` ($N = 0$) $\to$ `observed_uncalibrated` ($N \ge 1$ observation-existence label only; a single response is not a meaningful difficulty estimate) $\to$ `preliminary_elo_ordering` (governed by a configurable LearningApp policy threshold **`elo_min_observations`**, inactive until selected and validated for the relevant item pool; provides low-stakes heuristic Elo ordering per Pelánek, 2016, `ER-09b`, qualified by Bolsinova, Gergely, & Brinkhuis, 2026 regarding joint adaptive bias/variance/non-convergence) $\to$ `calibrated` (statistical IRT item estimates $a_i, b_i$; requires pool- and model-specific convergence diagnostics and an acceptable standard-error bound **`calibration_max_se`**—marked `pending_validation` and inactive until validated for that item pool, per `ER-09a`).
- **`readiness_validation_status`** (Target/model validation status): `unvalidated` $\to$ `pilot_observed` $\to$ `validated_for_intended_use`.

### C. Blueprint Alignment (`blueprint_alignment_state`)
- `unmapped` | `concept_mapped` | `blueprint_weighted` (mapped to an active `TargetVersion` exam domain/part).

### D. Four Separate Evidence & State Layers
1. **FSRS-6 Card Retrievability $R(t)$ (`v2_fsrs6`)**: Memory recall probability for an individual memory-review card (`Again`, `Hard`, `Good`, `Easy`).
2. **Concept Evidence (`user_concept_state`)**: Server-maintained projection of competence across a concept's facets and cognitive operations (updated by `record_events`; kept separate from `EXM-03` `exam_part_practice_attempts`).
3. **Reference-Navigation Evidence (`EXM-02B`)**: Open-book lookup accuracy and timing across `R1–R4`.
4. **Examination Readiness**: Synthesizes blueprint coverage, delayed retention, transfer to held-out items, and execution under actual exam conditions (e.g., **open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 3. Security, Supersession & Contract Coordination Between Branches

To ensure clean integration between this documentation branch (`docs/architecture-and-learning-science-plans`) and Antigravity's engineering branch (`feature/arch-review-phase-0` / PR `#136`):

1. **`ARCHITECTURE_REVIEW.md` Synchronized & Provisional Details Explicitly Superseded**:
   - Both branches use the identical 320-line `ARCHITECTURE_REVIEW.md` file (SHA `5fe779d3db382d03ad034dc03742409b9a6c1c7b`, including the official `10 GiB/month transfer` Firebase Hosting Spark limit), preventing any add/add merge conflict.
   - Where `ARCHITECTURE_REVIEW.md` contains provisional Phase 0 event-ledger or scheduler sketches (`presented_order`, conflated confidence/FSRS ratings, or synthetic FSRS initialization), **`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md` and `/docs/learning_science/01..08` formally supersede them**.
2. **Accurate `EXM-03` Surface & Phase 1 `FIX-12` Target Contract**:
   - On `main`, `EXM-03` (`20261101130000_exm_03_assigned_practice_scoring.sql`, `20261101140000_exm_03_authenticated_assignment_issuer.sql`, and `20261101150000_exm_03_authenticated_submit_protected_items.sql`) already provides answer-key-stripped assignment issuance (`exm03_issue_assigned_practice`), authenticated session-bound submission (`exm03_submit_assigned_practice`), and restrictive RLS (`exm03_no_direct_read_of_approved_answers`) for approved `EXM-02A` items (recording attempts in `exam_part_practice_attempts` without updating `user_concept_state`).
   - Extending the three-representation answer-key isolation model to all non-EXM diagnostic, mock exam, and adaptive practice items remains a **Phase 1 deliverable (`FIX-12`)**.
3. **Universal Option Shuffling (`FIX-1` — `PARTIALLY RESOLVED` in PR `#136` at `5a428b5`) & Separate Phase 1 `presented_option_ids` Persistence (`ARCH-1`)**:
   - Documents that PR `#136`'s description and status table must be updated from `RESOLVED` to `PARTIALLY RESOLVED` because shuffling at current PR head `5a428b5` (re-verified after earlier snapshots `e67a3d5` and `dc8f49f`) is only active in `AssessmentItemRenderer`.
   - Enforces the raw per-presentation `attemptNonce` contract: parent callers (`AdaptivePracticeScreen`, which currently only defines session-scoped `_sessionNonce`, and [`lib/widgets/lesson/rich_lesson_reader.dart`](lib/widgets/lesson/rich_lesson_reader.dart)) must introduce or increment a **raw per-presentation nonce (e.g. `_attemptNonce`)** and pass it unchanged as `presentationSeed` without pre-XORing `item.id.hashCode`, and `AssessmentItemRenderer` combines it with `item.id.hashCode` **exactly once** (`attemptNonce ^ item.id.hashCode`).
   - Tracks the remaining legacy [`lib/widgets/question_widgets/mcq_question_widget.dart`](lib/widgets/question_widgets/mcq_question_widget.dart) (`widget.content.options`), [`lib/widgets/mcq_options.dart`](lib/widgets/mcq_options.dart), and dual voice-input routes (`LessonContentRenderer` and `QuestionContentRenderer`) to close Phase 0 `FIX-1`, while explicitly keeping durable persistence of `presented_option_ids: text[]` in `public.learning_events` (trusted when bound to a server-issued presentation record; otherwise labeled `untrusted_client_reported` metadata) as **separate Phase 1 event-ledger work (`ARCH-1`, `06_MEASUREMENT_AND_SCHEDULING.md`)** rather than a Phase 0 `FIX-1` acceptance criterion (whereas `FIX-3` is Phase 0 client-to-migration schema drift).

---

## 4. Phased Execution Roadmap (Aligned with `ARCHITECTURE_REVIEW.md` §6)

- **Phase 0 — Foundational Security, Schema Drift & Accessibility (`FIX-1`–`FIX-14`)**: Complete universal option shuffling (`FIX-1`), XP RPC security (`FIX-2`), schema drift & CI contract verification (`FIX-3`), `flutter_bootstrap.js` (`FIX-4`), web semantics (`FIX-6`), UTC timestamp normalization (`FIX-7`), `flutter_lints` (`FIX-10`), RLS `(select auth.uid())` (`FIX-13`), hosting security headers (`FIX-14`), and `LICENSE` (`ARCH-10`).
- **Phase 1 — Evidence Engine, Server Projections & Answer-Key Isolation (`ARCH-1`, `ARCH-3`, `FIX-8`, `FIX-9`, `FIX-12`)**: Ship `public.learning_events` and `record_events` RPC (`ARCH-1`), server-maintained `user_concept_state` and `review_items` (`v2_fsrs6`) projections, general non-EXM three-representation answer-key isolation (`FIX-12`), local-first event outbox (`ARCH-3`), and empirical pilot validation across the 7 domain proving grounds (`07_READINESS_AND_VALIDATION.md`).
- **Phase 2 — Platform API, Content Unification & BYOK/MCP (`ARCH-2`, `ARCH-4`, `ARCH-5`, `ARCH-6`)**: Introduce versioned `curriculum_manifest.schema.json` `2.1.0` (`08_CONTENT_AND_IMPORT_ALIGNMENT.md`), 6-property provenance enforcement, versioned `api` schema, MCP server (`OPP-1`), BYOK AI generation, and deferred/WASM web delivery.
- **Phase 3 — Ecosystem & Interoperability (`OPP-2`–`OPP-7`)**: Creator channels with learning-gain ranking, practical performance checklists, QTI 3.0 / xAPI / LTI 1.3 / Open Badges 3.0 interoperability, and the modular fork kit.
