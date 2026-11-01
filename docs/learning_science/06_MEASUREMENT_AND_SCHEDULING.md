# 06 — Measurement, Event History (`learning_events`) & Versioned FSRS-6 Scheduling

This specification defines the **client vs. server security trust boundary** for the proposed `public.learning_events` ledger and `record_events` RPC, reconciles the `user_concept_state` projection discrepancy on `main` (`e538585`), and enforces strict separation between **FSRS-6 memory card ratings**, **concept evidence**, **reference-navigation telemetry**, and **scored assessment results**.

> **Implementation Status Note**: Neither `public.learning_events` nor `record_events` exists on the `main` (`e538585`) baseline or in PR `#136`'s changed files. They are **proposed Phase 1/5 specifications** designed to be implemented via guarded migrations.

---

## 1. Strict Separation of the Three Difficulty Constructs (`ER-09`)

1. **Construct 1 — Cognitive & Content Complexity (`ContentComplexityProfile`)**:
   - Defined in [`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md) (`reading_demand`, `reasoning_step_count`, `quantitative_complexity`, `prerequisite_depth`, `confusable_density`, `response_format_demand`, `reference_foraging_depth`, `has_statutory_exception`).
   - Describes intrinsic task demand at cold start ($N = 0$).
   - **Boundary Rule**: Never presented as an empirically calibrated IRT parameter, and **never used to manufacture unvalidated initial FSRS stability ($S$) or difficulty ($D$) parameters**.
2. **Construct 2 — Psychometric Item Difficulty & Discrimination (`item_psychometrics`)**:
   - Empirical difficulty and discrimination of an assessment item within a candidate population.
   - Starts `unobserved`. Online **Elo** updates provide relative ratings for small-sample adaptive ordering, while **IRT parameters ($a_i, b_i$)** are estimated separately with explicit standard errors ($\text{SE}$) when model convergence and sample conditions are satisfied (König, Spoden & Frey, 2020; see `ER-09`).
3. **Construct 3 — Individual Learner Memory State (`review_items` — FSRS-6 $S, D, R$)**:
   - Models how difficult it is for an individual learner to retain and retrieve a specific memory-review card over time.

---

## 2. Canonical Event Ledger & Security Trust Boundary (`public.learning_events` & `record_events`)

To prevent clients from forging scores, scheduler states, user identities, or provenance attributes, the `record_events` RPC enforces a strict **Client-Submitted vs. Server-Owned Trust Boundary**:

### 2.1 Client-Submitted vs. Server-Owned Contract Table

| Field | Type | Trust Ownership | Validation & Derivation Rule |
|---|---|---|---|
| **`id`** | `uuid primary key` | Client-submitted | Client-generated UUIDv7; validated for format |
| **`idempotency_key`** | `text unique not null` | Client-submitted | Used for idempotent deduplication (`ON CONFLICT DO NOTHING`) |
| **`user_id`** | `uuid not null` | **Server-owned** | Derived strictly from `auth.uid()`; never accepted from client payload |
| **`event_type`** | `text not null` | Client-submitted, **Server-validated** | Enum (`memory_card_review`, `concept_practice_attempt`, `scaffolded_step_attempt`, `diagnostic_attempt`); validated against item type |
| **`event_schema_version`** | `text not null` | **Server-enforced** | Schema version of the event contract (e.g., `'1.0.0'`) |
| **`session_id`** & **`attempt_id`** | `uuid not null` | Client-submitted, **Server-validated** | Verified against active session / server-issued attempt token where applicable |
| **`client_occurred_at`** | `timestamptz not null` | Client-submitted (Untrusted clock) | Recorded as informational client timestamp metadata; **never trusted as authoritative scheduling time** |
| **`received_at`** | `timestamptz not null` | **Server-owned** | Set to server `now()` (UTC); used as the authoritative timestamp for scheduling and audit ordering |
| **`content_id`** & **`item_id`** | `uuid not null` | Client-submitted, **Server-validated** | Verified to exist and be accessible to `auth.uid()` |
| **`content_version`** & **`target_version_id`** | `text not null` / `uuid` | **Server-owned** | Resolved by the server from the canonical item/target version record |
| **`task_profile`** & **`strategy_version`** | `jsonb not null` / `text` | **Server-owned** | Resolved by the server from canonical item metadata (`LearningTaskProfile`) |
| **`presented_option_ids`** | `text[]` | Client-submitted, **Server-validated** | Canonical ordered array of stable `option_id` values as displayed to the learner. **Validated by the server** to confirm it is an exact permutation of the item version's valid option IDs |
| **`learner_response`** | `jsonb not null` | Client-submitted | Selected `option_id`(s), free-recall text, or numeric/unit entry |
| **`scored_outcome`** | `jsonb` | **Server-owned** | Calculated authoritatively on the server against protected `scoring_spec` |
| **`client_latency_ms`** | `integer not null` | Client-submitted | Explicitly labeled as client-measured elapsed milliseconds (`>= 0`) |
| **`server_elapsed_ms`** | `integer` | **Server-owned** (Optional) | Computed by the server (`received_at - attempt_issued_at`) when a server-issued attempt start exists |
| **`assistance_provided`** | `jsonb not null` | Client-submitted, **Server-validated** | Hints viewed, worked-example fading stage, or audio/text cues revealed |
| **`learner_confidence`** | `smallint` | Client-submitted (Optional) | Self-reported metacognitive rating (`1=low, 2=medium, 3=high`), kept distinct from `user_concept_state.confidence` |
| **`fsrs_rating`** | `smallint` | Client-submitted / Server-validated (Memory cards only) | `1=Again, 2=Hard, 3=Good, 4=Easy` — populated **only** when `event_type == 'memory_card_review'`; `null` for non-SRS tasks |
| **`scheduler_version`** | `text` | **Server-owned** | `'v1_sm2_ladder'` or `'v2_fsrs6'` (standardized identifier across all docs) |
| **`scheduler_state_before`** & **`scheduler_state_after`** | `jsonb` | **Server-owned** | Authoritative scheduler transition computed by the server; never trusted from client |
| **`provenance_snapshot`** | `jsonb not null` | **Server-owned** | Captures **all six** provenance properties (`origin`, `visibility`, `rights_status`, `review_status`, `source_authority`, `version_validity`) from the canonical item record |
| **`assessment_conditions`** | `jsonb not null` | **Server-owned** | Captures the complete active `AssessmentPolicy` (`timing_regime`, `error_criticality`, `scoring_protection`) and `reference_policy` so assessment conditions are fully reproducible |

---

## 3. Separating FSRS Memory Ratings from Concept Evidence, Lookup Telemetry & Scored Assessments

FSRS ratings (`Again`, `Hard`, `Good`, `Easy`) specifically describe **how well a learner recalled a memory-review card**:
- **`Again (1)`**: Forgotten / incorrect recall.
- **`Hard (2)`**: Recalled correctly, but with substantial memory retrieval effort.
- **`Good (3)`**: Recalled normally at the scheduled interval.
- **`Easy (4)`**: Recalled immediately and effortlessly.

### Non-Conflation Rule
A slow open-book code lookup is a **reference-navigation observation**, not difficult memory recall. Likewise, a correct 4-option multiple-choice answer can reflect recognition or guessing rather than free recall, and completing a worked-example fading step is **scaffolded skill acquisition**, not a spaced memory review.

We therefore keep four evidence streams strictly separate:
1. **FSRS Memory Ratings (`fsrs_rating` on `memory_card_review` events)**: Used strictly for scheduled memory-review cards (`review_items`).
2. **Concept Evidence (`user_concept_state`)**: Evaluates demonstrated knowledge across the facets (`concept_facets[]`) and cognitive operations of a `knowledge_concept`.
3. **Reference-Navigation Evidence (`EXM-02B` `exam_reference_drill_events`)**: Evaluates lookup accuracy and timing across `R1–R4` open-book competencies.
4. **Scored Assessment Results (`EXM-03` & diagnostic/mock attempts)**: Evaluates performance under scored test conditions.

We do **not** automatically convert every multiple-choice recognition result or open-book lookup duration into an FSRS rating.

---

## 4. Reconciling `ConceptEvidenceService` and `user_concept_state` on `main`

Inspection of `main` (`e538585`) confirmed two issues to resolve in Phase 5:
1. [`lib/services/concept_evidence_service.dart`](../../lib/services/concept_evidence_service.dart) currently performs client-side select-then-upsert operations on `public.user_concept_state`.
2. [`supabase/migrations/20260925000001_v2_additive_schema.sql`](../../supabase/migrations/20260925000001_v2_additive_schema.sql) grants authenticated owners `FOR ALL` (`SELECT, INSERT, UPDATE, DELETE`) on `user_concept_state`, conflicting with `LEARNING_ARCHITECTURE_V2.md` §3.4's rule that `user_concept_state` is a server-maintained projection.

### Required Migration & Service Fix
1. **Server-Controlled Projection**:
   - Revoke direct client `INSERT`, `UPDATE`, and `DELETE` RLS policies on `public.user_concept_state` (retaining owner `SELECT` and authenticated owner erasure RPCs).
   - Update `user_concept_state` exclusively inside server-validated operations (`record_events` and `EXM-03` scoring RPCs).
2. **Preserve the Distinction Between Three "Confidence" Concepts**:
   - **`user_concept_state.confidence` (Observation-Count Sufficiency Band)**: On `main`, this field is derived from evidence count ($\ge 2$ observations $\to$ `medium`, $\ge 5 \to$ `high`). It is **not** a statistical confidence interval and must remain clearly distinguished from both:
   - **`learner_confidence` (Metacognitive self-report)**: The learner's subjective certainty on a single attempt (`1..3`).
   - **Statistical Uncertainty ($\text{SE}$ / Credible Interval)**: The standard error of an empirical psychometric estimate.

---

## 5. FSRS-6 Integration Rules (`package:fsrs` v2.0.1 — `v2_fsrs6`)

`package:fsrs` `2.0.1` implements **FSRS-6** (verified in package changelog v2.0.0+). All documents standardize on the version identifier **`v2_fsrs6`**:

1. **No Retroactive History Fabrication from `review_items`**:
   - Existing `review_items` rows on `main` store only aggregate counters (`total_reviews`, `correct_reviews`, `repetition_level`, `ease_factor`, `next_review_date`), not historical review sequences.
   - Existing rows retain their schedule under `scheduler_version = 'v1_sm2_ladder'` and transition forward to `'v2_fsrs6'` as new `memory_card_review` events are recorded.
2. **No Complexity-to-FSRS Parameter Manufacturing**:
   - `ContentComplexityProfile` is never used to manufacture synthetic initial FSRS stability ($S$) or difficulty ($D$) parameters.
3. **FSRS Retrievability $\ne$ Concept Mastery $\ne$ Exam Readiness**:
   - FSRS-6 estimates individual card memory retrievability $R(t)$.
   - Concept evidence (`user_concept_state`) evaluates learning across multiple facets and tasks.
   - Examination readiness evaluates blueprint coverage, delayed retention, transfer to held-out items, and execution under actual exam conditions (`07_READINESS_AND_VALIDATION.md`).
4. **Exam-Date Workload Planning Is Separate from Memory Parameters**:
   - Approaching exam dates adjust daily queue prioritization and workload budgets without mutating underlying FSRS-6 memory parameters ($S, D$).
