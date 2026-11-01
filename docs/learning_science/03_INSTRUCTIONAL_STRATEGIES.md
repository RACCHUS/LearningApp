# 03 — Instructional Strategies, Option Shuffling (`FIX-1`) & Moderator Rules

This specification defines how the adaptive delivery engine selects strategies from `InstructionalPolicy.eligible_strategies[]` ([`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md)) and specifies the exact contract and remaining implementation gaps for universal option shuffling (`FIX-1`).

---

## 1. Strategy Selection & Moderator Guardrails (`ER-01`–`ER-05`)

| Strategy ID | Evidence Basis | Activated When | Moderator Suppression Rule |
|---|---|---|---|
| `active_retrieval_first` | `ER-01` ($g = .37$, 95% CI $[.18, .56]$), `ER-03` | Default on retention reviews and concept/fact practice | Suppressed on first exposure to an unfamiliar multi-step `procedural_quantitative` task where worked examples are needed first (`ER-05`) |
| `contrastive_interleaving` | `ER-01` ($g = .40$, 95% CI $[.10, .71]$), `ER-04` | `ContentComplexityProfile.confusable_density == high_confusable_group` or problem-type discrimination | Suppressed when concepts have no confusable boundary (`confusable_density == none`) |
| `worked_example_backward_fading` | `ER-05` (Novice $d = .505$, CI $[.260, .750]$; Expert $d = -.428$, CI $[-.647, -.209]$) | `knowledge_facet == procedural_quantitative` AND learner state indicates novice or recent error | Suppressed when learner demonstrates competence on multi-signal diagnostic or unassisted execution |
| `elaborative_rationale_feedback` | `ER-03` (Butler, 2010) | `feedback_policy == immediate_explanatory` on conceptual/application items | Deferred during `timing_regime == exam_clock_enforced` until exam part submission |
| `reference_foraging_decomposition` | `ER-07`, `EXM_00` | `reference_policy == open_book_manifest` | Closed-book tasks |
| `multimodal_audio_orthographic` | `ER-06` (Tighe et al., 2026: untimed decoding $d = .12\text{--}.46$) | `knowledge_facet == sublexical_orthographic` or audio-first accessibility mode | Learner selects silent reading mode |

---

## 2. Universal Option Shuffling Contract & Implementation Gaps (`FIX-1`)

### 2.1 Target Architecture Contract
1. **Universal Default Across All Structured-Choice Routes**:
   - Every `structured_choice` (`singleChoice` and `multiSelect`) activity must shuffle its non-anchor options by default, preserving any legacy anchor options (e.g., `"none of the above"`, `"all of the above"`) at the end of the list.
2. **Single-XOR Per-Item Seed Rule (Preventing Seed Cancellation)**:
   - **Contract**: The parent screen or session controller passes a **session/attempt-level nonce (`sessionNonce`)** to the presentation component, and the presentation component combines that nonce with the item identifier **exactly once**:
     ```dart
     final int effectiveSeed = sessionNonce ^ item.id.hashCode;
     ```
   - *(Alternatively, if a caller passes a pre-mixed `itemPresentationSeed`, the renderer must use it directly without XORing `item.id.hashCode` a second time).*
3. **Single Canonical Persistence Field (`presented_option_ids`)**:
   - Because Dart's `Object.hash` and `String.hashCode` are randomized per isolate/execution ([Dart `Object.hash` API](https://api.dart.dev/stable/dart-core/Object/hash.html)), historical attempt records in `public.learning_events` standardize on a **single canonical field**:
     - **`presented_option_ids: text[]`** — The ordered list of stable `option_id` values in the exact order displayed to the learner.
   - Do **not** use raw integer index arrays (`presentation_order: List<int>`) in the event ledger, as stable option IDs remain unambiguous even if an item's options are later edited.

### 2.2 Remaining Implementation Gaps to Close in Code (`main` & PR `#136` Audit)
Code inspection of `main` and PR `#136` identifies three specific gaps that must be resolved during `FIX-1` completion:

1. **Gap 1 — Legacy Lesson MCQs Remain Unshuffled**:
   - [`lib/widgets/mcq_options.dart`](../../lib/widgets/mcq_options.dart) (used by [`lib/widgets/study/mcq_question_widget.dart`](../../lib/widgets/study/mcq_question_widget.dart), which is called by both `LessonContentRenderer` and `QuestionContentRenderer`) still renders `widget.question.options` in authored order.
   - **Required Fix**: Either route legacy lesson MCQs through the unified shuffled presentation component or apply deterministic per-attempt shuffling inside `McqQuestionWidget`/`McqOptions` while ensuring voice-input option letter selection (`"Option A"`, `"Option B"`) maps through the shuffled presentation order to the underlying option.
2. **Gap 2 — Seed XOR Cancellation in `AdaptivePracticeScreen` (PR `#136`)**:
   - In PR `#136`, `AdaptivePracticeScreen` passes `presentationSeed: _sessionNonce ^ _currentItem!.id.hashCode`, and `AssessmentItemRenderer` then computes `widget.presentationSeed! ^ widget.item.id.hashCode`. Because $(A \oplus B) \oplus B = A$, the two XOR operations cancel `item.id.hashCode`, reducing the seed to `_sessionNonce` and giving every item with the same option count the identical permutation within a session.
   - **Required Fix**: Pass `_sessionNonce` from `AdaptivePracticeScreen` and perform the `^ item.id.hashCode` combination **only once** inside `AssessmentItemRenderer`.
3. **Gap 3 — Missing Session Seed in Rich Lesson Reader**:
   - Call sites that instantiate `AssessmentItemRenderer(item: item)` without a `presentationSeed` fall back to `item.id.hashCode ^ 0x5bf03635`, producing a static permutation across attempts within the same app session.
   - **Required Fix**: Pass a session/attempt nonce from the lesson reader state so re-attempting an item produces a fresh permutation.
4. **Required Verification Tests**:
   - Widget/unit tests must verify: (a) legacy `McqOptions`/`McqQuestionWidget` shuffling, (b) voice-input selection mapping on shuffled options, (c) distinct permutations across consecutive 4-option items within the same `AdaptivePracticeScreen` session (regression test for XOR cancellation), and (d) variation across separate sessions.
