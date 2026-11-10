# LearningApp — Time-Efficient Learning
## TEL v0.5 Master Implementation Specification: Overview + Fast

| Field | Value |
|---|---|
| Document ID | **TEL-00 / Master** |
| Version | **0.5 — final self-review; documentation-only main commit** |
| Prepared | **2026-11-10** |
| Repository | [`RACCHUS/LearningApp`](https://github.com/RACCHUS/LearningApp) |
| Source documents | TEL-00 v0.1 (2026-11-09); TEL-00A v0.3 (2026-11-10); subsequent engineering review |
| Source inspection | `main` re-checked through `0ee74588dd2b49d8e2a8807afc7c4935659efb1e` (ANA-003 PR #207 merge) on 2026-11-10; see status snapshot and fresh-check requirement |
| Status | **REVIEWED PLANNING SPECIFICATION — authorized to commit this document to the root of `main`; feature implementation and deployment remain pending** |
| Product scope | Faster learning toward defined goals and quick subject exploration, on existing Learn / Library / Progress architecture |

> **Evidence and authority boundary.** Repository files, migrations, generators, GitHub PR metadata, and College Board public pages were inspected for the revisions below. No Flutter build, automated test suite, hosted Supabase data query, deployment audit, user study, or live learning-outcome validation was performed for TEL. A merged migration does not by itself verify production deployment. The external exam sources were checked as of 2026-11-10; confirm their effective edition before publication.
>
> **Implementation authority:** The product owner explicitly authorized a documentation-only commit of this reviewed plan to the root of `main`. This replaces TEL-00 v0.1 and TEL-00A v0.3 as the working planning reference; the earlier drafts remain historical. **The documentation commit is not permission to implement features, run hosted writes, apply migrations, spend money, merge unrelated PRs, or release without the normal approvals and checks.**

---

## 0. Executive decision

**Proceed with Overview first, followed by Fast v1 as guided prioritization.** Preserve the app's core architecture; use existing reviewed material, knowledge relationships, assessment services and goal definitions. Do not build a separate curriculum, duplicate knowledge graphs, or introduce a new top-level navigation tab.

- **Overview** is a **read-only, no-goal-required exploration experience** launched from Library or target detail. It helps someone understand the *shape* of a subject in 5, 15 or 30 minutes. It is **not** a persisted strategy on a learning context, not a mastery credential, and not an assessment prerequisite.
- **Fast** is a **persisted strategy for a defined LearningContext**. In v1 it transparently prioritizes existing eligible activities for an exam target, considers time constraints, reports evidence limitations and retains manual learner control. It **never automatically bypasses instruction, marks competence or predicts a pass probability**.
- **Standard** retains existing behavior, particularly with the TEL feature flag disabled. Lesson, Flashcards, MCQ, Concepts, Mixed and Focus Mode remain presentation/attention choices, not substitutes for these product-level experiences.
- **Fast v2** is the future evidence-based acceleration phase, requiring stronger separated assessment coverage, validated multi-signal evidence, and outcome research before any supported automated bypass or strong quantitative readiness claim.

**Allowed launch language:** “Get oriented in minutes” and “Study the most relevant material first.” **Not allowed:** “Guaranteed to pass,” “90% chance of passing,” “X% faster,” “Official CLEP score prediction,” or implying that a protected mock score is an equated official score.

**Key planning decision:** Overview TEL-01A/02/03 is the first implementation workstream once separately authorized, and can start without new learner-data persistence or a working CLEP diagnostic. Fast TEL-01B/04 requires design audits and explicit write, evidence, duration and ranking contracts. CLEP simulation format correction is a **separate CLEP/EXM issue**, not a blocker for a read-only Overview release.

### 0.1 Final proposed product decisions

| ID | Decision | Status / reasoning |
|---|---|---|
| D1 | Overview is read-only, accessible without creating/pinning a LearningContext | **Adopt**; avoids forcing a goal on exploratory users |
| D2 | Fast is a LearningContext-specific preference; Standard is default | **Adopt**; context remains source of goal identity |
| D3 | Maintain Learn / Library / Progress and Direct Access Rule | **Adopt**; no new tab, wizard or forced placement test |
| D4 | UI uses “Quick overview” action; Standard/Fast selector on eligible contexts | **Adopt**; Overview is not a third persisted selector value |
| D5 | Overview presets: 5, 15, 30 minutes as progressive detail over one reviewed outline | **Adopt**; custom budget later |
| D6 | Pilot Overview on CLEP Introductory Psychology and reviewed seven-family outline | **Adopt subject to editorial review** |
| D7 | Fast v1 targets **exam preparation only**; model contracts accommodate other goals later | **Adopt**; requires reviewed blueprint mapping, not numerical pass estimate |
| D8 | Fast v1 never issues `supported_bypass`; allows `recommended`, `deprioritized`, `unknown`, `manual_skip` | **Adopt**; bypass belongs to v2 |
| D9 | Diagnostic optional if genuinely available; lack of eligible items is normal | **Adopt**; no invented baseline |
| D10 | Reuse known exam date/daily minutes; optional total hours and deadline | **Adopt**; indicate infeasibility and uncovered outline honestly |
| D11 | Separate preference record with **server-enforced revision/conflict protocol**, not `scopeConfig` or whole-context upserts | **Conditional** on TEL-00 identity/RLS/offline design review |
| D12 | Resume pointer wins primary action; Fast recommendation may be a secondary action | **Adopt**; secondary source must be explicitly implemented |
| D13 | Content-time estimates distinguish `default`, `authored`, `measured` | **Adopt**; no precise total if unknown durations remain |
| D14 | Depth tagging uses `lesson_blocks.metadata.depth_tier` and passes through manifest validation | **Adopt conditionally**; audit current import/serialization |
| D15 | Curated reviewed external resource linking follows Overview/Fast pilot (TEL-05) | **Adopt**; linking is not evidence of learning |
| D16 | Original protected simulation bank stays sealed and separate from practice/diagnostic | **Non-negotiable** |
| D17 | Source authority requires real verifiable documents, dates, hashes and clear distinction between official ranges and model weights | **Non-negotiable** |
| D18 | External effectiveness/time-saving claims wait for trustworthy active-time and independent outcome measures | **Non-negotiable** |
| D19 | No new paid services, production data writes, unreviewed AI publication or feature-code merge without normal authorization/checks; this document-only commit is explicitly authorized | **Non-negotiable** |

---

## 1. Product rationale, desired results and exclusions

People often need one of several levels of understanding. They may want enough knowledge to pass a specific exam, enough practical competence to perform a job task, or just enough breadth to decide whether a field deserves further study. A conventional course-first experience can consume substantial time even where an entire curriculum is irrelevant to a narrower goal or the learner already knows parts of it.

**LearningApp's differentiated opportunity is not shortening pages.** It is identifying what matters, locating high-quality material wherever it lives, highlighting gaps, arranging a useful path, offering practice when beneficial, and distinguishing what the user *saw* from what they *demonstrated*. The system must also be able to say “unknown” when evidence is weak.

### 1.1 Success definitions

| Experience | Intended outcome | What does **not** count as proof |
|---|---|---|
| Standard | Conventional course and user-directed progress with existing recommendation/review policy | Merely opening a lesson |
| Overview | Correctly describe the major areas, relationships, examples and limitations within the chosen time/depth | Reading a summary = mastering the subject |
| Fast v1 | Prioritized, coherent and transparent path toward a documented goal using the time available | A prioritization rank = a pass likelihood |
| Fast v2 | Reduced measured learning time to independently supported competence, with appropriate safeguards | FSRS recall probability, self-report, or one MCQ = global mastery |

### 1.2 Anti-goals

Do not force every learner to create a goal before exploring; do not omit legally required training or safety-critical prerequisites; do not mirror copyrighted external lessons without license; do not turn optional knowledge checks into official completion; do not spend on new AI infrastructure to compensate for missing deterministic contracts; and do not call an unvalidated mock exam an official-score estimator.

---

## 2. Repository and dependency baseline

### 2.1 Existing architecture to reuse

| Area | Verified source | Status relevant to TEL |
|---|---|---|
| Context identity and scope | [`lib/models/learning_context.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/models/learning_context.dart) | Context has `rootType`, root ID, target version, scope mode/config, active focus; resume pointer separately modeled |
| Scope resolution | [`lib/models/scope.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/models/scope.dart), [`lib/services/scope_resolver.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/scope_resolver.dart) | Ordered activities, concept scope, role, required flag, duration; **no estimate quality or full objective mapping on activity** |
| Scope cache | `ScopeResolver.computeConfigHash` | Hash includes `scopeConfig`; **do not store Fast preference there** |
| Next action | [`lib/providers/next_action_provider.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/providers/next_action_provider.dart), [`lib/services/next_action_engine.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/next_action_engine.dart) | Provider chooses first incomplete required official activity; pure engine decides resume, remediation, review, next/exit |
| Daily time budget | [`lib/services/daily_plan_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/daily_plan_service.dart) | Exam-date and daily minute support; default 10 min/new, 1 min/review are **not outcome-optimized estimates** |
| Diagnostics | [`lib/services/assessment/diagnostic_assessment_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/assessment/diagnostic_assessment_service.dart) | Reads eligible `assessment_items`, requires coverage; not guaranteed to work for CLEP Psychology given protected-bank separation |
| Adaptive practice | [`lib/services/assessment/adaptive_practice_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/assessment/adaptive_practice_service.dart) | Heuristic three-tier difficulty and theta updates; not a validated skip signal |
| Readiness | [`lib/services/target_readiness_service.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/services/target_readiness_service.dart) | FSRS/concept-related estimates; retrievability ≠ official pass probability |
| Existing learning formats | [`lib/screens/study/lesson_mode_dialog.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/screens/study/lesson_mode_dialog.dart) | Separate from TEL's goal/experience level; file not re-audited during this revision |
| Lesson blocks | [`lib/models/lesson_block.dart`](https://github.com/RACCHUS/LearningApp/blob/main/lib/models/lesson_block.dart) | Generic JSON `metadata` supports potential depth-tier attribute; ingest path needs verification |
| External resource precedents | [`docs/catalog/P2_PRIVATE_GOALS_AND_OFFICIAL_PREP.md`](https://github.com/RACCHUS/LearningApp/blob/main/docs/catalog/P2_PRIVATE_GOALS_AND_OFFICIAL_PREP.md) | Reviewed outbound issuer links exist; no full external learning-path optimizer |
| Learning science | [`docs/learning_science/05_LEARNER_ADAPTATION.md`](https://github.com/RACCHUS/LearningApp/blob/main/docs/learning_science/05_LEARNER_ADAPTATION.md), [`07_READINESS_AND_VALIDATION.md`](https://github.com/RACCHUS/LearningApp/blob/main/docs/learning_science/07_READINESS_AND_VALIDATION.md) | Skip and readiness policies must remain conservative |
| Locked UX | [`UI_ARCHITECTURE_LOCKED.md`](https://github.com/RACCHUS/LearningApp/blob/main/UI_ARCHITECTURE_LOCKED.md) | Preserve three destinations, primary action and direct access; read target/detail screens before UI patch |

**Important data mismatch:** The official curriculum scope resolver currently uses `COALESCE((cn.metadata->>'estimated_minutes')::INTEGER, 10)` for official activities, with an additional single-lesson fallback. Bundled source manifests inspected in TEL-00A did not specify this curriculum-node value, so duration totals in current code are placeholders. Every official activity is marked `is_required=true`, which preserves Standard completion semantics but carries **no Fast ranking meaning**.

**Adaptive practice check:** With baseline information 1 and at most 0.25 Fisher information per item, the configured standard-error target of 0.35 requires more than the default 25 items. Thus the default session's nominal convergence threshold cannot be reached under that estimator; do not interpret theta or convergence as mastery or a bypass gate.

### 2.2 Concurrent PR/status snapshot (2026-11-10, checked after #207 merge)

| Dependency | Verified status | Effect on TEL |
|---|---|---|
| [PR #201, ANA-008](https://github.com/RACCHUS/LearningApp/pull/201) | **Merged** (GitHub PR metadata verified) | RPC-only evidence enforcement is in source; deployed behavior still unverified |
| [PR #203, ANA-001B](https://github.com/RACCHUS/LearningApp/pull/203) | **Merged** (GitHub PR metadata verified) | Canonical lesson progress consolidation in main |
| [PR #207, ANA-003](https://github.com/RACCHUS/LearningApp/pull/207) | **Merged into `main`** (GitHub PR metadata verified) | Foreground active-study interval code landed; correctness, hosted deployment and outcome-measure suitability **not validated for TEL** |
| `lib/services/progress_service.dart` | **Still has mock progress/Random paths** in inspected main | Do not compute TEL evaluation from placeholders; coordinate ANA-002 |
| Prior Priority-1 `record_events` corrective work | Not independently resolved in this audit | Check ownership and state before implementation |
| Other open work | [PR #188](https://github.com/RACCHUS/LearningApp/pull/188) observed open draft at snapshot | Avoid overlapping changes without branch coordination |

Repository state can change quickly; re-check open PRs, migration status and dependencies when creating TEL tickets. No CI or hosted deployment was checked for this plan. **ANA-003 being merged does not mean that time-efficiency metrics are validated or production-deployed.**

---

## 3. CLEP Introductory Psychology pilot: authoritative inventory

### 3.1 Two separate question pools

The [psychology generator](https://github.com/RACCHUS/LearningApp/blob/main/tool/generate_clep_psychology_course.py) verifies **25 lessons**, **50 formative questions** attached to `questions` (two per lesson), and **95 protected simulation items** in `assessment_items`; the source also includes **48 flashcards**. These are not 145 interchangeable assessment items. The 95 are tagged `bank: simulation_exam`, `is_protected: true`, `exposure: timed_exam_only` and must remain isolated from ordinary diagnostics and practice.

| Domain | Official published range | LearningApp model weight | Lessons | Formative | Protected simulation | Flashcards |
|---|---:|---:|---:|---:|---:|---:|
| 1. History, Approaches, and Methods | 11–12% | 0.115 | 2 | 4 | 11 | 4 |
| 2. Biological Bases of Behavior | 8–9% | 0.090 | 2 | 4 | 9 | 4 |
| 3. Sensation and Perception | 7–8% | 0.075 | 2 | 4 | 7 | 4 |
| 4. States of Consciousness | 5–6% | 0.055 | 2 | 4 | 5 | 4 |
| 5. Learning | 8–9% | 0.085 | 2 | 4 | 8 | 4 |
| 6. Cognition | 8–9% | 0.090 | 2 | 4 | 9 | 4 |
| 7. Motivation and Emotion | 5–6% | 0.055 | 2 | 4 | 5 | 4 |
| 8. Developmental Psychology Across the Lifespan | 8–9% | 0.085 | 2 | 4 | 8 | 4 |
| 9. Personality | 7–8% | 0.075 | 2 | 4 | 7 | 4 |
| 10. Psychological Disorders and Health | 8–9% | 0.085 | 2 | 4 | 8 | 4 |
| 11. Treatment of Psychological Disorders | 6–7% | 0.065 | 2 | 4 | 6 | 4 |
| 12. Social Psychology | 9–10% | 0.095 | 2 | 4 | 9 | 4 |
| 13. Statistics, Tests, and Measurement | 3–4% | 0.030 | 1 | 2 | 3 | 0 |
| **Total** | **Ranges, not additive point allocations** | **1.000** | **25** | **50** | **95** | **48** |

**Official-source check:** [College Board CLEP Introductory Psychology](https://clep.collegeboard.org/clep-exams/introductory-psychology), inspected 2026-11-10, publishes these approximate topic ranges, approximately **95 questions in 90 minutes**, and ACE's recommended credit-granting scaled score **50** (institutional policy may differ). The single-decimal LearningApp weights are **internal normalized model allocations**, not exact official question probabilities or a proprietary scoring formula.

### 3.2 Diagnostic availability

The diagnostic service loads client-visible `assessment_items`, whereas these 50 formative questions are in `public.questions`. The migration [`20261108140000_clep_simulation_bank_and_item_privacy.sql`](https://github.com/RACCHUS/LearningApp/blob/main/supabase/migrations/20261108140000_clep_simulation_bank_and_item_privacy.sql) adds a restrictive RLS rule preventing `anon` and `authenticated` clients from directly reading protected simulation items. **Prediction from code, not hosted verification:** CLEP Psychology currently has zero eligible client-visible diagnostic assessment items unless other, non-protected items were independently ingested. TEL must verify hosted counts and authorized client behavior; zero is a normal, supportable state.

**Consequences:** Fast v1 does **not** require a diagnostic. Do not request item text or answer keys from protected simulation tables. The UI shows *not assessed* if appropriate. Completed server-scored exam attempts might offer domain-level outcome summaries via authorized APIs after audit; their use must not expose protected keys or imply exam-equated prediction.

### 3.3 Confirmed sample-format mismatch; actual exam-format verification still required

The [official CLEP Introductory Psychology sample questions](https://clep.collegeboard.org/prepare-for-an-exam/practice-questions-study-guides/sample-questions-introductory-psychology) explicitly present **five suggested answers**. LearningApp's [`CLEP_LESSON_AND_ITEM_SPECIFICATION.md`](https://github.com/RACCHUS/LearningApp/blob/main/docs/catalog/CLEP_LESSON_AND_ITEM_SPECIFICATION.md) requires **exactly four options**, and the authored bank follows that specification.

The official page also cautions that its samples are *not presented exactly as questions will appear on the actual test*. Therefore: **the public sample's five-option format is confirmed; the full live-exam format must still be checked against the official current guide before declaring an exact exam-format rule.** A four-option bank has a different chance-guessing baseline from a five-option bank. Open a separate CLEP/EXM content-quality issue to audit authoring schema, option count, generators, lints, UX, item review, score interpretation and simulation tests. **Do not auto-add distractors, reproduce proprietary test items, or market the simulation as fully exam-realistic until reviewed.** This separate issue does not block read-only Overview.

### 3.4 Provenance audit (must close before verified-authority claims)

The source manifest contains two purported `sha256` values with an implausibly long shared substring. **Treat them as unverified/suspect placeholders**, not authenticated file hashes. Do not claim it is mathematically impossible for different files to share a substring, and do not invent replacement digests. Acquire the actual permissible source document or canonical source artifact; identify exact edition, retrieved date and applicable effective date; calculate the SHA-256 of the **actual archived bytes**; persist repeatable provenance, document URL/rights, and reviewer sign-off. If an official source cannot be archived or hashed legitimately, mark `hash_unavailable` with a verified publisher URL/date and explicit reason—do not fabricate cryptographic assurance.

Fast v1 may truthfully say “Based on College Board's published exam topic outline” when the current publisher page and topic ranges have been reviewed. It must not show “cryptographically verified official edition” until the stronger provenance gate passes. Distinguish this **copy eligibility** from a **release-blocking unverified authoritative requirement** in all acceptance tests.

---

## 4. Non-negotiable product and engineering invariants

1. **Global knowledge / scoped learning.** Reuse canonical concepts; never create a parallel mastery store or mutate official curriculum to make Fast look shorter.
2. **Direct Access Rule.** Any user can open the full official outline and manually choose any eligible lesson, activity, study mode or linked resource. Fast recommendations are not locks.
3. **Evidence is not completion.** Keep official curriculum completion, practice accuracy, self-report, FSRS retrievability, diagnostic evidence, simulation outcomes and external verified exam results distinct.
4. **No false certainty.** Unknown is not weak, and a completed activity is not mastered. No synthetic pass probability, scaled score estimate, guaranteed target outcome or unsupported time-saving percentage.
5. **No automatic bypass in Fast v1.** `manual_skip` is a navigation choice, never an evidence event or official completion. Fast v2 bypass needs independent multi-signal proof and is subject to target-specific policy.
6. **Safety and regulatory constraints.** Do not omit mandatory learning hours, practical demonstrations, safety training, legal prerequisites or exam eligibility rules.
7. **Protected exam integrity.** Only authorized issuer/submit/grading RPCs access protected simulation content. Aggregate reporting is safe only if its source is authorized and can't reconstruct private items or keys.
8. **Content rights.** External links remain outbound unless permission/licensing is verified. AI-drafted text is editorial input, not automatic authority.
9. **No surprise mutation.** Overview reads content but creates no context, pin, pointer, completion, concept evidence or FSRS update. Optional checkpoint is not a learner-mastery write.
10. **Backward compatibility.** With TEL flags disabled Standard is unchanged; old Hive objects/cached scopes load; strategy toggles preserve context and progress.
11. **No stale authority.** Treat source edition, plan metadata, resource availability and learner evidence as versioned/freshness-sensitive.
12. **No unapproved spend or deployment shortcuts.** Feature flags, migrations, RLS, privacy, tests and standard PR reviews remain mandatory.

---

## 5. User experience and eligibility

### 5.1 Overview: explore without commitment

**Entry:** `Library → [Subject/Target] → Quick overview` and equivalent target-detail affordance where design allows. No creation or mutation of a `LearningContext`, no onboarding wizard, no mandatory login or assessment beyond existing content access rights. Unknown/custom subjects without a reviewed outline should show *not yet available* or a reviewed partial outline rather than hallucinate completeness.

**Experience:** Start with the 15-minute orientation by default. A compact 5/15/30 selector controls progressive detail on the **same authored outline**, not three separately generated documents. Display a breadth map with a coherent narrative and one useful example/connection per family; preserve a route to all major families. Indicate omitted topics and information quality. Offer actions *Save topic*, *Start learning*, *Try Fast* only where those actions are actually supported. Saving a topic is a **separate explicit action** that may write data; viewing an overview is not.

**Checkpoint:** optional low-stakes comprehension prompt; no mastery event, official completion, FSRS update or hidden diagnostic inference. In v1, keep transient client state if needed for the screen. Separately approved anonymous product analytics may be added later subject to privacy controls; that is not learning evidence.

### 5.2 Overview: reviewed CLEP Psychology families

| Reviewed-family candidate (requires subject-editor approval) | Official domains included |
|---|---|
| Foundations and method | 1, 13 |
| Brain, senses and awareness | 2, 3, 4 |
| Learning and thinking | 5, 6 |
| Drives and feelings | 7 |
| Growth and personality | 8, 9 |
| Mental health and treatment | 10, 11 |
| People together | 12 |

| Depth | Content and boundary |
|---|---|
| **5 min** | One-paragraph framing, seven reviewed families, one representative concept per family, explicit overview limitations |
| **15 min** | All 5-minute material plus connections between branches, one real application each, 3–4 vocabulary cards and common misconceptions |
| **30 min** | Adds mechanisms, contrasts, examples and optional comprehension checkpoint, with deep links to further study |

Author one coherent outline including: subject definition, boundaries, families, important relationships, representative applications, misconceptions, limitations, direct source attribution and deeper-learning links. A short tour should not imply that all 13 CLEP domains are assessed or taught in sufficient exam depth. **Time presets are intended reading/interaction experiences, not measured guarantees** until observation or authored timing review supports them. Use existing reviewed content and appropriately attributed OpenStax *Psychology 2e* under CC BY 4.0; verify adaptation and attribution requirements in the content-governance workflow.

**Content contract proposal:** an `OverviewOutline` with `source_target_version`, `review_status`, `family_id`, `source_domain_ids`, authored `summary`, `core_concept_refs`, `relationships`, `examples`, `misconceptions`, `depth_sections`, `omitted_areas`, provenance, editorial revision and `duration_tier`. A family is a **reviewed presentation grouping**, not a replacement for official exam domain taxonomy. Avoid arbitrary automatic clustering in MVP.

### 5.3 Fast v1: goal-focused but no misleading automation

**Entry:** Standard/Fast quiet control on an eligible exam-target LearningContext. A target-detail action may create or reuse a target context **only after explicit user action**. Reuse existing exam date and daily minute policy; offer optional total hours/deadline edits without blocking normal use.

**Flow:** select exam goal → inspect verified outline → use any prior reliable evidence or explicitly offer a diagnostic only if eligible → compute prioritized plan → show **one recommended action and a brief reason** → permit full-outline/direct access → continuously adjust recommendations from appropriately authorized existing evidence → show domain coverage and what remains unknown. Switching to Standard is reversible.

**No “fluff” should be an undefined category.** Initially it means (a) off-blueprint content, (b) optional enrichment beyond the selected exam objective, or (c) low-immediate-priority review. It does **not** mean unassessed topics can be discarded, and does not imply mastery. Already-known content may receive lower recommendation urgency only when evidence permits; `supported_bypass` remains off until v2.

**Resume rule:** partially completed activity remains primary under the existing engine. If the Fast planner prefers a different activity, show it as a **secondary action** with a short rationale. A deprioritized resumed lesson remains accessible and resumable, with a gentle note; the learner may choose the new candidate. Switching never clears the pointer, and `planPosition` is recomputed, not separately persisted.

### 5.4 Explanation and learner-visible evidence

Use neutral distinctions:

| Label | Meaning | May drive automatic bypass in v1? |
|---|---|---|
| `not_assessed` | No relevant usable objective/domain evidence | **No** |
| `limited_evidence` | Self-report, lesson exposure, a small practice sample, or FSRS signal not sufficient for performance inference | **No** |
| `practice_evidence_available` | Eligible practice performance exists, but independence and representativeness are limited | **No** |
| `independent_evidence_available` | Appropriately separated and relevant authorized evaluation exists; report its specific scope/age | **No**, still Fast v1 |

Do **not** use unqualified domain labels like “strong” for a subjective familiarity response or FSRS retrieval state. When displaying a recommendation, label its reason as such: *“This area has one of the larger published exam topic ranges”*, *“You have not yet checked this area”*, *“Prerequisite for the next objective”*, *“You chose a shorter session”*, or *“Your recent independent practice suggests more work here”*—only where facts support each statement.

---

## 6. Architecture and data contracts

### 6.1 Two independent flows

```text
OVERVIEW — no LearningContext required
  Library/Target detail
      → Reviewed OverviewOutline + provenance
      → OverviewPlanner (pure; breadth/depth/omissions)
      → Read-only OverviewTour UI
      → Optional explicit Start learning / Try Fast action
      (NO learning evidence, completion, FSRS or resume writes)

FAST v1 — context-specific
  LearningContext + FastPreference + optional constraints
      → ScopeResolver (same eligible boundary)
      → ResolvedScope (+ estimate quality)
      → ContentCoverageService (authorized read-only metadata)
      → Learner Evidence Snapshot (with provenance and limitations)
      → LearningStrategyPlanner (pure deterministic ranking)
      → NextActionProvider.resolve (select planner candidate)
      → ContextSnapshot + separate secondary recommendation metadata
      → NextActionEngine (primary precedence unchanged)
      → Learn UI + direct-access outline
      → Authorized evidence services update underlying evidence
      → Recompute on future selection
```

**Integration seam:** The provider currently chooses a `nextActivity` from incomplete official lessons before calling `NextActionEngine`. For Fast only, choose that activity from planner output. Do not rewrite engine resume, remediation, due-review or forward/exit precedence. A minor `StartActivity` rationale field can be introduced with regression tests. **Secondary Fast recommendation requires a defined UI-provider contract**, because `ContextSnapshot.nextActivity` alone does not expose a second independent recommendation when Resume wins. Proposed: `ResolvedActionPresentation` or `FastCandidateView` returned alongside `NextAction`, containing `secondaryAction?`, `secondaryRationale?` and provenance; keep these presentation details outside the engine, unless an explicit regression review prefers a new optional snapshot field.

### 6.2 Logical models (draft—not migration authorization)

```text
PersistedLearningStrategy = standard | fast
OverviewExperience = quick_overview  // not persisted on a context

FastPreference {
  schemaVersion, contextId, userId, strategy,
  updatedAtServer?, revision, lastMutationId?,
  optionalTotalMinutes?, optionalDeadline?, optionalPolicyOverrides?
}

EstimateQuality = default | authored | measured
ScopedLearningActivity + {
  estimatedMinutes?, estimateQuality,
  // existing eligibility/source/required/order fields remain unchanged
}

CoverageRecord {
  targetVersionId, activityId, curriculumNodeId,
  objectiveIds[], conceptIds[], domainIds[],
  reviewedContentStatus, availablePracticeCounts?,
  authorizedAggregateSimulationCounts?,
  unmappedOrAmbiguous[], provenance
}

EvidenceSummary {
  domainId?, objectiveId?, conceptIds[],
  evidenceStatus, sourceKind, sourceAge?, independence?,
  sampleSize?, limitations[]
}

RecommendedActivity {
  activityId, targetVersionId, domainIds[], objectiveIds[],
  reasonCodes[], rankBand, prerequisiteIds[],
  estimateMinutes?, estimateQuality,
  evidenceStatus, sourceTrust, actionClass
}

FastPlanResult {
  plannerVersion, inputVersions, generatedAt,
  orderedCandidates[], coverageByDomain[],
  unassessedAreas[], blockedPrerequisites[],
  remainingUnknownTimeCount, knownDurationSubtotal?,
  budgetFeasibility, limitations[], explanationCodes[]
}
```

Contracts are conceptual; reuse existing canonical types where possible. The v1 plan is **computed**, not persisted or treated as an evidence source. Source/version/revision fields support future caching; no snapshot table until cost/performance justify one.

### 6.3 Preference persistence and concurrency: required safe protocol

`LearningContextSyncService` currently synchronizes **whole LearningContext objects** based on `lastActiveAt`, and on identity deduplication it may replace a local `context.id` with a remote ID. Therefore: **do not add strategy columns to whole-context sync**, do not put preference in `scopeConfig` (hashed for scope), and do not naively imitate `ResumePointer`'s “compare `updatedAt` then upsert” sequence—concurrent clients can overwrite each other.

Design a private one-row-per-context preference with:

1. **Stable identity:** owner ID + canonical server context ID (or an explicitly documented remapping key), `context_id` FK and delete behavior. Handle guest/local IDs, remote ID reconciliation, archived contexts and context deletion. Dedup/re-key must not orphan preferences.
2. **Owner permissions:** authenticated, owner-scoped SELECT/INSERT/UPDATE/DELETE RLS; forbid foreign context associations; no external read of learner preferences. SQL migration additive and tested.
3. **Conditional server writes:** a single atomic RPC/SQL compare-and-set using `expected_revision` (or equivalent version token) and an idempotency mutation key. Server assigns revision/commit timestamp; the client never dictates the authoritative ordering.
4. **Conflict policy:** a write with a stale revision **fails as a conflict** rather than silently overwriting another device. Client refreshes and, where appropriate, offers user choice or a visible retry. Never call client wall-clock timestamps a guarantee of true cross-device last-human-edit order. If product chooses last **server-accepted** write instead, state and test that alternative explicitly.
5. **Offline operation:** local Fast selection immediately available; queue one idempotent mutation per explicit preference change and reconcile on reconnect. Avoid a stale offline write silently replacing a newer accepted remote preference.
6. **Backward compatibility:** absent remote/local preference means Standard; old Hive adapters and synced contexts load; sign-out, account switch and deletion prevent cross-user leakage.

**TEL-01B exit:** local switching, reconnect replay, duplicate requests, simultaneous devices, server rejection, context ID re-key, remote delete and old-install restore are tested. Do not infer safety solely from a new `updatedAt` field.

**TEL-04A implementation note:** queued offline mutations replay on startup even when the server returns no preferences (e.g. a first Fast preference set offline) and again on connectivity regain; replay is skipped (queue retained) when remote sync is unavailable. The preference migration was renumbered from `20261110230000` to `20261111030000` before any deployment to avoid colliding with the merged Excel attempt-issuance migration; the old version was never applied (no guarded deploy runs).

### 6.4 Time estimates and depth metadata

- Audit the versioned resolver RPC, `ScopedLearningActivity`, `ResolvedScope` serialization and Hive adapter/cache. Introduce `estimateQuality` as an additive contract: `authored` when reviewed metadata specifies a plausible positive value, `default` for fallback 10/15-minute constants, `measured` only with trusted methodology and sufficient observations.
- When input is old or the quality field is missing, decode as **default/unknown**, not authored. Validate unit, reasonable bounds and invalid negative/zero values. `DailyPlanService` should not silently treat fallback values as precise for Fast.
- A complete total-time prediction must be **unknown** when any included activity is default/unknown. Optionally show “Known estimated portion: N minutes, plus activities with unknown duration,” not a falsely exact 3.2-hour promise. Do not infer time savings from this subtotal.
- The existing `lesson_blocks.metadata` JSONB and `LessonBlock` model permit `depth_tier = core | support | enrichment`; review actual manifest parser, ingest RPC and editor semantics before using it. Untagged blocks remain in Standard and full direct view; do not hide safety-critical context merely because of an enrichment tag. A separate authored `OverviewOutline` remains necessary for connecting narratives and reviewed family groupings.
- Author initial `estimated_minutes` at the appropriate imported curriculum-node metadata source, then verify the resolver actually reads it from an imported target. Mark authored guesses as authored *estimates*, not empirical measured medians.

### 6.5 Content coverage and authorization

`ContentCoverageService` must join **eligible** scope activities → curriculum nodes → approved objective/domain/concept mappings → reviewed lesson resources and authorized, purpose-specific counts. An activity ID alone does not supply its concept coverage. Return ambiguous and missing mappings explicitly; no optimistic inference from a title.

Assessment privacy is a hard boundary: the client must not query protected item text, correct answers, item-level secure metadata, or raw scoring keys. If the plan needs a count by domain, use a **reviewed manifest aggregate** or a server-authorized, limited summary endpoint; count outputs must be non-reconstructive and comply with existing RLS/EXM policy. Do not treat protected 95 simulation items as normal practice capacity.

**Per-target blueprint (TEL-04A):** Fast resolves the blueprint from the context's target (`officialDomainsForTarget`). Only CLEP Introductory Psychology has a reviewed blueprint; its lesson/concept mappings apply only to that blueprint. Other exam targets (Fast remains available to them) get a generic course-order plan with no official domain coverage, weighting or gap claims, and the Fast sheet discloses this.

### 6.6 Resource bridge (TEL-05, not an initial dependency)

A reviewed resource may carry provider, URL, concept coverage, source authority, license/rights, review state, access cost, language/modality/accessibility, duration quality, freshness and independent post-resource check availability. Link out by default; do not imply that a click/view proves learning. A later approach may recommend YouTube, Coursera or issuer sources, rank them on pedagogical value and cost, and supply LearningApp assessments to fill gaps. First pilot remains curated and reviewed, with no automatic unlicensed mirroring or unsourced timestamps.

---

## 7. Fast v1 deterministic ranking contract

A vague “goal-value divided by time” formula is **not** enough to be implemented reproducibly. v1 needs a testable rule-based ranker with policy versioning and reason codes, without pretending it is empirically calibrated.

### 7.1 Inputs and provenance

Inputs: target blueprint release and internal normalized weights, resolved eligible activities, reviewed activity-to-objective mappings, prerequisite edges, eligible evidence summaries, existing completion and review state, authored/unknown durations, optional exam date/daily minutes/total minutes. Missing or stale inputs must carry typed uncertainty rather than silently become zero. Self-reported familiarity can influence **recommended order only**, not evidence status or bypass.

### 7.2 Candidate generation and constraint policy (normative)

1. **Bound scope first:** include only directly eligible, accessible, reviewed target activities; preserve a separate complete outline showing deferred/unmapped items and official required activities.
2. **Respect absolute constraints:** safety/legal/credential requirements and versioned exam conditions cannot be reclassified as unnecessary. `is_required` remains official completion metadata, not a rank multiplier.
3. **Resolve prerequisites:** a candidate dependent on unmet prerequisites cannot lead its prerequisite. Construct a DAG when mappings support it. For missing/ambiguous edges, mark the dependency *unknown* and surface an explanation. Cycles fail safely to a reviewed deterministic sequence with an audit warning.
4. **Represent every official domain:** create a plan/coverage row for all 13 domains even with no content or evidence. High-weight areas do not erase low-weight ones. For an actionable plan, reserve an initial representative eligible activity for every domain **if time permits**; otherwise report which domains are not reached by the budget and retain them in the full plan.
5. **Use independent evidence only within its claimed scope:** FSRS is a review cue, formative items a practice cue, self-report a preference cue, simulation domain results only if an authorized summary is available. No automatic bypass.
6. **Rank by versioned, stable rules:** one admissible first policy is priority band → prerequisite readiness → mapped domain normalized weight → evidence need → authored-duration tie-break → official curriculum order → stable activity ID. The precise priority bands/weights must be frozen in `plannerPolicyVersion=fast_v1_1` fixtures before implementation. Do **not** use unknown minutes as denominator zero or a favorable shortcut.
7. **Replan without rewriting evidence:** choose `nextActivity` from eligible, incomplete planner output; retain the existing resume/review engine precedence and active session; record only separately authorized learning events.
8. **Render limitations:** show source-as-of, unmapped objectives, unassessed domains, budget coverage, estimated vs unknown time and reason codes. Do not show a numerical pass chance or fabricated certainty.

### 7.3 Suggested initial ranking policy for deterministic tests

This is a **design proposal, not learned or validated scoring**. Before the first TEL-04 PR, lock a policy table in the ADR and fixtures:

| Field | Suggested handling |
|---|---|
| Mandatory prerequisite | Becomes eligible and ranks ahead of dependent activity if unfinished |
| Explicit learner-selected activity | Direct access always permitted; never silently reclassified as proof |
| Domain weight | Official percentage **range** disclosed; normalized internal point used for stable ranking, not an official probability |
| `not_assessed` | Needs coverage; **neutral/high review priority**, never treated as already known or definitely weak |
| `limited_evidence` | Does not bypass; rationale states limitation |
| Independent objective-relevant weakness | May raise priority, but only with an authorized and representative input |
| `practice_evidence_available` | May affect review priority within limitations; doesn't imply mastery |
| Duration unknown | Preserve candidate; do not treat as free or certain; exclude from precise time totals |
| Equal admissible scores | Stable curriculum order, then stable activity ID |
| No coverage for an objective | Add unassessed/unmapped note; do not generate fake tasks |

**Budgeting:** If a complete plan will not fit before the deadline, choose the best feasible sequence respecting prerequisites, the core breadth floor where possible, and importance; list excluded/unreached areas explicitly. A daily budget from existing policy is a scheduling aid, not a readiness threshold. If **any** included duration is unknown, label total feasibility *provisional* and distinguish known work from unknown work. Never simply count 10-minute placeholders as actual savings.

### 7.4 Engine and resume integration tests

For a target with resolved activities: Standard still selects the first incomplete required official lesson; Fast uses ranker output as candidate; an existing partial resume remains primary; a different Fast recommendation is visible as a secondary action; direct navigation can start any eligible item; review-prioritized and remediation states retain existing order; a completed or removed resume pointer falls through safely; repeated plan recomputation produces identical results for identical inputs and policy version.

### 7.5 Executable Fast v1 policy seed and acceptance fixtures

**Baseline policy ID:** `fast_v1_1` (reviewed starting policy; *heuristic ordering*, not a calibrated learning-effect model). TEL-04 must implement or deliberately supersede this policy in a small versioned ADR **before code review**, not substitute an undocumented numerical score. The following default is sufficiently precise for deterministic fixture tests:

1. **Build candidates:** use incomplete, accessible and approved activities with explicit objective/domain mappings. Choose a `primaryDomainId` via the reviewed objective mapping; for a multi-domain activity, choose the mapped domain with the greatest normalized internal weight and then the lexicographically smallest domain ID. Preserve all secondary domains in coverage, without double-counting the activity as two completed lessons. Unmapped items stay accessible in the full outline but are **not** silently assigned a priority score.
2. **Establish dependencies:** use only confirmed prerequisite edges. A prerequisite that is itself eligible and incomplete is scheduled before its dependent activity, even when its domain has lower model weight. Do not call an unresolved or cyclic dependency 'already satisfied'; mark it ambiguous and use canonical curriculum order for the affected chain until editorial review.
3. **Breadth pass:** inspect official domain IDs by descending *internal normalized weight* and then stable domain ID. For each domain not yet represented, nominate the earliest eligible incomplete mapped activity according to canonical curriculum order plus its prerequisite closure. If no eligible mapped activity exists, emit `coverage_missing` for that domain. Include each candidate at most once. Breadth candidates are prioritized ahead of additional depth in a domain; preserve a full, untruncated course outline.
4. **Depth pass:** rank remaining ready incomplete candidates by a fixed tuple: **(a)** independent, authorized evidence of a relevant gap first, otherwise no asserted gap; **(b)** descending primary-domain model weight; **(c)** reviewed objective importance (`core` before `support` before `enrichment`) when known, otherwise neutral; **(d)** stable canonical curriculum order; **(e)** lexicographic activity ID. Formative/FSRS evidence and self-report can provide a visible, narrowly scoped recommendation note but **cannot lower priority as demonstrated mastery** in Fast v1. Do not promote an activity solely because duration is missing, or classify an unassessed domain as weak.
5. **Schedule against time:** maintain both `fullOrderedCandidates` and `provisionalBudgetSchedule`. For activities with `authored` or defensibly `measured` estimates, sum positive minutes. For any selected activity with `default` or absent quality, show **unknown total**, a known-duration subtotal and the number of unknown activities. Never claim a feasibility percentage based on placeholder 10/15-minute defaults. If a requested hard budget leaves some domains untouched, list those domains and the current schedule's breadth shortfall; never delete them from the full outline.
6. **Presentation and recompute:** `NextActionProvider` supplies the Fast candidate to the existing engine while the primary resume/review/remediation precedence remains unchanged. A separate typed presentation result carries the Fast candidate as a secondary action when Resume wins. Equal inputs plus the same `plannerPolicyVersion` and **explicit `asOf` clock value** yield the same ordered IDs, reason codes, omissions and estimates; `generatedAt` may differ only when explicitly excluded from deterministic comparison. No ranking call is a mastery, completion or exam-evidence write.

**Minimum golden fixtures** for `fast_v1_1` (with audited inputs and exact expected order/reasons):

| Fixture | Input condition | Required behavior |
|---|---|---|
| BREADTH-01 | 13 blueprint domains, uneven weights, all eligible | First coverage pass represents all 13 before second-depth recommendations, subject to prerequisite closure |
| PREREQ-01 | Highest-weight lesson depends on unfinished lower-weight prerequisite | Prerequisite appears first; explanation cites dependency |
| EVIDENCE-01 | Domain A self-reports familiarity; B has no valid assessment | A is **not** bypassed or marked competent; B remains `not_assessed` |
| COVERAGE-01 | Domain lacks mapped lesson | Domain stays in coverage as `coverage_missing`; no invented activity |
| BUDGET-01 | Known 20-minute budget, at least one unknown-duration lesson | Total and budget feasibility are provisional; known subtotal and unreached domains disclosed |
| RESUME-01 | Learner halfway through a deprioritized lesson | Resume is primary; Fast alternative is secondary; pointer unchanged |
| ORDER-01 | Same versioned inputs, ties and `asOf` | Ordered IDs and reason codes identical across repeat calls and offline restoration |
| SAFE-01 | Client attempts protected-bank read in planner/coverage | Denied or absent by construction; only approved aggregate metadata allowed |

These defaults are **engineering acceptance semantics, not a claim that this ranking maximizes pass rates**. Data and learner outcomes may support a later, separately reviewed policy version; existing plan/evidence history must not be silently reinterpreted.

---

## 8. Release standards and rollout gates

### 8.1 Overview MVP (TEL-03)

**May ship when:** reviewed and appropriately attributed seven-family Psychology outline; functioning 5/15/30 progressive detail; clear omitted-subject areas and limits; accessibility review; deep links working where offered; no implicit goal/context creation; no learner evidence/completion/FSRS writes; no false badge of competency; Standard unaffected with TEL flag off.

**Cannot claim:** comprehensive subject mastery, complete exam preparation, measured 5/15/30 completion for all users without evidence, or exam pass readiness.

### 8.2 Fast v1 — guided prioritization (TEL-04)

**May ship when all these are true:**

1. Publisher topic ranges/current outline reviewed; internal numeric weights explicitly labelled LearningApp allocations. Provenance display matches actual verification level—no placeholder digest passed as verified.
2. Every official domain appears in the coverage/outstanding-work display, and each recommended lesson has a reviewed objective/concept mapping or an explicit unmapped warning.
3. Unknown/default durations propagate and do not produce precise total-time or percentage-savings claims.
4. Every evidence cue has a source, specificity and quality label (`not_assessed`, `limited_evidence`, `practice_evidence_available`, `independent_evidence_available`); no blanket “strong” label derived from self-report or FSRS.
5. Deterministic planner rules, coverage floors, prerequisites, resumption, direct access, and unknown-data fallback pass tests.
6. Client planner/coverage code cannot read or reveal protected simulation item text/keys; domain counts, if displayed, are authorized reviewed aggregates.
7. No automatic bypass, no unsupported diagnostic requirement, no scaled-score/pass-probability claim, and no silent official completion change.
8. Preference persistence, conflict protocol, RLS, identity re-key and offline compatibility have passed review and tests.
9. Flag-off Standard regression, accessibility, responsive layout, offline fallback and rollback checks pass.

**Not required for Fast v1:** a diagnostic, a minimum item count per objective, an independent held-out bank or an empirical time-efficiency result. If the content is too sparse for useful recommendations, do not enable the flag for that target even if the generic implementation is safe; document a human editorial decision. The first Fast v1 pilot must also pass the versioned `fast_v1_1` fixtures in §7.5 (or a documented reviewed successor).

### 8.3 Fast v2 — evidence-based acceleration (future, separately approved)

Requires all Fast v1 guarantees plus sufficient *separate*, reviewed practice and independent held-out coverage, multi-signal objective-level evidence, validated diagnostics where proposed, cross-format appropriate tasks, and target-specific empirical research. TEL-00A's **provisional** authoring goal of four practice and two held-out items per objective can seed planning, but is **not** a universal psychometric standard; review by assessment experts and adjust to target objectives, item quality and statistical precision. Protected summative simulation questions remain distinct. `supported_bypass` may bypass **introductory instructional recommendation only** under explicit policy, not mandatory credentials, official completion, or exam eligibility.

Do not enable quantitative pass-readiness or “X% faster” marketing merely because a bank meets a raw item count. Require independent validation, reliable active time, delayed retention and, where possible, consented real-world outcomes.

### 8.4 Release and rollback mechanics

Use feature flags by route, target and user cohort; Standard remains default. Guard every DB migration with backward compatibility and owner-scoped RLS tests. Staged rollout: internal/reviewer → limited pilot → optional wider access after evaluation. Turning a flag off restores Standard without erasing preferences, progress or learner records. This **documentation-only** change may be committed directly to `main` because the product owner expressly requested it. Feature code and database changes still use ordinary PR review, required checks and branch protections before merge; do not bypass repository rules.

---

## 9. Delivery sequence and concrete PR backlog

| Phase | Scope | Dependencies | Deliverable and acceptance |
|---|---|---|---|
| **TEL-00** | Technical audit and ADR | Current `main`, ANA/CLEP/EXM state | Hosted/authorization inventory, read paths, source provenance, preference identity/RLS plan, duration/ingest compatibility, UI placements; no writes |
| **TEL-01A** | Overview feature-flag/route skeleton | TEL-00 UX/scope audit | `Quick overview` from Library/target detail, typed read-only contracts, no `LearningContext` or evidence mutation; flag-off regression and accessibility tests |
| **TEL-02A** | Content quality/metadata | Editorial review, import contract audit | Psychology seven-family reviewed outline, applications, misconceptions, OpenStax attribution, authored duration and `depth_tier` import validation |
| **TEL-02B** | Coverage and pure planner primitives | Mapping + scope resolver review | `ContentCoverageService`, estimate-quality propagation, reproducible fixtures, unknown-data safe defaults, no protected content read |
| **TEL-03** | Overview MVP | TEL-01A/02A | Cohesive 5/15/30 tour; omissions, deep links, optional no-evidence checkpoint, a11y/offline tests; ship independently of ANA-003 |
| **TEL-01B** | Fast preference persistence | TEL-00 concurrency/RLS/identity ADR | Separate preference record, server CAS, Hive/local fallback, idempotency, offline conflict and re-key tests |
| **TEL-04** | Fast v1 pilot | TEL-02B/01B, source/coverage review | Explicit ranking policy, explainable decisions, budget, secondary resume action, manual skip/unknown states; Fast v1 gates |
| **TEL-05** | Curated external resource bridge | Prior pilot + content governance | Link-out provenance/freshness/accessibility and concept mapping, no mirroring or click-as-mastery |
| **TEL-06** | Measurement and rollout | Trusted ANA active time + independent assessments | Standard/Fast comparable studies, Overview comprehension tests, delayed retention, verified caveats; claim gates and rollback |
| **CLEP/EXM parallel** | Official sample-option fidelity and exam-bank quality | Current official guide + content-review process | Independent issue and PR; audit five-option sample mismatch, scoring/UX/schema/generator impact, editorial review |

**Parallelization:** TEL-01A/02A Overview work can proceed without preference migration or a working Fast diagnostic, while ANA-002, ANA-003 verification/integration, Priority 1 and CLEP/EXM continue in their own streams. Avoid simultaneous edits to shared migrations and scope contracts. TEL-02B should coordinate with the newly merged ANA-003 active-time changes but **must not treat their measurements as validated efficiency outcomes**.

### 9.1 TEL-00 audit checklist (specific outputs)

- [ ] Snapshot current `main` SHA, feature flags, existing open PRs/owners, release/deployed version and overlapping work.
- [ ] Inspect `Library`, target-detail, Learn and UI-locked contracts for both entry actions and accessible labels.
- [ ] Validate `public.questions`/`assessment_items` hosted bank counts and whether any **non-protected** Psychology diagnostic items are client-visible; do not expose answer keys in audit logs.
- [ ] Confirm whether formative answers create concept evidence and at what specificity; distinguish server scoring from display.
- [ ] Verify manifest metadata propagation into `lesson_blocks.metadata` and curriculum-node `estimated_minutes`; add schema/lint cases.
- [ ] Verify resolver RPC JSON shape, `ResolvedScope` Hive/cache migration, invalidation and backwards compatibility for `estimateQuality`.
- [ ] Confirm actual current official CLEP source edition, approximate ranges, format conditions and documented source hash process; replace suspected placeholder hashes only using real bytes.
- [ ] Draft preference SQL/RPC+RLS contract, server revision/CAS policy, offline/re-key reconciliation and deletion semantics. Audit signed-out behavior.
- [ ] Confirm available authorized aggregate simulation coverage and whether domain-level submitted simulation feedback can safely inform *limited* Fast evidence.
- [ ] Record policy version and deterministic ranking examples; agree on prerequisite, unknown-time and coverage floors.
- [ ] Confirm accessibility, no-context read-only Overview route and no writes; sign off first editorial subject outline.
- [ ] Record privacy/consent and analytics dependencies; explicitly forbid time-saved claims pending ANA correctness.

### 9.2 Definition of done for each PR

A PR includes a bounded scope and issue reference, a change in behavior documented with source authority, deterministic unit/fixture tests, appropriate integration/widget/RLS tests, stable flag-off fallback, migration roll-forward/rollback plan if relevant, no paid infra additions, no entitlement changes, no protected item leakage, and all required CI results completed before merge. Update TEL plan status when a dependency changes rather than silently redefining previous acceptance gates.

---

## 10. Verification and test matrix

| Test family | Required cases | Phase |
|---|---|---|
| Overview read-only | Launch without context, close without writes, no pins/resume/progress/evidence changes, optional checkpoint transient only | 01A/03 |
| Editorial coverage | Every reviewed family maps to source domains, source attribution present, omissions explicit, unreviewed branch blocked | 02A/03 |
| Preset coherence | 5→15→30 progressively adds depth without inconsistent definitions or missing the breadth map; no independent duplicated documents | 02A/03 |
| Standard regression | TEL flag disabled reproduces current standard next action and three-tab navigation; direct access still works | Every PR |
| Duration quality | Old cache decodes quality `default`; missing/negative/invalid times do not become precise totals; authored import round-trips | 02B/04 |
| Mapping fidelity | Lesson→curriculum node→concept/objective; ambiguous/unmapped returned as unknown; no title-only guessed coverage | 02B/04 |
| Protected exam safety | Client-side coverage queries cannot select protected question text or scoring keys, RLS denied, authorized aggregate limited | 02B/04 |
| Ranking | Same snapshot produces same order; official domains represented; prerequisites first; missing time/evidence doesn't create magical high rank; stable ties | 02B/04 |
| Resume interaction | Mid-lesson switch to Fast: resume primary, Fast secondary; no pointer corruption or duplicate completion; review precedence remains | 04 |
| Storage/concurrency | Two devices change Fast simultaneously; one offline; stale CAS rejected; idempotent retries; context ID re-key; deletion and sign-out | 01B |
| Target version drift | Blueprint or content revision invalidates derived coverage/plan, published content not overwritten; no auto-transfer of unsupported evidence | 02B/04 |
| Accessibility | Keyboard, screen reader, focus, readable tap targets, reduced motion, narrow/mobile layouts and plain-language uncertainty | 01A/03/04 |
| External resources | URL provenance/permissions, stale/withdrawn links, cost/accessibility labels, click not recorded as mastery, no unsafe HTML/script processing | 05 |
| Outcomes | Validated foreground time and quality, comparable independent check, delayed retention, fairness/small-sample caveats, consent | 06 |
| Release | Rollback feature flag, migration compatibility, permissions, tests and required branch checks completed | Every PR |

**Unverified now:** none of these TEL tests has been executed by preparation of this document. They are future exit criteria, not completed evidence.

---

## 11. Evaluation and product metrics

### 11.1 Overview

Measure whether learners can name major branches, accurately connect concepts and give at least one representative application after the experience; measure first-useful-understanding time, readability, abandonment and choice to explore further. Do not use an optional ungraded checkpoint to infer official mastery. Feedback about confidence/interest is product feedback, not competence evidence.

### 11.2 Fast

Measure baseline comparable prior knowledge, coverage by official domain/objective, active study minutes from trustworthy foreground/non-idle instrumentation, independent post-checks, delayed retention, and voluntary real-world exam results where available. Evaluate Standard vs Fast for users with comparable initial knowledge and objectives; explicitly account for selection bias, small pilot sizes, missing data and repeat exposure of questions. Do not use protected simulation items simultaneously for teaching, diagnostic and independent validation.

**Claim policy:** before trustworthy evidence, say “prioritizes relevant material,” not “saves 40% of your study time.” Efficiency means **measured outcome improvement per verified unit of time**, not merely fewer lesson screens, reduced content or an optimistic countdown.

---

## 12. Risks, mitigation and ownership

| Risk | Mitigation / owner stream |
|---|---|
| Overview omits whole branches and masquerades as a complete field | Reviewed family map + explicit omitted areas — TEL-02A/03 editorial |
| Fast ranks unsupported high-weight items as known/unknown incorrectly | Typed evidence quality and complete domain rows — TEL-02B/04 |
| Official required activities confused with Fast priority | Keep `is_required` for Standard; separate policy rank — TEL-04 |
| Missing duration converted into invented savings | Default/authored/measured quality and unknown total — TEL-02B, ANA-003 |
| Protected simulation bank used as diagnostic or leaked | DB RLS, server issuer/submit RPC, nonreconstructive aggregates — EXM/CLEP + TEL-02B |
| CLEP five-option sample mismatch ignored in simulation fidelity | Separate assessed CLEP/EXM correction, no premature claim — CLEP/EXM |
| Suspect source hashes treated as authenticated | Retrieve/verify actual bytes or disclose missing hash — catalog/CLEP |
| Offline Fast selection silently overwritten | Server CAS+revision, conflicts, context re-key tests — TEL-01B |
| Fast suggests advanced work before prerequisites | Verified graph policy and deterministic fallback — TEL-04 |
| Planner claims mastery based on FSRS or self-report | Distinct evidence bands; supported bypass deferred — TEL-04/06 |
| New interface clutters locked UX | Contextual entry only, one primary action, low-salience secondary — TEL-01A/03/04 |
| External materials stale, paid or unlicensed | Reviewed links with cost/rights/freshness labels — TEL-05 |
| Other in-flight ANA/CLEP/EXM PRs conflict | Audit status/ownership, bounded PRs, explicit merge sequencing — TEL-00 |
| Quantitative effectiveness claim based on mock progress | ANA correctness and independent study before publication — TEL-06 |

---

## 13. Proposed source touchpoints and issue ownership

```text
# New contracts/logic (suggested paths; validate final naming at TEL-00)
lib/models/learning_strategy.dart          # persisted Standard/Fast + Overview entry contract
lib/models/fast_plan_result.dart
lib/models/overview_outline.dart
lib/services/planning/content_coverage_service.dart
lib/services/planning/learning_strategy_planner.dart
lib/services/planning/overview_planner.dart
lib/providers/learning_strategy_provider.dart
lib/screens/overview/overview_tour_screen.dart
lib/widgets/learn/learning_approach_selector.dart
lib/widgets/library/quick_overview_entry.dart

# Existing code to integrate carefully
lib/models/learning_context.dart
lib/models/scope.dart
lib/models/lesson_block.dart
lib/services/scope_resolver.dart
lib/services/learning_context_sync_service.dart
lib/providers/next_action_provider.dart
lib/services/next_action_engine.dart
lib/services/daily_plan_service.dart
lib/services/assessment/diagnostic_assessment_service.dart
lib/services/assessment/clep_simulation_service.dart
lib/services/target_readiness_service.dart
lib/screens/learn/learn_screen.dart
lib/screens/targets/target_detail_screen.dart

# Schemas and fixtures conditional on audit
supabase/migrations/*TEL*              # only if storage/aggregate RPC approved
supabase/tests/*TEL*.sql
test/services/planning/*
test/widgets/overview/*
test/providers/learning_strategy_provider_test.dart
content/clep_introductory_psychology.yaml
content/schema/curriculum_manifest.schema.json
```

**Important architectural choice:** Do not create duplicate `LearningContext`, concept state, plan-completion or assessment authority models. Use a pure planner + provenance-aware read models. Keep protected per-user mutation behind established RPC/authorization practices. Where a proposed interface collides with existing code, record a small ADR before patching.

---

## 14. Owner review and immediate next actions

### Recommended approval

**Approve TEL-00 and the read-only Overview workstream (TEL-01A/02A/03) now.** Approve Fast's **product behavior** but hold its persistence and implementation PRs until TEL-00 closes server conflicts, item/privacy contracts, deterministic policy and source/coverage audits. Create and prioritize a **separate CLEP/EXM fidelity ticket** for the five-option sample discrepancy; do not block Overview on it.

### First executable steps after authorization

1. **TEL-00 ADR + audit:** publish the authoritative contract, evidence-boundary and unresolved hosted findings; capture exact current main/PR state. No hosted writes.
2. **TEL-01A PR:** flag-gated `Quick overview` route and contracts, read-only and context-free, with direct-access/Standard regression and accessibility tests.
3. **TEL-02A editorial batch:** review Psychology families, connections, applications, misconceptions and attribution; author content once across depth tiers; verify import semantics where applicable.
4. **TEL-02B coverage work:** implement estimate-quality contract and readonly mapping with missing-data and protected-bank tests; maintain compatibility with active ANA work.
5. **TEL-03 Overview end-to-end:** run all checks, obtain content review, deploy only under flag/authorized review. Then complete TEL-01B/04 Fast gates and evaluate independently.

### Items requiring explicit product-owner confirmation

- Final release copy and eligibility for a context-free Overview; psychology first subject and seven-family editorial outline.
- Preference conflict UX (server rejects conflicting writes vs last-server-accepted update); default proposed is **reject stale revisions and reconcile visibly**.
- Whether Fast should show a “Known estimated portion + unknown time” subtotal when time is incomplete; default proposed is yes, without precise total or savings claim.
- Activation of a Fast v1 Psychology pilot after audit despite diagnostic absence; default proposed is yes **only if** reviewed mappings and plan quality are materially useful.

**Authorization boundary:** the owner requested a reviewed Markdown document in the root of `main`. That authorizes this documentation commit only, not feature implementation, migration, deployment or paid resources.

---

## Appendix A. Authority references

**Official sources**

- [College Board CLEP Introductory Psychology overview, published domain ranges, timing and credit policy](https://clep.collegeboard.org/clep-exams/introductory-psychology)
- [College Board Introductory Psychology sample questions — five suggested answers; explicit caveat about sample presentation](https://clep.collegeboard.org/prepare-for-an-exam/practice-questions-study-guides/sample-questions-introductory-psychology)
- [OpenStax Psychology 2e, CC BY 4.0 (verify attribution and adaptation)](https://openstax.org/details/books/psychology-2e)

**LearningApp source and policy**

- [LearningApp README](https://github.com/RACCHUS/LearningApp/blob/main/README.md)
- [Learning Architecture v2](https://github.com/RACCHUS/LearningApp/blob/main/LEARNING_ARCHITECTURE_V2.md)
- [Locked UI architecture](https://github.com/RACCHUS/LearningApp/blob/main/UI_ARCHITECTURE_LOCKED.md)
- [CLEP psychology generator — 50 formative + 95 protected simulation](https://github.com/RACCHUS/LearningApp/blob/main/tool/generate_clep_psychology_course.py)
- [CLEP lesson and assessment item specification](https://github.com/RACCHUS/LearningApp/blob/main/docs/catalog/CLEP_LESSON_AND_ITEM_SPECIFICATION.md)
- [CLEP privacy and bank separation migration](https://github.com/RACCHUS/LearningApp/blob/main/supabase/migrations/20261108140000_clep_simulation_bank_and_item_privacy.sql)
- [Learner adaptation policy](https://github.com/RACCHUS/LearningApp/blob/main/docs/learning_science/05_LEARNER_ADAPTATION.md)
- [Readiness validation policy](https://github.com/RACCHUS/LearningApp/blob/main/docs/learning_science/07_READINESS_AND_VALIDATION.md)
- [EXM design architecture](https://github.com/RACCHUS/LearningApp/blob/main/docs/exm/EXM_00_EXAM_SUCCESS_ARCHITECTURE_PLAN.md)
- [Analytics implementation plan](https://github.com/RACCHUS/LearningApp/blob/main/LEARNINGAPP_ANALYTICS_IMPLEMENTATION_PLAN.md)
- [Private goals and official preparation resources](https://github.com/RACCHUS/LearningApp/blob/main/docs/catalog/P2_PRIVATE_GOALS_AND_OFFICIAL_PREP.md)

## Appendix B. Changelog and supersession

- **v0.1 / TEL-00 — 2026-11-09:** Initial strategy architecture, learning-science invariants, original roadmap and open owner decisions.
- **v0.2 / TEL-00A — 2026-11-09:** Repository audit identified duration placeholders, official-required flag misuse, missing coverage mapping, item bank concerns and suggested Overview-first approach.
- **v0.3 / TEL-00A — 2026-11-10:** Corrected 50 formative/95 protected split, separated Overview from persisted strategies, split Fast v1/v2 release gates, introduced per-context preference and resume policy, flagged suspect blueprint hashes.
- **v0.4 / TEL Master — 2026-11-10:** Consolidated decisions into one specification; verified official ranges for all domains and five-option public sample; clarified that sample presentation does not prove live-exam format; specified server revision/CAS sync with context re-key handling; typed evidence quality; protected aggregate access; deterministic ranking and secondary action contract; changed roadmap to Overview-first read-only vertical slice; updated dependency states, test matrix and release gates.

- **v0.5 / TEL Master — 2026-11-10:** Final self-review: made documentation-only `main` authorization explicit; added `fast_v1_1` executable planner comparator, evidence guardrails and acceptance fixtures; refreshed main/ANA-003 status (merged, not outcome-validated); clarified deterministic plan inputs and provisional budgeting.

**Approval state:** **Documentation approved for placement in `main` by explicit request; feature implementation decisions and release gates still require normal owner/engineering approvals.** TEL-00 / TEL-00A prior drafts are historical references.
