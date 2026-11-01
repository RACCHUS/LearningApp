# 03 — Instructional Strategies, Option Shuffling & Moderator Rules

This specification defines how the adaptive delivery engine selects strategies from `InstructionalPolicy.eligible_strategies[]` ([`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md)) and specifies the reconciled option-shuffling contract (`FIX-1`).

---

## 1. Strategy Selection & Moderator Guardrails (`ER-01`–`ER-05`)

| Strategy ID | Evidence Basis | Activated When | Moderator Suppression Rule |
|---|---|---|---|
| `active_retrieval_first` | `ER-01` ($g = 0.37$), `ER-03` | Default on retention reviews and concept/fact practice | Suppressed on first exposure to an unfamiliar multi-step `procedural_quantitative` task where worked examples are needed first (`ER-05`) |
| `contrastive_interleaving` | `ER-01` ($g = 0.40$), `ER-04` | `ContentComplexityProfile.confusable_density == high_confusable_group` or problem-type discrimination | Suppressed when concepts have no confusable boundary (`confusable_density == none`) |
| `worked_example_backward_fading` | `ER-05` (Novice benefit $d = 0.505$; Expert reversal $d = -0.428$) | `knowledge_facet == procedural_quantitative` AND learner diagnostic/prior state indicates novice or recent error | Suppressed when learner demonstrates competence on diagnostic pretest or unassisted execution |
| `elaborative_rationale_feedback` | `ER-03` (Butler, 2010) | `feedback_policy == immediate_explanatory` on conceptual/application items | Deferred during `timing_regime == exam_clock_enforced` until exam part submission |
| `reference_foraging_decomposition` | `ER-07`, `EXM_00` | `reference_policy == open_book_manifest` | Closed-book tasks |
| `multimodal_audio_orthographic` | `ER-06` | `knowledge_facet == sublexical_orthographic` or audio-first accessibility mode | Learner selects silent reading mode |

---

## 2. Reconciled Option Shuffling & Presentation Persistence Contract (`FIX-1`)

To eliminate positional answer cues across all structured-choice items (USCIS, DMV, GED, lesson MCQs, and `AssessmentItemRenderer`) while maintaining full compatibility with Antigravity's PR `#136` implementation:

1. **Universal Shuffling Default**:
   - **Every** `structured_choice` (`singleChoice` and `multiSelect`) item shuffles its non-anchor options by default (`shuffleOptions = true`), not merely items where `correct_index == 0` or where LLM B/C bias is suspected.
   - Anchor options (e.g., legacy items containing `"none of the above"` or `"all of the above"`, where still present in imported material) remain pinned at the bottom while all preceding options shuffle.
2. **In-Session Seed Stability (Coordinated with PR `#136`)**:
   - Within a live widget lifecycle, `AssessmentItemRenderer` derives a deterministic PRNG seed from the session/presentation nonce combined with the item identifier (`presentationSeed ^ item.id.hashCode`), ensuring that UI rebuilds or theme changes never reshuffle options mid-attempt.
3. **Cross-Restart Persistence Invariant (Why Hash Recomputation Is Not Used for History)**:
   - Dart's `Object.hash` and `String.hashCode` are randomized per isolate/process execution and are **not guaranteed to produce the same integer across app restarts** ([Dart `Object.hash` API docs](https://api.dart.dev/stable/dart-core/Object/hash.html)).
   - Therefore, audit and event records (`public.learning_events`) **must persist the actual presented option order (`presented_option_ids` / `presentation_order: List<int>`)** generated at presentation time rather than attempting to reconstruct option order later from a seed.
