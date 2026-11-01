# 05 — Learner Adaptation, Diagnostic Pretesting & Adaptive Scaffolding

This specification defines how LearningApp adapts instruction and scaffolding to prior knowledge using evidence from the 2023 Prequestioning Meta-Analysis (`ER-10`) and the 2025 Expertise Reversal Meta-Analysis (`ER-05`).

---

## 1. Diagnostic Pretesting: Specific Routing, Not Universal Transfer (`ER-10`)

The 2023 prequestioning meta-analysis demonstrates a strong positive effect on the **specific material pretested ($g = 0.54$)**, but a near-zero effect on **untested material in the same lesson ($g = 0.04$)**.

### Design Rules for Diagnostic Pretesting
1. **Objective-Specific Routing**:
   - Diagnostic pretests are used to measure baseline competence on the specific `knowledge_concepts` tested by the diagnostic items and to prime attention on those exact objectives.
   - Passing a diagnostic item for Concept $A$ allows the learner to bypass introductory scaffolding on Concept $A$, but **never** skips instruction or scaffolding on untested Concept $B$.
2. **Honesty Invariant**:
   - Consistent with `UI_ARCHITECTURE_LOCKED.md`, diagnostics only run when mapped items exist for the target concepts.

---

## 2. Adaptive Scaffolding & Expertise Reversal Prevention (`ER-05`)

The 2025 meta-analysis ($k = 60$ studies, $N = 5,924$) shows that high instructional assistance benefits novices ($d = 0.505$) while low assistance benefits experienced learners ($d = -0.428$), with substantial heterogeneity across tasks.

### Adaptive Scaffolding Controller (`InstructionalPolicy.scaffolding_policy`)
1. **Initial Routing**:
   - If `user_concept_state` has no prior observations (or low accuracy), `procedural_quantitative` tasks start with high assistance (worked example + backward fading).
   - If the learner passes the concept's diagnostic pretest or selects a direct unassisted challenge, scaffolding is bypassed immediately.
2. **Dynamic Adjustment (Tunable Heuristic — `Implementation Hypothesis`)**:
   - Because the 2025 meta-analysis exhibits substantial heterogeneity, specific step-up/step-down rules (such as promoting to unassisted practice after consecutive correct responses or stepping back to a faded step after an error or hint request) are implemented as **configurable policy parameters** rather than claimed as universal psychological constants, and are evaluated empirically in Phase 6/7.

---

## 3. Prerequisite-Aware Remediation

When a learner errs repeatedly on a task with `ContentComplexityProfile.prerequisite_depth > 0`:
1. Inspect incoming `prerequisite_of` edges in `concept_relations`.
2. Surface a non-blocking recommendation to review any prerequisite concept with weak or unobserved evidence in `user_concept_state`, preserving the Direct Access Rule.
