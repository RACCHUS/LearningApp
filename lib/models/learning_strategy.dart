/// Core domain primitives for Time-Efficient Learning (TEL v0.5):
/// - Overview read-only tours (`OverviewDurationPreset`)
/// - Persisted per-context learning approaches (`PersistedLearningStrategy`)
/// - Duration estimate quality (`EstimateQuality`)
/// - Lesson block importance tiers (`DepthTier`)
/// - Truthful evidence status labels (`EvidenceStatusLabel`)
/// - Deterministic planner reason codes and feature flags.
library;

/// Persisted strategy for a target-backed [LearningContext].
///
/// Note: `Overview` is intentionally NOT a persisted [LearningContext] strategy;
/// it is a read-only exploration flow that creates no context or progress state.
enum PersistedLearningStrategy {
  standard('standard', 'Standard'),
  fast('fast', 'Fast');

  final String wireValue;
  final String displayName;

  const PersistedLearningStrategy(this.wireValue, this.displayName);

  static PersistedLearningStrategy fromWire(String? raw) {
    if (raw == fast.wireValue) {
      return PersistedLearningStrategy.fast;
    }
    return PersistedLearningStrategy.standard;
  }
}

/// Duration presets for the read-only Subject Overview tour.
enum OverviewDurationPreset {
  fiveMinutes(5, '5 min', 'Quick map & big ideas'),
  fifteenMinutes(15, '15 min', 'Core concepts, key terms & misconceptions'),
  thirtyMinutes(
    30,
    '30 min',
    'Full guided tour, applications & optional self-check',
  );

  final int minutes;
  final String shortLabel;
  final String description;

  const OverviewDurationPreset(
    this.minutes,
    this.shortLabel,
    this.description,
  );

  static OverviewDurationPreset fromMinutes(int? minutes) {
    switch (minutes) {
      case 5:
        return OverviewDurationPreset.fiveMinutes;
      case 30:
        return OverviewDurationPreset.thirtyMinutes;
      case 15:
      default:
        return OverviewDurationPreset.fifteenMinutes;
    }
  }
}

/// Quality classification for activity duration estimates (`TEL-02B`).
///
/// Activities using [defaultEstimate] (`15` minutes fallback) must not be
/// presented as exact known durations when computing time budgets (`BUDGET-01`).
enum EstimateQuality {
  defaultEstimate('default'),
  authored('authored'),
  measured('measured');

  final String wireValue;
  const EstimateQuality(this.wireValue);

  bool get isKnownDuration =>
      this == EstimateQuality.authored || this == EstimateQuality.measured;

  static EstimateQuality fromWire(String? raw) {
    switch (raw) {
      case 'authored':
        return EstimateQuality.authored;
      case 'measured':
        return EstimateQuality.measured;
      case 'default':
      default:
        return EstimateQuality.defaultEstimate;
    }
  }
}

/// Authoring tier for lesson blocks and objectives (`TEL-02B`).
enum DepthTier {
  core('core', 0),
  support('support', 1),
  enrichment('enrichment', 2);

  final String wireValue;
  final int priorityRank;

  const DepthTier(this.wireValue, this.priorityRank);

  static DepthTier fromWire(Object? raw) {
    if (raw is String) {
      switch (raw.trim().toLowerCase()) {
        case 'support':
          return DepthTier.support;
        case 'enrichment':
          return DepthTier.enrichment;
        case 'core':
        default:
          return DepthTier.core;
      }
    }
    return DepthTier.core;
  }
}

/// Action class assigned to each candidate activity by `LearningStrategyPlanner`.
///
/// In Fast v1, `supported_bypass` is intentionally absent (`EVIDENCE-01`).
enum FastCandidateActionClass {
  recommended('recommended'),
  deprioritized('deprioritized'),
  unknown('unknown'),
  manualSkip('manual_skip');

  final String wireValue;
  const FastCandidateActionClass(this.wireValue);

  static FastCandidateActionClass fromWire(String? raw) {
    switch (raw) {
      case 'deprioritized':
        return FastCandidateActionClass.deprioritized;
      case 'unknown':
        return FastCandidateActionClass.unknown;
      case 'manual_skip':
        return FastCandidateActionClass.manualSkip;
      case 'recommended':
      default:
        return FastCandidateActionClass.recommended;
    }
  }
}

/// Truthful evidence status labels for domain and concept readiness (`TEL-04`).
enum EvidenceStatusLabel {
  notAssessed('not_assessed', 'Not yet checked'),
  limitedEvidence('limited_evidence', 'Limited practice evidence'),
  practiceEvidenceAvailable(
    'practice_evidence_available',
    'Practice evidence available',
  ),
  independentEvidenceAvailable(
    'independent_evidence_available',
    'Independent check evidence available',
  );

  final String wireValue;
  final String userFacingLabel;

  const EvidenceStatusLabel(this.wireValue, this.userFacingLabel);

  static EvidenceStatusLabel fromWire(String? raw) {
    switch (raw) {
      case 'limited_evidence':
        return EvidenceStatusLabel.limitedEvidence;
      case 'practice_evidence_available':
        return EvidenceStatusLabel.practiceEvidenceAvailable;
      case 'independent_evidence_available':
        return EvidenceStatusLabel.independentEvidenceAvailable;
      case 'not_assessed':
      default:
        return EvidenceStatusLabel.notAssessed;
    }
  }
}

/// Source provenance verification status for curriculum/overview disclosures.
enum SourceVerificationLevel {
  topicOutlineReviewed('topic_outline_reviewed'),
  cryptographicallyVerified('cryptographically_verified'),
  hashUnavailable('hash_unavailable'),
  unverifiedPlaceholder('unverified_placeholder');

  final String wireValue;
  const SourceVerificationLevel(this.wireValue);
}

/// Stable reason codes emitted by `LearningStrategyPlanner` (`fast_v1_1`).
abstract final class FastReasonCodes {
  static const String breadthCoverage = 'breadth_coverage';
  static const String prerequisiteRequired = 'prerequisite_required';
  static const String highDomainWeight = 'high_domain_weight';
  static const String unassessedDomain = 'unassessed_domain';
  static const String independentGapEvidence = 'independent_gap_evidence';
  static const String shortSessionFit = 'short_session_fit';
  static const String deprioritizedAfterBreadth = 'deprioritized_after_breadth';
  static const String manualLearnerSkip = 'manual_learner_skip';

  /// Human-readable, honest explanation corresponding to a reason code.
  static String describe(String code, {String? domainName, String? dependentTitle}) {
    switch (code) {
      case prerequisiteRequired:
        if (dependentTitle != null && dependentTitle.isNotEmpty) {
          return 'Recommended first because "$dependentTitle" builds on this foundation';
        }
        return 'Recommended first because a higher-priority topic builds on this foundation';
      case independentGapEvidence:
        if (domainName != null && domainName.isNotEmpty) {
          return 'Prioritized to reinforce gaps seen in $domainName checks';
        }
        return 'Prioritized to reinforce gaps seen in recent checks';
      case breadthCoverage:
        if (domainName != null && domainName.isNotEmpty) {
          return 'Covers core exam topic area: $domainName';
        }
        return 'Builds first-pass coverage across major exam topic areas';
      case highDomainWeight:
        if (domainName != null && domainName.isNotEmpty) {
          return 'High-emphasis exam area ($domainName)';
        }
        return 'High-emphasis exam topic area';
      case unassessedDomain:
        return 'Topic area not yet checked';
      case shortSessionFit:
        return 'Fits within your current study time window';
      case deprioritizedAfterBreadth:
        return 'Scheduled after first-pass coverage of all major topic areas';
      case manualLearnerSkip:
        return 'Skipped by learner preference (topic remains unassessed)';
      default:
        return 'Study the most relevant material first';
    }
  }
}

/// Feature flags and target-level rollout controls for TEL v0.5 (`§6`).
class TelFeatureFlags {
  final bool overviewEnabled;
  final bool fastEnabled;
  final Set<String> overviewEligibleTargetSlugs;
  final Set<String> fastEligibleTargetSlugs;

  const TelFeatureFlags({
    this.overviewEnabled = true,
    this.fastEnabled = true,
    this.overviewEligibleTargetSlugs = const {
      'clep-introductory-psychology',
      'clep_introductory_psychology',
      'a0000000-0000-0000-0000-000000000001',
    },
    this.fastEligibleTargetSlugs = const {
      'clep-introductory-psychology',
      'clep_introductory_psychology',
      'a0000000-0000-0000-0000-000000000001',
    },
  });

  static const TelFeatureFlags disabled = TelFeatureFlags(
    overviewEnabled: false,
    fastEnabled: false,
  );

  bool isOverviewEnabledForTarget(String? slugOrId) {
    if (!overviewEnabled) return false;
    if (slugOrId == null || slugOrId.trim().isEmpty) return false;
    final normalized = slugOrId.trim().toLowerCase();
    return overviewEligibleTargetSlugs.contains(normalized);
  }

  bool isFastEnabledForTarget(String? slugOrId, {bool isExamTarget = true}) {
    // Owner decision: Fast remains broadly available to exam targets.
    // The historical fastEligibleTargetSlugs list is retained for backwards
    // compatibility only; it did not actually restrict other exam targets.
    // Scoped rollout belongs to the server-backed feature registry.
    if (!fastEnabled || !isExamTarget) return false;
    return true;
  }

  TelFeatureFlags copyWith({
    bool? overviewEnabled,
    bool? fastEnabled,
    Set<String>? overviewEligibleTargetSlugs,
    Set<String>? fastEligibleTargetSlugs,
  }) {
    return TelFeatureFlags(
      overviewEnabled: overviewEnabled ?? this.overviewEnabled,
      fastEnabled: fastEnabled ?? this.fastEnabled,
      overviewEligibleTargetSlugs:
          overviewEligibleTargetSlugs ?? this.overviewEligibleTargetSlugs,
      fastEligibleTargetSlugs:
          fastEligibleTargetSlugs ?? this.fastEligibleTargetSlugs,
    );
  }
}
