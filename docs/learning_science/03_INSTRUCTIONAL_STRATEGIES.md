# 03 — Instructional Strategies & Moderator Rules

This specification defines the reusable **Instructional Strategies** available in LearningApp's delivery engine and the empirical moderators that govern when each strategy is activated or suppressed.

---

## 1. Strategy Catalog & Activation Conditions

| Strategy ID | Description | Activated When (`LearningTaskProfile`) | Suppressed When (Moderator Guardrail) |
|---|---|---|---|
| `active_retrieval_first` | Prompt learner to retrieve or commit to an answer before revealing explanation or options | Default across retention reviews and quiz blocks (`ER-02`, `ER-03`) | First exposure to a complex multi-step `procedural_quantitative` procedure where learner has zero prior schema (`ER-04`) |
| `contrastive_interleaving` | Mix items from competing/confusable concepts within the same practice set | Items share a verified `confusable_group_id` or require problem-type selection (`ER-02`) | Unrelated introductory vocabulary where interleaving adds extraneous switching cost without discriminative benefit |
| `worked_example_backward_fading` | Present complete worked solution, then progressively fade final $\to$ setup steps | `knowledge_facet == procedural_quantitative` AND learner prior competence is low or learner just erred (`ER-04`) | Learner demonstrates prior competence on diagnostic or unassisted item (`ER-05` Expertise Reversal) |
| `elaborative_rationale_feedback` | Show why the target rule applies and why specific misconception distractors fail | `conceptual_relational`, `apply_to_scenario`, or high-confidence errors | Rapid perceptual classification bursts where long text interrupts visual feature tuning |
| `reference_foraging_decomposition` | Decompose open-book lookup into resource selection $\to$ section $\to$ provision $\to$ exception (`EXM R1–R4`) | `reference_policy == open_book_manifest` (`ER-07`) | Closed-book recall tasks |
| `multimodal_audio_orthographic` | Synchronized phoneme/word audio + visual grapheme highlighting + minimal-pair contrast | `knowledge_facet == sublexical_orthographic` or learner selects audio-first support (`ER-06`) | Learner opts into silent fast-reading mode |

---

## 2. Option Shuffling & Anti-Cueing Invariant (`FIX-1`)

Across all `structured_choice` items (including standard MCQs, diagnostics, and USCIS/DMV/GED simulators):
1. **Deterministic Per-Attempt Shuffling**:
   - Options must never be rendered in static authored order when `correctOptionIndex == 0` or LLM B/C bias exists.
   - Use a deterministic seed `Object.hash(sessionId, itemId, attemptOrdinal)` so options remain stable across widget rebuilds within a single attempt, while randomizing across attempts and learners.
2. **Per-Option Metadata**:
   - Options carry stable option IDs (`option_id`), `is_correct`, `rationale`, and optional `misconception_tag` so shuffled presentation never corrupts scoring or distractor analytics.

---

## 3. Feedback Timing Rules

1. **Acquisition, Literacy & Diagnostic Remediation (`immediate_explanatory`)**:
   - During initial learning, worked-example fading, and literacy decoding, feedback is delivered immediately after each response so errors are not reinforced.
2. **Exam Execution & Timed Part Practice (`deferred_until_submission`)**:
   - During timed mock exams and `EXM-03` assigned part practice, item-by-item answer keys are withheld until part submission to preserve assessment validity and time-management realism, followed by a structured post-session diagnostic review.
