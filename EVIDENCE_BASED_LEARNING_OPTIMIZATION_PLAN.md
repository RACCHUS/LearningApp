# LearningApp — Evidence-Based Learning Science & Instructional Optimization Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Workstream:** `feature/arch-review-phase-0` (PR `#136`, kept strictly independent)
**Research Directory:** `/docs/learning_science/` · **Status:** Reconciled Root Specification (v2.2 — Merge-Ready Revision)

---

## 1. Architectural Baseline: Implemented on `main` vs. Proposed Specifications

This plan builds on `main` (`e538585`) without assuming unmerged code from `feature/arch-review-phase-0` (PR `#136`). To prevent implementation defects, we explicitly separate **what is currently implemented on `main`** from **what is specified by this plan for phased implementation**:

### 1.1 Implemented & Active on `main` (`e538585`)
- **Curriculum Manifest & Provenance Infrastructure**: `content/schema/curriculum_manifest.schema.json` (which currently enforces `additionalProperties: false`, string-array `options`, and `scoring_spec.correct_index`), source citations, and manifest ingestion RPCs.
- **Learning Architecture V2 & Canonical Taxonomy v2.4**: Global `knowledge_concepts`, scoped curricula (`ResolvedScope`), `TargetVersion` visibility guards, and dual-layer taxonomy crosswalks.
- **`review_items` Scheduler**: Persistent spaced-repetition state (`scheduler_version = 'v1_sm2_ladder'`) using a simplified SM-2 interval ladder (`[1, 3, 7, 14, 30, 60, 120]`) and aggregate counters (`total_reviews`, `correct_reviews`, `repetition_level`, `ease_factor`).
- **`ConceptEvidenceService` & `user_concept_state`**: Concept-level evidence aggregation (currently using client-side select-then-upsert with `FOR ALL` owner RLS and an observation-count-based `confidence` heuristic: $\ge 2$ observations = `medium`, $\ge 5$ = `high`).
- **EXM-01..03 Architecture**: Reference manifest revisions (`EXM-01`), durable ungraded reference-navigation drill events (`EXM-02B` `exam_reference_drill_events`), and a **`service_role`-only scoring backend for assigned exam part practice** (`EXM-03`, deliberately not yet connected to the learner UI as a general assessment submission API).
- **ECO-00..04 & Literacy Foundations**: Moderation (`ECO-00B`), quotas (`ECO-00C`), concept Q&A (`ECO-01`), editorial review workflow (`ECO-02`), educator profiles (`ECO-04`), and the audio-first Literacy Hub (`LITERACY_ACCESSIBILITY_PLAN.md`).

### 1.2 Specified in This Plan (Not Yet Implemented on `main`)
- **`LearningTaskProfile`, `ContentComplexityProfile`, `InstructionalPolicy`, and `AssessmentPolicy`** (requires a versioned schema `2.1.0` update to `curriculum_manifest.schema.json` before use in manifests).
- **Three-Representation Answer-Key Isolation (`FIX-12` Target)**: Authoring representation $\to$ Learner presentation DTO without answer keys $\to$ Server scoring representation. General assessment answer-key isolation and learner-facing scoring RPCs remain **scheduled for Phase 1** (in both this plan and PR `#136`, where `AssessmentItemRenderer` still scores client-side).
- **Universal Option Shuffling Completion (`FIX-1` Target)**: Closing the remaining gaps in legacy `McqOptions`/`McqQuestionWidget`, fixing the double-XOR seed cancellation in `AdaptivePracticeScreen`, passing session seeds from the rich lesson reader, and persisting `presented_option_ids` ([`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)).
- **General `public.learning_events` ledger and `record_events` RPC** with strict client-submitted vs. server-owned trust boundaries ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)).
- **Versioned FSRS-6 scheduler integration (`package:fsrs` v2.0.1, `v2_fsrs6`)**.
- **6-property decomposed content provenance** (`rights_review_required` for unverified imports) and measurement-quality tracking.

---

## 2. Canonical Task & Policy Architecture (Four Distinct Schemas)

The taxonomy defined here and in [`docs/learning_science/02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md) is an **engineering ontology for organizing learning experiences and instructional delivery**—it is not claimed to be an empirically validated psychological classification system.

A single `knowledge_concept` can involve multiple `concept_facets[]`. Each individual learning or assessment activity specifies the particular facet and operation it exercises using **four canonical schemas**:

### 2.1 `LearningTaskProfile` (What the Activity Exercises)
- `knowledge_facet`: `sublexical_orthographic` | `verbal_terminology` | `conceptual_relational` | `procedural_quantitative` | `procedural_execution` | `perceptual_diagnostic` | `reference_navigation`
- `cognitive_operation`: `define_or_identify` | `explain_mechanism` | `distinguish_confusable` | `classify_example_non_example` | `apply_to_scenario` | `calculate_and_verify_units` | `locate_and_interpret_provision` | `justify_why_correct`
- `stimulus_channel`: `visual_text` | `audio_first` | `audio_plus_visual` | `diagram_or_image` | `scenario_with_reference_manifest`
- `response_channel`: `structured_choice` | `free_recall_text` | `spoken_production` | `numeric_with_unit` | `ordered_checklist` | `reference_locator_step` | `grapheme_trace_or_tap`
- `reference_policy`: `closed_book` | `open_book_manifest` | `formula_sheet_only`

### 2.2 `ContentComplexityProfile` (What Makes the Task Demanding at Cold Start)
Used identically across [`02`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md), [`06`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md), and [`08`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md):
- `reading_demand`: `{ word_count, reading_grade_estimate, lexical_rarity_tier }` *(Note per Tighe et al., 2026: `reading_grade_estimate` describes **text passage linguistic demand**, never an adult learner's ability level)*
- `reasoning_step_count`: integer ($\ge 1$)
- `quantitative_complexity`: `none` | `arithmetic` | `single_formula` | `multi_step_with_unit_conversion`
- `prerequisite_depth`: integer ($\ge 0$, depth in `concept_relations`)
- `confusable_density`: `none` | `low` | `high_confusable_group`
- `response_format_demand`: `recognition_choice` | `cued_recall` | `uncued_production` | `multi_step_execution`
- `reference_foraging_depth`: `none` | `r1_resource` | `r2_section` | `r3_provision` | `r4_exception`
- `has_statutory_exception`: boolean

### 2.3 `InstructionalPolicy` (How the Adaptive Engine Delivers & Scaffolds)
- `eligible_strategies[]`: array of strategy IDs (`active_retrieval_first`, `contrastive_interleaving`, `worked_example_backward_fading`, `elaborative_rationale_feedback`, `reference_foraging_decomposition`, `multimodal_audio_orthographic`)
- `scaffolding_policy`: `none` | `adaptive_on_error` | `diagnostic_gated_fading`
- `feedback_policy`: `immediate_explanatory` | `deferred_until_submission` | `minimal_verification`

### 2.4 `AssessmentPolicy` (Scoring, Timing & Error Criticality)
- `timing_regime`: `untimed_mastery` | `paced_practice` | `exam_clock_enforced`
- `error_criticality`: `standard_compensatory` | `authoritative_critical_step_gate` (only when backed by an official rubric or safety regulation)
- `scoring_protection`: `client_practice` | `server_protected_scoring`

---

## 3. Summary of the Seven Task Approaches & Verified Scientific Guardrails

Full bibliographic citations, DOIs, 95% confidence intervals, heterogeneity ($I^2$), and study limitations are documented in [`docs/learning_science/01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md) and [`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md):

1. **Literacy & Phonics (`sublexical_orthographic`)**: Keep phonemic awareness, grapheme-phoneme mapping, decoding, spelling, and audio-first UI. **No universal 95% grapheme gate** (stages remain recommendations per `LITERACY_ACCESSIBILITY_PLAN.md`). Grounded in **Tighe et al. (2026, Kentucky Reading Research Center report, 15 peer-reviewed studies, adults aged 16–76)**: untimed decoding effects are most consistent ($d = .12\text{--}.46$), timed decoding gains are much smaller, and fluency/vocabulary/spelling/comprehension evidence is mixed.
2. **Open-Book Navigation (`reference_navigation` / `EXM`)**: **No arbitrary 30/70 internalize/lookup split.** Aligns with `EXM_00` by independently measuring six competencies: *(1) Resource selection, (2) Section location, (3) Provision location, (4) Exception comprehension, (5) Provision application, and (6) Execution within the exam time budget.* Under-preparation/timeout causation is labeled as an `Implementation Hypothesis` rather than attributed to Durning et al. (2016).
3. **Concepts & Vocabulary (`verbal_terminology` & `conceptual_relational`)**: Supports six cognitive operations (*Define, Explain, Distinguish, Recognize examples/non-examples, Apply, Explain why correct*) without forcing three angles on every concept. Selective contrastive interleaving (**Ruitenburg et al., 2026**, `DOI: 10.1007/s10648-026-10225-5`: retrieval $g = .37$ CI $[.18, .56]$, spacing $g = .20$ CI $[.03, .36]$, interleaving $g = .40$ CI $[.10, .71]$, qualified for classroom populations).
4. **Calculations & Procedures (`procedural_quantitative`)**: Adaptive worked examples and backward fading grounded in **Tetzlaff et al. (2025, *Learning and Instruction*, `DOI: 10.1016/j.learninstruc.2025.102142`, $k = 60, N = 5,924$)**: high assistance benefits novices ($d = .505$, CI $[.260, .750]$, $I^2 = 90.87\%$) while impairing experienced learners ($d = -.428$, CI $[-.647, -.209]$). Separates prequestioning (**St. Hilaire, Chan & Ahn, 2023/2024**, `DOI: 10.3758/s13423-023-02353-8`: specific $g = .54$ CI $[.42, .66]$ vs. general $g = .04$ CI $[-.04, .11]$) from multi-signal diagnostic validity (`05_LEARNER_ADAPTATION.md`).
5. **Oral Production (`spoken_production`)**: Used where spoken output is required (e.g., USCIS civics interview). Separates transfer-appropriate processing (Morris et al., 1977) and the production effect (MacLeod et al., 2010 — recognition experiments) from spoken free-recall exam performance (marked `experimental` `Implementation Hypothesis`). Speech-onset time is never a mastery gate.
6. **Visual Classification (`perceptual_diagnostic`)**: Establishes classification accuracy before speed; no arbitrary latency threshold.
7. **Critical-Step Checklists (`procedural_execution`)**: Critical-fail gates are restricted strictly to steps designated as critical by an authoritative exam rubric or safety standard.

---

## 4. Separating Difficulty Constructs, FSRS-6 (`v2_fsrs6`), Concept Mastery & Exam Readiness

Detailed in [`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md):

1. **Content Complexity (`ContentComplexityProfile`) $\ne$ Psychometric Item Difficulty ($b_i$) $\ne$ Individual Memory State (FSRS-6 $S, D$)**:
   - `ContentComplexityProfile` describes intrinsic task demand at $N=0$. It is **never** used to fabricate pseudo-IRT parameters or manufacture unvalidated initial FSRS stability/difficulty values.
   - Online Elo updates provide relative ratings and are kept distinct from calibrated IRT parameters ($a_i, b_i$), where simulation results like **König, Spoden & Frey (2020, `DOI: 10.1177/0146621619893786`)** ($N = 100$ under a specific hierarchical Bayesian 2PL model) depend on model assumptions and verified standard errors ($\text{SE}$) rather than a universal user-count rule.
2. **FSRS-6 Card Retrievability $\ne$ Concept Evidence $\ne$ Reference-Navigation Evidence $\ne$ Exam Readiness**:
   - **FSRS-6 (`package:fsrs` v2.0.1, `scheduler_version = 'v2_fsrs6'`)** estimates memory retrievability $R(t)$ for a *specific memory-review card* using card recall ratings (`Again`, `Hard`, `Good`, `Easy`). We do **not** automatically convert MCQ recognition results or slow open-book reference lookups into FSRS memory ratings. Because existing `review_items` rows store only aggregate counters, items migrate to `'v2_fsrs6'` forward from their next memory review.
   - **Concept Evidence (`user_concept_state`)** is a server-maintained projection (with direct client DML revoked) evaluating competence across the facets and cognitive operations of a concept.
   - **Reference-Navigation Evidence (`EXM-02B`)** evaluates open-book lookup accuracy and timing across `R1–R4`.
   - **Examination Readiness** evaluates authoritative blueprint coverage, delayed retention, transfer to held-out unfamiliar items, and execution under actual exam conditions (**open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 5. Decomposed Provenance, Answer-Key Isolation (`FIX-12`) & Event Trust Boundary

1. **Six Orthogonal Provenance Properties ([`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md))**:
   - **`origin`** (`official_source`, `curated_editorial`, `community_contribution`, `user_import`, `ai_generated`)
   - **`visibility`** (`private`, `shared_unlisted`, `public_catalog`)
   - **`rights_status`** (`verified_permissive_or_public_domain`, `licensed_embed_or_link`, `rights_review_required`, `restricted_or_unknown` — replacing `private_fair_use_only`)
   - **`review_status`** (`unreviewed`, `automated_checks_passed`, `editorially_reviewed`, `authoritatively_verified`)
   - **`source_authority`** (`primary_regulator_or_statute`, `accredited_publisher_or_standard`, `secondary_educational`, `user_supplied_unverified`)
   - **`version_validity`** (`{ effective_from, effective_to, superseded_by_version_id, status }`)
2. **Server-Owned vs. Client-Submitted Event Fields ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md))**:
   - In the proposed `public.learning_events` and `record_events` contract, `user_id`, `received_at`, `content_version`, `task_profile`, `scored_outcome`, `scheduler_version`, `scheduler_state_before/after`, `provenance_snapshot` (all 6 properties), and `assessment_conditions` are **server-owned/derived** and never trusted from client input; `presented_option_ids` (`text[]`) is validated by the server against the canonical item's option IDs.

---

## 6. Research Directory Index

| Document | Scope |
|---|---|
| **[`docs/learning_science/README.md`](docs/learning_science/README.md)** | Research governance, evidentiary standards, and reconciliation with legacy `LEARNING_UI_RESEARCH.md` |
| **[`01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md)** | Complete peer-reviewed evidence register (`ER-01`–`ER-10`) with exact DOIs, 95% CIs, heterogeneity ($I^2$), and study limitations |
| **[`02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md)** | Canonical `LearningTaskProfile`, `ContentComplexityProfile` (with adult reading demand guardrail), `InstructionalPolicy`, and `AssessmentPolicy` |
| **[`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)** | Strategy selection rules, moderators, `FIX-1` shuffling contract + 3 remaining code gaps, and canonical `presented_option_ids` |
| **[`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md)** | Delivery rules across all 7 task approaches |
| **[`05_LEARNER_ADAPTATION.md`](docs/learning_science/05_LEARNER_ADAPTATION.md)** | Prequestioning (`ER-10`) vs. multi-signal diagnostic validity, and adaptive scaffolding (`ER-05`) |
| **[`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)** | Client vs. server trust boundary for `public.learning_events` / `record_events`, `user_concept_state` projection, and `v2_fsrs6` rules |
| **[`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)** | 6-property provenance (`rights_review_required`), FL Contractor open-book vs. FL Insurance closed-book, and all 7 proving grounds |
| **[`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md)** | 6-stage ingestion pipeline, accurate `FIX-12` Phase 1 status, and proposed versioned `curriculum_manifest.schema.json` `2.1.0` extensions |
