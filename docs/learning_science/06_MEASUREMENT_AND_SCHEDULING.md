# 06 — Measurement, Evidence Architecture & Versioned Scheduling

This document specifies how LearningApp separates the **three types of difficulty**, reconciles existing evidence services on `main` (`e538585`), and introduces **versioned FSRS scheduling** without disrupting existing learner data.

---

## 1. Strict Separation of the Three Difficulty Constructs (`ER-09`)

Cognitive task complexity, psychometric item difficulty, and individual memory difficulty measure fundamentally different things and must never be stored in or substituted for the same variable:

### Construct 1: Cognitive & Content Complexity (`content_complexity_profile`)
- **What it is**: An intrinsic property of the material and task, established at cold start ($N=0$) via deterministic analysis and editorial review.
- **Dimensions recorded**:
  - `reading_demand` (word count, lexical rarity / SCOWL tier, syntactic complexity)
  - `reasoning_step_count` (number of inferential or procedural steps required)
  - `quantitative_complexity` (arithmetic vs. multi-variable formula vs. unit conversion)
  - `prerequisite_depth` (depth in canonical `concept_relations` graph)
  - `confusable_density` (presence of verified `confusable_group_id` distractors)
  - `response_format_demand` (recognition choice vs. cued recall vs. uncued production/numeric)
  - `reference_foraging_depth` (`closed_book` vs. `R1`–`R4` lookup chain)
- **Role**: Guides initial instructional scaffolding and serves as an explicit `research_informed_prior` before learner response telemetry exists.

### Construct 2: Psychometric Item Difficulty & Discrimination (`item_psychometrics`)
- **What it is**: Empirical statistical performance of an assessment item within a defined candidate population ($p$-value, Elo difficulty estimate, IRT difficulty $b_i$, discrimination $a_i$, and standard errors).
- **Cold-Start Rule**: Starts at `measurement_quality_level = unobserved` (or `research_informed_prior` referencing `content_complexity_profile`). The engine **never** labels a heuristic cold-start score as a calibrated IRT parameter.
- **Empirical Evolution**: Updated as valid learner attempts accumulate, retaining explicit sample counts ($N$) and uncertainty bounds ($\text{SE}$) in accordance with small-sample psychometric research (`ER-09`).

### Construct 3: Individual Learner Memory State (`review_items` — Stability & Memory Difficulty)
- **What it is**: How difficult it is for a *specific learner* to retain and retrieve a specific item or concept over time (SM-2 `ease_factor`/`repetition_level` or FSRS `stability` $S$ and `difficulty` $D$).
- **Role**: Drives personal review spacing and longitudinal retention estimates. Never conflated with population IRT item difficulty $b_i$.

---

## 2. Reconciling the Existing Evidence Architecture on `main` (`e538585`)

The current `main` branch contains four evidence-related mechanisms:
1. **`review_items`**: Persistent spaced-repetition schedule table.
2. **`ConceptEvidenceService` & `user_concept_state`**: Currently performs client-side select-then-upsert of aggregate counters (`weighted_correct`, `weighted_total`), which conflicts with `LEARNING_ARCHITECTURE_V2.md` §3.4's rule that `user_concept_state` is a read-only analytical projection.
3. **`EXM-02B` (`exam_reference_drill_events`)**: Durable, ungraded event recording for open-book reference navigation steps (`R1–R4`), with owner export and batched erasure.
4. **`EXM-03` (`exam_part_practice_attempts` & protected scoring RPCs)**: Server-validated scoring for protected exam parts that keeps answer keys (`scoring_spec`) unexposed.

### Reconciliation Plan (No Competing Parallel Ledger)
1. **Keep `EXM-02B` and `EXM-03` Authoritative for Exam Drills & Protected Parts**:
   - Do not weaken or bypass `EXM-03` server-side scoring or `EXM-02B` drill telemetry.
2. **Introduce a Unified Evidence Contract & General Attempt Ledger (`learning_attempt_events`)**:
   - Record answer-level events for general study, flashcards, concept practice, and literacy tasks using the same owner-privacy, export, and erasure standards as `EXM-02B`/`EXM-03`.
   - Required contract fields per activity:
     - `content_id`, `item_id`, and `target_version_id` / manifest revision
     - Canonical `knowledge_concept` and curriculum objective mappings
     - `learning_task_profile` & `assessment_format`
     - `presented_option_ids` and learner response
     - Scored outcome (where applicable)
     - `latency_ms`
     - `assistance_used` (hints, worked-example fading stage)
     - `confidence_level` (when collected)
     - `content_trust_level` and `blueprint_alignment_state`
3. **Make `user_concept_state` a True Server-Maintained Projection**:
   - Update `user_concept_state` atomically on the server when `learning_attempt_events` or `EXM-03` scored attempts are recorded, resolving the discrepancy between `ConceptEvidenceService` and `LEARNING_ARCHITECTURE_V2.md`.
   - Maintain separate projection columns for `verified_evidence` (`editorially_reviewed` / `authoritatively_verified`) vs. `personal_evidence` (`personal_import`).

---

## 3. Versioned Scheduler Architecture (`SM-2` $\to$ `FSRS`)

To introduce FSRS (`package:fsrs`) safely:
1. **Explicit `scheduler_version` Column on `review_items`**:
   - `'v1_sm2_ladder'` (current default on `main`)
   - `'v2_fsrs'` (FSRS stability $S$, difficulty $D$, retrievability $R(t)$)
2. **Zero-Disruption Migration**:
   - Existing learner schedules remain intact. When an item is reviewed under `v2_fsrs`, its initial $(S, D)$ is seeded conservatively from its review history or complexity prior.
3. **Separation of Concerns**:
   - **Initial learning / intraday relearning** is handled by a session-level acquisition queue.
   - **Long-term retention scheduling** is handled by FSRS $(S, D)$.
   - **Exam-date workload planning** is a separate scheduling policy layer that adjusts daily review budgets as an exam date approaches without mutating the underlying memory parameters.
