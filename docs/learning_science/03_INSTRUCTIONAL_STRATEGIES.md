# 03 — Instructional Strategies, Option Shuffling (`FIX-1`) & Moderator Rules

This specification defines how the adaptive delivery engine selects strategies from `InstructionalPolicy.eligible_strategies[]` ([`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md)) and specifies the exact contract and remaining implementation gaps for universal option shuffling (`FIX-1`).

---

## 1. Strategy Selection & Moderator Guardrails (`ER-01`–`ER-05`)

| Strategy ID | Evidence Basis | Activated When | Moderator Suppression Rule |
|---|---|---|---|
| `active_retrieval_first` | `ER-01` ($g = .37$, 95% CI $[.18, .56]$, $I^2_{\text{total}} = 85.29\%$, $I^2_{\text{within}} = 24.50\%$, $I^2_{\text{between}} = 60.79\%$; null on transfer $p = .92$ & comprehension $p = .23$; negative on mixed posttest formats), `ER-03` | Default on retention reviews and factual/recognition practice; paired with `elaborative_rationale_feedback` (`ER-03`) for comprehension/transfer | Suppressed on first exposure to an unfamiliar multi-step `procedural_quantitative` task where worked examples are needed first (`ER-05`), and never used without elaborative rationale feedback when targeting comprehension or transfer (`ER-01`, `ER-03`) |
| `contrastive_interleaving` | `ER-01` ($g = .40$, 95% CI $[.10, .71]$, $I^2_{\text{total}} = 73.52\%$, $I^2_{\text{within}} = 3.70\%$, $I^2_{\text{between}} = 69.82\%$; nonsignificant with immediate feedback $p = .75$), `ER-04` | `ContentComplexityProfile.confusable_density == high_confusable_group` or problem-type discrimination | Suppressed when concepts have no confusable boundary (`confusable_density == none`); feedback timing (`immediate_explanatory` vs. delayed contrastive summary) is tracked as a moderator in Phase 1 (`ER-01`) |
| `worked_example_backward_fading` | `ER-05` (Novice $d = .505$, CI $[.260, .750]$, $I^2 = 90.87\%$; Expert $d = -.428$, CI $[-.647, -.209]$, $I^2 = 87.55\%$) | `knowledge_facet == procedural_quantitative` AND learner state indicates novice or recent error | Suppressed when learner demonstrates competence on multi-signal diagnostic or unassisted execution |
| `elaborative_rationale_feedback` | `ER-03` (Butler, 2010) | `feedback_policy == immediate_explanatory` on conceptual/application items | Deferred during `timing_regime == exam_clock_enforced` until exam part submission |
| `reference_foraging_decomposition` | `ER-07`, `EXM_00` | `reference_policy == open_book_manifest` | Closed-book tasks |
| `multimodal_audio_orthographic` | `ER-06` (Tighe et al., 2026: untimed decoding $d = .12\text{--}.46$) | `knowledge_facet == sublexical_orthographic` or audio-first accessibility mode | Learner selects silent reading mode |

---

## 2. Universal Option Shuffling Contract & Implementation Gaps (`FIX-1`)

> **Implementation Status (`main` after PR `#136` merge at `a23cebb`, following earlier PR `#136` snapshots `5a428b5`, `e67a3d5`, and `dc8f49f`)**:
> Although PR `#136` (`feature/arch-review-phase-0`, merged to `main` at `a23cebb`) listed `FIX-1` as `RESOLVED` in its pull-request description, **`FIX-1` remains `PARTIALLY RESOLVED` (`INCOMPLETE`) on `main` (`a23cebb`)**:
> 1. [`lib/widgets/mcq_options.dart`](../../lib/widgets/mcq_options.dart) (`options.asMap().entries`) still renders authored order for [`lib/widgets/question_widgets/mcq_question_widget.dart`](../../lib/widgets/question_widgets/mcq_question_widget.dart) (`widget.content.options`), and both legacy voice-input paths (`LessonContentRenderer` and `QuestionContentRenderer`) still map `A`–`D` directly to authored indices.
> 2. While the final PR `#136` merge commit (`a23cebb`) removed the double-XOR (`_sessionNonce ^ _currentItem!.id.hashCode`) in `AdaptivePracticeScreen` (`lib/screens/assessment/adaptive_practice_screen.dart`) and added `_sessionNonce` to [`lib/widgets/lesson/rich_lesson_reader.dart`](../../lib/widgets/lesson/rich_lesson_reader.dart), **both screens still pass a session-scoped `_sessionNonce` rather than a per-presentation `_attemptNonce`**—meaning re-presenting or retrying the same item within the same session/reader instance produces the identical option permutation.

### 2.1 Target Architecture Contract
1. **Universal Default Across All Structured-Choice Routes**:
   - Every `structured_choice` (`singleChoice` and `multiSelect`) activity must shuffle its non-anchor options by default, preserving any legacy anchor options (e.g., `"none of the above"`, `"all of the above"`) at the end of the list.
2. **Raw Per-Presentation `attemptNonce` & Single-XOR Seed Rule (Preventing Seed Cancellation & Same-Session Repeats)**:
   - **Per-Attempt Nonce Requirement**: A session-wide nonce alone (such as `_sessionNonce` in `AdaptivePracticeScreen` and `RichLessonReader`) produces the identical option permutation if the same item is re-presented or retried within the same study or lesson session. Whenever a fresh permutation is required on each presentation, the controller must generate or increment a **raw per-presentation / per-attempt nonce (`attemptNonce`)** when advancing to or retrying an item.
   - **Single-XOR Combination Contract**: Parent screens and controllers (`AdaptivePracticeScreen`, `RichLessonReader`, etc.) must introduce or increment a **raw per-presentation nonce (e.g. `_attemptNonce`)** and pass it unchanged as `presentationSeed` (never pre-XORed with `item.id.hashCode`), and `AssessmentItemRenderer` combines that raw nonce with the item identifier **exactly once**:
     ```dart
     final int effectiveSeed = attemptNonce ^ item.id.hashCode;
     ```
3. **Single Canonical Persistence Field (`presented_option_ids` — Separate Phase 1 Event-Ledger Work `ARCH-1`, Not a Phase 0 `FIX-1` Acceptance Criterion)**:
   - Phase 0 `FIX-1` acceptance criteria cover only the three client/UI option-shuffling, legacy MCQ/voice-input mapping, and raw per-presentation nonce items in §2.2 below.
   - Durable event-ledger persistence of the displayed option order is tracked separately as **Phase 1 event-ledger work (`ARCH-1`, specified in [`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md); whereas `FIX-3` is Phase 0 schema drift)**. Because Dart's `Object.hash` and `String.hashCode` are randomized per isolate/execution ([Dart `Object.hash` API](https://api.dart.dev/stable/dart-core/Object/hash.html)), Phase 1 historical attempt records in `public.learning_events` standardize on a **single canonical field**:
     - **`presented_option_ids: text[]`** — The ordered list of stable `option_id` values in the exact order displayed to the learner (see [`06_MEASUREMENT_AND_SCHEDULING.md`](06_MEASUREMENT_AND_SCHEDULING.md) for server-issued vs. client-reported trust rules).
   - Do **not** use raw integer index arrays (`presentation_order: List<int>`) in the Phase 1 event ledger, as stable option IDs remain unambiguous even if an item's options are later edited.

### 2.2 Remaining Implementation Gaps to Close in Code (`main` at `a23cebb` after PR `#136`)
Code inspection of `main` (`a23cebb`, following PR `#136` snapshots `5a428b5`, `e67a3d5`, and `dc8f49f`) identifies the specific remaining code gaps and two voice-input mapping paths that must be resolved to complete Phase 0 `FIX-1`:

1. **Gap 1 — Legacy Lesson MCQs Remain Unshuffled (`McqQuestionWidget` & `McqOptions`)**:
   - [`lib/widgets/question_widgets/mcq_question_widget.dart`](../../lib/widgets/question_widgets/mcq_question_widget.dart) passes `options: widget.content.options` (with `widget.content.correctAnswer` holding the authored index) directly to [`lib/widgets/mcq_options.dart`](../../lib/widgets/mcq_options.dart), which renders `options.asMap().entries` in authored order.
   - `McqQuestionWidget` is invoked by both [`lib/widgets/lesson_content_renderer.dart`](../../lib/widgets/lesson_content_renderer.dart) and [`lib/widgets/content_renderers/question_content_renderer.dart`](../../lib/widgets/content_renderers/question_content_renderer.dart).
   - **Required Fix**: Apply deterministic per-presentation shuffling to `widget.content.options` (or route legacy lesson MCQs through the unified shuffled choice presenter) and update **both** legacy voice-input paths so spoken letter commands map through the displayed shuffled order to the underlying authored option:
     - **Voice Path A**: [`lib/widgets/lesson_content_renderer.dart`](../../lib/widgets/lesson_content_renderer.dart) (which processes spoken answers via `VoiceInputHandler`).
     - **Voice Path B**: [`lib/widgets/content_renderers/question_content_renderer.dart`](../../lib/widgets/content_renderers/question_content_renderer.dart) (which performs its own spoken letter-to-index mapping `a->0, b->1, c->2, d->3`).
2. **Gap 2 — Session-Scoped `_sessionNonce` vs. Per-Presentation `_attemptNonce` in `AdaptivePracticeScreen` & `RichLessonReader`**:
   - Earlier PR `#136` snapshots (`dc8f49f`–`5a428b5`) passed `_sessionNonce ^ _currentItem!.id.hashCode` from `AdaptivePracticeScreen` (causing double-XOR cancellation in `AssessmentItemRenderer`) and omitted `presentationSeed` in `RichLessonReader`. While the merged PR `#136` commit (`a23cebb`) updated both `AdaptivePracticeScreen` (`lib/screens/assessment/adaptive_practice_screen.dart`) and `RichLessonReader` (`lib/widgets/lesson/rich_lesson_reader.dart`) to pass raw `presentationSeed: _sessionNonce`, **both screens still only define a session-scoped `_sessionNonce` initialized once per widget state** rather than a per-presentation `_attemptNonce`. Consequently, when the same item is re-presented or retried within the same session or lesson view, `_sessionNonce ^ item.id.hashCode` yields the identical option permutation.
   - **Required Fix**: Introduce or increment a raw per-presentation nonce (e.g. `_attemptNonce`) in both `AdaptivePracticeScreen` and `RichLessonReader` whenever an item is presented or retried, and pass it unchanged as `presentationSeed` (never pre-XORed with `item.id.hashCode`; `AssessmentItemRenderer` combines the nonce with `item.id.hashCode` **exactly once**).
3. **Required Verification Tests**:
   - Widget/unit tests must verify: (a) shuffling in `lib/widgets/question_widgets/mcq_question_widget.dart` and `lib/widgets/mcq_options.dart` on `widget.content.options`, (b) spoken `"Option A"`/`"B"`/`"C"`/`"D"` voice-input mapping in **both** `LessonContentRenderer` (`VoiceInputHandler`) and `QuestionContentRenderer`, (c) distinct permutations across consecutive 4-option items within the same `AdaptivePracticeScreen` session (regression test for XOR cancellation), and (d) fresh permutations when re-presenting an item within the same `AdaptivePracticeScreen` or `RichLessonReader` session.
