# TEL-00: Technical Audit & Architecture Decision Record (Overview + Fast v1)

| Field | Value |
| --- | --- |
| **Document ID** | `TEL-00` |
| **Status** | Accepted & Implemented |
| **Baseline Commit** | `3b6f4cc` (`origin/main` following ANA-008, ANA-001B, ANA-003, ANA-101/102, and TEL v0.5 master plan) |
| **Normative Spec** | [`LEARNINGAPP_TEL_V0_5_MASTER_IMPLEMENTATION_PLAN.md`](../../LEARNINGAPP_TEL_V0_5_MASTER_IMPLEMENTATION_PLAN.md) |
| **Planner Policy Version** | `fast_v1_1` |

---

## 1. Executive Decision Summary

1. **Overview (`Quick overview`) and Fast (`Fast` learning approach) are distinct product modes**:
   - **Overview** is a read-only, transient subject tour (`5 min`, `15 min`, `30 min`) launched from `Library` or `TargetDetailScreen` via `/overview/:targetId`. It never creates or modifies a `LearningContext`, `ResumePointer`, `learner_activity_progress`, `user_concept_state`, or FSRS card state.
   - **Fast** is a persisted per-context learning strategy (`PersistedLearningStrategy.standard | fast`) for eligible target-backed contexts (`LearningContextType.examTarget` in v1) that re-ranks candidate lessons by official domain breadth, prerequisite closure, and independent gap evidence while keeping **Resume** primary (`RESUME-01`).

2. **Strict Separation of Fast Preference from `LearningContext.scopeConfig`**:
   - `ScopeResolver.computeConfigHash` hashes `context.scopeConfig` directly. Storing strategy or budget preferences inside `scopeConfig` would invalidate `ResolvedScope` cache keys and risk whole-row overwrites during `LearningContextNotifier._syncToSupabase`.
   - `FastPreference` is persisted in a dedicated per-context store (`FastPreferenceStore` / `LearningStrategyNotifier`) with explicit schema versioning, user-scoped storage keys, compare-and-set (`expectedRevision`) conflict detection, idempotency mutation keys (`lastMutationId`), and `rekeyContext(oldContextId, newContextId)` migration when client-generated context IDs reconcile with server UUIDs.

3. **Truthful Evidence & Simulation Bank Isolation (`SAFE-01`, `EVIDENCE-01`)**:
   - In `content/clep_introductory_psychology.yaml`, only the 50 formative items (`practice` / `checkpoint` / `drill`) are exposed to client-side coverage and practice inspection.
   - The 95 simulation items (`delivery_mode: simulation_only`) remain strictly isolated behind server RPCs (`start_simulation_attempt`, `get_simulation_attempt_items`, `submit_simulation_attempt`). `ContentCoverageService` and `LearningStrategyPlanner` reject any attempt to read protected item stems, choices, or scoring keys (`SAFE-01`).
   - Fast v1 is **guided prioritization**, never `supported_bypass`. Self-reported familiarity or FSRS card stability never marks a domain as mastered or bypassed (`EVIDENCE-01`).

---

## 2. Fresh Baseline Verification (`main` @ `3b6f4cc`)

| Subsystem | Inspected Path | Baseline Finding & TEL Design Impact |
| --- | --- | --- |
| **Context & Scope** | `lib/models/learning_context.dart`, `lib/models/scope.dart`, `lib/services/scope_resolver.dart` | `ScopedLearningActivity.estimatedMinutes` defaults to `15` when null in curriculum/Supabase rows. Added `EstimateQuality estimateQuality` (`defaultEstimate`, `authored`, `measured`) with safe fallback decoding for cached JSON/Hive snapshots. |
| **Lesson Block Metadata** | `lib/models/lesson_block.dart` | `LessonBlock.metadata` is `Map<String, dynamic>`. Added typed `DepthTier get depthTier` (`core`, `support`, `enrichment`; defaults to `core`). |
| **Completion & Evidence** | `lib/providers/next_action_provider.dart` | `ContextSnapshotResolver._getCompletedLessonIds` queries canonical `learner_activity_progress` (`status = 'completed'`) with legacy fallback to `user_progress`. Fast planner consumes this exact completed-activity set. |
| **Next-Action Precedence** | `lib/services/next_action_engine.dart` | Primary precedence (`ChooseSomething` -> `ResumeActivity` -> `ReinforceConcepts` -> `PrioritizedReview` -> `StartActivity` -> `ReviewOnly` -> `ContextComplete`) is preserved unchanged. When `ResumeActivity` wins while Fast recommends a different top candidate, `ResolvedActionPresentation` surfaces the Fast recommendation as a secondary action (`RESUME-01`). |
| **CLEP Psychology Manifest** | `content/clep_introductory_psychology.yaml` | Contains 13 official domains (`1.0`..`13.0`), 21 lessons, 50 formative items, and 95 simulation items. The two manifest `sha256` strings share a repeated substring (`...e95632b85d38f8cf2e4389ab9213bc54784a621e25e9d3d3a77a94f0...`) and are flagged as `SourceVerificationLevel.unverifiedPlaceholder` (`hash_unavailable`) in UI/provenance disclosures. |

---

## 3. Normative `fast_v1_1` Ranking & Tie-Breaking Contract

1. **Candidate Normalization**:
   - Each incomplete `ScopedLearningActivity` in `ResolvedScope` is mapped to its curriculum domains and concepts via `ContentCoverageService`.
   - `primaryDomainId` is the mapped official domain with the highest normalized internal weight (ties broken by lexicographic domain ID). All additional mapped domains remain in `secondaryDomainIds`.
2. **Prerequisite Closure (`PREREQ-01`)**:
   - Unfinished eligible prerequisite activities must precede dependent activities. Cycles or dangling prerequisite IDs are detected via 3-color DFS, logged as structural warnings, and fall back deterministically to canonical curriculum order.
3. **Pass 1 — Official Blueprint Breadth (`BREADTH-01`, `COVERAGE-01`)**:
   - Iterates through all 13 official domains ordered by descending normalized internal model weight, then lexicographic `domainId`.
   - For each domain lacking independent competency evidence and not yet covered by a completed or already-scheduled activity, selects the best eligible representative activity (and its unfinished prerequisites) using the Pass 2 tie-breaker.
   - Domains with no mapped eligible activity emit `coverage_missing` in `DomainCoverageSummary` without inventing activities.
4. **Pass 2 — Weighted Gap & Core Depth (`EVIDENCE-01`, `ORDER-01`)**:
   - Remaining eligible activities are ordered by:
     1. Independent authorized gap evidence (`independentEvidenceAvailable` with low score / high gap first),
     2. Descending primary-domain normalized weight,
     3. Objective importance (`DepthTier.core` < `support` < `enrichment`),
     4. Canonical curriculum `orderIndex`,
     5. Lexicographic `activity.id`.
5. **Pass 3 — Provisional Time Budgeting (`BUDGET-01`)**:
   - Always emits `fullOrderedCandidates`.
   - When `optionalTotalMinutes` is provided, constructs `provisionalBudgetSchedule`. If any candidate relies on `EstimateQuality.defaultEstimate`, `budgetFeasibility` is marked `BudgetFeasibilityStatus.provisionalUnknownTime` and the UI discloses `knownDurationSubtotalMinutes` and `remainingUnknownTimeCount`.
