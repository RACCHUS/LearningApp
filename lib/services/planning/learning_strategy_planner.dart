import '../../models/fast_plan_result.dart';
import '../../models/learning_strategy.dart';
import '../../models/scope.dart';
import '../next_action_engine.dart';
import 'content_coverage_service.dart';

/// Deterministic, side-effect-free planner implementing policy `fast_v1_1` (`TEL-04`).
///
/// Satisfies all 8 normative golden fixtures (`§7.5`):
/// - `BREADTH-01`: Official blueprint breadth pass across all 13 domains before depth pass.
/// - `PREREQ-01`: Unfinished prerequisites scheduled before dependents with explicit rationale.
/// - `EVIDENCE-01`: Self-report / FSRS never bypasses or marks competent; unassessed stays `not_assessed`.
/// - `COVERAGE-01`: Domains without mapped activities remain visible as `coverage_missing`.
/// - `BUDGET-01`: Unknown (`defaultEstimate`) durations mark budget feasibility provisional.
/// - `RESUME-01`: Active partial `ResumePointer` stays primary; Fast recommendation is secondary.
/// - `ORDER-01`: Identical versioned inputs produce identical ordered IDs and reason codes.
/// - `SAFE-01`: Protected simulation bank reads are rejected by construction.
class LearningStrategyPlanner {
  final ContentCoverageService _coverageService;

  const LearningStrategyPlanner({
    ContentCoverageService coverageService = const ContentCoverageService(),
  }) : _coverageService = coverageService;

  /// Computes a deterministic [FastPlanResult] for [scope] and [coverage].
  FastPlanResult plan({
    required ResolvedScope scope,
    required ScopeCoverageBundle coverage,
    required DateTime asOf,
    PersistedLearningStrategy activeStrategy = PersistedLearningStrategy.fast,
    Set<String> completedActivityIds = const {},
    Map<String, EvidenceSummary> domainEvidence = const {},
    Set<String> manualSkippedActivityIds = const {},
    int? optionalTotalMinutes,
    Iterable<Map<String, dynamic>>? rawAssessmentMetadataToValidate,
  }) {
    if (rawAssessmentMetadataToValidate != null) {
      _coverageService.validateAssessmentItemMetadata(
        rawAssessmentMetadataToValidate,
      );
    }

    final records = coverage.recordsByActivityId;
    final incompleteIds = <String>{};
    for (final activity in scope.orderedActivities) {
      if (!completedActivityIds.contains(activity.activityId)) {
        incompleteIds.add(activity.activityId);
      }
    }

    // Validate prerequisite graph for cycles or dangling references (`PREREQ-01`).
    final cycleWarnings = <String>[];
    final validPrereqsByActivity = _sanitizePrerequisiteDag(
      incompleteIds: incompleteIds,
      records: records,
      outWarnings: cycleWarnings,
    );

    // If strategy is Standard, preserve canonical curriculum order.
    if (activeStrategy == PersistedLearningStrategy.standard) {
      return _buildStandardPlanResult(
        scope: scope,
        coverage: coverage,
        asOf: asOf,
        completedActivityIds: completedActivityIds,
        domainEvidence: domainEvidence,
        manualSkippedActivityIds: manualSkippedActivityIds,
        optionalTotalMinutes: optionalTotalMinutes,
        cycleWarnings: cycleWarnings,
      );
    }

    final scheduledIds = <String>{};
    final scheduledOrder = <String>[];
    final reasonCodesByActivity = <String, List<String>>{};
    final dependentTitleByPrereq = <String, String>{};
    final breadthRepresentativeByDomain = <String, String>{};
    final breadthPassActivityIds = <String>{};

    // Domains already covered by completed activities
    final coveredDomains = <String>{};
    for (final completedId in completedActivityIds) {
      final rec = records[completedId];
      if (rec != null) {
        coveredDomains.addAll(rec.allDomainIds);
      }
    }

    // Non-skipped eligible candidates vs manually skipped candidates
    final activeEligibleIds = incompleteIds
        .where((id) => !manualSkippedActivityIds.contains(id))
        .toSet();

    // Helper to schedule an activity and its unfinished eligible prerequisites first
    void scheduleWithPrerequisites(
      String targetActivityId, {
      required List<String> targetReasonCodes,
      bool isBreadthPass = false,
    }) {
      if (scheduledIds.contains(targetActivityId)) return;

      final visiting = <String>{};
      void dfs(String currentId, {String? requiredForTitle}) {
        if (scheduledIds.contains(currentId)) return;
        if (!activeEligibleIds.contains(currentId)) return;
        if (visiting.contains(currentId)) return;
        visiting.add(currentId);

        final currentRec = records[currentId];
        final prereqs = validPrereqsByActivity[currentId] ?? const <String>[];
        // Sort prerequisites deterministically by Pass 2 comparator
        final sortedPrereqs =
            prereqs
                .where(
                  (p) =>
                      activeEligibleIds.contains(p) &&
                      !scheduledIds.contains(p),
                )
                .toList()
              ..sort(
                (a, b) =>
                    _compareCandidates(a, b, records: records, domainEvidence: domainEvidence),
              );

        for (final prereqId in sortedPrereqs) {
          dfs(
            prereqId,
            requiredForTitle:
                currentRec?.activityTitle ?? requiredForTitle ?? currentId,
          );
        }

        visiting.remove(currentId);
        if (scheduledIds.contains(currentId)) return;

        scheduledIds.add(currentId);
        scheduledOrder.add(currentId);
        if (isBreadthPass) {
          breadthPassActivityIds.add(currentId);
        }

        if (currentId != targetActivityId) {
          reasonCodesByActivity[currentId] = [
            FastReasonCodes.prerequisiteRequired,
            ..._intrinsicReasonCodes(
              currentId,
              records: records,
              domainEvidence: domainEvidence,
            ),
          ];
          if (requiredForTitle != null) {
            dependentTitleByPrereq[currentId] = requiredForTitle;
          }
        } else {
          reasonCodesByActivity[currentId] = targetReasonCodes;
        }

        if (currentRec != null) {
          coveredDomains.addAll(currentRec.allDomainIds);
        }
      }

      dfs(targetActivityId);
    }

    // =========================================================================
    // PASS 1: Official Blueprint Breadth (`BREADTH-01`, `COVERAGE-01`)
    // =========================================================================
    final sortedBlueprintDomains =
        List.of(coverage.officialDomains)..sort((a, b) {
          final weightCmp = b.normalizedModelWeight.compareTo(
            a.normalizedModelWeight,
          );
          if (weightCmp != 0) return weightCmp;
          return a.domainId.compareTo(b.domainId);
        });

    for (final domain in sortedBlueprintDomains) {
      if (coveredDomains.contains(domain.domainId)) {
        continue;
      }

      // Find all non-skipped incomplete activities mapped to this domain
      final domainCandidates =
          activeEligibleIds.where((id) {
              final rec = records[id];
              if (rec == null || rec.unmappedOrAmbiguous) return false;
              return rec.allDomainIds.contains(domain.domainId);
            }).toList()
            ..sort(
              (a, b) => _compareCandidatesForDomain(
                a,
                b,
                targetDomainId: domain.domainId,
                records: records,
                domainEvidence: domainEvidence,
              ),
            );

      if (domainCandidates.isEmpty) {
        // Domain has no eligible mapped activity (`COVERAGE-01`).
        continue;
      }

      final chosenId = domainCandidates.first;
      breadthRepresentativeByDomain[domain.domainId] = chosenId;

      final reasons = <String>[
        FastReasonCodes.breadthCoverage,
        ..._intrinsicReasonCodes(
          chosenId,
          records: records,
          domainEvidence: domainEvidence,
        ),
      ];

      scheduleWithPrerequisites(
        chosenId,
        targetReasonCodes: reasons.toSet().toList(),
        isBreadthPass: true,
      );
    }

    // =========================================================================
    // PASS 2: Weighted Gap & Core Depth (`EVIDENCE-01`, `ORDER-01`)
    // =========================================================================
    final remainingMappedEligible =
        activeEligibleIds.where((id) {
            final rec = records[id];
            return !scheduledIds.contains(id) &&
                rec != null &&
                !rec.unmappedOrAmbiguous;
          }).toList()
          ..sort(
            (a, b) => _compareCandidates(
              a,
              b,
              records: records,
              domainEvidence: domainEvidence,
            ),
          );

    for (final candidateId in remainingMappedEligible) {
      if (scheduledIds.contains(candidateId)) continue;
      final reasons = <String>[
        ..._intrinsicReasonCodes(
          candidateId,
          records: records,
          domainEvidence: domainEvidence,
        ),
        FastReasonCodes.deprioritizedAfterBreadth,
      ];
      scheduleWithPrerequisites(
        candidateId,
        targetReasonCodes: reasons.toSet().toList(),
        isBreadthPass: false,
      );
    }

    // Unmapped/ambiguous activities are placed after mapped candidates (`unknown` class)
    final unmappedEligible =
        activeEligibleIds.where((id) {
            final rec = records[id];
            return !scheduledIds.contains(id) &&
                (rec == null || rec.unmappedOrAmbiguous);
          }).toList()
          ..sort(
            (a, b) => _compareCandidates(
              a,
              b,
              records: records,
              domainEvidence: domainEvidence,
            ),
          );

    for (final unmappedId in unmappedEligible) {
      scheduledIds.add(unmappedId);
      scheduledOrder.add(unmappedId);
      reasonCodesByActivity[unmappedId] = const [
        FastReasonCodes.unassessedDomain,
      ];
    }

    // Manually skipped activities remain at the tail with `manualSkip` class
    final manualSkippedRemaining =
        incompleteIds
            .where(
              (id) =>
                  manualSkippedActivityIds.contains(id) &&
                  !scheduledIds.contains(id),
            )
            .toList()
          ..sort(
            (a, b) => _compareCandidates(
              a,
              b,
              records: records,
              domainEvidence: domainEvidence,
            ),
          );

    for (final skippedId in manualSkippedRemaining) {
      scheduledIds.add(skippedId);
      scheduledOrder.add(skippedId);
      reasonCodesByActivity[skippedId] = const [
        FastReasonCodes.manualLearnerSkip,
      ];
    }

    // =========================================================================
    // PASS 3: Provisional Time Budgeting (`BUDGET-01`)
    // =========================================================================
    return _assemblePlanResult(
      contextId: scope.contextId,
      asOf: asOf,
      activeStrategy: activeStrategy,
      scheduledOrder: scheduledOrder,
      breadthPassActivityIds: breadthPassActivityIds,
      breadthRepresentativeByDomain: breadthRepresentativeByDomain,
      reasonCodesByActivity: reasonCodesByActivity,
      dependentTitleByPrereq: dependentTitleByPrereq,
      validPrereqsByActivity: validPrereqsByActivity,
      coverage: coverage,
      completedActivityIds: completedActivityIds,
      domainEvidence: domainEvidence,
      manualSkippedActivityIds: manualSkippedActivityIds,
      optionalTotalMinutes: optionalTotalMinutes,
      cycleWarnings: cycleWarnings,
    );
  }

  /// Combines the canonical [NextActionEngine] decision with the secondary
  /// Fast recommendation when `ResumeActivity` wins (`RESUME-01`).
  ResolvedActionPresentation resolvePresentation({
    required NextAction primaryAction,
    required FastPlanResult? fastPlan,
    required PersistedLearningStrategy activeStrategy,
  }) {
    if (activeStrategy != PersistedLearningStrategy.fast || fastPlan == null) {
      return ResolvedActionPresentation(
        primaryAction: primaryAction,
        activeStrategy: PersistedLearningStrategy.standard,
      );
    }

    final topFast = fastPlan.topRecommendedActivity;
    if (primaryAction is ResumeActivity && topFast != null) {
      final resumedId = switch (primaryAction.activity) {
        LessonActivity(:final lessonId) => lessonId,
        StudySetActivity(:final studySetId) => studySetId,
        ReviewActivity() => null,
      };

      if (resumedId != topFast.activityId) {
        final secondaryStart = StartActivity(
          activity: LessonActivity(
            lessonId: topFast.activityId,
            title: topFast.title,
            estimate: Duration(minutes: topFast.estimatedMinutes),
          ),
          customRationale: topFast.userFacingRationale,
        );
        return ResolvedActionPresentation(
          primaryAction: primaryAction,
          secondaryFastAction: secondaryStart,
          secondaryFastRationale: topFast.userFacingRationale,
          fastPlan: fastPlan,
          activeStrategy: activeStrategy,
        );
      }
    }

    return ResolvedActionPresentation(
      primaryAction: primaryAction,
      fastPlan: fastPlan,
      activeStrategy: activeStrategy,
    );
  }

  FastPlanResult _buildStandardPlanResult({
    required ResolvedScope scope,
    required ScopeCoverageBundle coverage,
    required DateTime asOf,
    required Set<String> completedActivityIds,
    required Map<String, EvidenceSummary> domainEvidence,
    required Set<String> manualSkippedActivityIds,
    required int? optionalTotalMinutes,
    required List<String> cycleWarnings,
  }) {
    final scheduledOrder = <String>[];
    final reasonCodesByActivity = <String, List<String>>{};
    for (final activity in scope.orderedActivities) {
      if (!completedActivityIds.contains(activity.activityId)) {
        scheduledOrder.add(activity.activityId);
        reasonCodesByActivity[activity.activityId] = const [
          FastReasonCodes.breadthCoverage,
        ];
      }
    }

    return _assemblePlanResult(
      contextId: scope.contextId,
      asOf: asOf,
      activeStrategy: PersistedLearningStrategy.standard,
      scheduledOrder: scheduledOrder,
      breadthPassActivityIds: scheduledOrder.toSet(),
      breadthRepresentativeByDomain: const {},
      reasonCodesByActivity: reasonCodesByActivity,
      dependentTitleByPrereq: const {},
      validPrereqsByActivity: const {},
      coverage: coverage,
      completedActivityIds: completedActivityIds,
      domainEvidence: domainEvidence,
      manualSkippedActivityIds: manualSkippedActivityIds,
      optionalTotalMinutes: optionalTotalMinutes,
      cycleWarnings: cycleWarnings,
    );
  }

  FastPlanResult _assemblePlanResult({
    required String contextId,
    required DateTime asOf,
    required PersistedLearningStrategy activeStrategy,
    required List<String> scheduledOrder,
    required Set<String> breadthPassActivityIds,
    required Map<String, String> breadthRepresentativeByDomain,
    required Map<String, List<String>> reasonCodesByActivity,
    required Map<String, String> dependentTitleByPrereq,
    required Map<String, List<String>> validPrereqsByActivity,
    required ScopeCoverageBundle coverage,
    required Set<String> completedActivityIds,
    required Map<String, EvidenceSummary> domainEvidence,
    required Set<String> manualSkippedActivityIds,
    required int? optionalTotalMinutes,
    required List<String> cycleWarnings,
  }) {
    final records = coverage.recordsByActivityId;
    final fullOrderedCandidates = <RecommendedActivity>[];
    final provisionalBudgetSchedule = <RecommendedActivity>[];

    int runningMinutes = 0;
    int knownDurationSubtotal = 0;
    int unknownDurationCount = 0;
    bool budgetExhausted = false;

    for (var i = 0; i < scheduledOrder.length; i++) {
      final activityId = scheduledOrder[i];
      final rec = records[activityId];
      if (rec == null) continue;

      final isSkipped = manualSkippedActivityIds.contains(activityId);
      final FastCandidateActionClass actionClass;
      if (isSkipped) {
        actionClass = FastCandidateActionClass.manualSkip;
      } else if (rec.unmappedOrAmbiguous) {
        actionClass = FastCandidateActionClass.unknown;
      } else if (breadthPassActivityIds.contains(activityId)) {
        actionClass = FastCandidateActionClass.recommended;
      } else {
        actionClass = FastCandidateActionClass.deprioritized;
      }

      if (rec.estimateQuality.isKnownDuration) {
        knownDurationSubtotal += rec.estimatedMinutes;
      } else {
        unknownDurationCount++;
      }

      bool fitsBudget = true;
      if (optionalTotalMinutes != null && optionalTotalMinutes > 0) {
        if (isSkipped) {
          fitsBudget = false;
        } else if (!budgetExhausted &&
            (runningMinutes + rec.estimatedMinutes <= optionalTotalMinutes ||
                provisionalBudgetSchedule.isEmpty)) {
          runningMinutes += rec.estimatedMinutes;
          fitsBudget = true;
        } else {
          budgetExhausted = true;
          fitsBudget = false;
        }
      }

      final baseReasons =
          reasonCodesByActivity[activityId] ??
          const [FastReasonCodes.breadthCoverage];
      final effectiveReasons = <String>{
        ...baseReasons,
        if (optionalTotalMinutes != null && fitsBudget && !isSkipped)
          FastReasonCodes.shortSessionFit,
      }.toList();

      final primaryEvidence = rec.primaryDomainId != null
          ? _resolveDomainEvidenceStatus(rec.primaryDomainId!, domainEvidence)
          : EvidenceStatusLabel.notAssessed;

      final primaryReason = effectiveReasons.first;
      final rationale = FastReasonCodes.describe(
        primaryReason,
        domainName: rec.primaryDomainTitle,
        dependentTitle: dependentTitleByPrereq[activityId],
      );

      final recommended = RecommendedActivity(
        activityId: activityId,
        title: rec.activityTitle,
        rank: i + 1,
        actionClass: actionClass,
        primaryDomainId: rec.primaryDomainId,
        primaryDomainTitle: rec.primaryDomainTitle,
        secondaryDomainIds: rec.secondaryDomainIds,
        primaryDomainWeight: rec.primaryDomainNormalizedWeight,
        depthTier: rec.primaryDepthTier,
        canonicalOrderIndex: rec.canonicalOrderIndex,
        estimatedMinutes: rec.estimatedMinutes,
        estimateQuality: rec.estimateQuality,
        reasonCodes: List<String>.unmodifiable(effectiveReasons),
        userFacingRationale: rationale,
        evidenceStatus: primaryEvidence,
        satisfiedPrerequisiteActivityIds:
            validPrereqsByActivity[activityId] ?? const [],
        includedInProvisionalBudget: fitsBudget,
      );

      fullOrderedCandidates.add(recommended);
      if (fitsBudget && !isSkipped) {
        provisionalBudgetSchedule.add(recommended);
      }
    }

    final budgetCoveredDomains = <String>{};
    for (final completedId in completedActivityIds) {
      final rec = records[completedId];
      if (rec != null) {
        budgetCoveredDomains.addAll(rec.allDomainIds);
      }
    }
    for (final item in provisionalBudgetSchedule) {
      if (item.primaryDomainId != null) {
        budgetCoveredDomains.add(item.primaryDomainId!);
      }
      budgetCoveredDomains.addAll(item.secondaryDomainIds);
    }

    final domainSummaries = <DomainCoverageSummary>[];
    final unreachedDomainsInBudget = <String>[];

    for (final domain in coverage.officialDomains) {
      final mappedIds = <String>[];
      final completedInDomain = <String>[];
      bool allMappedManuallySkipped = false;

      for (final rec in records.values) {
        if (rec.allDomainIds.contains(domain.domainId)) {
          mappedIds.add(rec.activityId);
          if (completedActivityIds.contains(rec.activityId)) {
            completedInDomain.add(rec.activityId);
          }
        }
      }

      if (mappedIds.isNotEmpty &&
          completedInDomain.isEmpty &&
          mappedIds.every(manualSkippedActivityIds.contains)) {
        allMappedManuallySkipped = true;
      }

      final isCoverageMissing = mappedIds.isEmpty;
      final isCoveredInBudget = budgetCoveredDomains.contains(domain.domainId);
      if (!isCoveredInBudget) {
        unreachedDomainsInBudget.add(domain.domainId);
      }

      domainSummaries.add(
        DomainCoverageSummary(
          domainId: domain.domainId,
          title: domain.title,
          publishedWeightRangeLabel: domain.publishedWeightRangeLabel,
          normalizedModelWeight: domain.normalizedModelWeight,
          evidenceStatus: _resolveDomainEvidenceStatus(
            domain.domainId,
            domainEvidence,
          ),
          mappedActivityIds: List<String>.unmodifiable(mappedIds),
          completedActivityIds: List<String>.unmodifiable(completedInDomain),
          breadthRepresentativeActivityId:
              breadthRepresentativeByDomain[domain.domainId],
          isCoverageMissing: isCoverageMissing,
          isCoveredInProvisionalBudget: isCoveredInBudget,
          isManuallySkippedByLearner: allMappedManuallySkipped,
        ),
      );
    }

    final BudgetFeasibilityStatus feasibility;
    if (optionalTotalMinutes == null || optionalTotalMinutes <= 0) {
      feasibility = unknownDurationCount > 0
          ? BudgetFeasibilityStatus.provisionalUnknownTime
          : BudgetFeasibilityStatus.noBudgetSpecified;
    } else if (unknownDurationCount > 0) {
      feasibility = BudgetFeasibilityStatus.provisionalUnknownTime;
    } else if (provisionalBudgetSchedule.length <
        fullOrderedCandidates
            .where((c) => c.actionClass != FastCandidateActionClass.manualSkip)
            .length) {
      feasibility = BudgetFeasibilityStatus.insufficientBudget;
    } else {
      feasibility = BudgetFeasibilityStatus.feasible;
    }

    return FastPlanResult(
      contextId: contextId,
      asOf: asOf,
      activeStrategy: activeStrategy,
      fullOrderedCandidates: List<RecommendedActivity>.unmodifiable(
        fullOrderedCandidates,
      ),
      provisionalBudgetSchedule: List<RecommendedActivity>.unmodifiable(
        provisionalBudgetSchedule,
      ),
      domainCoverage: List<DomainCoverageSummary>.unmodifiable(domainSummaries),
      unmappedActivityIds: coverage.unmappedActivityIds,
      prerequisiteCycleWarnings: List<String>.unmodifiable(cycleWarnings),
      budgetFeasibility: feasibility,
      requestedBudgetMinutes: optionalTotalMinutes,
      knownDurationSubtotalMinutes: knownDurationSubtotal,
      remainingUnknownTimeCount: unknownDurationCount,
      unreachedDomainIdsInBudget: List<String>.unmodifiable(
        unreachedDomainsInBudget,
      ),
    );
  }

  /// Resolves domain evidence status while strictly enforcing `EVIDENCE-01`:
  /// self-reported familiarity or FSRS history without independent check
  /// attempts stays `notAssessed` (or `limitedEvidence` if practice exists).
  EvidenceStatusLabel _resolveDomainEvidenceStatus(
    String domainId,
    Map<String, EvidenceSummary> domainEvidence,
  ) {
    final summary = domainEvidence[domainId];
    if (summary == null) {
      return EvidenceStatusLabel.notAssessed;
    }
    if (summary.independentAttemptCount <= 0) {
      if (summary.statusLabel ==
          EvidenceStatusLabel.independentEvidenceAvailable) {
        return EvidenceStatusLabel.notAssessed;
      }
      return summary.statusLabel;
    }
    return summary.statusLabel;
  }

  List<String> _intrinsicReasonCodes(
    String activityId, {
    required Map<String, CoverageRecord> records,
    required Map<String, EvidenceSummary> domainEvidence,
  }) {
    final rec = records[activityId];
    if (rec == null || rec.primaryDomainId == null) {
      return const [FastReasonCodes.unassessedDomain];
    }
    final domainId = rec.primaryDomainId!;
    final ev = domainEvidence[domainId];
    final codes = <String>[];

    if (ev != null && ev.hasIndependentGapEvidence) {
      codes.add(FastReasonCodes.independentGapEvidence);
    }
    if (rec.primaryDomainNormalizedWeight >= 0.08) {
      codes.add(FastReasonCodes.highDomainWeight);
    }
    final status = _resolveDomainEvidenceStatus(domainId, domainEvidence);
    if (status == EvidenceStatusLabel.notAssessed) {
      codes.add(FastReasonCodes.unassessedDomain);
    }
    return codes;
  }

  int _compareCandidatesForDomain(
    String a,
    String b, {
    required String targetDomainId,
    required Map<String, CoverageRecord> records,
    required Map<String, EvidenceSummary> domainEvidence,
  }) {
    final ra = records[a]!;
    final rb = records[b]!;

    // Prefer activities whose primaryDomainId is the target domain
    final aIsPrimary = ra.primaryDomainId == targetDomainId;
    final bIsPrimary = rb.primaryDomainId == targetDomainId;
    if (aIsPrimary != bIsPrimary) {
      return aIsPrimary ? -1 : 1;
    }

    return _compareCandidates(
      a,
      b,
      records: records,
      domainEvidence: domainEvidence,
    );
  }

  /// Normative `fast_v1_1` tie-breaking comparator (`§7.5` Step 4):
  /// 1. Independent authorized gap evidence first
  /// 2. Descending primary-domain normalized weight
  /// 3. Objective importance (`core` < `support` < `enrichment`)
  /// 4. Canonical curriculum order (`canonicalOrderIndex`)
  /// 5. Lexicographic `activityId`
  int _compareCandidates(
    String a,
    String b, {
    required Map<String, CoverageRecord> records,
    required Map<String, EvidenceSummary> domainEvidence,
  }) {
    final ra = records[a];
    final rb = records[b];
    if (ra == null && rb == null) return a.compareTo(b);
    if (ra == null) return 1;
    if (rb == null) return -1;

    final gapA =
        ra.primaryDomainId != null &&
        (domainEvidence[ra.primaryDomainId!]?.hasIndependentGapEvidence ??
            false);
    final gapB =
        rb.primaryDomainId != null &&
        (domainEvidence[rb.primaryDomainId!]?.hasIndependentGapEvidence ??
            false);
    if (gapA != gapB) {
      return gapA ? -1 : 1;
    }

    final weightCmp = rb.primaryDomainNormalizedWeight.compareTo(
      ra.primaryDomainNormalizedWeight,
    );
    if (weightCmp != 0) return weightCmp;

    final tierCmp = ra.primaryDepthTier.priorityRank.compareTo(
      rb.primaryDepthTier.priorityRank,
    );
    if (tierCmp != 0) return tierCmp;

    final orderCmp = ra.canonicalOrderIndex.compareTo(rb.canonicalOrderIndex);
    if (orderCmp != 0) return orderCmp;

    return a.compareTo(b);
  }

  /// Detects cycles or dangling prerequisite edges via 3-color DFS and strips
  /// only offending cyclic edges so scheduling falls back safely to canonical order.
  Map<String, List<String>> _sanitizePrerequisiteDag({
    required Set<String> incompleteIds,
    required Map<String, CoverageRecord> records,
    required List<String> outWarnings,
  }) {
    final adj = <String, List<String>>{};
    for (final id in incompleteIds) {
      final raw = records[id]?.prerequisiteActivityIds ?? const <String>[];
      final valid = <String>[];
      for (final p in raw) {
        if (p == id) {
          outWarnings.add('Self-prerequisite ignored on activity $id.');
          continue;
        }
        if (incompleteIds.contains(p)) {
          valid.add(p);
        }
      }
      adj[id] = valid;
    }

    // 0 = unvisited, 1 = visiting, 2 = visited
    final state = <String, int>{};
    final sanitized = <String, List<String>>{};

    void dfs(String node) {
      state[node] = 1;
      final cleanEdges = <String>[];
      for (final neighbor in adj[node] ?? const <String>[]) {
        final neighborState = state[neighbor] ?? 0;
        if (neighborState == 1) {
          outWarnings.add(
            'Prerequisite cycle detected: $node -> $neighbor; falling back to canonical order.',
          );
          continue;
        }
        cleanEdges.add(neighbor);
        if (neighborState == 0) {
          dfs(neighbor);
        }
      }
      sanitized[node] = cleanEdges;
      state[node] = 2;
    }

    final sortedIds = incompleteIds.toList()..sort();
    for (final id in sortedIds) {
      if ((state[id] ?? 0) == 0) {
        dfs(id);
      }
    }

    return sanitized;
  }
}
