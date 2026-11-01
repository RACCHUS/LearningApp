# 05 — Learner Adaptation, Prior Knowledge & Scaffolding

This specification defines how LearningApp adapts instruction, scaffolding, and practice selection to an individual learner's prior knowledge and ongoing performance without violating the Direct Access Rule (`UI_ARCHITECTURE_LOCKED.md`).

---

## 1. Avoiding the Expertise Reversal Effect (`ER-05`)

Instructional guidance that is essential for a novice (such as step-by-step worked examples or phonetic segmentation scaffolds) becomes extraneous cognitive load for a learner who already possesses the underlying schema.

LearningApp resolves this through **Bidirectional Adaptive Scaffolding**:

```text
[Diagnostic or Unassisted Challenge]
        │
        ├── Correct (Confident & Accurate) ──► Bypass worked examples; schedule spaced retrieval / transfer
        │
        └── Incorrect or "Show Step Hint"  ──► Activate targeted scaffolding (Worked Example -> Faded Step -> Unassisted)
```

### Scaffolding Levels
1. **`unassisted_execution`**: Full exam-like or target-task execution with no hints.
2. **`minimal_cue_scaffold`**: Formula reminder, first-word prompt, or reference manual part hint.
3. **`backward_faded_step`**: Final step or intermediate + final steps open for completion while prior steps are shown.
4. **`full_worked_example`**: Complete worked demonstration with a single self-explanation prompt (*"Why does this step apply here?"*).

---

## 2. Diagnostic Pretesting Without Fabricated Questions

1. **Pretesting Principle (`ER-02`, `ER-05`)**:
   - Offering an optional diagnostic pretest before a module serves two functions: it calibrates initial scaffolding depth for experienced learners, and—even when a novice answers incorrectly—pretesting primes attention for subsequent instruction.
2. **Honesty Invariant**:
   - Consistent with `UI_ARCHITECTURE_LOCKED.md`, diagnostics only run when mapped assessment items actually exist for the target scope; the engine never fabricates placeholder diagnostic claims.

---

## 3. Prerequisite-Aware Remediation Using the Concept Graph

When a learner repeatedly fails an item mapped to concept $C_{\text{target}}$:
1. Check `concept_relations` (`prerequisite_of` edges into $C_{\text{target}}$).
2. If a prerequisite concept $C_{\text{prereq}}$ has `unobserved` or low retrieval evidence in `user_concept_state`, surface a **Recommended Prerequisite Brush-Up** chip rather than endlessly repeating the downstream item.
3. Preserve learner agency: the prerequisite brush-up is a clear recommendation, never a forced progression lock.
