# 06 — Measurement, Event History (`learning_events`) & Versioned FSRS-6 Scheduling

This specification defines the canonical event ledger, reconciles the `user_concept_state` projection discrepancy on `main` (`e538585`), and establishes strict mathematical boundaries between **content complexity**, **psychometric item difficulty**, **FSRS-6 card retrievability**, **concept mastery**, and **examination readiness**.

---

## 1. Strict Separation of the Three Difficulty Constructs (`ER-09`)

1. **Construct 1 — Cognitive & Content Complexity (`ContentComplexityProfile`)**:
   - Defined in [`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md) (`reading_demand`, `reasoning_step_count`, `quantitative_complexity`, `prerequisite_depth`, `confusable_density`, `response_format_demand`, `reference_foraging_depth`, `has_statutory_exception`).
   - Describes intrinsic task demand at cold start ($N = 0$).
   - **Boundary Rule**: Never presented as an empirically calibrated IRT parameter, and **never used to manufacture unvalidated initial FSRS stability ($S$) or difficulty ($D$) parameters**.
2. **Construct 2 — Psychometric Item Difficulty & Discrimination (`item_psychometrics`)**:
   - Empirical difficulty and discrimination of an assessment item within a candidate population.
   - Starts `unobserved`. Online **Elo** updates provide relative ratings for small-sample adaptive ordering, while **IRT parameters ($a_i, b_i$)** are estimated separately with explicit standard errors ($\text{SE}$) when model convergence and sample conditions are satisfied (`ER-09`).
3. **Construct 3 — Individual Learner Memory State (`review_items` — FSRS-6 $S, D, R$)**:
   - Models how difficult it is for an individual learner to retain and retrieve a specific review card over time.

---

## 2. Canonical Event Ledger (`public.learning_events` & `record_events`)

To unify terminology across `ARCHITECTURE_REVIEW.md` and the learning-science specifications while preserving `EXM-02B` (`exam_reference_drill_events`) and `EXM-03` (`exam_part_practice_attempts`), general learning telemetry uses the canonical table **`public.learning_events`** and atomic RPC **`record_events`**.

### 2.1 Minimum Required Contract Fields for `public.learning_events`
- **`id`** (`uuid primary key`) & **`idempotency_key`** (`text unique not null`) — Client-generated UUIDv7 / idempotency key for safe offline retries (`ON CONFLICT DO NOTHING`).
- **`user_id`** (`uuid not null`), **`session_id`** (`uuid not null`), **`attempt_id`** (`uuid not null`) — Learner, study session, and item attempt identifiers.
- **`occurred_at`** (`timestamptz not null`) & **`received_at`** (`timestamptz not null default now()`) — UTC client occurrence timestamp and server receipt timestamp.
- **`content_id`** (`uuid`), **`item_id`** (`uuid not null`), **`content_version`** (`text not null`) — Target content, item, and manifest/target version.
- **`task_profile`** (`jsonb not null`) & **`strategy_version`** (`text not null`) — Canonical `LearningTaskProfile` and active instructional strategy version.
- **`presented_option_ids`** (`text[] not null`) — Exact option IDs in the order presented to the learner (persisted directly because Dart's `Object.hash` / `String.hashCode` is isolate-specific and not stable across restarts; see [`03_INSTRUCTIONAL_STRATEGIES.md`](03_INSTRUCTIONAL_STRATEGIES.md)).
- **`learner_response`** (`jsonb not null`) & **`scored_outcome`** (`jsonb`) — Selected option ID(s) / entered value, correctness boolean, and numeric score (`0.0..1.0`).
- **`latency_ms`** (`integer not null`) — Elapsed response time in milliseconds.
- **`assistance_provided`** (`jsonb not null`) — Hints viewed, worked-example fading stage used, or audio/text scaffold revealed.
- **`learner_confidence`** (`smallint`) — Optional self-reported metacognitive confidence (`1=low/guess, 2=medium, 3=high/certain`), kept distinct from `user_concept_state.confidence`.
- **`fsrs_rating`** (`smallint`) — Explicit FSRS-6 rating (`1=Again, 2=Hard, 3=Good, 4=Easy`) when the event updates a scheduled review card.
- **`scheduler_version`** (`text`) & **`scheduler_state_before` / `scheduler_state_after`** (`jsonb`) — Scheduler engine version (`v1_sm2_ladder` | `v2_fsrs6`) and state transition snapshot.
- **`provenance_snapshot`** (`jsonb not null`) & **`assessment_conditions`** (`jsonb not null`) — Decomposed provenance (`origin`, `review_status`, `source_authority`) and active `AssessmentPolicy` (`reference_policy`, `timing_regime`).

### 2.2 Separating `fsrs_rating` from Binary Correctness
FSRS uses four ordinal ratings (`Again`, `Hard`, `Good`, `Easy`). A correct answer is **not** automatically an `Easy` rating:
1. **Recall / Flashcard Items**: The learner selects `Again`, `Hard`, `Good`, or `Easy` after reveal (or is capped at `Again` if their typed/spoken recall check failed).
2. **Structured-Choice / Quantitative Items**:
   - Incorrect response (or critical-step failure) $\to$ `Again (1)`.
   - Correct response *only after* viewing a hint, revealing a faded worked-example step, or exceeding the paced lookup target $\to$ capped at `Hard (2)`.
   - Unassisted correct response within normal pacing $\to$ `Good (3)` (or `Easy (4)` only when explicitly rated high-confidence/effortless by the learner on a non-cued recall task).

---

## 3. Reconciling `ConceptEvidenceService` and `user_concept_state` on `main`

Inspection of `main` (`e538585`) confirmed two issues that must be resolved during Phase 5 implementation:
1. [`lib/services/concept_evidence_service.dart`](../../lib/services/concept_evidence_service.dart) currently performs client-side select-then-upsert operations on `public.user_concept_state`.
2. [`supabase/migrations/20260925000001_v2_additive_schema.sql`](../../supabase/migrations/20260925000001_v2_additive_schema.sql) grants authenticated owners `FOR ALL` (`SELECT, INSERT, UPDATE, DELETE`) on `user_concept_state`, contradicting `LEARNING_ARCHITECTURE_V2.md` §3.4's design that `user_concept_state` is a read-only analytical projection.

### Required Migration & Service Fix
1. **Server-Controlled Projection**:
   - Revoke direct client `INSERT`, `UPDATE`, and `DELETE` policies on `public.user_concept_state` (retaining owner `SELECT` and owner erasure RPC support).
   - Update `user_concept_state` exclusively inside the server-side `record_events` RPC and `EXM-03` protected scoring RPCs.
2. **Preserve the Distinction Between Three "Confidence" Concepts**:
   - **`user_concept_state.confidence` (`evidence_count_band`)**: In existing `main` code, this field represents an **observation-count band** (`0..1` observations $\to$ `low`, `2..4` $\to$ `medium`, $\ge 5$ $\to$ `high`). It is **not** a statistical confidence interval and should be clearly labeled as `evidence_sufficiency_band` in analytics.
   - **`learner_confidence` (Metacognitive self-report)**: How sure the learner felt on a specific attempt (`1..3`).
   - **Statistical Uncertainty ($\text{SE}$ / Credible Interval)**: The standard error around an item parameter or readiness estimate.

---

## 4. FSRS-6 Integration Rules (`package:fsrs` v2.0.1)

Verification against pub.dev confirms that `fsrs 2.0.1` implements the **FSRS-6** algorithm (introduced in v2.0.0). Its integration follows four strict rules:

1. **No Retroactive History Fabrication from `review_items`**:
   - Existing `review_items` rows on `main` store only aggregate counters (`total_reviews`, `correct_reviews`, `repetition_level`, `ease_factor`, `next_review_date`) and do **not** store historical review sequences.
   - Full FSRS review logs cannot be reconstructed retroactively; existing items preserve their current `next_review_date` under `scheduler_version = 'v1_sm2_ladder'` and transition to `'v2_fsrs6'` forward as new `learning_events` are recorded.
2. **No Unvalidated Complexity-to-FSRS Parameter Manufacturing**:
   - New cards in `v2_fsrs6` initialize using the validated FSRS-6 default parameter weights (`w`), not synthetic stability/difficulty numbers manufactured from `ContentComplexityProfile`.
3. **FSRS Retrievability $\ne$ Concept Mastery $\ne$ Exam Readiness**:
   - **FSRS Retrievability $R(t)$**: Estimates the probability that a learner can recall a *specific review card* at time $t$.
   - **Concept Evidence (`user_concept_state`)**: Evaluates demonstrated competence across the multiple facets and cognitive operations of a `knowledge_concept`.
   - **Examination Readiness**: Evaluates official blueprint coverage, delayed retention, transfer to held-out unfamiliar items, and execution under actual exam conditions (`07_READINESS_AND_VALIDATION.md`).
4. **Exam-Date Planning Is a Separate Workload Policy Layer**:
   - Approaching exam dates adjust daily queue prioritization and session time budgets in the study planner without mutating the underlying FSRS-6 memory parameters ($S, D$).
