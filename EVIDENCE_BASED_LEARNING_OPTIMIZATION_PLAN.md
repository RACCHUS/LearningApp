# LearningApp — Evidence-Based Learning Science & Instructional Optimization Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Workstream:** `feature/arch-review-phase-0` (PR `#136`, kept strictly independent)
**Research Directory:** `/docs/learning_science/` · **Status:** Reconciled Root Specification (v2.1 — Pre-Merge Revision)

---

## 1. Architectural Baseline: Implemented on `main` vs. Proposed Specifications

This plan builds on `main` (`e538585`) without assuming unmerged code from `feature/arch-review-phase-0` (PR `#136`). To prevent implementation ambiguity, we explicitly separate **what is already implemented on `main`** from **what is specified by this plan for phased implementation**:

### 1.1 Implemented & Active on `main` (`e538585`)
- **Curriculum Manifest & Provenance Infrastructure**: `content/schema/curriculum_manifest.schema.json` (which currently enforces `additionalProperties: false`, string-array `options`, and `scoring_spec.correct_index`), source citations, and manifest ingestion RPCs.
- **Learning Architecture V2 & Canonical Taxonomy v2.4**: Global `knowledge_concepts`, scoped curricula (`ResolvedScope`), `TargetVersion` visibility guards, and dual-layer taxonomy crosswalks.
- **`review_items` Scheduler**: Persistent spaced-repetition state using a simplified SM-2 interval ladder (`[1, 3, 7, 14, 30, 60, 120]`) and aggregate counters (`total_reviews`, `correct_reviews`, `repetition_level`, `ease_factor`).
- **`ConceptEvidenceService` & `user_concept_state`**: Concept-level evidence aggregation (currently using client-side select-then-upsert with `FOR ALL` owner RLS and an evidence-count-based `confidence` heuristic: $\ge 2$ observations = `medium`, $\ge 5$ = `high`).
- **EXM-01..03 Architecture**: Reference manifest revisions (`EXM-01`), durable ungraded reference-navigation drill events (`EXM-02B` `exam_reference_drill_events`), and server-validated protected exam part scoring (`EXM-03` `exam_part_practice_attempts`).
- **ECO-00..04 & Literacy Foundations**: Moderation (`ECO-00B`), quotas (`ECO-00C`), concept Q&A (`ECO-01`), editorial review workflow (`ECO-02`), educator profiles (`ECO-04`), and the audio-first Literacy Hub (`LITERACY_ACCESSIBILITY_PLAN.md`).

### 1.2 Specified in This Plan (Not Yet Implemented on `main`)
- **`LearningTaskProfile`, `ContentComplexityProfile`, `InstructionalPolicy`, and `AssessmentPolicy`** (requires a versioned schema update to `curriculum_manifest.schema.json` before use in manifests).
- **Authoring vs. Learner Presentation vs. Server Scoring option separation** (coordinating with PR `#136` `FIX-12`).
- **`ContentQualityValidator`** and the 6-stage universal import alignment pipeline.
- **General `public.learning_events` ledger and `record_events` RPC** (converting `user_concept_state` into a server-maintained projection with direct client DML revoked).
- **Versioned FSRS-6 scheduler integration (`package:fsrs` v2.0.1)**.
- **6-property decomposed content provenance** and measurement-quality tracking.

---

## 2. Canonical Task & Policy Architecture (Four Distinct Schemas)

The taxonomy defined here and in [`docs/learning_science/02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md) is an **engineering ontology for organizing learning experiences and instructional delivery**—it is not claimed to be an empirically validated psychological classification system.

A single `knowledge_concept` can involve multiple `concept_facets[]` (e.g., vocabulary, symbol recognition, relational understanding, calculation, code-book lookup, and safety execution). Each individual learning or assessment activity specifies the particular facet and operation it exercises using **four canonical schemas**:

### 2.1 `LearningTaskProfile` (What the Activity Exercises)
- `knowledge_facet`: `sublexical_orthographic` | `verbal_terminology` | `conceptual_relational` | `procedural_quantitative` | `procedural_execution` | `perceptual_diagnostic` | `reference_navigation`
- `cognitive_operation`: `define_or_identify` | `explain_mechanism` | `distinguish_confusable` | `classify_example_non_example` | `apply_to_scenario` | `calculate_and_verify_units` | `locate_and_interpret_provision` | `justify_why_correct`
- `stimulus_channel`: `visual_text` | `audio_first` | `audio_plus_visual` | `diagram_or_image` | `scenario_with_reference_manifest`
- `response_channel`: `structured_choice` | `free_recall_text` | `spoken_production` | `numeric_with_unit` | `ordered_checklist` | `reference_locator_step` | `grapheme_trace_or_tap`
- `reference_policy`: `closed_book` | `open_book_manifest` | `formula_sheet_only`

### 2.2 `ContentComplexityProfile` (What Makes the Task Demanding at Cold Start)
Used identically across [`02`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md), [`06`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md), and [`08`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md):
- `reading_demand`: `{ word_count, reading_grade_estimate, lexical_rarity_tier }`
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

## 3. Summary of the Seven Task Approaches & Scientific Guardrails

Full citations, sample sizes, effect sizes, moderators, and limitations are documented in [`docs/learning_science/01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md) and [`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md):

1. **Literacy & Phonics (`sublexical_orthographic`)**: Keep phonemic awareness, grapheme-phoneme mapping, decoding, spelling, and audio-first UI. **No universal 95% grapheme gate** (stages remain recommendations per `LITERACY_ACCESSIBILITY_PLAN.md`). Grounded in the 2026 systematic review of adult reading interventions (15 studies, ages 16–76: consistent decoding improvements, mixed results on broader reading components).
2. **Open-Book Navigation (`reference_navigation` / `EXM`)**: **No arbitrary 30/70 internalize/lookup split.** Aligns with `EXM_00` by independently measuring six competencies: *(1) Resource selection, (2) Section location, (3) Provision location, (4) Exception comprehension, (5) Provision application, and (6) Execution within the exam time budget.* Under-preparation/time-out hypotheses are tracked as empirical research questions rather than attributed to Durning et al. (2016).
3. **Concepts & Vocabulary (`verbal_terminology` & `conceptual_relational`)**: Supports six cognitive operations (*Define, Explain, Distinguish, Recognize examples/non-examples, Apply, Explain why correct*) without forcing three angles on every concept. Selective contrastive interleaving (`g = 0.40`, Ruitenburg et al., 2026) when concepts are genuinely confusable.
4. **Calculations & Procedures (`procedural_quantitative`)**: Adaptive worked examples and backward fading grounded in the 2025 Expertise Reversal meta-analysis (60 studies, $N = 5,924$: high assistance helps novices $d = 0.505$; low assistance helps experienced learners $d = -0.428$).
5. **Oral Production (`spoken_production`)**: Used where spoken output is required (e.g., USCIS civics interview). Separates transfer-appropriate processing (Morris et al., 1977) and the production effect (MacLeod et al., 2010) from spoken free-recall exam performance (marked as an **experimental hypothesis**). Speech-onset time is never a mastery gate.
6. **Visual Classification (`perceptual_diagnostic`)**: Establishes classification accuracy before speed; no arbitrary latency threshold.
7. **Critical-Step Checklists (`procedural_execution`)**: Critical-fail gates are restricted strictly to steps designated as critical by an authoritative exam rubric or safety standard.

---

## 4. Separating the Three Difficulty Constructs, FSRS-6, Concept Mastery & Exam Readiness

We enforce a strict boundary across both cold-start ($N=0$) and empirical ($N > 0$) stages ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)):

1. **Content Complexity (`ContentComplexityProfile`) $\ne$ Psychometric Item Difficulty ($b_i$) $\ne$ Individual Memory State (FSRS $S, D$)**:
   - `ContentComplexityProfile` describes intrinsic task demand at $N=0$. It is **never** used to fabricate pseudo-IRT parameters or manufacture unvalidated initial FSRS stability/difficulty values.
   - Online Elo updates provide relative ratings and are kept distinct from calibrated IRT parameters ($a_i, b_i$), whose sample requirements depend on model structure and priors (`ER-09`).
2. **FSRS-6 Card Retrievability $\ne$ Concept Mastery $\ne$ Examination Readiness**:
   - **FSRS-6 (`package:fsrs` v2.0.1)** estimates memory retrievability $R(t)$ for a *specific review card*. Because existing `review_items` rows store only aggregate counters (`total_reviews`, `correct_reviews`), historical review sequences cannot be reconstructed; items migrate to `v2_fsrs` forward from their next review.
   - **Concept Mastery (`user_concept_state`)** evaluates evidence across the multiple facets and cognitive operations of a concept.
   - **Examination Readiness** evaluates authoritative blueprint coverage, delayed retention, transfer to held-out unfamiliar items, and performance under actual exam conditions (e.g., open-book reference navigation for Florida Certified Contractor vs. closed-book timed MCQ for Florida Insurance).
   - **Exam-Date Workload Policy**: Approaching exam dates adjust daily workload and prioritization as a separate policy layer without mutating underlying FSRS memory parameters.

---

## 5. Decomposed Provenance, Answer-Key Protection & Unified Event Contract

### 5.1 Six Orthogonal Provenance Properties (Replacing Conflated `content_trust_level`)
To allow a privately imported government manual (`origin: user_import`, `source_authority: primary_regulator_or_statute`) to be accurately represented and later reviewed without losing its origin, provenance is decomposed into six independent fields ([`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md), [`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md)):
1. **`origin`**: `official_source` | `curated_editorial` | `community_contribution` | `user_import` | `ai_generated`
2. **`visibility`**: `private` | `shared_unlisted` | `public_catalog`
3. **`rights_status`**: `verified_permissive_or_public_domain` | `licensed_embed_or_link` | `private_fair_use_only` | `restricted_or_unknown`
4. **`review_status`**: `unreviewed` | `automated_checks_passed` | `editorially_reviewed` | `authoritatively_verified`
5. **`source_authority`**: `primary_regulator_or_statute` | `accredited_publisher_or_standard` | `secondary_educational` | `user_supplied_unverified`
6. **`version_validity`**: `{ effective_from, effective_to, superseded_by_version_id, status: 'active' | 'expired' | 'superseded' }`

### 5.2 Three Content Representations (Answer-Key Security — `FIX-12` Alignment)
1. **Authoring / Storage Representation**: Contains prompt, options (`option_id`, `text`), `scoring_spec` (`correct_option_ids` / `correct_index`), `rationale`, and `misconception_tag`.
2. **Learner Presentation DTO**: Delivers prompt, stimulus, and shuffled options (`option_id`, `text`) **without** `is_correct`, `correct_index`, `scoring_spec`, or answer-revealing rationales prior to submission.
3. **Server Scoring Representation**: Evaluates responses server-side via protected RPCs and releases rationales/feedback only after submission (or after part submission in exam mode).

### 5.3 Canonical Event Ledger (`public.learning_events` & `record_events`)
Unifies general learning telemetry under the canonical table **`public.learning_events`** and RPC **`record_events`** (matching `ARCHITECTURE_REVIEW.md` while preserving `EXM-02B` `exam_reference_drill_events` and `EXM-03` `exam_part_practice_attempts`), and transitions `user_concept_state` to a server-maintained projection with direct client DML revoked ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)).

---

## 6. Research Directory & Seven-Phase Implementation Roadmap

| Document | Scope |
|---|---|
| **[`docs/learning_science/README.md`](docs/learning_science/README.md)** | Research governance, evidentiary standards, and reconciliation with legacy `LEARNING_UI_RESEARCH.md` |
| **[`01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md)** | Peer-reviewed evidence register (`ER-01`–`ER-10`), including Ruitenburg et al. (2026), Expertise Reversal (2025), Adult Literacy (2026), and Prequestioning (2023) |
| **[`02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md)** | Canonical `LearningTaskProfile`, `ContentComplexityProfile`, `InstructionalPolicy`, and `AssessmentPolicy` schemas |
| **[`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)** | Strategy selection rules, moderators, universal option shuffling (`FIX-1` aligned with PR `#136`), and feedback timing |
| **[`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md)** | Delivery rules across all 7 task approaches |
| **[`05_LEARNER_ADAPTATION.md`](docs/learning_science/05_LEARNER_ADAPTATION.md)** | Diagnostic pretesting (`ER-10`), adaptive scaffolding (`ER-05`), and prerequisite remediation |
| **[`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)** | `public.learning_events` + `record_events` contract, `user_concept_state` server projection, FSRS-6 migration, and the 3 difficulty constructs |
| **[`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)** | Decomposed provenance vs. measurement quality, corrected proving grounds (FL Contractor open-book vs. FL Insurance closed-book, plus visual & checklist targets), and outcome calibration |
| **[`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md)** | 6-stage ingestion pipeline, authoring vs. learner vs. server representations, and proposed versioned `curriculum_manifest.schema.json` extensions |
