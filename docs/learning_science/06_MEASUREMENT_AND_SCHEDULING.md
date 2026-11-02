# 06 — Measurement, Event History (`learning_events`) & Versioned FSRS-6 Scheduling

This specification defines the **client vs. server security trust boundary** for the proposed `public.learning_events` ledger and `record_events` RPC, reconciles the `user_concept_state` projection discrepancy on `main` (`a23cebb`, unchanged from historical audit baseline `e538585`), documents the complete `EXM-03` scoring surface, and enforces strict separation between **FSRS-6 memory card ratings**, **concept evidence**, **reference-navigation telemetry**, and **scored assessment results**.

> **Implementation Status Note**: Neither `public.learning_events` nor `record_events` exists on the `main` (`a23cebb`, following the merge of PR `#136`) baseline. They are **proposed Phase 1 (`ARCH-1`) specifications** designed to be implemented via guarded migrations.
>
> **Alignment & Supersession of Summary Sketches in `/ARCHITECTURE_REVIEW.md`**:
> `/ARCHITECTURE_REVIEW.md` serves as the Phase 0 architectural audit, while **`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md` and `/docs/learning_science/01..08` provide the full normative specifications**:
> 1. **`presented_option_ids: text[]`** supersedes `presented_order` (`List<int>`).
> 2. **`fsrs_rating`** (`1..4`, populated **only** on `memory_card_review` events) is kept strictly separate from **`learner_confidence`** (`1..3` metacognitive self-report) and from `user_concept_state.confidence` (observation-count sufficiency band).
> 3. **FSRS-6 (`scheduler_version = 'v2_fsrs6'`)** models individual memory-card retrievability $R(t)$ only—it is never equated with multi-facet concept mastery or exam readiness, never initialized by fabricating parameters from SM-2 counters or `ContentComplexityProfile` priors, and kept separate from exam-date daily workload planning.
> 4. **Offline Provisional vs. Server-Canonical Scheduling, Server-Computed Digest, Intra-Batch Preflight & Transaction Serialization (§2.4)**: On-device FSRS computes provisional local schedule state for offline responsiveness, while server `record_events` acquires transaction-scoped locks on `(user_id, idempotency_key)` (serializing concurrent retries or cross-session collisions for the same key), `(user_id, session_id)`, and affected `(user_id, item_id)` / `(user_id, concept_id)` streams; runs an **intra-batch preflight** on `idempotency_key` (deduplicating same-key + same-digest + identical-`id` occurrences as retries while rejecting/quarantining all occurrences of any new same-key group with conflicting `v_payload_sha256` or mismatched `id` with `idempotency_payload_mismatch` so neither conflicting entry or `id` wins by input order); deterministically sorts remaining batch items by `(session_id ASC, client_seq ASC, idempotency_key ASC)` independent of request array order; evaluates `UNIQUE (user_id, idempotency_key)` **first** (comparing a **server-computed `payload_sha256` via `encode(digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'), 'hex')` over the 13 semantic event-payload fields** against the stored digest before running sequence or timestamp checks so delayed retries always return `duplicate_noop`); and—only for new keys—enforces `UNIQUE (user_id, session_id, client_seq)`, validates `client_occurred_at` against the **joint feasibility of the 14-day plausibility window and bidirectional per-session `(session_id, client_seq)` non-decreasing neighbor bounds**, and executes the event insert (`INSERT ... ON CONFLICT (user_id, idempotency_key) DO NOTHING`) and deterministic projection replay (`(effective_occurred_at ASC, session_id ASC, client_seq ASC, id ASC)`) atomically inside a per-item PL/pgSQL **`BEGIN ... EXCEPTION ... END` subtransaction block** (converting only recognized item-level failures into documented item statuses and re-raising unexpected errors via `WHEN OTHERS THEN RAISE;`).

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

To prevent clients from forging scores, scheduler states, payload digests, user identities, timing, or provenance attributes, the `record_events` RPC enforces a strict **Client-Submitted vs. Server-Owned Trust Boundary**:

### 2.1 Client-Submitted vs. Server-Owned Contract Table

| Field | Type | Trust Ownership | Validation & Derivation Rule |
|---|---|---|---|
| **`id`** | `uuid primary key` | Client-submitted | Client-generated UUIDv7 row identifier; validated for format, persisted durably alongside `idempotency_key` in the local outbox row, and reused verbatim across network retries. Excluded from `payload_sha256` (which hashes the 13 semantic event-payload fields); intra-batch duplicate keys with mismatched `id` values are quarantined in preflight (§2.4) |
| **`idempotency_key`** | `text not null` (`UNIQUE (user_id, idempotency_key)`) | Client-submitted, **User-scoped uniqueness, lock serialization & durable retry reuse** | UUIDv4 generated **once** when the logical event is created, persisted durably in the local outbox row, and **reused verbatim across all network retries**. Protected by a user-scoped transaction advisory lock `(user_id, idempotency_key)`, intra-batch preflight conflict quarantine (`COUNT(DISTINCT v_payload_sha256) > 1 OR COUNT(DISTINCT id) > 1`), pre-validation lookup, and atomic `INSERT ... ON CONFLICT (user_id, idempotency_key) DO NOTHING` fallback (§2.4) |
| **`payload_sha256`** | `text not null` | **Server-computed (Authoritative canonical event-payload digest)** | Computed **independently by the server** via `encode(digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'), 'hex')` where `v_canonical_payload` is a server-constructed **`jsonb`** object (`jsonb_build_object(...)`) containing the **13 immutable client-controlled semantic event-payload fields** (`session_id`, `client_seq`, `attempt_id`, `event_type`, `content_id`, `item_id`, `presented_option_ids`, `learner_response`, `fsrs_rating`, `assistance_provided`, `learner_confidence`, `client_latency_ms`, `client_occurred_at_utc_iso`), intentionally excluding envelope row/retry identifiers `id` and `idempotency_key`. Uses PostgreSQL's native `jsonb::text` representation as the server-only canonical format. Checked **prior to** sequence/timestamp validation (and after any `ON CONFLICT` fallback): if `(user_id, idempotency_key)` exists with a **matching** `payload_sha256`, `record_events` immediately returns `status = 'duplicate_noop'`; if it exists with a **different** `payload_sha256` (or appears multiple times in the same batch with conflicting digests or mismatched `id`s), `record_events` immediately rejects and flags the item (`status = 'idempotency_payload_mismatch'`) (§2.4) |
| **`user_id`** | `uuid not null` | **Server-owned** | Derived strictly from `auth.uid()`; never accepted from client payload |
| **`event_type`** | `text not null` | Client-submitted, **Server-validated** | Enum (`memory_card_review`, `concept_practice_attempt`, `scaffolded_step_attempt`, `diagnostic_attempt`); validated against item type |
| **`event_schema_version`** | `text not null` | **Server-enforced** | Version of the `public.learning_events` envelope schema (e.g., `'1.0.0'`), tracked independently from curriculum/item metadata schema evolution |
| **`metadata_schema_version`** | `text not null` | **Server-enforced** | Version of the curriculum/item metadata contract used to populate `task_profile` and `provenance_snapshot` (`'1.0-phase1-derived'` in Phase 1 before full manifest `2.1.0` migration; `'2.1.0'` once catalog items carry explicit `2.1.0` metadata; see §2.3) |
| **`session_id`** | `uuid not null` | Client-submitted, **Device-specific & Server-validated** | Client-generated UUIDv4/v7 created locally **per device and study session** when a study, review, or assessment session begins (never shared across devices; allows offline sessions to generate a valid `session_id` without a prior server round-trip) |
| **`client_seq`** | `integer not null` (`>= 1`, `CONSTRAINT learning_events_user_session_seq_key UNIQUE (user_id, session_id, client_seq)`) | Client-submitted, **Strictly increasing per-session sequence with named composite uniqueness constraint** | Strictly increasing 1-based sequence number (`1, 2, 3, ...`) assigned within each `(user_id, session_id)` by the local outbox. Enforces **`CONSTRAINT learning_events_user_session_seq_key UNIQUE (user_id, session_id, client_seq)`** so two distinct logical events (with different `idempotency_key`s) cannot share the same sequence slot; a colliding new `idempotency_key` is rejected (`status = 'sequence_conflict'`, §2.4) |
| **`attempt_id`** | `uuid null` | **Conditional by assessment mode** | **Nullable (`uuid`)**: required (`NOT NULL`) and verified against an active server-issued assignment/attempt record owned by `auth.uid()` when `assessment_conditions.scoring_protection == 'server_protected_scoring'` (e.g., `EXM-03`, diagnostics, timed mocks); `NULL` (or optional local group UUID) for standalone/offline `memory_card_review` and unissued low-stakes practice |
| **`client_occurred_at`** | `timestamptz not null` | Client-submitted (**Untrusted client clock, bounded validation**) | Client-recorded UTC timestamp when the review/attempt occurred; validated against the **joint feasibility** of the server plausibility window and bidirectional per-session `(session_id, client_seq)` non-decreasing neighbor bounds to derive `effective_occurred_at` (see §2.4) |
| **`received_at`** | `timestamptz not null` | **Server-owned** | Set to server `now()` (UTC); authoritative for **ledger ingestion audit time** and **timed/high-stakes assessment cutoffs (`server_elapsed_ms`)** |
| **`effective_occurred_at`** | `timestamptz not null` | **Server-derived (Bounded scheduling input)** | Bounded timestamp used for **FSRS-6 elapsed-interval calculations ($t$)**: computed only after verifying that the 14-day plausibility window and **bidirectional** `(session_id, client_seq)` neighbor bounds (`prev_effective_ts` for `client_seq < current` and `next_effective_ts` for `client_seq > current`) have a non-empty intersection (otherwise rejected/quarantined with `status = 'rejected_window_neighbor_conflict'`; see §2.4). **Trust qualification**: preserves plausible client-reported offline intervals for ordinary memory scheduling, but is **not** trusted timing evidence |
| **`content_id`** & **`item_id`** | `uuid not null` | Client-submitted, **Server-validated** | Verified to exist and be accessible to `auth.uid()` |
| **`content_version`** & **`target_version_id`** | `text not null` / `uuid` | **Server-owned** | Resolved by the server from the canonical item/target version record |
| **`task_profile`** & **`strategy_version`** | `jsonb not null` / `text` | **Server-owned** | Resolved by the server from explicit item `learning_task_profile` when populated (`profile_source = 'manifest_v2_1'`), or deterministically derived in Phase 1 from existing item columns (`item_type`, `practice_kind`, modality/EXM tables; `profile_source = 'phase1_server_derived'`; see §2.3) |
| **`presented_option_ids`** | `text[]` | **Trust depends on issuance mode** (See §2.2) | Ordered array of stable `option_id` values. Server validates that the array is a valid permutation of the item's option IDs; however, **set-permutation validation alone only proves valid option IDs, not that the client actually displayed that order**. Considered **trusted audit order (`server_issued`)** only when bound to a server-issued presentation/attempt record; otherwise labeled **`untrusted_client_reported` metadata** |
| **`learner_response`** | `jsonb not null` | Client-submitted | Selected `option_id`(s), free-recall text, or numeric/unit entry |
| **`scored_outcome`** | `jsonb` | **Server-owned** | Calculated authoritatively on the server against protected `scoring_spec` |
| **`client_latency_ms`** | `integer not null` | Client-submitted (**Untrusted client timing**) | Explicitly labeled as **untrusted client-reported elapsed milliseconds (`>= 0`)**; never used for timed-exam enforcement or high-stakes scoring |
| **`server_elapsed_ms`** | `integer` | **Server-owned** (**Required for timed/high-stakes**) | Computed on the server (`received_at - attempt_issued_at`) from a server-issued attempt/assignment start timestamp; **required for all timing-critical or high-stakes assessment decisions** |
| **`assistance_provided`** | `jsonb not null` | Client-submitted, **Server-validated** | Hints viewed, worked-example fading stage, or audio/text cues revealed |
| **`learner_confidence`** | `smallint` | Client-submitted (Optional) | Self-reported metacognitive rating (`1=low, 2=medium, 3=high`), kept distinct from `user_concept_state.confidence` |
| **`fsrs_rating`** | `smallint` | Client-submitted / Server-validated (Memory cards only) | `1=Again, 2=Hard, 3=Good, 4=Easy` — populated **only** when `event_type == 'memory_card_review'`; `null` for non-SRS tasks |
| **`scheduler_version`** | `text` | **Server-owned** | `'v1_sm2_ladder'` or `'v2_fsrs6'` (standardized identifier across all docs) |
| **`scheduler_state_before`** & **`scheduler_state_after`** | `jsonb` | **Server-owned (Canonical)** | Authoritative scheduler transition computed by the server over the canonical `(effective_occurred_at ASC, session_id ASC, client_seq ASC, id ASC)` event stream under transaction-level entity lock protection (reconciling any provisional local offline schedule; see §2.4) |
| **`provenance_snapshot`** | `jsonb not null` | **Server-owned** | Captures **all six** provenance properties (`origin`, optional `origin_client_id`, `visibility`, `rights_status`, `review_status`, `source_authority`, `version_validity`) from explicit item metadata (`provenance_source = 'manifest_v2_1'`) or Phase 1 deterministic server derivation (`provenance_source = 'phase1_server_derived'`; see §2.3) |
| **`assessment_conditions`** | `jsonb not null` | **Server-owned** | Captures the complete active `AssessmentPolicy` (`timing_regime`, `error_criticality`, `scoring_protection`) and `reference_policy` so assessment conditions are fully reproducible |

### 2.2 Critical Trust Qualifications on `presented_option_ids` and Timing (`client_latency_ms` vs. `server_elapsed_ms`)
1. **Why Permutation Validation Alone Does Not Prove Displayed Order**:
   - Checking on the server that `presented_option_ids` contains the exact same set of `option_id` values as the canonical item prevents invalid option IDs, but a modified client could still submit any valid permutation.
   - Therefore, in low-stakes client-shuffled practice where no server presentation token was issued beforehand, `presented_option_ids` is stored as **untrusted client-reported presentation metadata (`untrusted_client_reported`)**.
   - Whenever presentation order must be trusted as authoritative audit data (e.g., high-stakes diagnostics, mock exams, or position-effect calibration), the server must **issue or sign the presentation permutation when delivering the Learner Presentation DTO (`attempt_id`)** and verify `presented_option_ids` against that server-issued record upon submission.
2. **Authoritative Timing Requires `server_elapsed_ms`**:
   - `client_latency_ms` is untrusted client-reported telemetry and must never govern timed exam cutoffs, paced pass/fail criteria, or high-stakes readiness scores.
   - Any timing-critical or high-stakes assessment (`timing_regime == 'exam_clock_enforced'` or `'paced_practice'` used for readiness) must record a server-side `attempt_issued_at` / `started_at` timestamp and evaluate elapsed time using server-computed **`server_elapsed_ms`**.

### 2.3 Phase 1 (`ARCH-1`) vs. Phase 2 (`ARCH-5`) Metadata & Snapshot Contract
Because `public.learning_events` ships in **Phase 1 (`ARCH-1`)** while the `curriculum_manifest.schema.json` `2.1.0` authoring enforcement ships in **Phase 2 (`ARCH-5`)**, the database and `record_events` RPC keep the event envelope version (`event_schema_version = '1.0.0'`) separate from the curriculum/item metadata contract version (`metadata_schema_version`):
1. **Phase 1 Database Columns & Deterministic Server Derivation (`event_schema_version = '1.0.0'`, `metadata_schema_version = '1.0-phase1-derived'`)**:
   - The Phase 1 `learning_events` migration adds nullable/defaulted metadata columns (`learning_task_profile jsonb`, `provenance_metadata jsonb`, `complexity_assessment_status`, `item_psychometric_status`, `readiness_validation_status`) on canonical item tables alongside `public.learning_events`.
   - When an item row does not yet have explicit `2.1.0` `learning_task_profile` or `provenance_metadata` populated, `record_events` sets `metadata_schema_version = '1.0-phase1-derived'` and deterministically derives both snapshots on the server from existing `main` (`a23cebb`) catalog columns:
     - **`task_profile`**: Derived from `item_type`, `practice_kind`, and domain table context (`exm` open-book manifest vs. closed-book, audio literacy vs. visual text) and tagged with `"profile_source": "phase1_server_derived"`.
     - **`provenance_snapshot`**: Derived from existing pack/item columns (`origin` mapped from pack source type, `origin_client_id: null`, `visibility` from pack visibility, `rights_status` from pack license or `'rights_review_required'`, `review_status` from `exm02a_item_reviews` / `eco02` editorial state or `'unreviewed'`, `source_authority` from citation tier, and `version_validity` from `target_versions`), tagged with `"provenance_source": "phase1_server_derived"`.
2. **Phase 2 Manifest `2.1.0` Enforcement & Catalog Backfill (`event_schema_version = '1.0.0'`, `metadata_schema_version = '2.1.0'`)**:
   - Phase 2 updates `curriculum_manifest.schema.json` to `2.1.0` ([`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](08_CONTENT_AND_IMPORT_ALIGNMENT.md)), backfills explicit `learning_task_profile` and 6-property `provenance_metadata` across existing catalog items (`metadata_schema_version = '2.1.0'`, `"profile_source": "manifest_v2_1"`, `"provenance_source": "manifest_v2_1"`), and leaves historical Phase 1 `learning_events` rows immutable with their `"1.0-phase1-derived"` metadata snapshot tags preserved.

### 2.4 Offline Reviews, Server-Computed Digest, Intra-Batch Preflight, Transaction Locks, Joint Window/Neighbor Validation (`effective_occurred_at`) & Replay
To support offline reviews (`ARCH-3`) without corrupting FSRS intervals when offline batches sync hours or days later—while preventing idempotency digest forgery, cross-session concurrent idempotency races, intra-batch duplicate-key ambiguity, request-order sensitivity, and conflicting timestamp bounds:
1. **Local Provisional Schedule & Server-Computed Event-Payload Digest (`payload_sha256`)**:
   - During offline study, on-device `package:fsrs` computes **provisional local schedule state** (`provisional_scheduler_state_after`) in the local outbox/cache (`hive_ce` / `drift`) so the learner's review queue updates immediately offline.
   - Each logical event is assigned a client-generated row `id` (UUIDv7), a retry `idempotency_key` (UUIDv4), a **device-specific `session_id`**, and a **strictly increasing** per-session **`client_seq` (`1, 2, 3, ...`)** **once at event creation**, persisted durably in the local outbox row and reused verbatim across network retries. (The client may also store a local outbox digest for client-side diagnostics, but **the server never trusts a client-supplied digest**.)
   - **Server-Computed Canonical Payload Digest (`payload_sha256`) & Explicit Exclusion of Envelope Identifiers**: For every incoming event item, `record_events` constructs a server-side **`v_canonical_payload jsonb`** object (`jsonb_build_object(...)`) over the **13 immutable, client-controlled semantic event-payload fields** and computes `payload_sha256` in PostgreSQL using `pgcrypto`:
     ```sql
     v_payload_sha256 := encode(
       digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'),
       'hex'
     );
     ```
     - **Included Semantic Payload Fields (13 fields)**: `session_id`, `client_seq`, `attempt_id`, `event_type`, `content_id`, `item_id`, `presented_option_ids`, `learner_response`, `fsrs_rating`, `assistance_provided`, `learner_confidence`, `client_latency_ms`, and normalized `client_occurred_at_utc_iso`.
     - **Explicit Exclusion of `id` and `idempotency_key`**: The client-submitted row primary key `id` (UUIDv7) and retry identifier `idempotency_key` (UUIDv4) are **intentionally excluded** from `v_canonical_payload`: `idempotency_key` is the lookup key that identifies the retry attempt, whereas `payload_sha256` hashes the semantic event payload attached to that key to detect whether a retry key was reused with different event data.
     - **Server-Only PostgreSQL `jsonb::text` Canonical Representation (Not RFC 8785 JCS)**: Before building `v_canonical_payload jsonb`, `record_events` normalizes `client_occurred_at` to UTC ISO-8601 microsecond precision (`to_char(client_occurred_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')`), represents omitted nullable fields (`attempt_id`, `presented_option_ids`, `fsrs_rating`, `learner_confidence`) as explicit JSON `null`, and preserves array element order in `presented_option_ids` (`to_jsonb(presented_option_ids)`) and `assistance_provided`. `v_canonical_payload::text` uses **PostgreSQL's native `jsonb` text serialization as the server-only canonical representation** (note: PostgreSQL `jsonb` orders object keys by key length first and then bytewise, and preserves numeric trailing zeros, so it is **not** equivalent to RFC 8785 JCS; because `payload_sha256` is both computed and compared exclusively on the server in PostgreSQL, `v_canonical_payload::text` is completely deterministic without requiring cross-platform JCS serialization).
2. **Transaction-Level Concurrency Serialization (Including User-Scoped Idempotency Locks), Intra-Batch Preflight & Deterministic Server-Side Batch Ordering**:
   - Without user-scoped idempotency locks, two concurrent transactions submitting the same `(user_id, idempotency_key)` under different `session_id` values (`S1` vs. `S2`) would acquire different session locks, both observe no existing row during lookup, and race into `INSERT`—raising an unhandled unique-constraint error instead of returning `duplicate_noop` or `idempotency_payload_mismatch`. Similarly, if a single batch contains duplicate `idempotency_key` entries with different payloads or different row `id` UUIDs, sorting by `(session_id, client_seq, idempotency_key)` alone would lack a deterministic rule and could let one conflicting payload or `id` win depending on input order.
   - Therefore, `record_events(p_events jsonb[])` enforces **upfront user-scoped idempotency + session + entity lock acquisition, intra-batch duplicate-key preflight, and deterministic server-side batch sorting** before evaluating any item:
     1. **Sorted Transaction-Scoped Advisory Lock Acquisition (`idempotency_key`, `session_id`, `item_id`, `concept_id`)**: Extract the distinct `idempotency_key`s, `session_id`s, `item_id`s, and `concept_id`s referenced in `p_events` for `v_user_id := auth.uid()`, sort each set lexicographically to prevent deadlocks, and acquire transaction-scoped advisory locks upfront:
        ```sql
        PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':idempotency:' || v_idempotency_key, 0));
        PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':session:' || v_session_id::text, 0));
        PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':item:' || v_item_id::text, 0));
        PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':concept:' || v_concept_id::text, 0));
        ```
        Acquiring `pg_advisory_xact_lock` on `(user_id, idempotency_key)` serializes any two concurrent transactions submitting the same `idempotency_key` for the same user—even across different `session_id`s—until the first transaction's event and projection writes commit.
     2. **Intra-Batch Duplicate `idempotency_key` Preflight Rule (Order-Independent Deduplication, `id` Consistency & Conflict Quarantine)**: Unnest `p_events WITH ORDINALITY AS t(item_json, input_idx)`, compute `v_payload_sha256` for every element, and group by `idempotency_key` within the batch before running per-item validation:
        - **Same `idempotency_key` + Same `v_payload_sha256` + Identical `id` within the batch (`COUNT(DISTINCT v_payload_sha256) = 1 AND COUNT(DISTINCT id) = 1`, `COUNT(*) > 1`)**: Because a legitimate outbox retry reuses both `id` (UUIDv7) and `idempotency_key` (UUIDv4) from the same durable outbox row, identical `(idempotency_key, v_payload_sha256, id)` tuples represent a valid intra-batch retry. Select a single canonical representative deterministically (`ORDER BY id ASC LIMIT 1`, where all candidate `id`s, digests, and semantic fields in the group are identical and therefore independent of `input_idx`) to enter the sorted validation/insert pipeline; all duplicate occurrences in the batch are marked `status = 'duplicate_noop'` and inherit the canonical representative's resolved `event_id` and `effective_occurred_at` (or rejection status if the canonical representative is rejected).
        - **Same `idempotency_key` + Conflicting `v_payload_sha256` OR Mismatched `id` within the batch (`COUNT(DISTINCT v_payload_sha256) > 1 OR COUNT(DISTINCT id) > 1`)**: Because `id` is excluded from `v_canonical_payload`, two entries in the same batch that share an `idempotency_key` while supplying either different semantic payloads or different envelope `id` UUIDs are conflicting/malformed retry envelopes, and neither entry is permitted to win by input order. If `(v_user_id, v_idempotency_key)` does **not** already exist in `public.learning_events`, **every** occurrence of that `idempotency_key` in the batch is quarantined and rejected with `status = 'idempotency_payload_mismatch'` without inserting any row or mutating projections. If `(v_user_id, v_idempotency_key)` already exists in `public.learning_events`, any occurrence whose `v_payload_sha256` matches the already-stored `payload_sha256` returns `status = 'duplicate_noop'` (returning the already-persisted `learning_events.id` and `effective_occurred_at`) and any occurrence whose digest differs returns `status = 'idempotency_payload_mismatch'`. This guarantees that the persisted `learning_events.id` and all batch outcomes are strictly independent of request array order.
     3. **Deterministic Server-Side Batch Sorting (`(session_id ASC, client_seq ASC, idempotency_key ASC)`)**: Sort all non-quarantined candidate items on the server by **`(session_id ASC, client_seq ASC, idempotency_key ASC)`** prior to sequential processing (preserving `input_idx` so the returned per-item status array is ordered back to `input_idx ASC` for caller correlation). Because Step 2 has already deduplicated identical `(idempotency_key, v_payload_sha256, id)` retries and quarantined any conflicting intra-batch duplicate keys, `(session_id, client_seq, idempotency_key)` is strictly unique across all remaining candidate items, and a batch containing `(seq = 1, 10:07)` and `(seq = 2, 10:05)` in any request array order always evaluates `seq = 1` (`10:07`) first and clamps `seq = 2` upward to `10:07` (`clamp_reason = 'preceding_seq_bound'`).
3. **Exact Per-Item Order of Operations (Idempotency Lookup Prioritized Before Sequence & Timestamp Validation, Plus Atomic `BEGIN ... EXCEPTION ... END` Insert/Projection Subtransaction)**:
   - If a legitimate network retry of a previously accepted event arrives hours or days later—after the server plausibility window or session neighbor bounds have advanced—running timestamp or sequence validation before checking `idempotency_key` could falsely reject a retry of an already-committed event. Therefore, for each candidate item in `(session_id ASC, client_seq ASC, idempotency_key ASC)` order (under the `(user_id, idempotency_key)` and `(user_id, session_id)` transaction advisory locks), `record_events` executes the following exact 5-step sequence:
     - **Step 1 — Use Precomputed Server-Side Payload Digest**: Retrieve `v_canonical_payload jsonb` and `v_payload_sha256 = encode(digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'), 'hex')` computed during batch preflight.
     - **Step 2 — Lookup `(user_id, idempotency_key)` First**: Query `public.learning_events` for an existing row matching `(v_user_id, v_idempotency_key)`.
     - **Step 3 — Matching Digest $\to$ Immediate `duplicate_noop`**: If an existing row is found and its stored `payload_sha256` equals `v_payload_sha256`, immediately record `status = 'duplicate_noop'` (returning the existing row's persisted `id` and `effective_occurred_at`) and **skip Steps 4–5**.
     - **Step 4 — Mismatched Digest $\to$ Immediate `idempotency_payload_mismatch`**: If an existing row is found and its stored `payload_sha256` differs from `v_payload_sha256` (e.g., the same `idempotency_key` was reused with a modified `fsrs_rating`, `learner_response`, or `client_seq`), immediately reject the item with `status = 'idempotency_payload_mismatch'` (so the client outbox quarantines the collision) and **skip Step 5**.
     - **Step 5 — New Key Only $\to$ Sequence-Conflict, Joint Window/Neighbor Timestamp Validation & Atomic `BEGIN ... EXCEPTION ... END` Subtransaction Write**: Only when `(v_user_id, v_idempotency_key)` does **not** exist in `public.learning_events`:
       1. **Check `CONSTRAINT learning_events_user_session_seq_key UNIQUE (user_id, session_id, client_seq)`**: If `(v_user_id, v_session_id, v_client_seq)` already exists in `public.learning_events` (necessarily under a different `idempotency_key`), reject and quarantine the item with `status = 'sequence_conflict'` without mutating projections.
       2. **Evaluate Joint Feasibility of the 14-Day Plausibility Window & Bidirectional Neighbor Bounds (`effective_occurred_at`)**:
          - **Explicit Trust Boundary**: `received_at` (`now()` UTC) and `server_elapsed_ms` remain strictly authoritative for **audit arrival time** and **all timed/high-stakes assessments**. By contrast, **`effective_occurred_at`** is a **bounded, best-effort scheduling input** designed to **preserve plausible client-reported offline intervals** for ordinary memory scheduling (`review_items`), and is **never treated as trusted timing evidence**.
          - Define the plausibility window $[W_{\min}, W_{\max}] = [\text{received\_at} - \text{interval '14 days'},\ \text{received\_at} + \text{interval '5 minutes'}]$.
          - Query the bidirectional session neighbors across already-persisted rows in `public.learning_events` (including earlier items inserted during the current batch):
            $$t_{\text{prev}} = \max_{\text{seq} < \text{client\_seq}} \text{effective\_occurred\_at}, \qquad t_{\text{next}} = \min_{\text{seq} > \text{client\_seq}} \text{effective\_occurred\_at}$$
          - **5a — Corrupted Neighbor Bounds Check**: If both $t_{\text{prev}}$ and $t_{\text{next}}$ exist and $t_{\text{prev}} > t_{\text{next}}$, reject and quarantine the item (`status = 'rejected_ordering_conflict'`).
          - **5b — Joint Window–Neighbor Feasibility Check**: Compute the feasible interval intersection $[F_{\min}, F_{\max}] = [\max(W_{\min}, t_{\text{prev}}),\ \min(W_{\max}, t_{\text{next}})]$ (using $W_{\min}$ when $t_{\text{prev}}$ is absent and $W_{\max}$ when $t_{\text{next}}$ is absent). **If $F_{\min} > F_{\max}$** (for example, $t_{\text{next}} < W_{\min}$ because the succeeding sequence was recorded more than 14 days ago, or $t_{\text{prev}} > W_{\max}$), the 14-day plausibility window and bidirectional non-decreasing neighbor ordering **cannot both be satisfied**. `record_events` **rejects and quarantines** the event (`status = 'rejected_window_neighbor_conflict'`) without inserting into `public.learning_events` or mutating projections.
          - **5c — Candidate Plausibility Check & Neighbor Clamp within $[F_{\min}, F_{\max}]$**: When $F_{\min} \le F_{\max}$:
            - If `client_occurred_at` falls outside $[W_{\min}, W_{\max}]$, set candidate $t_{\text{cand}} = \text{received\_at}$ and `timestamp_clamped = true` (`clamp_reason = 'plausibility_window'`); otherwise set $t_{\text{cand}} = \text{client\_occurred\_at}$.
            - Clamp $t_{\text{cand}}$ into $[t_{\text{prev}}, t_{\text{next}}]$:
              - If $t_{\text{prev}}$ exists and $t_{\text{cand}} < t_{\text{prev}}$, set $\text{effective\_occurred\_at} = t_{\text{prev}}$ and `timestamp_clamped = true` (`clamp_reason = 'preceding_seq_bound'`).
              - Else if $t_{\text{next}}$ exists and $t_{\text{cand}} > t_{\text{next}}$, set $\text{effective\_occurred\_at} = t_{\text{next}}$ and `timestamp_clamped = true` (`clamp_reason = 'succeeding_seq_bound'`).
              - Else set $\text{effective\_occurred\_at} = t_{\text{cand}}$.
            Because $F_{\min} \le F_{\max}$ and $t_{\text{cand}} \in [W_{\min}, W_{\max}]$, the resulting `effective_occurred_at` is **mathematically guaranteed** to satisfy **both** $[W_{\min}, W_{\max}]$ **and** $t_{\text{prev}} \le \text{effective\_occurred\_at} \le t_{\text{next}}$.
       3. **Atomic Event Insert (`INSERT ... ON CONFLICT DO NOTHING`) & Projection Update Inside a PL/pgSQL `BEGIN ... EXCEPTION ... END` Subtransaction Block**:
          - In PL/pgSQL, a bare `BEGIN ... END` block is only syntactic statement grouping (and `SAVEPOINT` cannot be called directly in PL/pgSQL); only a **`BEGIN ... EXCEPTION ... END`** block establishes a PostgreSQL subtransaction whose inner writes are atomically rolled back when an exception is caught.
          - Therefore, `record_events` enforces the following four subtransaction rules for every item write:
            1. **Event Insert & All Projection Writes Share One `BEGIN ... EXCEPTION ... END` Block**: The `INSERT INTO public.learning_events` statement and all corresponding `public.review_items` and `public.user_concept_state` projection writes execute inside the **same** PL/pgSQL `BEGIN ... EXCEPTION ... END` block so that the event row and its projection updates either both commit or both roll back together for that item.
            2. **Defense-in-Depth `ON CONFLICT` & Strictly Scoped Item-Level Failure Mapping (`SQLSTATE 'PZ001'` + `CONSTRAINT_NAME` Check)**: `INSERT INTO public.learning_events (...) VALUES (...) ON CONFLICT (user_id, idempotency_key) DO NOTHING RETURNING id, effective_occurred_at` runs first inside the block as defense-in-depth alongside the `(user_id, idempotency_key)` advisory lock. If `RETURNING` yields no row, the block re-reads the stored `payload_sha256` for `(v_user_id, v_idempotency_key)`, classifies the item as `status = 'duplicate_noop'` (when `stored.payload_sha256 = v_payload_sha256`) or `status = 'idempotency_payload_mismatch'` (when `stored.payload_sha256 <> v_payload_sha256`), and skips projection updates without raising. If a recognized item-level invariant fails after insert during write/projection evaluation, `record_events` raises a dedicated custom application SQLSTATE **`'PZ001'`** (never `P0002`, which is PostgreSQL's built-in `no_data_found` condition raised by `SELECT ... INTO STRICT`) and validates `GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT` against the explicit rejection status whitelist (`'sequence_conflict'`, `'rejected_ordering_conflict'`, `'rejected_window_neighbor_conflict'`), re-raising via `RAISE;` if the message is not in that whitelist. Likewise, `WHEN unique_violation` inspects `GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME` and maps to `status = 'sequence_conflict'` **only** when `v_constraint_name = 'learning_events_user_session_seq_key'`; any `unique_violation` originating from `public.review_items`, `public.user_concept_state`, or any other constraint is immediately re-raised via `RAISE;`.
            3. **Unexpected Errors Are Re-Raised (`WHEN OTHERS THEN RAISE;`)**: The `EXCEPTION` clause catches **only** explicitly verified item-level failure conditions (`SQLSTATE 'PZ001'` with a whitelisted status code or `unique_violation` on `learning_events_user_session_seq_key`); any `no_data_found` (`P0002`), projection constraint violation, or programming defect hits `RAISE;` and aborts the transaction loudly rather than silently converting defects into rejected events.
            4. **Batch Continuation Restricted to Recognized Item-Level Failures**: `record_events` continues iterating to subsequent items in the batch **only** after a verified item-level rejection/conflict status.
          - Reference PL/pgSQL subtransaction structure:
            ```sql
            BEGIN
              INSERT INTO public.learning_events (...)
              VALUES (...)
              ON CONFLICT (user_id, idempotency_key) DO NOTHING
              RETURNING id, effective_occurred_at
              INTO v_inserted_id, v_effective_occurred_at;

              IF v_inserted_id IS NULL THEN
                -- Concurrent or fallback conflict on (user_id, idempotency_key):
                -- compare stored payload_sha256 against v_payload_sha256 and set
                -- v_item_status := 'duplicate_noop' or 'idempotency_payload_mismatch'
              ELSE
                -- Update / deterministically replay public.review_items and public.user_concept_state
                -- If a recognized item-level invariant fails after insert, signal via dedicated custom SQLSTATE 'PZ001'
                -- (never P0002, which is PostgreSQL's built-in no_data_found SQLSTATE):
                -- RAISE EXCEPTION USING ERRCODE = 'PZ001', MESSAGE = <documented_status>;
                v_item_status := 'accepted';
              END IF;
            EXCEPTION
              WHEN SQLSTATE 'PZ001' THEN
                -- Dedicated application SQLSTATE for recognized item-level rejection;
                -- all writes in this BEGIN..EXCEPTION..END block are rolled back.
                GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
                IF v_error_message IN (
                  'sequence_conflict',
                  'rejected_ordering_conflict',
                  'rejected_window_neighbor_conflict'
                ) THEN
                  v_item_status := v_error_message;
                ELSE
                  RAISE;
                END IF;
              WHEN unique_violation THEN
                -- Only classify as sequence_conflict when raised by learning_events_user_session_seq_key;
                -- re-raise any unique_violation from review_items, user_concept_state, or other constraints.
                GET STACKED DIAGNOSTICS v_constraint_name = CONSTRAINT_NAME;
                IF v_constraint_name = 'learning_events_user_session_seq_key' THEN
                  v_item_status := 'sequence_conflict';
                ELSE
                  RAISE;
                END IF;
              WHEN OTHERS THEN
                -- Never mask no_data_found (P0002), projection constraint errors, or unexpected defects
                RAISE;
            END;
            ```
4. **Deterministic Out-of-Order & Multi-Device Replay**:
   - Under the entity-level advisory locks (`(user_id, item_id)` and `(user_id, concept_id)`), whenever a newly inserted event has `(effective_occurred_at, session_id, client_seq, id)` earlier than an already-processed event for the same `(user_id, item_id)` (or concept), `record_events` deterministically replays the card's `memory_card_review` history ordered by **`(effective_occurred_at ASC, session_id ASC, client_seq ASC, id ASC)`** through the FSRS-6 state machine (and recomputes `user_concept_state` over the identically ordered concept event stream) within the same per-item `BEGIN ... EXCEPTION ... END` subtransaction block so projections converge to a single deterministic state across all devices.

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

### 4.1 Complete 3-Migration `EXM-03` Surface on `main` (`a23cebb`, unchanged from `e538585`)
On `main`, the `EXM-03` assigned exam-part practice workflow comprises **three guarded migrations**:
1. [`supabase/migrations/20261101130000_exm_03_assigned_practice_scoring.sql`](../../supabase/migrations/20261101130000_exm_03_assigned_practice_scoring.sql): Creates `public.exam_part_practice_assignments` and `public.exam_part_practice_attempts`, plus the private canonical scorer `public.exm03_record_assigned_practice` (`service_role`-only execution).
2. [`supabase/migrations/20261101140000_exm_03_authenticated_assignment_issuer.sql`](../../supabase/migrations/20261101140000_exm_03_authenticated_assignment_issuer.sql): Provides the authenticated assignment issuer **`public.exm03_issue_assigned_practice(p_target_version_id uuid, p_exam_part_key text)`**, which creates a quota-bound assignment and returns a safe item projection with `scoring_spec`, `correct_index`, and answer-revealing fields stripped.
3. [`supabase/migrations/20261101150000_exm_03_authenticated_submit_protected_items.sql`](../../supabase/migrations/20261101150000_exm_03_authenticated_submit_protected_items.sql):
   - Provides the **authenticated, session- and owner-bound submission wrapper `public.exm03_submit_assigned_practice(p_assignment_id uuid, p_responses jsonb)`** (which verifies `auth.uid()` ownership and active JWT session binding before delegating to `public.exm03_record_assigned_practice`).
   - Enforces the restrictive RLS policy **`exm03_no_direct_read_of_approved_answers` on `public.assessment_items`**, preventing authenticated clients from directly `SELECT`ing rows that belong to an approved `EXM-02A` item review (`public.exm02a_item_reviews`), while **non-EXM assessment items remain readable on `main` until general Phase 1 `FIX-12` answer-key isolation is implemented**.
   - **Important Boundary (`EXM-03` Does Not Update `user_concept_state`)**: `public.exm03_record_assigned_practice` and `public.exm03_submit_assigned_practice` write scored attempt rows to `public.exam_part_practice_attempts`; they **do not** write to or update `public.user_concept_state`. `EXM-03` remains a dedicated assigned-practice workflow unless an explicit concept-projection integration migration is introduced in a future phase.

### 4.2 Reconciling `ConceptEvidenceService` and `user_concept_state` on `main`
Inspection of `main` (`a23cebb`, unchanged from `e538585`) confirmed two issues to resolve in Phase 1 (`ARCH-1`):
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
