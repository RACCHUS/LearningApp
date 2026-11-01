# 04 — Task-Specific Delivery Specifications

This document defines the concrete instructional and assessment delivery rules for the seven core task domains in LearningApp, incorporating all corrections from the architectural and scientific review.

---

## 1. Adult Literacy, Phonics & Emergent Reading (`sublexical_orthographic`)

1. **Recommendations, Never Hard Progression Locks**:
   - Consistent with `LITERACY_ACCESSIBILITY_PLAN.md` and the Direct Access Rule, phonics/decoding stages guide recommended next actions without locking learners out of functional survival words (`survival_word_item.dart`), decodable stories, or civic preparation.
   - **No universal 95% grapheme gate** is enforced.
2. **Adult-Specific Evidence Alignment**:
   - Adult emergent readers bring mature spoken/world concepts alongside specific decoding gaps (`ER-06`). Instruction pairs sub-lexical grapheme-phoneme mapping (blending, segmenting, minimal-pair discrimination, letter tracing) directly with high-utility adult vocabulary (workplace safety, signage, forms, currency, health).
3. **Zero-Text-Assumption Chrome & Web Semantics**:
   - Audio instructions and spoken stems play automatically or via clear icon controls, and `SemanticsBinding.instance.ensureSemantics()` is enabled on web startup (`FIX-6`) so screen readers and assistive tools function immediately.

---

## 2. Open-Book Reference & Licensing Examinations (`reference_navigation` / `EXM`)

Aligned with `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md` and `ER-07`, LearningApp does **not** impose an arbitrary "30% memorize / 70% lookup" split. Instead, it trains and independently tracks **six open-book competencies**:

1. **Resource Selection (`R1`)**: Identifying which authoritative manual, statute chapter, or code book governs the problem.
2. **Section Navigation (`R2`)**: Using the index, table of contents, or part hierarchy to reach the governing chapter/article.
3. **Provision Location (`R3`)**: Pinpointing the exact clause, table row/column, or formula.
4. **Exception & Footnote Comprehension (`R4`)**: Identifying statutory exceptions, notes, or conditional overrides that modify the base rule.
5. **Provision Application**: Applying the located rule or table value (including any required calculation) to the scenario stem.
6. **Paced Execution**: Completing the end-to-end lookup and application within the exam part's real per-item time budget.

**Separation of Evidence**: Domain concept knowledge (`user_concept_state`) and reference-navigation fluency (`exam_reference_drill_events` / `EXM-02B`) remain explicitly separate in readiness reporting.

---

## 3. Concepts, Terminology & Domain Rules (`verbal_terminology` & `conceptual_relational`)

Because memorizing a definition is not equivalent to understanding a concept, the delivery engine supports six cognitive operations—applied selectively according to the concept's role in the curriculum rather than forcing a rigid 3-angle quota on every concept:

1. **Define / Identify**: Recall the term or core definition.
2. **Explain**: Describe how the mechanism or rule works.
3. **Distinguish from Confusable Neighbors**: When a concept belongs to a `confusable_group_id`, deliver contrastive questions that force discrimination along the exact boundary attribute.
4. **Recognize Examples & Non-Examples**: Classify concrete cases.
5. **Apply to Novel Scenarios**: Solve unfamiliar cases where textbook phrasing is absent.
6. **Explain Why Correct**: Identify the governing rationale or why a tempting distractor is invalid.

---

## 4. Calculations & Multi-Step Procedures (`procedural_quantitative`)

1. **Adaptive Worked-Example Fading (Not Fixed 4-Stage Lockstep)**:
   - Supports full worked examples, partially faded steps, and unassisted parameterized problems (`ER-04`, `ER-05`).
   - Learners with low prior competence on the concept start with worked examples and backward step fading; learners who pass initial diagnostic or unassisted items skip directly to unassisted practice.
   - If a learner fails an unassisted calculation, the remediation loop steps down to the faded step where the error occurred (formula selection vs. substitution vs. unit conversion).
2. **Parameterized Values & Unit Verification**:
   - Calculation templates vary numerical inputs across attempts so learners cannot memorize a static answer key, and validate both numeric tolerance and measurement units.

---

## 5. Oral Production & Spoken Interviews (`spoken_production`)

1. **Transfer-Appropriate Practice for Oral Exams**:
   - Where the real assessment is oral (e.g., USCIS 128-question 2025 Civics Test and Form N-400 interview), practice transitions from audio-assisted recognition to **acoustic prompt + spoken/free-recall response** matched against official `acceptableAnswers[]` (`ER-08`).
2. **Non-Punitive Response Timing**:
   - Speech-onset latency is **never** used as a universal mastery gate, ensuring fair evaluation for ESL learners, older adults, and users with speech differences.

---

## 6. Visual & Perceptual Classification (`perceptual_diagnostic`)

1. **Accuracy Before Fluency**:
   - For road signs (DMV), schematic symbols, and hazard recognition, learners first establish classification accuracy without time pressure, using side-by-side visual comparisons of commonly confused signs/symbols.
   - Optional paced fluency drills are offered only after baseline accuracy is established, with **no universal 200ms or 3.5s hard gate**.

---

## 7. Practical & Safety Critical-Step Checklists (`procedural_execution`)

1. **Authoritative Grounding of Critical Failures**:
   - Checklist items train step ordering and completeness for practical trade, clinical, and workplace safety procedures.
   - A step may only be enforced as an automatic `critical_fail` gate when its `content_provenance` cites an authoritative exam rubric or regulatory safety standard that designates that step as critical.
