# LearningApp — Evidence-Based Learning Science & Instructional Optimization Plan

**Date:** 2026-11-01 · **Authoritative Baseline:** `main` at `e538585` (PR `#135`)
**Concurrent Engineering Workstream:** `feature/arch-review-phase-0` (PR `#136`, kept strictly independent)
**Research Directory:** `/docs/learning_science/` · **Status:** Reconciled Root Specification (v2.0)

---

## 1. Architectural Baseline & Honest Implementation Audit

This plan builds directly on the authoritative `main` branch (`e538585`) without assuming unmerged changes from `feature/arch-review-phase-0` (PR `#136`) and without dismantling any existing platform foundation.

To keep engineering and scientific claims rigorous, we explicitly distinguish **what is already implemented and tested on `main`**, **what exists as partial implementation or architectural specification**, and **what requires new implementation and real-world empirical validation**:

| Foundation on `main` (`e538585`) | Current Implementation Status | What Still Requires Reconciliation or Validation |
|---|---|---|
| **Learning Architecture V2** (`LEARNING_ARCHITECTURE_V2.md`, `lib/services/scope_resolver.dart`) | **Implemented & tested:** Global `knowledge_concepts`, scoped curricula (`ResolvedScope`), `TargetVersion` visibility guards, and curriculum manifest ingestion. | `LEARNING_ARCHITECTURE_V2.md` defines `user_concept_state` as a read-only analytical projection, whereas `ConceptEvidenceService` currently upserts `user_concept_state` directly and aggregates without a general answer-level history. |
| **Canonical Taxonomy v2.4** (`CANONICAL_TAXONOMY_ARCHITECTURE.md`) | **Implemented & tested:** Dual-layer ontology (`fields` decoupled from CIP/SOC/O\*NET), crosswalks, and statistical privacy guards. | Needs task-profile metadata alignment so concepts can declare multi-dimensional learning requirements across targets. |
| **Curriculum Manifest Pipeline** (`content/schema/curriculum_manifest.schema.json`) | **Implemented & tested:** JSON Schema validation, provenance hashes, source citations, and dry-run/production ingestion RPCs. | Needs extension to carry multidimensional `learning_task_profile` and instructional strategy metadata for imported and authored content. |
| **Literacy Architecture** (`LITERACY_ACCESSIBILITY_PLAN.md`, `lib/screens/literacy/`) | **Implemented (Foundational):** Audio-first hub, phonics/CVC items, letter tracing, decodable stories, and milestone simulators (USCIS, DMV, GED, survival). | Pedagogical stages are recommendations (not gates); needs adult-specific reading evidence calibration, option shuffling (`FIX-1`), and expanded item pools. |
| **EXM Exam Success Architecture** (`EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md`, `EXM-01..03`) | **Implemented & pgTAP-tested:** Reference manifest revisions (`EXM-01`), R1–R4 reference navigation drills, durable drill events (`EXM-02B`), server-validated protected part scoring (`EXM-03`), and account portability/erasure. | Needs live candidate validation on the Florida contractor pilot (`Pilot A`) and integration with longitudinal retention scheduling. |
| **ECO Community & Educator Architecture** (`ECO-00..04`) | **Implemented & pgTAP-tested:** Trust/safety moderation (`ECO-00B`), usage quotas (`ECO-00C`), concept-scoped Q&A (`ECO-01`), moderator review workflow (`ECO-02`), and educator profiles/verification (`ECO-04`). | Needs integration with the 6-stage content ingestion pipeline so educator reviews promote content provenance tiers. |
| **Spaced Repetition & Concept Evidence** (`lib/models/spaced_repetition.dart`, `review_items`, `ConceptEvidenceService`) | **Implemented (Heuristic baseline):** Persistent `review_items` table with a simplified SM-2 interval ladder (`[1, 3, 7, 14, 30, 60, 120]`) and cumulative concept evidence weighting. | Scheduler ignores actual elapsed overdue time, clamps ease at its initial value (`2.5`), lacks an intraday relearning queue, and does not yet separate content complexity from psychometric item difficulty or memory stability. |

---

## 2. Multidimensional Learning Task Profiles (Replacing Mutually Exclusive Modalities)

### 2.1 Why Mutually Exclusive Modalities Are the Wrong Abstraction
An earlier draft proposed assigning every concept and item to one of seven mutually exclusive modalities (`M1..M7`). As architectural review demonstrated, those seven categories actually describe **different dimensions of a learning task**:
- *Open-book* describes an **assessment & reference condition** and a set of foraging competencies.
- *Oral production* describes a **response and communication requirement**.
- *Vocabulary* and *conceptual understanding* describe **knowledge objectives**.
- *Visual classification* describes a **stimulus and perceptual task demand**.
- *Safety checklists* describe **procedural execution and error-criticality criteria**.

A single concept often requires multiple instructional experiences across these dimensions. For example, mastering **electrical circuit protection** requires:
1. Understanding the **vocabulary** (*ampacity, overcurrent, ground fault*).
2. Visually recognizing the **schematic/blueprint symbols**.
3. Understanding the **conceptual relationship** between conductor gauge, load, and breaker rating.
4. **Calculating** electrical values using worked examples and adaptive fading.
5. **Navigating the reference code book** (NEC tables and exceptions) under open-book exam conditions.
6. Executing a **critical-step safety procedure** (Lockout/Tagout checklist) without omitting life-safety steps.

Research strongly supports this multidimensional view: a 2026 meta-analysis across 53 studies and 7,303 learners confirmed substantial benefits from retrieval practice, spacing, and interleaving, while demonstrating that effectiveness is significantly moderated by **knowledge type, assessment format, and feedback structure** ([`/docs/learning_science/01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md)).

### 2.2 The Multidimensional `LearningTaskProfile` Model
Instead of a single rigid modality enum, every learning objective, concept, or activity is configured via a composable **`LearningTaskProfile`** along five orthogonal axes:

1. **`knowledge_facets[]` (What kind of knowledge is being built?)**:
   - `sublexical_orthographic` (phoneme-grapheme mapping, decoding, encoding/spelling)
   - `verbal_terminology` (definitions, labels, nomenclature, symbol names)
   - `conceptual_relational` (principles, cause-and-effect, boundary distinctions, mental models)
   - `procedural_quantitative` (multi-step math, formula setup, unit conversion, algorithms)
   - `procedural_execution` (ordered physical/clinical/safety steps, inspection sequences)
   - `perceptual_diagnostic` (visual pattern recognition, sign/diagram/rhythm classification)
   - `reference_navigation` (resource routing, index/TOC foraging, clause/exception extraction)

2. **`cognitive_operations[]` (What must the learner do with the knowledge?)**:
   - `define_or_identify`
   - `explain_mechanism`
   - `distinguish_confusable` (when verified confusable neighbors exist)
   - `classify_example_non_example`
   - `apply_to_scenario`
   - `calculate_and_verify_units`
   - `locate_and_interpret_provision`
   - `justify_why_correct`

3. **`stimulus_and_response_channel` (How is the prompt delivered and answered?)**:
   - `Prompt`: `visual_text` | `audio_first` | `diagram_or_image` | `scenario_with_reference_manifest`
   - `Response`: `structured_choice` | `free_recall_text` | `spoken_production` | `numeric_with_unit` | `ordered_checklist` | `reference_locator_step`

4. **`assessment_conditions` (What constraints govern execution?)**:
   - `reference_policy`: `closed_book` | `open_book_manifest` | `formula_sheet_only`
   - `timing_regime`: `untimed_mastery` | `paced_practice` | `exam_clock_enforced`
   - `error_criticality`: `standard_compensatory` | `authoritative_critical_step_gate`

5. **`instructional_strategies[]` (Which evidence-based delivery strategies apply?)**:
   - Composable strategies selected dynamically based on the task profile and the learner's current state (detailed in §2.3).

### 2.3 Corrected Domain Delivery Rules across the Seven Approaches

| Approach | Retained Core Strengths | Corrections & Guardrails Enforced in v2.0 |
|---|---|---|
| **1. Literacy & Phonics** | Phonemic awareness, grapheme-phoneme mapping, decoding, encoding/spelling, and audio-first zero-text-assumption UI. | **Removed universal 95% grapheme gate.** Preserves `LITERACY_ACCESSIBILITY_PLAN.md` rule that pedagogical stages are **recommendations, not hard locks** (Direct Access Rule). Grounds adult literacy separately from child reading research—reflecting the 2026 systematic review of adult reading interventions (consistent decoding gains, mixed transfer across broader reading comprehension components). |
| **2. Open-Book Navigation (`EXM`)** | Explicit training of reference navigation rather than assuming open-book exams require no preparation or pure memorization. | **Removed arbitrary 30/70 internalize/lookup split.** Aligns directly with `EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md` by independently measuring six competencies: **(1) Resource selection, (2) Finding the correct section, (3) Locating the relevant provision, (4) Understanding exceptions, (5) Applying the provision, and (6) Completing within available time.** |
| **3. Concepts & Vocabulary** | Going beyond definition memorization; supporting contrastive learning and interleaving where concepts are genuinely confusable. | **Removed mandatory 3-angle lock on every concept.** Supports six cognitive tasks (*Define, Explain, Distinguish from similar concepts, Recognize examples/non-examples, Apply in a new situation, Explain why an answer is correct*) and activates contrastive interleaving selectively when concepts have a documented `confusable_group_id`. |
| **4. Calculations & Procedures** | Worked examples followed by gradually reduced assistance (fading) and unit-aware numeric validation. | **Replaced fixed 4-stage lockstep with prior-knowledge-adaptive scaffolding.** Per the 2025 meta-analysis on instructional assistance for low vs. high prior knowledge (and the Expertise Reversal Effect), novices receive worked examples and step fading while learners demonstrating prior competence bypass redundant scaffolding. |
| **5. Oral Production** | Acoustic-first prompting and spoken/free-recall practice where the target assessment or real-world task requires spoken output (e.g., USCIS civics interview). | **Removed speech-onset latency as a universal mastery gate.** Response time is recorded as an informational observation, never used to fail or penalize learners with speech differences, accents, or thoughtful retrieval pacing. |
| **6. Visual Classification** | Perceptual discrimination training with visually confusable distractors for signs, symbols, and diagrams. | **Accuracy established before speed; removed universal latency targets.** Fluency pacing is introduced only after reliable classification accuracy is demonstrated, with no arbitrary 200ms or 3.5s hard gate. |
| **7. Critical-Step Checklists** | Procedural sequence training and explicit handling of high-consequence safety steps. | **Critical failures must be grounded strictly in authoritative assessment or safety requirements.** A step may only be marked `critical_fail` when backed by an official exam rubric or regulatory safety standard (`content_provenance`). |

---

## 3. Solving Cold-Start ($N=0$) Without Conflating the Three Types of Difficulty

When the platform launches—or when new content is imported—we need strong initial instructional and scheduling behavior before crowd telemetry exists. However, our model must **strictly separate three non-interchangeable constructs**:

| Difficulty Construct | What It Measures | How It Is Determined at Cold Start ($N=0$) | How It Evolves with Data ($N > 0$) |
|---|---|---|---|
| **1. Cognitive / Content Complexity** | Intrinsic demand of the material and task (vocabulary rarity, reading load, number of reasoning/calculation steps, prerequisite depth, confusable similarity, response format, reference-navigation steps). | Established deterministically at ingestion via automated linguistic/structural analysis and expert/author metadata (`content_complexity_profile`). | Remains an intrinsic descriptor of the task; refined if content or scaffolding is edited. |
| **2. Psychometric Item Difficulty ($b_i$, $a_i$)** | How difficult and discriminating a specific assessment item is for a defined candidate population. | **Unobserved (`null` empirical parameter).** Uses `content_complexity_profile` solely as a labeled **research-informed prior** with wide explicit uncertainty—never presented as a calibrated IRT parameter. | Updated via online estimation / small-sample-aware IRT calibration (respecting ETS small-sample calibration constraints) with explicit standard errors ($\text{SE}(b_i)$). |
| **3. Individual Memory Difficulty ($D_{\text{FSRS}}$, $S_{\text{FSRS}}$)** | How difficult it is for a *specific learner* to retain and retrieve a specific memory trace over time. | Initialized per learner from population-baseline FSRS priors modulated conservatively by task type on first exposure. | Updated individually from that learner's own longitudinal review ratings and elapsed intervals. |

### 3.1 Versioned Scheduler Architecture (SM-2 $\to$ FSRS)
Rather than overwriting `lib/models/spaced_repetition.dart` in place and risking disruption to existing learner schedules, FSRS is introduced via a **Versioned Scheduler Architecture (`SchedulerEngineVersion`)**:
1. **Preserve Existing Schedules (`v1_sm2_ladder`)**: Existing `review_items` rows retain their valid `next_review_date`, `repetition_level`, and `ease_factor`.
2. **Non-Destructive Migration Path (`v2_fsrs`)**: Add nullable FSRS state columns (`scheduler_version`, `fsrs_stability`, `fsrs_difficulty`, `fsrs_state`, `fsrs_lapses`) to `review_items`. Items migrate cleanly on their next review event (or via deterministic state mapping) without resetting learner progress.
3. **Separate Initial Acquisition from Long-Term Retention**: Intraday learning/relearning steps (short-term working/episodic consolidation within a session) are managed separately from multi-day FSRS stability scheduling.
4. **Separate Exam-Date Planning from Baseline Retention**: Ordinary FSRS scheduling optimizes long-term retention efficiency; optional exam-date compression is layered as a distinct **Study Plan Policy** so underlying memory parameters ($S, D$) are never distorted by calendar deadlines.

---

## 4. Two Independent Evidence & Trust Systems (Plus Blueprint Alignment & Learner Mastery)

An official regulator statute can be 100% authoritative at $N=0$ learner responses, while a viral community quiz can have $N=10,000$ responses and still teach an outdated or factually wrong rule. Furthermore, verified content does not equal learner mastery.

We therefore replace the single 4-tier ladder with **four orthogonal dimensions**:

### Dimension A — Content Trust & Provenance (`content_trust_level`)
1. **`personal_import`**: Private to the importing user (`is_public = false`), source recorded, unverified. Usable immediately for personal study and retention scheduling; **excluded from authoritative exam-readiness claims**.
2. **`automated_checked`**: Passed deterministic schema, citation format, option-structure, and consistency checks (`ContentQualityValidator`).
3. **`editorially_reviewed`**: Passed human/educator review (`ECO-02` / `ECO-04`) for factual accuracy, distractor quality, and instructional clarity.
4. **`authoritatively_verified`**: Verified against the primary regulator/issuer source and pinned to an effective `TargetVersion` and source release window (`content_provenance`).

### Dimension B — Measurement Quality (`measurement_quality_level`)
1. **`unobserved`**: $N = 0$ learner responses; no empirical item statistics.
2. **`research_informed_prior`**: Complexity profile (`content_complexity_profile`) computed from deterministic task features; zero empirical calibration claimed.
3. **`observed`**: Empirical learner responses recorded ($1 \le N < N_{\text{min}}$), providing preliminary p-value and latency observations with high uncertainty.
4. **`calibrated`**: Sufficient representative sample size and validated statistical estimates (item difficulty, discrimination, distractor functioning) with bounded standard error.
5. **`validated_for_intended_use`**: Demonstrated predictive/construct validity in the target candidate population and examination context.

### Dimension C — Blueprint Alignment (`blueprint_alignment_state`)
- Recorded independently: whether an item/activity is `unmapped`, `concept_mapped` (linked to canonical `knowledge_concepts`), or `blueprint_weighted` (linked to an official `TargetVersion` exam part/domain with verified blueprint weight).

### Dimension D — Learner Mastery & Readiness Evidence
Evaluated per learner across distinct questions that are never conflated into a single opaque percentage:
1. **Comprehension & Acquisition**: Did the learner understand the concept during instruction/scaffolding?
2. **Delayed Retrieval**: Can the learner recall it across spaced intervals without cues?
3. **Transfer to Unfamiliar Problems**: Can the learner apply it to **held-out / novel items** they have not memorized?
4. **Exam-Condition Execution**: Can the learner perform within the actual time budget and reference constraints (`EXM`) of the exam?

---

## 5. Reconciling the Answer-History & Evidence Architecture on `main`

Inspection of `main` (`e538585`) shows several existing evidence mechanisms that must be **reconciled and unified**, not duplicated by a competing parallel architecture:
- **`review_items`** (`20250101000001_create_review_items.sql`): Current SRS state store.
- **`ConceptEvidenceService` & `user_concept_state`** (`lib/services/concept_evidence_service.dart`, `20260925000001_v2_additive_schema.sql`): Currently performs client-side select-then-upsert of aggregate weighted counters, which diverges from `LEARNING_ARCHITECTURE_V2.md` §3.4's specification that `user_concept_state` should be a read-only analytical projection.
- **`EXM-02B` (`exam_reference_drill_events`)**: Durable, ungraded event recording for open-book R1–R4 reference navigation observations, complete with owner export and batched erasure RPCs.
- **`EXM-03` (`exam_part_practice_attempts` & server-scored RPCs)**: Protected server-side scoring path that keeps answer keys (`scoring_spec`) hidden from anonymous/untrusted reads on protected exam items.

### Architectural Resolution: Unified Evidence Contract
1. **Preserve `EXM-02B` and `EXM-03` Security & Scoring Boundaries**:
   - Protected exam items continue to score exclusively through `EXM-03`'s server-validated submission RPCs.
   - Ungraded reference-foraging telemetry continues to use `EXM-02B`'s durable drill event contract and portability/erasure guarantees.
2. **Resolve the `ConceptEvidenceService` / `user_concept_state` Discrepancy**:
   - Introduce an append-only general learning attempt ledger (`learning_attempt_events`) for standard practice, flashcards, literacy, and concept quizzes, following the exact same owner-isolation, export, and erasure patterns established in `EXM-02B`/`EXM-03`.
   - Transition `user_concept_state` to an atomic server-maintained projection updated when attempt events or `EXM-03` scored attempts are recorded, eliminating client-side read-modify-write races.
3. **Standardized Evidence Fields Across Activity Types**:
   - Every recorded learning or assessment event captures (where applicable to the activity):
     - Content ID, item ID, and `TargetVersion` / manifest revision
     - Canonical `knowledge_concept` and curriculum objective mappings
     - Task profile & assessment format (`structured_choice`, `free_recall`, `spoken_production`, `numeric_with_unit`, `reference_locator_step`, `checklist`)
     - Presented option order (`presented_option_ids`) and selected response
     - Scored outcome / correctness (scored server-side for protected items)
     - Response latency (`latency_ms`)
     - Scaffolding / hints / fading stage used
     - Learner self-reported confidence (when collected)
     - Active exam conditions (`open_book_manifest`, timer state)
     - Provenance tier (`content_trust_level`) so `personal_import` attempts are never mixed into `authoritatively_verified` exam readiness projections.
4. **Measured Storage Discipline (No Unverified Byte Promises)**:
   - Rather than claiming a theoretical 72-byte row size, we benchmark actual PostgreSQL tuple header + index + TOAST overhead under `supabase db reset` before setting retention/archival thresholds.

---

## 6. The 6-Stage Content & Import Pipeline (AI, YouTube, PDFs, Manuals, Decks)

Content availability is solved as a structured pipeline problem while keeping generated/imported material strictly distinguishable from authoritatively verified material:

```text
[1. Source Acquisition]  --> YouTube URLs · PDFs · Official Manuals · Anki/CSV · BYOK/MCP AI
          │
          ▼
[2. Extraction & Provenance] --> Source identity · License/rights · Version/effective date · Citations & passages
          │
          ▼
[3. Knowledge Organization]  --> Map to Canonical Taxonomy fields · Knowledge concepts · Prerequisites · Confusable links
          │
          ▼
[4. Learning Design]         --> Assign LearningTaskProfile · Cognitive operations · Adaptive scaffolding · Distractors
          │
          ▼
[5. Quality Assurance]       --> Deterministic validator · Citation check · Editorial review (ECO-02/04) · Trust level assignment
          │
          ▼
[6. Personalized Delivery]   --> Task-specific instruction · Retrieval & fading · Versioned SRS · Evidence recording
```

### Guardrails Preserving Both Openness and Free-Tier Sustainability
- **Optional Provider Integrations (BYOK / MCP / Local)**: Users may connect their own API keys (including Gemini's public YouTube URL analysis within its free-tier allowance, OpenRouter, OpenAI, or Anthropic) or local browser models. None are mandatory server-paid dependencies.
- **Embed, Never Re-Host**: Video sources use privacy-enhanced embeds + timestamped retrieval checkpoints.
- **Strict Readiness Quarantine for Unverified Imports**: Material at `content_trust_level = personal_import` or `automated_checked` is immediately usable for personal study and spaced review, but **cannot** contribute to official Exam Readiness claims until promoted to `editorially_reviewed` / `authoritatively_verified`.

---

## 7. Research Governance & `/docs/learning_science/` Directory Structure

To replace informal heuristics and secondary summaries (such as Wikipedia citations in legacy UI notes) with auditable primary science, `/docs/learning_science/` is organized into **eight specification documents**:

| Document | Responsibility |
|---|---|
| **[`README.md`](docs/learning_science/README.md)** | Research governance, evidence grading standards, and reconciliation with legacy `docs/design/LEARNING_UI_RESEARCH.md` |
| **[`01_EVIDENCE_REGISTER.md`](docs/learning_science/01_EVIDENCE_REGISTER.md)** | Peer-reviewed research register (DOI/source, methodology, population, sample size, effect size, limitations, negative/mixed findings, applicability, and test plan) |
| **[`02_LEARNING_TASK_TAXONOMY.md`](docs/learning_science/02_LEARNING_TASK_TAXONOMY.md)** | Multidimensional `LearningTaskProfile` taxonomy across knowledge facets, cognitive operations, channels, and conditions |
| **[`03_INSTRUCTIONAL_STRATEGIES.md`](docs/learning_science/03_INSTRUCTIONAL_STRATEGIES.md)** | Retrieval practice, spacing, interleaving, worked examples, feedback timing, backward fading, and empirical moderators |
| **[`04_TASK_SPECIFIC_DELIVERY.md`](docs/learning_science/04_TASK_SPECIFIC_DELIVERY.md)** | Delivery specifications for literacy, vocabulary/concepts, open-book navigation, calculations, oral production, visual classification, and checklists |
| **[`05_LEARNER_ADAPTATION.md`](docs/learning_science/05_LEARNER_ADAPTATION.md)** | Prior-knowledge diagnostics, adaptive scaffolding, and preventing the Expertise Reversal Effect |
| **[`06_MEASUREMENT_AND_SCHEDULING.md`](docs/learning_science/06_MEASUREMENT_AND_SCHEDULING.md)** | Unified evidence contract, reconciling `ConceptEvidenceService` & `user_concept_state`, versioned SM-2 $\to$ FSRS scheduling, and the 3 difficulty constructs |
| **[`07_READINESS_AND_VALIDATION.md`](docs/learning_science/07_READINESS_AND_VALIDATION.md)** | Assessment validity, held-out transfer evaluation, domain-specific validation plans, and real-world outcome verification |
| **[`08_CONTENT_AND_IMPORT_ALIGNMENT.md`](docs/learning_science/08_CONTENT_AND_IMPORT_ALIGNMENT.md)** | Schema & pipeline rules for assigning `LearningTaskProfile` and provenance metadata to existing and imported content |

---

## 8. Phased Implementation Plan & Branch Coordination

### 8.1 Coordination Between `main` and Antigravity (`feature/arch-review-phase-0` / PR `#136`)
- **Stream 1 — Learning Science & Instructional Optimization (this plan, anchored on `main` `e538585`)**: Focuses on the research register, multidimensional task taxonomy, content organization, instructional delivery rules, and unified evidence/readiness specifications.
- **Stream 2 — Engineering & Security Hardening (Antigravity's `feature/arch-review-phase-0`, PR `#136`)**: Continues independently on security fixes, migrations, schema contract checks, lints, and runtime reliability.
- **Integration Rule**: Neither stream assumes unmerged code from the other; both integrate into `main` through reviewed PRs passing all 3 required GitHub Actions status checks.

### 8.2 Seven Implementation Phases & Acceptance Gates

1. **Phase 1 — Research Audit & Evidence Register (`docs/learning_science/01_EVIDENCE_REGISTER.md`)**
   - Audit existing claims in `docs/design/LEARNING_UI_RESEARCH.md` and `LITERACY_ACCESSIBILITY_PLAN.md`; remove unsupported hard rules (e.g., mandatory Pomodoro locks, universal 95% grapheme gates, universal latency thresholds); record positive, mixed, and null findings with DOIs and sample sizes.
2. **Phase 2 — Multidimensional Learning Task Architecture (`02_LEARNING_TASK_TAXONOMY.md`)**
   - Formalize `LearningTaskProfile` and `InstructionalStrategy` schemas and align them with `curriculum_manifest.schema.json` and `CANONICAL_TAXONOMY_ARCHITECTURE.md`.
3. **Phase 3 — Task-Specific Delivery & Adaptive Scaffolding Rules (`03`–`05`)**
   - Specify teaching, adaptive worked-example fading, contrastive interleaving, feedback timing, and assessment rules for each task profile.
4. **Phase 4 — Content Ingestion & Retrofitting Existing Curricula (`08_CONTENT_AND_IMPORT_ALIGNMENT.md`)**
   - Upgrade existing bundled manifests (`content/*.yaml`, `assets/lessons/*.json`, literacy/civic items) and the 6-stage import pipeline to assign `LearningTaskProfile`, `content_complexity_profile`, and `content_trust_level` metadata automatically.
5. **Phase 5 — Unified Evidence Contract & Versioned Scheduler Integration (`06_MEASUREMENT_AND_SCHEDULING.md`)**
   - Reconcile `review_items`, `ConceptEvidenceService`, `user_concept_state`, `EXM-02B`, and `EXM-03`; introduce versioned FSRS scheduling (`v2_fsrs`) alongside preserved `v1_sm2_ladder` schedules.
6. **Phase 6 — Domain-Appropriate Cold-Start Validation (`07_READINESS_AND_VALIDATION.md`)**
   - Validate cold-start defaults using expert-reviewed material, held-out transfer items, and representative learner testing across **each distinct task family** (Florida contractor open-book `EXM` pilot for reference navigation; separate targeted evaluations for adult literacy/decoding, oral civics production, and procedural calculations).
7. **Phase 7 — Empirical Refinement & Outcome Calibration**
   - Update item parameters ($b_i, a_i$ with standard errors), instructional strategy selection, retention scheduling, and readiness calibration as real learner observations and exam outcomes accumulate.
