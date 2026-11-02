# 05 — Learner Adaptation, Prequestioning vs. Diagnostic Validity & Adaptive Scaffolding

This specification defines how LearningApp distinguishes **prequestioning as a learning intervention** from **diagnostic prior-knowledge assessment**, and how it adapts instructional scaffolding (`ER-05`, `ER-10`).

---

## 1. Distinguishing Prequestioning from Diagnostic-Test Validity (`ER-10`)

Two distinct mechanisms must not be conflated:

### 1.1 Prequestioning as a Learning Intervention (`Direct Empirical Support` — St. Hilaire, Chan & Ahn, 2023/2024)
- Asking a learner a question *before* they study the target material significantly improves subsequent learning of **that specific prequestioned material ($g = .54$, 95% CI $[.42, .66]$, $k = 97$)**, even when the learner's initial guess is wrong.
- However, prequestioning has virtually **no general transfer effect on untested material in the same lesson ($g = .04$, 95% CI $[-.04, .11]$, $k = 91$)**.
- **Design Rule**: Optional pre-lesson prequestions are used to prime attention on the specific core concepts they ask about, never to claim broad enhancement of untested content.

### 1.2 Diagnostic Assessment for Skipping Scaffolding (`Implementation Hypothesis` — Requires Multi-Signal Evidence)
- St. Hilaire et al. (2023/2024) do **not** establish that answering a single prequestion correctly is a psychometrically valid measure of prior competence.
- A single 4-option multiple-choice item has a $25\%$ random guessing probability. Allowing a learner to automatically bypass instruction or scaffolding on Concept $A$ based on a single lucky MCQ guess risks leaving knowledge gaps unaddressed.
- **Design Rule**:
  1. **Direct Access Preserved**: Learners may always manually choose to jump straight to practice or unassisted problems (`UI_ARCHITECTURE_LOCKED.md`).
  2. **Automated Scaffolding Bypass Requires Stronger Evidence (`Implementation Hypothesis`)**: Automatically routing a learner past introductory worked examples on Concept $A$ requires stronger evidence than a single MCQ hit—such as passing an uncued/numeric/free-recall check, demonstrating competence across multiple items/facets of Concept $A$ with high confidence and low latency, or holding established `user_concept_state` stability from a cross-target concept match. The exact bypass threshold is treated as an `Implementation Hypothesis` to be calibrated in Phase 1 (`ARCH-1`).

---

## 2. Adaptive Scaffolding & Expertise Reversal Prevention (`ER-05`)

Tetzlaff et al. (2025, *Learning and Instruction*, $k = 60$, $N = 5,924$) demonstrate that high assistance benefits novices ($d = .505$, 95% CI $[.260, .750]$, $I^2 = 90.87\%$) while low assistance benefits experienced learners ($d = -.428$, 95% CI $[-.647, -.209]$, $I^2 = 87.55\%$).

### Adaptive Scaffolding Controller (`InstructionalPolicy.scaffolding_policy`)
1. **Novice / Unobserved State**:
   - Starts `procedural_quantitative` tasks with high instructional assistance (worked example + backward step fading) unless the learner explicitly selects unassisted practice or satisfies the multi-signal competence check above.
2. **Dynamic Fading & Remediation (`Implementation Hypothesis`)**:
   - Because of the high heterogeneity across both novice ($I^2 = 90.87\%$) and experienced ($I^2 = 87.55\%$) subgroups, step-up and step-down rules (fading assistance as unassisted steps succeed; re-introducing step guidance when an error or hint occurs) are implemented as configurable policy parameters rather than fixed universal constants.

---

## 3. Prerequisite-Aware Remediation

When a learner errs repeatedly on a task with `ContentComplexityProfile.prerequisite_depth > 0`:
1. Inspect incoming `prerequisite_of` edges in `concept_relations`.
2. Surface a non-blocking recommendation to review any prerequisite concept with weak or unobserved evidence in `user_concept_state`, preserving the Direct Access Rule.
