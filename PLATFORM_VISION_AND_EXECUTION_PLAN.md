# LearningApp — Platform Vision, Trust Architecture & Full-Scope Execution Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Branch:** `feature/arch-review-phase-0` (PR `#136`, tracked separately)
**Related Plan:** [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md) · **Status:** Reconciled Platform Strategy (v2.2 — Pre-Merge Revision)

---

## 1. Strategic Position: Broad Reusable Platform + Strict Scientific & Security Boundaries

1. **Preserve the Full Multi-Domain Platform Architecture**
   - LearningApp builds on the substantial foundations already present on `main` (`e538585`): **Learning Architecture V2**, **Canonical Taxonomy v2.4**, **Curriculum Manifests**, **Audio-First Literacy**, **EXM-01..03**, and **ECO-00..04**.
2. **Distinguish Implemented Foundations from Proposed Specifications & Validated Claims**
   - Specifications for `LearningTaskProfile`, `ContentComplexityProfile`, `public.learning_events` (`record_events`), and FSRS-6 (`package:fsrs` v2.0.1) are explicitly documented as **proposed phased extensions** requiring versioned schema and migration changes before activation.
   - Only claims backed by empirical validation in the relevant population and assessment context are presented to learners as proven.

---

## 2. Decomposed Content Provenance, Measurement Quality & Readiness Eligibility

Rather than collapsing origin, review status, and statistical calibration into a single enum, the platform tracks them independently ([`docs/learning_science/07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)):

### A. Six Orthogonal Content Provenance Properties
1. **`origin`**: `official_source` | `curated_editorial` | `community_contribution` | `user_import` | `ai_generated`
2. **`visibility`**: `private` | `shared_unlisted` | `public_catalog`
3. **`rights_status`**: `verified_permissive_or_public_domain` | `licensed_embed_or_link` | `private_fair_use_only` | `restricted_or_unknown`
4. **`review_status`**: `unreviewed` | `automated_checks_passed` | `editorially_reviewed` | `authoritatively_verified`
5. **`source_authority`**: `primary_regulator_or_statute` | `accredited_publisher_or_standard` | `secondary_educational` | `user_supplied_unverified`
6. **`version_validity`**: `{ effective_from, effective_to, superseded_by_version_id, status: 'active' | 'expired' | 'superseded' }`

### B. Measurement Quality (`measurement_quality_level`)
- `unobserved` ($N = 0$) $\to$ `research_informed_prior` (`ContentComplexityProfile`) $\to$ `observed` ($1 \le N < N_{\text{min}}$) $\to$ `calibrated` (validated statistical estimates with bounded error) $\to$ `validated_for_intended_use`.

### C. Blueprint Alignment (`blueprint_alignment_state`)
- `unmapped` | `concept_mapped` | `blueprint_weighted` (mapped to an active `TargetVersion` exam domain/part).

### D. Three Separate Levels of Learner State
1. **FSRS-6 Card Retrievability $R(t)$**: Memory retention estimate for an individual review item.
2. **Concept Evidence (`user_concept_state`)**: Server-maintained projection of competence across a concept's facets and cognitive operations.
3. **Examination Readiness**: Synthesizes blueprint coverage, delayed retention, transfer to held-out items, and execution under actual exam conditions (e.g., **open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 3. Security & Contract Coordination Between Branches

To ensure clean integration between this documentation branch (`docs/architecture-and-learning-science-plans`) and Antigravity's engineering branch (`feature/arch-review-phase-0` / PR `#136`):

1. **`ARCHITECTURE_REVIEW.md` Synchronized**:
   - Both branches use the identical 320-line `ARCHITECTURE_REVIEW.md` file (including the official `10 GiB/month transfer` Firebase Hosting Spark limit), preventing any add/add merge conflict.
2. **Answer-Key Isolation (`FIX-12`)**:
   - Authoring representations (`is_correct`, `scoring_spec`, answer-revealing `rationale`) are stripped from learner presentation DTOs before delivery and evaluated via server-protected scoring RPCs.
3. **Universal Option Shuffling & Order Persistence (`FIX-1`)**:
   - Every structured-choice item shuffles non-anchor options by default (`AssessmentItemRenderer.shuffleOptions = true`). Because Dart's `Object.hash` and `String.hashCode` are not guaranteed stable across isolates/restarts, the exact `presented_option_ids` / `presentation_order` array is persisted in the attempt event record (`public.learning_events`).
