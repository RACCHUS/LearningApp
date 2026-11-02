# LearningApp — Platform Vision, Trust Architecture & Full-Scope Execution Plan

**Initial Audit Date:** 2026-10-31 (`ARCHITECTURE_REVIEW.md` at `e538585`) · **Initial Plan Authoring Date:** 2026-11-01 (PR `#135`) · **Post-PR `#136` Merge Revision Date:** 2026-11-02 · **Authoritative Baseline:** `main` at `a23cebb` (following merge of PR `#136` from `feature/arch-review-phase-0`)
**Scope:** Documentation and architecture specifications only. This PR (`#137`) does not implement Phase 1 migrations, the `public.learning_events` ledger, `record_events`, FSRS scheduling, or associated application runtime changes.
**Related Plan:** [`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md`](EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md) · **Status:** Reconciled Platform Strategy (v2.5 — Post-PR `#136` Merge Revision)

---

## 1. Strategic Position: Broad Reusable Platform + Strict Scientific & Security Boundaries

1. **Preserve the Full Multi-Domain Platform Architecture**
   - LearningApp builds on the substantial foundations already present on `main` (`a23cebb`, following the merge of PR `#136` onto `e538585`): **Learning Architecture V2**, **Canonical Taxonomy v2.4**, **Curriculum Manifests**, **Audio-First Literacy**, **EXM-01..03**, and **ECO-00..04**.
2. **Distinguish Implemented Foundations from Proposed Specifications & Validated Claims**
   - Specifications for `LearningTaskProfile`, `ContentComplexityProfile`, `public.learning_events` (`record_events`), three-representation answer-key isolation (`FIX-12`), and FSRS-6 (`package:fsrs` v2.0.1, `v2_fsrs6`) are explicitly documented as **proposed phased extensions** requiring versioned schema and migration changes before activation.
   - Only claims backed by empirical validation in the relevant population and assessment context are presented to learners as proven.

---

## 2. Decomposed Content Provenance, Measurement Quality & Readiness Eligibility

Rather than collapsing origin, review status, and statistical calibration into a single enum, the platform tracks them independently ([`docs/learning_science/07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)):

### A. Six Orthogonal Content Provenance Properties
1. **`origin`** (+ optional `origin_client_id`): `official_source` | `curated_editorial` | `community_contribution` | `user_import` | `ai_generated` (paired with optional `origin_client_id: string | null`, e.g., `'mcp:<client_id>'` for MCP-authored drafts so `origin` remains a closed 5-value enum)
2. **`visibility`**: `private` | `shared_unlisted` | `public_catalog`
3. **`rights_status`**: `verified_permissive_or_public_domain` | `licensed_embed_or_link` | `rights_review_required` | `restricted_or_unknown` *(note: private visibility does not automatically constitute fair use; unverified imports default to `rights_review_required`)*
4. **`review_status`**: `unreviewed` | `automated_checks_passed` | `editorially_reviewed` | `authoritatively_verified`
5. **`source_authority`**: `primary_regulator_or_statute` | `accredited_publisher_or_standard` | `secondary_educational` | `user_supplied_unverified`
6. **`version_validity`**: `{ effective_from, effective_to, superseded_by_version_id, status: 'active' | 'expired' | 'superseded' }`

### B. Separated Complexity Status, Item Psychometric Status & Readiness Validation
Rather than conflating a cold-start `ContentComplexityProfile` or a single empirical observation ($N=1$) with calibrated item parameters, the platform separates them into three distinct status fields:
- **`complexity_assessment_status`** (Cold-start `ContentComplexityProfile` status): `unassessed` | `deterministic_profile` | `expert_reviewed_profile`.
- **`item_psychometric_status`** (Empirical item measurement status): `unobserved` ($N = 0$) $\to$ `observed_uncalibrated` ($N \ge 1$ observation-existence label only; a single response is not a meaningful difficulty estimate) $\to$ `preliminary_elo_ordering` (governed by a configurable LearningApp policy threshold **`elo_min_observations`**, inactive until selected and validated for the relevant item pool; provides low-stakes heuristic Elo ordering per Pelánek, 2016, `ER-09b`, qualified by Bolsinova, Gergely, & Brinkhuis, 2026 regarding joint adaptive bias/variance/non-convergence) $\to$ `calibrated` (statistical IRT item estimates $a_i, b_i$; requires pool- and model-specific convergence diagnostics and an acceptable standard-error bound **`calibration_max_se`**—marked `pending_validation` and inactive until validated for that item pool, per `ER-09a`).
- **`readiness_validation_status`** (Target/model validation status): `unvalidated` $\to$ `pilot_observed` $\to$ `validated_for_intended_use`.

### C. Blueprint Alignment (`blueprint_alignment_state`)
- `unmapped` | `concept_mapped` | `blueprint_weighted` (mapped to an active `TargetVersion` exam domain/part).

### D. Four Separate Evidence & State Layers
1. **FSRS-6 Card Retrievability $R(t)$ (`v2_fsrs6`)**: Memory recall probability for an individual memory-review card (`Again`, `Hard`, `Good`, `Easy`).
2. **Concept Evidence (`user_concept_state`)**: Server-maintained projection of competence across a concept's facets and cognitive operations (updated by `record_events`; kept separate from `EXM-03` `exam_part_practice_attempts`).
3. **Reference-Navigation Evidence (`EXM-02B`)**: Open-book lookup accuracy and timing across `R1–R4`.
4. **Examination Readiness**: Synthesizes blueprint coverage, delayed retention, transfer to held-out items, and execution under actual exam conditions (e.g., **open-book reference navigation** for Pilot A Florida Certified Contractor vs. **closed-book timed MCQ** for Pilot B Florida Insurance).

---

## 3. Security, Supersession & Post-PR `#136` Contract Alignment

Following the merge of PR `#136` (`feature/arch-review-phase-0`) into `main` at `a23cebb`, this documentation branch (`docs/architecture-and-learning-science-plans`, PR `#137`) establishes the normative specifications for remaining Phase 0 follow-up and Phase 1–3 execution:

### 3.1 `ARCHITECTURE_REVIEW.md` Alignment & Normative Specifications
- `ARCHITECTURE_REVIEW.md` incorporates the PR `#137` review refinements (including Firebase's official Hosting quota listings: **10 GB/month** on the Firebase Hosting *Usage and quotas* page vs. **360 MB/day** on the *Firebase Pricing* page; qualified `srs-benchmark` Log Loss/RMSE/AUC metrics and Anki 23.10 optional FSRS claims without an unverified 20–30% review-reduction figure; canonical `origin` + `origin_client_id = 'mcp:<client_id>'`; and reconciled offline FSRS sequence/idempotency/timestamp/concurrency/replay rules).
- **`/EVIDENCE_BASED_LEARNING_OPTIMIZATION_PLAN.md` and `/docs/learning_science/01..08` serve as the full normative specifications** for `public.learning_events`, `record_events`, `v2_fsrs6`, and the 6-property provenance model.

### 3.2 Accurate `EXM-03` Surface & Phase 1 `FIX-12` Target Contract
- On `main` (`a23cebb`), `EXM-03` (`20261101130000_exm_03_assigned_practice_scoring.sql`, `20261101140000_exm_03_authenticated_assignment_issuer.sql`, and `20261101150000_exm_03_authenticated_submit_protected_items.sql`) already provides answer-key-stripped assignment issuance (`exm03_issue_assigned_practice`), authenticated session-bound submission (`exm03_submit_assigned_practice`), and restrictive RLS (`exm03_no_direct_read_of_approved_answers`) for approved `EXM-02A` items (recording attempts in `exam_part_practice_attempts` without updating `user_concept_state`).
- Extending the three-representation answer-key isolation model to all non-EXM diagnostic, mock exam, and adaptive practice items remains a **Phase 1 deliverable (`FIX-12`)**.

### 3.3 Universal Option Shuffling (`FIX-1` — `PARTIALLY RESOLVED` on `main` at `a23cebb`) & Separate Phase 1 `presented_option_ids` Persistence (`ARCH-1`)
- Documents that although PR `#136` listed `FIX-1` as `RESOLVED`, `FIX-1` remains `PARTIALLY RESOLVED` on `main` (`a23cebb`, following earlier PR `#136` snapshots `5a428b5`, `e67a3d5`, and `dc8f49f`) because shuffling is only active in `AssessmentItemRenderer`.
- Enforces the raw per-presentation `attemptNonce` contract: while `a23cebb` removed the double-XOR in `AdaptivePracticeScreen` and added `_sessionNonce` to [`lib/widgets/lesson/rich_lesson_reader.dart`](lib/widgets/lesson/rich_lesson_reader.dart), both callers still only define a session-scoped `_sessionNonce` and must introduce or increment a **raw per-presentation nonce (e.g. `_attemptNonce`)** passed unchanged as `presentationSeed` without pre-XORing `item.id.hashCode`, so `AssessmentItemRenderer` combines it with `item.id.hashCode` **exactly once** (`attemptNonce ^ item.id.hashCode`).
- Tracks the remaining legacy [`lib/widgets/question_widgets/mcq_question_widget.dart`](lib/widgets/question_widgets/mcq_question_widget.dart) (`widget.content.options`), [`lib/widgets/mcq_options.dart`](lib/widgets/mcq_options.dart), and dual voice-input routes (`LessonContentRenderer` and `QuestionContentRenderer`) to close Phase 0 `FIX-1`, while explicitly keeping durable persistence of `presented_option_ids: text[]` in `public.learning_events` (trusted when bound to a server-issued presentation record; otherwise labeled `untrusted_client_reported` metadata) as **separate Phase 1 event-ledger work (`ARCH-1`, `06_MEASUREMENT_AND_SCHEDULING.md`)** rather than a Phase 0 `FIX-1` acceptance criterion (whereas `FIX-3` is Phase 0 client-to-migration schema drift).

---

## 4. Phased Execution Roadmap (Complete `FIX-1`–`FIX-14` & `ARCH-1`–`ARCH-10` Mapping)

- **Phase 0 — Foundational Security, Schema Drift, Config & Accessibility (`FIX-1`–`FIX-4`, `FIX-5a`, `FIX-6`, `FIX-7`, `FIX-8a`, `FIX-9a`, `FIX-10`, `FIX-11`, `FIX-13`, `FIX-14`, `ARCH-10` — PR `#136` merged at `a23cebb` + remaining `FIX-1` follow-up)**: Complete universal option shuffling (`FIX-1` legacy `McqQuestionWidget`/`McqOptions`, dual voice paths, and per-presentation `_attemptNonce`), XP RPC security (`FIX-2`), schema drift & CI contract verification (`FIX-3`), `flutter_bootstrap.js` & service-worker cleanup (`FIX-4`), **remove dead web FCM/Firebase notification dependencies and enforce truthful local reminder UI copy (`FIX-5a`)**, web semantics `ensureSemantics()` (`FIX-6`), UTC timestamp normalization (`FIX-7`), typed error states & retry UI replacing silent `catch -> []` in SRS reads (`FIX-8a`), bounded/paginated client queries (`FIX-9a`), `flutter_lints` & async-context safety (`FIX-10`), **`--dart-define-from-file` client config hardening & removing `.env` from bundled assets (`FIX-11`)**, RLS `(select auth.uid())` & `search_path` hardening (`FIX-13`), hosting security headers & icon/meta cleanup (`FIX-14`), and `LICENSE` (`ARCH-10`).
- **Phase 1 — Evidence Engine, Offline Reconciliation, Web Push & Answer-Key Isolation (`ARCH-1`, `ARCH-3`, `FIX-5b`, `FIX-8b`, `FIX-9b`, `FIX-12`)**: Ship `public.learning_events` (`event_schema_version = '1.0.0'`) and `record_events` RPC (`ARCH-1`) with **Phase 1 deterministic server derivation (`metadata_schema_version = '1.0-phase1-derived'`) for `task_profile` and 6-property `provenance_snapshot`** (`06_MEASUREMENT_AND_SCHEDULING.md` §2.3), transaction-scoped advisory locks on `(user_id, session_id)` and affected `(user_id, item_id)` / `(user_id, concept_id)` streams, deterministic server-side batch sorting by `(session_id ASC, client_seq ASC, idempotency_key ASC)`, server-maintained `user_concept_state` and `review_items` (`v2_fsrs6`) projections, **local-first event outbox (`ARCH-3` / `FIX-8b`) with durable `idempotency_key` retry reuse checked first against server-computed `payload_sha256` (`encode(digest(convert_to(v_canonical_payload::text, 'UTF8'), 'sha256'), 'hex')` over the 13 semantic event-payload fields) prior to sequence or timestamp checks, composite `UNIQUE (user_id, session_id, client_seq)`, provisional on-device FSRS scheduling, and server-validated `effective_occurred_at` joint window/neighbor feasibility + deterministic replay over `(effective_occurred_at ASC, session_id ASC, client_seq ASC, id ASC)` to preserve plausible client-reported offline intervals (`06_MEASUREMENT_AND_SCHEDULING.md` §2.4)**, **Web Push (VAPID) reminders via Supabase Edge Function + `pg_cron` and optional email digest (`FIX-5b`)**, server-side aggregate readiness/summary RPCs (`FIX-9b`), general non-EXM three-representation answer-key isolation (`FIX-12`), 90-day event archival/compaction cost guard (`ARCHITECTURE_REVIEW.md` `ARCH-1` §7), and empirical pilot validation across the 7 domain proving grounds (`07_READINESS_AND_VALIDATION.md`).
- **Phase 2 — Platform API, Manifest `2.1.0` Unification & BYOK/MCP (`ARCH-2`, `ARCH-4`, `ARCH-5`, `ARCH-6`)**: Upgrade `curriculum_manifest.schema.json` to **`2.1.0`** (`08_CONTENT_AND_IMPORT_ALIGNMENT.md`) to enforce authored `LearningTaskProfile` and 6-property `provenance_metadata` (with `origin_client_id`) and backfill existing catalog items (`metadata_schema_version = '2.1.0'`), introduce the versioned `api` schema (`ARCH-2`), MCP server (`OPP-1`), BYOK AI generation (`ARCH-4`), and deferred/WASM web delivery (`ARCH-6`).
- **Phase 3 — Ecosystem & Interoperability (`OPP-2`–`OPP-7`)**: Creator channels with learning-gain ranking, practical performance checklists, QTI 3.0 / xAPI / LTI 1.3 / Open Badges 3.0 interoperability, and the modular fork kit.
