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

> **Cross-PR Implementation Status (`main` `e538585` vs. PR `#136`)**:
> While Antigravity's PR `#136` (`feature/arch-review-phase-0`) implements option shuffling inside `AssessmentItemRenderer`, **`FIX-1` is not yet complete across all structured-choice routes**. Specifically, legacy lesson MCQs (`McqQuestionWidget` / `McqOptions`), `RichLessonReader` call sites, both legacy voice-input selection handlers, and the `AdaptivePracticeScreen` double-XOR seed cancellation remain open and must be resolved before `FIX-1` is marked fully closed.

### 2.1 Target Architecture Contract
1. **Universal Default Across All Structured-Choice Routes**:
   - Every `structured_choice` (`singleChoice` and `multiSelect`) activity must shuffle its non-anchor options by default, preserving any legacy anchor options (e.g., `"none of the above"`, `"all of the above"`) at the end of the list.
2. **Per-Presentation / Per-Attempt Nonce & Single-XOR Seed Rule (Preventing Seed Cancellation & Same-Session Repeats)**:
   - **Per-Attempt Nonce Requirement**: A session-wide nonce alone produces the identical option permutation if the same item is re-presented or retried within the same study or lesson session. Whenever a fresh permutation is required on each presentation, the controller must generate or increment a **per-presentation / per-attempt nonce (`attemptNonce`)** when advancing to or retrying an item.
   - **Single-XOR Combination Contract**: The parent screen or controller passes `attemptNonce` to the presentation component, and the presentation component combines that nonce with the item identifier **exactly once**:
     ```dart
     final int effectiveSeed = attemptNonce ^ item.id.hashCode;
     ```
   - *(If a caller passes an already-combined `itemPresentationSeed`, the renderer must use it directly without XORing `item.id.hashCode` a second time).*
3. **Single Canonical Persistence Field (`presented_option_ids`)**:
   - Because Dart's `Object.hash` and `String.hashCode` are randomized per isolate/execution ([Dart `Object.hash` API](https://api.dart.dev/stable/dart-core/Object/hash.html)), historical attempt records in `public.learning_events` standardize on a **single canonical field**:
     - **`presented_option_ids: text[]`** — The ordered list of stable `option_id` values in the exact order displayed to the learner (see [`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md) for server-issued vs. client-reported trust rules).
   - Do **not** use raw integer index arrays (`presentation_order: List<int>`) in the event ledger, as stable option IDs remain unambiguous even if an item's options are later edited.

### 2.2 Remaining Implementation Gaps to Close in Code (`main` & PR `#136` Audit)
Code inspection of `main` and PR `#136` identifies three specific code gaps and two voice-input mapping paths that must be resolved to complete `FIX-1`:

1. **Gap 1 — Legacy Lesson MCQs Remain Unshuffled (`McqQuestionWidget` & `McqOptions`)**:
   - [`lib/widgets/question_widgets/mcq_question_widget.dart`](../../lib/widgets/question_widgets/mcq_question_widget.dart) passes `options: widget.content.options` (with `widget.content.correctAnswer` holding the authored index) directly to [`lib/widgets/mcq_options.dart`](../../lib/widgets/mcq_options.dart), which renders `options.asMap().entries` in authored order.
   - `McqQuestionWidget` is invoked by both [`lib/widgets/lesson_content_renderer.dart`](../../lib/widgets/lesson_content_renderer.dart) and [`lib/widgets/content_renderers/question_content_renderer.dart`](../../lib/widgets/content_renderers/question_content_renderer.dart).
   - **Required Fix**: Apply deterministic per-presentation shuffling to `widget.content.options` (or route legacy lesson MCQs through the unified shuffled choice presenter) and update **both** legacy voice-input paths so spoken letter commands map through the displayed shuffled order to the underlying authored option:
     - **Voice Path A**: [`lib/widgets/lesson_content_renderer.dart`](../../lib/widgets/lesson_content_renderer.dart) (which processes spoken answers via `VoiceInputHandler`).
     - **Voice Path B**: [`lib/widgets/content_renderers/question_content_renderer.dart`](../../lib/widgets/content_renderers/question_content_renderer.dart) (which performs its own spoken letter-to-index mapping `a->0, b->1, c->2, d->3`).
2. **Gap 2 — Seed XOR Cancellation in `AdaptivePracticeScreen` (PR `#136`)**:
   - In PR `#136`, `AdaptivePracticeScreen` passes `presentationSeed: _sessionNonce ^ _currentItem!.id.hashCode`, and `AssessmentItemRenderer` then computes `widget.presentationSeed! ^ widget.item.id.hashCode`. Because $(A \oplus B) \oplus B = A$, the two XOR operations cancel `item.id.hashCode`, reducing the seed to `_sessionNonce` and giving every item with the same option count the identical permutation within a session.
   - **Required Fix**: Pass a per-attempt nonce (`_attemptNonce`) from `AdaptivePracticeScreen` and perform the `^ item.id.hashCode` combination **only once** inside `AssessmentItemRenderer`.
3. **Gap 3 — Missing Per-Presentation Seed in `RichLessonReader`**:
   - In [`lib/widgets/lesson/rich_lesson_reader.dart`](../../lib/widgets/lesson/rich_lesson_reader.dart), `AssessmentItemRenderer(item: item, ...)` is instantiated without a `presentationSeed`, falling back to `item.id.hashCode ^ 0x5bf03635` and producing a static permutation across retries within the same app process.
   - **Required Fix**: Pass a per-presentation/per-attempt nonce from `RichLessonReader` state so presenting or retrying an item produces a fresh permutation.
4. **Required Verification Tests**:
   - Widget/unit tests must verify: (a) shuffling in `lib/widgets/question_widgets/mcq_question_widget.dart` and `lib/widgets/mcq_options.dart` on `widget.content.options`, (b) spoken `"Option A"`/`"B"`/`"C"`/`"D"` voice-input mapping in **both** `LessonContentRenderer` (`VoiceInputHandler`) and `QuestionContentRenderer`, (c) distinct permutations across consecutive 4-option items within the same `AdaptivePracticeScreen` session (regression test for XOR cancellation), and (d) fresh permutations when re-presenting an item in `RichLessonReader` or across sessions.
