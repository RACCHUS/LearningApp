# LearningApp — Evidence-Based Learning Science & Instructional Optimization Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Workstream:** `feature/arch-review-phase-0` (PR `#136`, kept strictly independent)
**Research Directory:** `/docs/learning_science/` · **Status:** Reconciled Root Specification (v2.3 — Final Merge-Ready Revision)

> **Supersession of Provisional `ARCHITECTURE_REVIEW.md` Details**:
> `/ARCHITECTURE_REVIEW.md` is retained at exact blob SHA `5fe779d3db382d03ad034dc03742409b9a6c1c7b` across branches as a historical point-in-time Phase 0 audit. Where `/ARCHITECTURE_REVIEW.md` contains provisional event-ledger or scheduler recommendations, **this plan and `/docs/learning_science/01..08` formally supersede them** (specifically: standardizing on `presented_option_ids: text[]` rather than `presented_order`, separating `fsrs_rating` from `learner_confidence` and restricting `fsrs_rating` to memory-review cards, standardizing on `scheduler_version = 'v2_fsrs6'` without manufacturing initial FSRS parameters from SM-2 counters or complexity priors, and keeping exam-date workload planning separate from FSRS memory stability/difficulty parameters).

---

## 1. Architectural Baseline: Implemented on `main` vs. Proposed Specifications

This plan builds on `main` (`e538585`) without assuming unmerged code from `feature/arch-review-phase-0` (PR `#136`). To prevent implementation defects, we explicitly separate **what is currently implemented on `main`** from **what is specified by this plan for phased implementation**:

### 1.1 Implemented & Active on `main` (`e538585`)
- **Curriculum Manifest & Provenance Infrastructure**: `content/schema/curriculum_manifest.schema.json` (which currently enforces `additionalProperties: false`, string-array `options`, and `scoring_spec.correct_index`), source citations, and manifest ingestion RPCs.
- **Learning Architecture V2 & Canonical Taxonomy v2.4**: Global `knowledge_concepts`, scoped curricula (`ResolvedScope`), `TargetVersion` visibility guards, and dual-layer taxonomy crosswalks.
- **`review_items` Scheduler**: Persistent spaced-repetition state (`scheduler_version = 'v1_sm2_ladder'`) using a simplified SM-2 interval ladder (`[1, 3, 7, 14, 30, 60, 120]`) and aggregate counters (`total_reviews`, `correct_reviews`, `repetition_level`, `ease_factor`).
- **`ConceptEvidenceService` & `user_concept_state`**: Concept-level evidence aggregation (currently using client-side select-then-upsert with `FOR ALL` owner RLS and an observation-count-based `confidence` heuristic: $\ge 2$ observations = `medium`, $\ge 5$ = `high`).
- **EXM-01..03 Architecture**: Reference manifest revisions (`EXM-01`), durable ungraded reference-navigation drill events (`EXM-02B` `exam_reference_drill_events`), and **assigned exam-part practice scoring (`EXM-03`)** across three migrations (`20261101130000_exm_03_assigned_practice_scoring.sql`, `20261101140000_exm_03_authenticated_assignment_issuer.sql`, and `20261101150000_exm_03_authenticated_submit_protected_items.sql`), which provide `exm03_issue_assigned_practice`, the authenticated session-bound wrapper `exm03_submit_assigned_practice`, and the restrictive `assessment_items` RLS policy `exm03_no_direct_read_of_approved_answers` for approved `EXM-02A` items (writing to `exam_part_practice_attempts` without updating `user_concept_state`).
- **ECO-00..04 & Literacy Foundations**: Moderation (`ECO-00B`), quotas (`ECO-00C`), concept Q&A (`ECO-01`), editorial review workflow (`ECO-02`), educator profiles (`ECO-04`), and the audio-first Literacy Hub (`LITERACY_ACCESSIBILITY_PLAN.md`).

### 1.2 Specified in This Plan (Not Yet Implemented on `main`)
- **`LearningTaskProfile`, `ContentComplexityProfile`, `InstructionalPolicy`, and `AssessmentPolicy`** (requires a versioned schema `2.1.0` update to `curriculum_manifest.schema.json` before use in manifests).
- **General Three-Representation Answer-Key Isolation (`FIX-12` Target)**: Extending answer-key-stripped Learner Presentation DTOs and server scoring RPCs beyond `EXM-02A`/`EXM-03` to all non-EXM diagnostic, mock exam, and adaptive practice items in **Phase 1** (on PR `#136`, `AssessmentItemRenderer` still scores client-side).
- **Universal Option Shuffling Completion (`FIX-1` Target — `PARTIALLY RESOLVED` in PR `#136`)**: Although PR `#136`'s description currently lists `FIX-1` as `RESOLVED`, its implementation at current PR head `e67a3d5` (re-verified after earlier snapshot `dc8f49f`) is **partial/incomplete** because it only shuffles inside `AssessmentItemRenderer` (`lib/widgets/assessment/assessment_item_renderer.dart`). Completing Phase 0 `FIX-1` across all routes requires three code fixes: (1) shuffling `widget.content.options` in legacy [`lib/widgets/question_widgets/mcq_question_widget.dart`](lib/widgets/question_widgets/mcq_question_widget.dart) / [`lib/widgets/mcq_options.dart`](lib/widgets/mcq_options.dart) and updating both legacy voice-input handlers ([`lib/widgets/lesson_content_renderer.dart`](lib/widgets/lesson_content_renderer.dart) and [`lib/widgets/content_renderers/question_content_renderer.dart`](lib/widgets/content_renderers/question_content_renderer.dart)) to use the display-to-original index mapping, (2) introducing or incrementing a raw per-presentation nonce (e.g. `_attemptNonce`) in `AdaptivePracticeScreen` (`lib/screens/assessment/adaptive_practice_screen.dart` currently only defines `_sessionNonce`, which is session-scoped) and passing it unchanged as `presentationSeed` without pre-XORing `item.id.hashCode`, and (3) **passing the raw per-presentation `attemptNonce` from `RichLessonReader` ([`lib/widgets/lesson/rich_lesson_reader.dart`](lib/widgets/lesson/rich_lesson_reader.dart)); `AssessmentItemRenderer` combines the nonce with `item.id.hashCode` exactly once** ([`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)).
- **General `public.learning_events` ledger and `record_events` RPC (Phase 1 `FIX-3`)**: Separate Phase 1 event-ledger work (not a Phase 0 `FIX-1` acceptance criterion) that persists canonical `presented_option_ids: text[]` with strict client-submitted vs. server-owned trust boundaries ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)).
- **Versioned FSRS-6 scheduler integration (`package:fsrs` v2.0.1, `v2_fsrs6`)**.
- **6-property decomposed content provenance** (`rights_review_required` for unverified imports) and separated **`complexity_assessment_status`**, **`item_psychometric_status`**, and **`readiness_validation_status`** tracking ([`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)).

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
- `reading_demand`: `{ word_count, reading_grade_estimate, lexical_rarity_tier }` *(Note per Tighe et al., 2026: it has not been empirically determined whether child-based grade equivalencies accurately describe adult reading ability; `reading_grade_estimate` describes **text passage linguistic demand**, never an adult learner's ability level)*
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

Full bibliographic citations, DOIs/URLs, subgroup sample sizes, 95% confidence intervals, heterogeneity ($I^2$), and study limitations are documented in [`docs/learning_science/01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md) and [`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md):

1. **Literacy & Phonics (`sublexical_orthographic`)**: Keep phonemic awareness, grapheme-phoneme mapping, decoding, spelling, and audio-first UI. **No universal 95% grapheme gate** (stages remain recommendations per `LITERACY_ACCESSIBILITY_PLAN.md`). Grounded in **Tighe, E. L., Greenberg, D., Feinberg, I., Ogrodnick, M. M., Sun, C. D., & Jarrard, C. (2026, September 2, Kentucky Reading Research Center report, `https://www.kyreadingresearch.org/wp-content/uploads/2026/10/Effective-Adult-Reading-Interventions.pdf`, 15 peer-reviewed studies, adults aged 16–76, excluding ESL-only studies)**: untimed decoding effects are most consistent ($d = .12\text{--}.46$), timed decoding gains are much smaller, fluency findings are generally positive but mixed, vocabulary/spelling/morphology/phonological evidence is limited, and comprehension varies by assessment (with some larger RCTs showing gains).
2. **Open-Book Navigation (`reference_navigation` / `EXM`)**: **No arbitrary 30/70 internalize/lookup split.** Aligns with `EXM_00` by independently measuring six competencies: *(1) Resource selection, (2) Section location, (3) Provision location, (4) Exception comprehension, (5) Provision application, and (6) Execution within the exam time budget.* Under-preparation/timeout causation is labeled as an `Implementation Hypothesis` rather than attributed to Durning et al. (2016).
3. **Concepts & Vocabulary (`verbal_terminology` & `conceptual_relational`)**: Supports six cognitive operations (*Define, Explain, Distinguish, Recognize examples/non-examples, Apply, Explain why correct*) without forcing three angles on every concept. Selective contrastive interleaving (**Ruitenburg, Goos, Lambert, Kirschner, Jarodzka, & Camp, 2026**, `DOI: 10.1007/s10648-026-10225-5`, overall $k = 53, N = 7,303$: retrieval $k = 31, n = 3,391, g = .37$ CI $[.18, .56], I^2 = 85.29\%$; spacing $k = 15, n = 2,010, g = .20$ CI $[.03, .36], I^2 = 73.18\%$; interleaving $k = 10, n = 1,902, g = .40$ CI $[.10, .71], I^2 = 73.52\%$, qualified for classroom populations).
4. **Calculations & Procedures (`procedural_quantitative`)**: Adaptive worked examples and backward fading grounded in **Tetzlaff, Simonsmeier, Peters, & Brod (2025, *Learning and Instruction*, `DOI: 10.1016/j.learninstruc.2025.102142`, $k = 60, N = 5,924$)**: high assistance benefits novices ($d = .505$, CI $[.260, .750]$, $I^2 = 90.87\%$) while impairing experienced learners ($d = -.428$, CI $[-.647, -.209]$). Separates prequestioning (**St. Hilaire, Chan, & Ahn, 2023/2024**, *Psychonomic Bulletin & Review*, 31, 411–441, `DOI: 10.3758/s13423-023-02353-8`: specific $g = .54$ CI $[.42, .66]$ vs. general $g = .04$ CI $[-.04, .11]$) from multi-signal diagnostic validity (`05_LEARNER_ADAPTATION.md`).
5. **Oral Production (`spoken_production`)**: Used where spoken output is required (e.g., USCIS civics interview). Separates transfer-appropriate processing (Morris et al., 1977) and the production effect (MacLeod et al., 2010 — recognition experiments) from spoken free-recall exam performance (marked `experimental` `Implementation Hypothesis`). Speech-onset time is never a mastery gate.
6. **Visual Classification (`perceptual_diagnostic`)**: Establishes classification accuracy before speed; no arbitrary latency threshold.
7. **Critical-Step Checklists (`procedural_execution`)**: Critical-fail gates are restricted strictly to steps designated as critical by an authoritative exam rubric or safety standard.

---

## 4. Separating Difficulty Constructs, Status Fields, FSRS-6 (`v2_fsrs6`), Concept Mastery & Exam Readiness

Detailed in [`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md) and [`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md):

1. **Content Complexity (`ContentComplexityProfile`) $\ne$ Psychometric Item Difficulty ($b_i$) $\ne$ Individual Memory State (FSRS-6 $S, D$)**:
   - **Cold-Start Complexity (`complexity_assessment_status`)**: `unassessed` | `deterministic_profile` | `expert_reviewed_profile`. Never presented as an empirical psychometric measurement level and never used to manufacture initial FSRS stability/difficulty parameters.
   - **Item Psychometric Status (`item_psychometric_status`)**: `unobserved` ($N=0$) $\to$ `observed_uncalibrated` ($N \ge 1$ observation-existence label only; a single response is not a meaningful difficulty estimate) $\to$ `preliminary_elo_ordering` (governed by a configurable LearningApp policy threshold **`elo_min_observations`** rather than a literature-derived constant; **inactive until selected and validated for the relevant item pool**; provides heuristic Elo ordering per Pelánek, 2016, `ER-09b`, qualified by **Bolsinova, Gergely, & Brinkhuis, 2026**, `DOI: 10.1111/bmsp.12395`, regarding joint adaptive bias, context-dependent variance, and non-convergence) $\to$ `calibrated` (statistical IRT parameters $a_i, b_i$; requires model-specific convergence diagnostics and an acceptable standard-error bound **`calibration_max_se`** validated for the item pool—marked `pending_validation` and inactive until established, as König, Spoden & Frey, 2020, `ER-09a`, provide `Grade C` simulation evidence across $N \in \{50, 75, 100, 150, 200, 500\}$, $25/50$ items, $100$ datasets/condition rather than a universal real-world $\text{SE}$ rule).
   - **Readiness Model Validation Status (`readiness_validation_status`)**: `unvalidated` $\to$ `pilot_observed` $\to$ `validated_for_intended_use`.
2. **FSRS-6 Card Retrievability $\ne$ Concept Evidence $\ne$ Reference-Navigation Evidence $\ne$ Exam Readiness**:
   - **FSRS-6 (`package:fsrs` v2.0.1 Technical Implementation Reference `ER-09c`, `scheduler_version = 'v2_fsrs6'`)** estimates memory retrievability $R(t)$ for a *specific memory-review card* using card recall ratings (`Again`, `Hard`, `Good`, `Easy`). Because existing `review_items` rows store only aggregate counters, items migrate to `'v2_fsrs6'` forward from their next memory review.
   - **Concept Evidence (`user_concept_state`)** is a server-maintained projection (with direct client DML revoked) updated by `record_events` (while `EXM-03` writes to `exam_part_practice_attempts` without mutating `user_concept_state`).
   - **Reference-Navigation Evidence (`EXM-02B`)** evaluates open-book lookup accuracy and timing across `R1–R4`.
   - **Examination Readiness** evaluates authoritative blueprint coverage, delayed retention, transfer to held-out unfamiliar items, and execution under actual exam conditions (**open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 5. Decomposed Provenance, Answer-Key Isolation (`FIX-12`) & Event Trust Boundary

1. **Six Orthogonal Provenance Properties ([`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md))**:
   - **`origin`** (`official_source`, `curated_editorial`, `community_contribution`, `user_import`, `ai_generated`)
   - **`visibility`** (`private`, `shared_unlisted`, `public_catalog`)
   - **`rights_status`** (`verified_permissive_or_public_domain`, `licensed_embed_or_link`, `rights_review_required`, `restricted_or_unknown`)
   - **`review_status`** (`unreviewed`, `automated_checks_passed`, `editorially_reviewed`, `authoritatively_verified`)
   - **`source_authority`** (`primary_regulator_or_statute`, `accredited_publisher_or_standard`, `secondary_educational`, `user_supplied_unverified`)
   - **`version_validity`** (`{ effective_from, effective_to, superseded_by_version_id, status }`)
2. **Server-Owned vs. Client-Submitted Event Fields ([`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md))**:
   - In the proposed `public.learning_events` and `record_events` contract, `user_id`, `received_at`, `content_version`, `task_profile`, `scored_outcome`, `scheduler_version`, `scheduler_state_before/after`, `provenance_snapshot` (all 6 properties), and `assessment_conditions` are **server-owned/derived**.
   - `presented_option_ids` (`text[]`) is treated as **trusted audit order (`server_issued`) only when bound to a server-issued presentation/attempt record**, and otherwise labeled **`untrusted_client_reported` metadata**.
   - `client_latency_ms` is explicitly labeled **untrusted client-reported timing**, whereas **`server_elapsed_ms`** (computed from a server-issued attempt start timestamp) is required for all timing-critical or high-stakes assessment decisions.

---

## 6. Research Directory Index

| Document | Scope |
|---|---|
| **[`docs/learning_science/README.md`](docs/learning_science/README.md)** | Research governance, `ARCHITECTURE_REVIEW.md` supersession note, and reconciliation with legacy `LEARNING_UI_RESEARCH.md` |
| **[`01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md)** | Research and technical evidence register (`ER-01`–`ER-10`) with full authors, DOIs/URLs, subgroup samples, 95% CIs, heterogeneity ($I^2$), Grade C simulation details, and technical references |
| **[`02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md)** | Canonical `LearningTaskProfile`, `ContentComplexityProfile` (with adult reading demand guardrail), `InstructionalPolicy`, and `AssessmentPolicy` |
| **[`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)** | Strategy selection rules, moderators, Phase 0 `FIX-1` per-attempt shuffling contract + exact legacy file/voice paths (verified at `e67a3d5`), and separate Phase 1 `presented_option_ids` event-ledger handoff (`FIX-3`) |
| **[`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md)** | Delivery rules across all 7 task approaches |
| **[`05_LEARNER_ADAPTATION.md`](docs/learning_science/05_LEARNER_ADAPTATION.md)** | Prequestioning (`ER-10`) vs. multi-signal diagnostic validity, and adaptive scaffolding (`ER-05`) |
| **[`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)** | Client vs. server trust boundary (`presented_option_ids`, `server_elapsed_ms`), 3-migration `EXM-03` surface, `user_concept_state` projection, and `v2_fsrs6` rules |
| **[`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)** | 6-property provenance, separated `complexity_assessment_status` vs. `item_psychometric_status` vs. `readiness_validation_status`, and all 7 proving grounds |
| **[`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md)** | 6-stage ingestion pipeline, accurate `EXM-03` vs. Phase 1 `FIX-12` status, and proposed versioned `curriculum_manifest.schema.json` `2.1.0` extensions |
