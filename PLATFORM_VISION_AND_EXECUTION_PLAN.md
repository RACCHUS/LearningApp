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

### B. Measurement Quality (`measurement_quality_level`)
- `unobserved` ($N = 0$) $\to$ `research_informed_prior` (`ContentComplexityProfile`) $\to$ `observed` ($1 \le N < N_{\text{min}}$) $\to$ `calibrated` (validated statistical estimates with verified convergence and bounded $\text{SE}$) $\to$ `validated_for_intended_use`.

### C. Blueprint Alignment (`blueprint_alignment_state`)
- `unmapped` | `concept_mapped` | `blueprint_weighted` (mapped to an active `TargetVersion` exam domain/part).

### D. Four Separate Evidence & State Layers
1. **FSRS-6 Card Retrievability $R(t)$ (`v2_fsrs6`)**: Memory recall probability for an individual memory-review card (`Again`, `Hard`, `Good`, `Easy`).
2. **Concept Evidence (`user_concept_state`)**: Server-maintained projection of competence across a concept's facets and cognitive operations.
3. **Reference-Navigation Evidence (`EXM-02B`)**: Open-book lookup accuracy and timing across `R1–R4`.
4. **Examination Readiness**: Synthesizes blueprint coverage, delayed retention, transfer to held-out items, and execution under actual exam conditions (e.g., **open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 3. Security & Contract Coordination Between Branches

To ensure clean integration between this documentation branch (`docs/architecture-and-learning-science-plans`) and Antigravity's engineering branch (`feature/arch-review-phase-0` / PR `#136`):

1. **`ARCHITECTURE_REVIEW.md` Synchronized**:
   - Both branches use the identical 320-line `ARCHITECTURE_REVIEW.md` file (SHA `5fe779d3db382d03ad034dc03742409b9a6c1c7b`, including the official `10 GiB/month transfer` Firebase Hosting Spark limit), preventing any add/add merge conflict.
2. **Accurate `FIX-12` Status & Target Contract**:
   - The three-representation model (Authoring representation $\to$ Learner presentation DTO without answer keys $\to$ Server scoring representation) is the proposed Phase 1 target. Existing `EXM-03` on `main` is a `service_role`-only scoring backend for assigned practice, and PR `#136` schedules general learner-facing answer-key isolation and server scoring RPCs for Phase 1.
3. **Universal Option Shuffling & Single Canonical `presented_option_ids` Field (`FIX-1`)**:
   - Documents the single-XOR per-item seed contract (`sessionNonce ^ item.id.hashCode`), the remaining legacy `McqOptions`/`McqQuestionWidget` and rich lesson reader routes to migrate, and standardizes exclusively on `presented_option_ids: text[]` in `public.learning_events` (`03_INSTRUCTIONAL_STRATEGIES.md`, `06_MEASUREMENT_AND_SCHEDULING.md`).
