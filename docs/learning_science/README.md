# LearningApp — Learning Science Research Governance & Standards (`/docs/learning_science/`)

**Master Root Plan:** [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](../../EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md)
**Authoritative Baseline:** `main` (`e538585`)

---

## 1. Purpose & Governance Rules

This directory governs the scientific foundations, task taxonomy, instructional delivery rules, and measurement architecture of LearningApp.

To prevent informal folk-pedagogy or secondary summaries (such as Wikipedia references in earlier UI notes like `docs/design/LEARNING_UI_RESEARCH.md`) from becoming rigid application rules, **no instructional rule, gate, or psychometric assumption may be hard-coded into the learning engine unless it is registered in [`01_EVIDENCE_REGISTER.md`](01_EVIDENCE_REGISTER.md) with its full evidentiary profile.**

### Mandatory Fields for Every Research Claim in `01_EVIDENCE_REGISTER.md`
1. **Citation & Identifier**: Exact primary publication, authors, year, journal/institution, and DOI or official URL.
2. **Methodology**: Meta-analysis, randomized controlled trial (RCT), quasi-experimental study, longitudinal cohort, or psychometric simulation.
3. **Population Studied**: K–12, university undergraduates, adult vocational/licensing candidates, or adult emergent readers/ESL.
4. **Sample Size ($N$)**: Number of studies ($k$) and total participants ($N$).
5. **Measured Outcome**: Immediate recall, delayed retention, far transfer, lookup fluency, or exam pass rate.
6. **Effect Size**: Standardized effect size ($d$, $g$, $r$, odds ratio) and confidence interval where published.
7. **Limitations & Moderators**: Boundary conditions, populations where the effect weakens or reverses (including **null, mixed, or negative findings**).
8. **Applicability to LearningApp**: Which `LearningTaskProfile` dimensions the finding governs.
9. **Recommended Implementation**: How the engine configures instruction, scaffolding, or scheduling (distinguishing *default recommendations* from *hard gates*).
10. **Verification & Test Plan**: How we test that the implementation works as intended in LearningApp.

---

## 2. Supersession of Provisional `ARCHITECTURE_REVIEW.md` Details & Legacy UI Research

### 2.1 Supersession of Provisional Event-Ledger & Scheduler Sketches in `/ARCHITECTURE_REVIEW.md`
`/ARCHITECTURE_REVIEW.md` is preserved at exact blob SHA `5fe779d3db382d03ad034dc03742409b9a6c1c7b` as a historical point-in-time Phase 0 audit across branches. Where `/ARCHITECTURE_REVIEW.md` contains provisional event-ledger or FSRS-6 migration recommendations, **`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md` and `/docs/learning_science/01..08` formally supersede them**:
- **`presented_option_ids: text[]`** supersedes `presented_order` (`List<int>`), and is treated as authoritative display order only when bound to a server-issued presentation/attempt record (`06_MEASUREMENT_AND_SCHEDULING.md`).
- **`fsrs_rating`** (`1..4`, restricted strictly to `memory_card_review` events) is kept separate from **`learner_confidence`** (`1..3` metacognitive self-report) and `user_concept_state.confidence` (observation-count sufficiency band).
- **FSRS-6 (`scheduler_version = 'v2_fsrs6'`)** estimates individual card retrievability $R(t)$ only—it is never equated with concept mastery or exam readiness, never initialized by fabricating parameters from SM-2 counters or `ContentComplexityProfile` priors, and kept separate from exam-date workload planning.

### 2.2 Reconciliation with Legacy `docs/design/LEARNING_UI_RESEARCH.md`
Earlier UI research (`docs/design/LEARNING_UI_RESEARCH.md`) synthesized useful general ideas but stated several claims more definitively than primary evidence supports. The following corrections apply across the codebase:

- **Fixed Pomodoro Intervals**: Structured breaks can reduce subjective fatigue (Biwer et al., 2023), but fixed 25/5 timers are **optional learner tools**, never mandatory session locks that interrupt an active retrieval or open-book simulation flow.
- **Universal Microlearning Claims**: Breaking complex material into manageable segments reduces extraneous load, but complex open-book scenarios and multi-step calculations require sustained problem-solving windows.
- **Immediate vs. Delayed Feedback**: Immediate corrective feedback helps during initial acquisition and error correction, whereas delayed feedback can benefit transfer in certain advanced retrieval tasks. Feedback timing is configured per `LearningTaskProfile` rather than globally locked.
- **Universal 95% Grapheme Gate (Removed)**: In alignment with `LITERACY_ACCESSIBILITY_PLAN.md`, literacy stages remain **recommendations, not hard locks** (Direct Access Rule).

---

## 3. Directory Map

| File | Responsibility |
|---|---|
| **[`01_EVIDENCE_REGISTER.md`](01_EVIDENCE_REGISTER.md)** | Research and technical evidence register (`ER-01`–`ER-10`): peer-reviewed studies, research synthesis reports, Monte Carlo simulation evidence (`Grade C`), and technical implementation references |
| **[`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md)** | Multidimensional `LearningTaskProfile` specification replacing mutually exclusive modalities |
| **[`03_INSTRUCTIONAL_STRATEGIES.md`](03_INSTRUCTIONAL_STRATEGIES.md)** | Retrieval practice, spacing, interleaving, worked examples, feedback timing, and `FIX-1` option-shuffling rules |
| **[`04_TASK_SPECIFIC_DELIVERY.md`](04_TASK_SPECIFIC_DELIVERY.md)** | Delivery rules for literacy, open-book exams (`EXM`), concepts/vocabulary, calculations, oral production, visual classification, and critical-step checklists |
| **[`05_LEARNER_ADAPTATION.md`](05_LEARNER_ADAPTATION.md)** | Prior-knowledge diagnostics, adaptive scaffolding, and preventing the Expertise Reversal Effect |
| **[`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md)** | Client vs. server trust boundary for `learning_events`, `user_concept_state` projection, `EXM-03` surface, and versioned `v2_fsrs6` scheduling |
| **[`07_READINESS_AND_VALIDATION.md`](07_READINESS_AND_VALIDATION.md)** | 6-property provenance, separated `complexity_assessment_status` vs. `item_psychometric_status` vs. `readiness_validation_status`, and all 7 proving grounds |
| **[`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](08_CONTENT_AND_IMPORT_ALIGNMENT.md)** | 6-stage ingestion pipeline, accurate `FIX-12` Phase 1 status, and proposed versioned `curriculum_manifest.schema.json` `2.1.0` extensions |
