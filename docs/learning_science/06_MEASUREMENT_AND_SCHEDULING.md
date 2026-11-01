# 06 — Measurement, Event History (`learning_events`) & Versioned FSRS-6 Scheduling

This specification defines the **client vs. server security trust boundary** for the proposed `public.learning_events` ledger and `record_events` RPC, reconciles the `user_concept_state` projection discrepancy on `main` (`e538585`), documents the complete `EXM-03` scoring surface, and enforces strict separation between **FSRS-6 memory card ratings**, **concept evidence**, **reference-navigation telemetry**, and **scored assessment results**.

> **Implementation Status Note**: Neither `public.learning_events` nor `record_events` exists on the `main` (`e538585`) baseline or in PR `#136`'s changed files. They are **proposed Phase 1 (`ARCH-1`) specifications** designed to be implemented via guarded migrations.
>
> **Explicit Supersession of Provisional `ARCHITECTURE_REVIEW.md` Details**:
> `/ARCHITECTURE_REVIEW.md` is retained at exact blob SHA `5fe779d3db382d03ad034dc03742409b9a6c1c7b` as a historical point-in-time Phase 0 audit across branches. Where `ARCHITECTURE_REVIEW.md` contains provisional event-ledger or scheduler sketches, **`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md` and `/docs/learning_science/01..08` formally supersede them**:
> 1. **`presented_option_ids: text[]`** supersedes `presented_order` (`List<int>`).
> 2. **`fsrs_rating`** (`1..4`, populated **only** on `memory_card_review` events) is kept strictly separate from **`learner_confidence`** (`1..3` metacognitive self-report) and from `user_concept_state.confidence` (observation-count sufficiency band).
> 3. **FSRS-6 (`scheduler_version = 'v2_fsrs6'`)** models individual memory-card retrievability $R(t)$ only—it is never equated with multi-facet concept mastery or exam readiness, never initialized by fabricating parameters from SM-2 counters or `ContentComplexityProfile` priors, and kept separate from exam-date daily workload planning.

---

## 1. Strict Separation of the Three Difficulty Constructs (`ER-09`)

1. **Construct 1 — Cognitive & Content Complexity (`ContentComplexityProfile`)**:
   - Defined in [`02_LEARNING_TASK_TAXONOMY.md`](02_LEARNING_TASK_TAXONOMY.md) (`reading_demand`, `reasoning_step_count`, `quantitative_complexity`, `prerequisite_depth`, `confusable_density`, `response_format_demand`, `reference_foraging_depth`, `has_statutory_exception`).
   - Describes intrinsic task demand at cold start ($N = 0$), tracked by **`complexity_assessment_status`** (`unassessed` | `deterministic_profile` | `expert_reviewed_profile`).
   - **Boundary Rule**: Never presented as an empirically calibrated IRT parameter, and **never used to manufacture unvalidated initial FSRS stability ($S$) or difficulty ($D$) parameters**.
2. **Construct 2 — Psychometric Item Difficulty & Discrimination (`item_psychometrics`)**:
   - Empirical difficulty and discrimination of an assessment item within a candidate population, tracked separately by **`item_psychometric_status`** (`unobserved` | `observed_uncalibrated` | `preliminary_elo_ordering` | `calibrated`; see [`07_READINESS_AND_VALIDATION.md`](07_READINESS_AND_VALIDATION.md)).
   - Starts `unobserved` ($N = 0$). Recording $N \ge 1$ responses marks the item `observed_uncalibrated` (an observation exists, which is **not** a difficulty estimate). Transitioning to `preliminary_elo_ordering` requires reaching a configurable LearningApp policy threshold (**`elo_min_observations`**, not a literature-derived constant; **inactive until selected and validated for the relevant item pool**), where online **Elo** updates (`ER-09b`: Pelánek, 2016; qualified by Bolsinova, Gergely, & Brinkhuis, 2026 regarding joint selection/update bias, context-dependent variance, and non-convergence) provide low-stakes heuristic ordering only. **IRT parameters ($a_i, b_i$)** are estimated separately (`calibrated`) only when pool- and model-specific convergence diagnostics and an explicitly configured maximum standard-error bound (**`calibration_max_se`**) are defined and verified (`ER-09a`, König, Spoden & Frey, 2020; **inactive / `pending_validation` until validated for the target item pool**).
3. **Construct 3 — Individual Learner Memory State (`review_items` — FSRS-6 $S, D, R$)**:
   - Models how difficult it is for an individual learner to retain and retrieve a specific memory-review card over time (`ER-09c`, `package:fsrs` v2.0.1).

---

## 2. Canonical Event Ledger & Security Trust Boundary (`public.learning_events` & `record_events`)

To prevent clients from forging scores, scheduler states, user identities, timing, or provenance attributes, the `record_events` RPC enforces a strict **Client-Submitted vs. Server-Owned Trust Boundary**:

### 2.1 Client-Submitted vs. Server-Owned Contract Table

| Field | Type | Trust Ownership | Validation & Derivation Rule |
|---|---|---|---|
| **`id`** | `uuid primary key` | Client-submitted | Client-generated UUIDv7; validated for format |
| **`idempotency_key`** | `text unique not null` | Client-submitted | Used for idempotent deduplication (`ON CONFLICT DO NOTHING`) |
| **`user_id`** | `uuid not null` | **Server-owned** | Derived strictly from `auth.uid()`; never accepted from client payload |
| **`event_type`** | `text not null` | Client-submitted, **Server-validated** | Enum (`memory_card_review`, `concept_practice_attempt`, `scaffolded_step_attempt`, `diagnostic_attempt`); validated against item type |
| **`event_schema_version`** | `text not null` | **Server-enforced** | Schema version of the event contract (e.g., `'1.0.0'`) |
| **`session_id`** & **`attempt_id`** | `uuid not null` | Client-submitted, **Server-validated** | Verified against active session / server-issued attempt record where applicable |
| **`client_occurred_at`** | `timestamptz not null` | Client-submitted (**Untrusted client clock**) | Recorded strictly as informational client timestamp metadata; **never trusted as authoritative scheduling or audit time** |
| **`received_at`** | `timestamptz not null` | **Server-owned** | Set to server `now()` (UTC); used as the authoritative timestamp for scheduling and audit ordering |
| **`content_id`** & **`item_id`** | `uuid not null` | Client-submitted, **Server-validated** | Verified to exist and be accessible to `auth.uid()` |
| **`content_version`** & **`target_version_id`** | `text not null` / `uuid` | **Server-owned** | Resolved by the server from the canonical item/target version record |
| **`task_profile`** & **`strategy_version`** | `jsonb not null` / `text` | **Server-owned** | Resolved by the server from canonical item metadata (`LearningTaskProfile`) |
| **`presented_option_ids`** | `text[]` | **Trust depends on issuance mode** (See §2.2) | Ordered array of stable `option_id` values. Server validates that the array is a valid permutation of the item's option IDs; however, **set-permutation validation alone only proves valid option IDs, not that the client actually displayed that order**. Considered **trusted audit order (`server_issued`)** only when bound to a server-issued presentation/attempt record; otherwise labeled **`untrusted_client_reported` metadata** |
| **`learner_response`** | `jsonb not null` | Client-submitted | Selected `option_id`(s), free-recall text, or numeric/unit entry |
| **`scored_outcome`** | `jsonb` | **Server-owned** | Calculated authoritatively on the server against protected `scoring_spec` |
| **`client_latency_ms`** | `integer not null` | Client-submitted (**Untrusted client timing**) | Explicitly labeled as **untrusted client-reported elapsed milliseconds (`>= 0`)**; never used for timed-exam enforcement or high-stakes scoring |
| **`server_elapsed_ms`** | `integer` | **Server-owned** (**Required for timed/high-stakes**) | Computed on the server (`received_at - attempt_issued_at`) from a server-issued attempt/assignment start timestamp; **required for all timing-critical or high-stakes assessment decisions** |
| **`assistance_provided`** | `jsonb not null` | Client-submitted, **Server-validated** | Hints viewed, worked-example fading stage, or audio/text cues revealed |
| **`learner_confidence`** | `smallint` | Client-submitted (Optional) | Self-reported metacognitive rating (`1=low, 2=medium, 3=high`), kept distinct from `user_concept_state.confidence` |
| **`fsrs_rating`** | `smallint` | Client-submitted / Server-validated (Memory cards only) | `1=Again, 2=Hard, 3=Good, 4=Easy` — populated **only** when `event_type == 'memory_card_review'`; `null` for non-SRS tasks |
| **`scheduler_version`** | `text` | **Server-owned** | `'v1_sm2_ladder'` or `'v2_fsrs6'` (standardized identifier across all docs) |
| **`scheduler_state_before`** & **`scheduler_state_after`** | `jsonb` | **Server-owned** | Authoritative scheduler transition computed by the server; never trusted from client |
| **`provenance_snapshot`** | `jsonb not null` | **Server-owned** | Captures **all six** provenance properties (`origin`, `visibility`, `rights_status`, `review_status`, `source_authority`, `version_validity`) from the canonical item record |
| **`assessment_conditions`** | `jsonb not null` | **Server-owned** | Captures the complete active `AssessmentPolicy` (`timing_regime`, `error_criticality`, `scoring_protection`) and `reference_policy` so assessment conditions are fully reproducible |

### 2.2 Critical Trust Qualifications on `presented_option_ids` and Timing (`client_latency_ms` vs. `server_elapsed_ms`)
1. **Why Permutation Validation Alone Does Not Prove Displayed Order**:
   - Checking on the server that `presented_option_ids` contains the exact same set of `option_id` values as the canonical item prevents invalid option IDs, but a modified client could still submit any valid permutation.
   - Therefore, in low-stakes client-shuffled practice where no server presentation token was issued beforehand, `presented_option_ids` is stored as **untrusted client-reported presentation metadata (`untrusted_client_reported`)**.
   - Whenever presentation order must be trusted as authoritative audit data (e.g., high-stakes diagnostics, mock exams, or position-effect calibration), the server must **issue or sign the presentation permutation when delivering the Learner Presentation DTO (`attempt_id`)** and verify `presented_option_ids` against that server-issued record upon submission.
2. **Authoritative Timing Requires `server_elapsed_ms`**:
   - `client_latency_ms` is untrusted client-reported telemetry and must never govern timed exam cutoffs, paced pass/fail criteria, or high-stakes readiness scores.
   - Any timing-critical or high-stakes assessment (`timing_regime == 'exam_clock_enforced'` or `'paced_practice'` used for readiness) must record a server-side `attempt_issued_at` / `started_at` timestamp and evaluate elapsed time using server-computed **`server_elapsed_ms`**.

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

## 4. Accurate `EXM-03` Architecture on `main` & Reconciling `user_concept_state`

### 4.1 Complete 3-Migration `EXM-03` Surface on `main` (`e538585`)
On `main`, the `EXM-03` assigned exam-part practice workflow comprises **three guarded migrations**:
1. [`supabase/migrations/20261101130000_exm_03_assigned_practice_scoring.sql`](../../supabase/migrations/20261101130000_exm_03_assigned_practice_scoring.sql): Creates `public.exam_part_practice_assignments` and `public.exam_part_practice_attempts`, plus the private canonical scorer `public.exm03_record_assigned_practice` (`service_role`-only execution).
2. [`supabase/migrations/20261101140000_exm_03_authenticated_assignment_issuer.sql`](../../supabase/migrations/20261101140000_exm_03_authenticated_assignment_issuer.sql): Provides the authenticated assignment issuer **`public.exm03_issue_assigned_practice(p_target_version_id uuid, p_exam_part_key text)`**, which creates a quota-bound assignment and returns a safe item projection with `scoring_spec`, `correct_index`, and answer-revealing fields stripped.
3. [`supabase/migrations/20261101150000_exm_03_authenticated_submit_protected_items.sql`](../../supabase/migrations/20261101150000_exm_03_authenticated_submit_protected_items.sql):
   - Provides the **authenticated, session- and owner-bound submission wrapper `public.exm03_submit_assigned_practice(p_assignment_id uuid, p_responses jsonb)`** (which verifies `auth.uid()` ownership and active JWT session binding before delegating to `public.exm03_record_assigned_practice`).
   - Enforces the restrictive RLS policy **`exm03_no_direct_read_of_approved_answers` on `public.assessment_items`**, preventing authenticated clients from directly `SELECT`ing rows that belong to an approved `EXM-02A` item review (`public.exm02a_item_reviews`), while **non-EXM assessment items remain readable on `main` until general Phase 1 `FIX-12` answer-key isolation is implemented**.
   - **Important Boundary (`EXM-03` Does Not Update `user_concept_state`)**: `public.exm03_record_assigned_practice` and `public.exm03_submit_assigned_practice` write scored attempt rows to `public.exam_part_practice_attempts`; they **do not** write to or update `public.user_concept_state`. `EXM-03` remains a dedicated assigned-practice workflow unless an explicit concept-projection integration migration is introduced in a future phase.

### 4.2 Reconciling `ConceptEvidenceService` and `user_concept_state` on `main`
Inspection of `main` (`e538585`) confirmed two issues to resolve in Phase 1 (`ARCH-1`):
1. [`lib/services/concept_evidence_service.dart`](../../lib/services/concept_evidence_service.dart) currently performs client-side select-then-upsert operations on `public.user_concept_state`.
2. [`supabase/migrations/20260925000001_v2_additive_schema.sql`](../../supabase/migrations/20260925000001_v2_additive_schema.sql) grants authenticated owners `FOR ALL` (`SELECT, INSERT, UPDATE, DELETE`) on `user_concept_state`, conflicting with `LEARNING_ARCHITECTURE_V2.md` §3.4's rule that `user_concept_state` is a server-maintained projection.

### Required Migration & Service Fix
1. **Server-Controlled Projection**:
   - Revoke direct client `INSERT`, `UPDATE`, and `DELETE` RLS policies on `public.user_concept_state` (retaining owner `SELECT` and authenticated owner erasure RPCs).
   - Update `user_concept_state` inside server-validated `record_events` projection logic (and keep `EXM-03` separate unless a dedicated projection bridge is explicitly added).
2. **Preserve the Distinction Between Three "Confidence" Concepts**:
   - **`user_concept_state.confidence` (Observation-Count Sufficiency Band)**: On `main`, this field is derived from evidence count ($\ge 2$ observations $\to$ `medium`, $\ge 5 \to$ `high`). It is **not** a statistical confidence interval and must remain clearly distinguished from both:
   - **`learner_confidence` (Metacognitive self-report)**: The learner's subjective certainty on a single attempt (`1..3`).
   - **Statistical Uncertainty ($\text{SE}$ / Credible Interval)**: The standard error of an empirical psychometric estimate.

---

## 5. FSRS-6 Integration Rules (`package:fsrs` v2.0.1 — `v2_fsrs6`)

`package:fsrs` `2.0.1` implements **FSRS-6** (verified in package changelog v2.0.0+; `ER-09c` Technical Implementation Reference). All documents standardize on the version identifier **`v2_fsrs6`**:

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
