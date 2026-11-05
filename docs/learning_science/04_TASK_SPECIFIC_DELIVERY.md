# 04 — Task-Specific Delivery Specifications

This document defines the concrete instructional and assessment delivery rules for the seven core task domains in LearningApp, incorporating all corrections from the architectural and scientific review.

---

## 1. Adult Literacy, Phonics & Emergent Reading (`sublexical_orthographic`)

1. **Recommendations, Never Hard Progression Locks**:
   - Consistent with `LITERACY_ACCESSIBILITY_PLAN.md` and the Direct Access Rule, phonics/decoding stages guide recommended next actions without locking learners out of functional survival words (`survival_word_item.dart`), decodable stories, or civic preparation.
   - **No universal 95% grapheme gate** is enforced.
2. **Adult-Specific Evidence Alignment (`ER-06`, Tighe et al., 2026)**:
   - **Empirical Finding (`Direct Empirical Support`)**: Tighe et al. (2026, September 2; 15 studies of adults aged 16–76, excluding ESL-only studies) report consistent adult gains on **untimed decoding ($d = .12\text{--}.46$)**, much smaller gains on **timed decoding assessments**, **generally positive but mixed** findings for **fluency**, **limited** evidence for **vocabulary, spelling, morphology, and phonological skills**, and **comprehension outcomes that varied by assessment** (with some larger RCTs showing gains).
   - **LearningApp Product & Accessibility Policy (`Implementation Policy`)**: Tighe et al. (2026) show smaller intervention transfer to timed decoding measures rather than proving that all timed practice is harmful. Informed by those smaller timed-decoding gains and the adult accessibility goals in `LITERACY_ACCESSIBILITY_PLAN.md`, LearningApp sets core adult decoding mastery drills to `timing_regime = untimed_mastery` (never gating mastery progression on speed timers), while keeping **optional, learner-initiated fluency practice** available without speed penalties. In addition, because **it has not been empirically determined whether child-based reading-grade equivalencies accurately describe adult reading ability**, `reading_grade_estimate` is used strictly to describe **text passage complexity**, never to assign a child grade-level label to an adult learner.
3. **Zero-Text-Assumption Chrome & Web Semantics**:
   - Audio instructions and spoken stems play automatically or via clear icon controls, and `SemanticsBinding.instance.ensureSemantics()` is enabled on web startup (`FIX-6`) so screen readers function immediately.

---

## 2. Open-Book Reference & Licensing Examinations (`reference_navigation` / `EXM`)

Aligned with `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md` and `ER-07`, LearningApp does **not** impose an arbitrary "30% memorize / 70% lookup" split. Instead, it trains and independently tracks **six open-book competencies**:

1. **Resource Selection (`R1`)**: Identifying which authoritative manual, statute chapter, or code book governs the problem.
2. **Section Navigation (`R2`)**: Using the index, table of contents, or part hierarchy to reach the governing chapter/article.
3. **Provision Location (`R3`)**: Pinpointing the exact clause, table row/column, or formula.
4. **Exception & Footnote Comprehension (`R4`)**: Identifying statutory exceptions, notes, or conditional overrides that modify the base rule.
5. **Provision Application**: Applying the located rule or table value (including any required calculation) to the scenario stem.
6. **Paced Execution**: Completing the end-to-end lookup and application within the exam part's real per-item time budget.

**Separation of Evidence**: Domain concept knowledge (`user_concept_state`), reference-navigation fluency (`exam_reference_drill_events` / `EXM-02B`), and FSRS card recall remain explicitly separate—slow lookup time is recorded as reference-navigation telemetry, never converted into a false FSRS memory lapse (`06_MEASUREMENT_AND_SCHEDULING.md`).

---

## 3. Concepts, Terminology & Domain Rules (`verbal_terminology` & `conceptual_relational`)

Because memorizing a definition is not equivalent to understanding a concept, the delivery engine supports six cognitive operations—applied selectively according to the concept's role in the curriculum rather than forcing a rigid 3-angle quota on every concept:

1. **Define / Identify**: Recall the term or core definition.
2. **Explain**: Describe how the mechanism or rule works.
3. **Distinguish from Confusable Neighbors**: When a concept belongs to a `confusable_group_id`, deliver contrastive questions (`ER-01` interleaving $g = .40$, CI $[.10, .71]$, $I^2_{\text{total}} = 73.52\%$, $I^2_{\text{within}} = 3.70\%$, $I^2_{\text{between}} = 69.82\%$) that force discrimination along the exact boundary attribute.
4. **Recognize Examples & Non-Examples**: Classify concrete cases.
5. **Apply to Novel Scenarios**: Solve unfamiliar cases where textbook phrasing is absent (`ER-03`).
6. **Explain Why Correct**: Identify the governing rationale or why a tempting distractor is invalid.

---

## 4. Calculations & Multi-Step Procedures (`procedural_quantitative`)

1. **Adaptive Worked-Example Fading (`ER-05`, Tetzlaff et al., 2025)**:
   - Supports full worked examples, partially faded steps, and unassisted parameterized problems.
   - Novices benefit significantly from high assistance ($d = .505$, CI $[.260, .750]$, $I^2 = 90.87\%$), while experienced learners are harmed by redundant guidance ($d = -.428$, CI $[-.647, -.209]$, $I^2 = 87.55\%$).
   - If a learner fails an unassisted calculation, the remediation loop steps down to the faded step where the error occurred (formula selection vs. substitution vs. unit conversion).
2. **Parameterized Values & Unit Verification**:
   - Calculation templates vary numerical inputs across attempts so learners cannot memorize a static answer key, and validate both numeric tolerance and measurement units.

---

## 5. Oral Production & Spoken Interviews (`spoken_production`)

1. **Experimental Spoken Free-Recall Practice (`ER-08`)**:
   - Where the target assessment is oral (e.g., USCIS 128-question 2025 Civics Test and Form N-400 interview), practice transitions from audio-assisted recognition to **acoustic prompt + spoken/free-recall response** matched against official `acceptableAnswers[]`.
   - Because Morris et al. (1977) and MacLeod et al. (2010) studied recognition rather than spoken free-recall exam performance, this workflow carries `experimental` maturity status and will be validated empirically in Phase 1 (`07_READINESS_AND_VALIDATION.md`).
2. **Non-Punitive Response Timing**:
   - Speech-onset latency is **never** used as a mastery gate.

---

## 6. Visual & Perceptual Classification (`perceptual_diagnostic`)

1. **Accuracy Before Fluency**:
   - For road signs (DMV), schematic symbols, and hazard recognition, learners first establish classification accuracy without time pressure, using side-by-side visual comparisons of commonly confused signs/symbols.
   - Optional paced fluency drills are offered only after baseline accuracy is established, with **no universal latency gate**.

---

## 7. Practical & Safety Critical-Step Checklists (`procedural_execution`)

1. **Authoritative Grounding of Critical Failures**:
   - Checklist items train step ordering and completeness for practical trade, clinical, and workplace safety procedures.
   - A step may only be enforced as an automatic `authoritative_critical_step_gate` when its provenance cites an authoritative exam rubric or regulatory safety standard that designates that step as critical.
