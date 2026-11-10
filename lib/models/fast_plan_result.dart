import '../services/next_action_engine.dart';
import 'learning_strategy.dart';

/// Per-context Fast preference state (`TEL-01B`).
///
/// Stored outside `LearningContext.scopeConfig` so changing between `Standard`
/// and `Fast` never alters `ScopeResolver.computeConfigHash` or triggers
/// whole-context overwrites.
class FastPreference {
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String contextId;
  final String? userId;
  final PersistedLearningStrategy strategy;
  final int revision;
  final DateTime updatedAtServer;
  final String lastMutationId;
  final int? optionalTotalMinutes;
  final DateTime? optionalDeadline;
  final Set<String> manualSkippedActivityIds;

  const FastPreference({
    this.schemaVersion = currentSchemaVersion,
    required this.contextId,
    this.userId,
    this.strategy = PersistedLearningStrategy.standard,
    this.revision = 0,
    required this.updatedAtServer,
    this.lastMutationId = 'initial',
    this.optionalTotalMinutes,
    this.optionalDeadline,
    this.manualSkippedActivityIds = const {},
  });

  factory FastPreference.defaultStandard({
    required String contextId,
    String? userId,
    DateTime? timestamp,
  }) {
    return FastPreference(
      contextId: contextId,
      userId: userId,
      strategy: PersistedLearningStrategy.standard,
      revision: 0,
      updatedAtServer: timestamp ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastMutationId: 'default-standard',
    );
  }

  FastPreference copyWith({
    int? schemaVersion,
    String? contextId,
    String? userId,
    PersistedLearningStrategy? strategy,
    int? revision,
    DateTime? updatedAtServer,
    String? lastMutationId,
    int? optionalTotalMinutes,
    bool clearOptionalTotalMinutes = false,
    DateTime? optionalDeadline,
    bool clearOptionalDeadline = false,
    Set<String>? manualSkippedActivityIds,
  }) {
    return FastPreference(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      contextId: contextId ?? this.contextId,
      userId: userId ?? this.userId,
      strategy: strategy ?? this.strategy,
      revision: revision ?? this.revision,
      updatedAtServer: updatedAtServer ?? this.updatedAtServer,
      lastMutationId: lastMutationId ?? this.lastMutationId,
      optionalTotalMinutes: clearOptionalTotalMinutes
          ? null
          : (optionalTotalMinutes ?? this.optionalTotalMinutes),
      optionalDeadline: clearOptionalDeadline
          ? null
          : (optionalDeadline ?? this.optionalDeadline),
      manualSkippedActivityIds:
          manualSkippedActivityIds ?? this.manualSkippedActivityIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'context_id': contextId,
        'user_id': userId,
        'strategy': strategy.wireValue,
        'revision': revision,
        'updated_at_server': updatedAtServer.toUtc().toIso8601String(),
        'last_mutation_id': lastMutationId,
        if (optionalTotalMinutes != null)
          'optional_total_minutes': optionalTotalMinutes,
        if (optionalDeadline != null)
          'optional_deadline': optionalDeadline!.toUtc().toIso8601String(),
        'manual_skipped_activity_ids': manualSkippedActivityIds.toList()..sort(),
      };

  factory FastPreference.fromJson(Map<String, dynamic> json) {
    final rawSkipped = json['manual_skipped_activity_ids'];
    final skippedSet = <String>{};
    if (rawSkipped is List) {
      for (final item in rawSkipped) {
        if (item is String && item.trim().isNotEmpty) {
          skippedSet.add(item.trim());
        }
      }
    }

    final rawMinutes = json['optional_total_minutes'];
    int? parsedMinutes;
    if (rawMinutes is int && rawMinutes > 0) {
      parsedMinutes = rawMinutes;
    } else if (rawMinutes is num && rawMinutes > 0) {
      parsedMinutes = rawMinutes.toInt();
    }

    DateTime parsedUpdated;
    final rawUpdated = json['updated_at_server'];
    if (rawUpdated is String) {
      parsedUpdated = DateTime.tryParse(rawUpdated)?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    } else {
      parsedUpdated = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    DateTime? parsedDeadline;
    final rawDeadline = json['optional_deadline'];
    if (rawDeadline is String && rawDeadline.isNotEmpty) {
      parsedDeadline = DateTime.tryParse(rawDeadline)?.toUtc();
    }

    return FastPreference(
      schemaVersion: (json['schema_version'] as int?) ?? currentSchemaVersion,
      contextId: (json['context_id'] as String?) ?? '',
      userId: json['user_id'] as String?,
      strategy: PersistedLearningStrategy.fromWire(json['strategy'] as String?),
      revision: (json['revision'] as int?) ?? 0,
      updatedAtServer: parsedUpdated,
      lastMutationId: (json['last_mutation_id'] as String?) ?? 'initial',
      optionalTotalMinutes: parsedMinutes,
      optionalDeadline: parsedDeadline,
      manualSkippedActivityIds: skippedSet,
    );
  }
}

/// Coverage mapping for a single learning activity (`TEL-02B`, `TEL-04`).
class CoverageRecord {
  final String activityId;
  final String activityTitle;
  final String? activitySlug;
  final int canonicalOrderIndex;
  final int estimatedMinutes;
  final EstimateQuality estimateQuality;
  final DepthTier primaryDepthTier;

  /// Primary blueprint domain selected by highest normalized model weight,
  /// then lexicographic domain ID.
  final String? primaryDomainId;
  final String? primaryDomainTitle;
  final double primaryDomainNormalizedWeight;

  /// Additional blueprint domains touched by this activity.
  final List<String> secondaryDomainIds;

  /// All mapped blueprint domains (`[primaryDomainId, ...secondaryDomainIds]`).
  final List<String> allDomainIds;

  /// Mapped concept IDs (`concept_ids` / `required_concepts`).
  final List<String> conceptIds;

  /// Prerequisite activity IDs in the current scope.
  final List<String> prerequisiteActivityIds;

  /// Prerequisite concept IDs declared by curriculum metadata.
  final List<String> prerequisiteConceptIds;

  /// Formative assessment item count mapped to this activity/domain.
  final int formativeItemCount;

  /// True when an activity lacks an explicit blueprint domain mapping.
  final bool unmappedOrAmbiguous;

  const CoverageRecord({
    required this.activityId,
    required this.activityTitle,
    this.activitySlug,
    required this.canonicalOrderIndex,
    required this.estimatedMinutes,
    required this.estimateQuality,
    this.primaryDepthTier = DepthTier.core,
    required this.primaryDomainId,
    this.primaryDomainTitle,
    required this.primaryDomainNormalizedWeight,
    this.secondaryDomainIds = const [],
    this.allDomainIds = const [],
    this.conceptIds = const [],
    this.prerequisiteActivityIds = const [],
    this.prerequisiteConceptIds = const [],
    this.formativeItemCount = 0,
    this.unmappedOrAmbiguous = false,
  });
}

/// Truthful summary of learner evidence for a domain or concept (`EVIDENCE-01`).
///
/// Self-report and FSRS review state are tracked separately and never satisfy
/// [hasIndependentCompetency] or authorize `supported_bypass`.
class EvidenceSummary {
  final String subjectKey;
  final EvidenceStatusLabel statusLabel;

  /// Independent assessment attempts from authorized formative/diagnostic checks.
  final int independentAttemptCount;

  /// Observed accuracy or mastery score in `[0.0, 1.0]` from independent checks.
  final double? independentScore;

  /// Optional learner self-report (e.g. "familiar"), which is NEVER treated as
  /// verified competency (`EVIDENCE-01`).
  final bool hasSelfReportedFamiliarity;

  /// Optional FSRS stability/retrievability presence, which drives spaced review
  /// rather than topic bypass.
  final bool hasFsrsSchedulingHistory;

  const EvidenceSummary({
    required this.subjectKey,
    this.statusLabel = EvidenceStatusLabel.notAssessed,
    this.independentAttemptCount = 0,
    this.independentScore,
    this.hasSelfReportedFamiliarity = false,
    this.hasFsrsSchedulingHistory = false,
  });

  /// True when independent check evidence reveals a gap requiring priority study.
  bool get hasIndependentGapEvidence =>
      statusLabel == EvidenceStatusLabel.independentEvidenceAvailable &&
      independentAttemptCount > 0 &&
      (independentScore != null && independentScore! < 0.75);

  /// In Fast v1, no client-side evidence summary grants `supported_bypass`.
  bool get canBypassDomainInV1 => false;
}

/// Ranked candidate produced by `LearningStrategyPlanner` (`fast_v1_1`).
class RecommendedActivity {
  final String activityId;
  final String title;
  final int rank;
  final FastCandidateActionClass actionClass;
  final String? primaryDomainId;
  final String? primaryDomainTitle;
  final List<String> secondaryDomainIds;
  final double primaryDomainWeight;
  final DepthTier depthTier;
  final int canonicalOrderIndex;
  final int estimatedMinutes;
  final EstimateQuality estimateQuality;
  final List<String> reasonCodes;
  final String userFacingRationale;
  final EvidenceStatusLabel evidenceStatus;
  final List<String> satisfiedPrerequisiteActivityIds;
  final bool includedInProvisionalBudget;

  const RecommendedActivity({
    required this.activityId,
    required this.title,
    required this.rank,
    required this.actionClass,
    required this.primaryDomainId,
    this.primaryDomainTitle,
    this.secondaryDomainIds = const [],
    required this.primaryDomainWeight,
    required this.depthTier,
    required this.canonicalOrderIndex,
    required this.estimatedMinutes,
    required this.estimateQuality,
    required this.reasonCodes,
    required this.userFacingRationale,
    required this.evidenceStatus,
    this.satisfiedPrerequisiteActivityIds = const [],
    this.includedInProvisionalBudget = true,
  });
}

/// Per-domain coverage and status row across the official exam blueprint (`TEL-04`).
class DomainCoverageSummary {
  final String domainId;
  final String title;
  final String publishedWeightRangeLabel;
  final double normalizedModelWeight;
  final EvidenceStatusLabel evidenceStatus;
  final List<String> mappedActivityIds;
  final List<String> completedActivityIds;
  final String? breadthRepresentativeActivityId;
  final bool isCoverageMissing;
  final bool isCoveredInProvisionalBudget;
  final bool isManuallySkippedByLearner;

  const DomainCoverageSummary({
    required this.domainId,
    required this.title,
    required this.publishedWeightRangeLabel,
    required this.normalizedModelWeight,
    required this.evidenceStatus,
    required this.mappedActivityIds,
    required this.completedActivityIds,
    this.breadthRepresentativeActivityId,
    required this.isCoverageMissing,
    required this.isCoveredInProvisionalBudget,
    this.isManuallySkippedByLearner = false,
  });

  bool get hasCompletedActivity => completedActivityIds.isNotEmpty;
}

/// Time-budget feasibility classification (`BUDGET-01`).
enum BudgetFeasibilityStatus {
  noBudgetSpecified('no_budget_specified'),
  feasible('feasible'),
  provisionalUnknownTime('provisional_unknown_time'),
  insufficientBudget('insufficient_budget');

  final String wireValue;
  const BudgetFeasibilityStatus(this.wireValue);
}

/// Deterministic output of `LearningStrategyPlanner.plan` (`fast_v1_1`).
class FastPlanResult {
  static const String currentPolicyVersion = 'fast_v1_1';

  final String policyVersion;
  final String contextId;
  final DateTime asOf;
  final PersistedLearningStrategy activeStrategy;
  final List<RecommendedActivity> fullOrderedCandidates;
  final List<RecommendedActivity> provisionalBudgetSchedule;
  final List<DomainCoverageSummary> domainCoverage;
  final List<String> unmappedActivityIds;
  final List<String> prerequisiteCycleWarnings;
  final BudgetFeasibilityStatus budgetFeasibility;
  final int? requestedBudgetMinutes;
  final int knownDurationSubtotalMinutes;
  final int remainingUnknownTimeCount;
  final List<String> unreachedDomainIdsInBudget;

  const FastPlanResult({
    this.policyVersion = currentPolicyVersion,
    required this.contextId,
    required this.asOf,
    required this.activeStrategy,
    required this.fullOrderedCandidates,
    required this.provisionalBudgetSchedule,
    required this.domainCoverage,
    this.unmappedActivityIds = const [],
    this.prerequisiteCycleWarnings = const [],
    required this.budgetFeasibility,
    this.requestedBudgetMinutes,
    required this.knownDurationSubtotalMinutes,
    required this.remainingUnknownTimeCount,
    this.unreachedDomainIdsInBudget = const [],
  });

  /// Top recommended incomplete activity (excluding manual skips when non-skipped exist).
  RecommendedActivity? get topRecommendedActivity {
    for (final candidate in fullOrderedCandidates) {
      if (candidate.actionClass == FastCandidateActionClass.recommended ||
          candidate.actionClass == FastCandidateActionClass.deprioritized ||
          candidate.actionClass == FastCandidateActionClass.unknown) {
        return candidate;
      }
    }
    return fullOrderedCandidates.isNotEmpty ? fullOrderedCandidates.first : null;
  }

  bool get hasUnknownDurations => remainingUnknownTimeCount > 0;
}

/// Presentation wrapper combining the canonical primary [NextAction] with an
/// optional secondary Fast recommendation when `ResumeActivity` wins (`RESUME-01`).
class ResolvedActionPresentation {
  final NextAction primaryAction;
  final StartActivity? secondaryFastAction;
  final String? secondaryFastRationale;
  final FastPlanResult? fastPlan;
  final PersistedLearningStrategy activeStrategy;

  const ResolvedActionPresentation({
    required this.primaryAction,
    this.secondaryFastAction,
    this.secondaryFastRationale,
    this.fastPlan,
    this.activeStrategy = PersistedLearningStrategy.standard,
  });

  bool get hasSecondaryFastAlternative => secondaryFastAction != null;
}
