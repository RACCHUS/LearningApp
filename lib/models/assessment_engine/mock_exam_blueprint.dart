import '../assessment_item.dart';

/// Specifies the blueprint and weighting constraints for generating a mock exam.
class MockExamBlueprint {
  final String targetVersionId;
  final String examCode;
  final String title;
  final int timeLimitMinutes;
  final int officialPassingScore;
  final String officialScoreScale;
  final int defaultQuestionCount;
  final List<DomainWeightConstraint> domainWeights;
  final Map<String, double> difficultyDistribution;
  final Set<AssessmentInteractionType> allowedInteractionTypes;
  final double maxStimulusItemsRatio;
  final Map<String, dynamic> metadata;

  const MockExamBlueprint({
    required this.targetVersionId,
    required this.examCode,
    required this.title,
    this.timeLimitMinutes = 90,
    this.officialPassingScore = 750,
    this.officialScoreScale = '100-900',
    this.defaultQuestionCount = 50,
    required this.domainWeights,
    this.difficultyDistribution = const {
      'beginner': 0.20,
      'intermediate': 0.60,
      'advanced': 0.20,
    },
    this.allowedInteractionTypes = const {
      AssessmentInteractionType.singleChoice,
      AssessmentInteractionType.multiSelect,
      AssessmentInteractionType.orderedResponse,
      AssessmentInteractionType.matching,
    },
    this.maxStimulusItemsRatio = 0.25,
    this.metadata = const {},
  });

  Duration get timeLimit => Duration(minutes: timeLimitMinutes);

  /// Computes target question quota per domain for a given total item count.
  /// Handles rounding remainders so the sum exactly matches [totalQuestions].
  Map<String, int> computeDomainQuotas(int totalQuestions) {
    if (domainWeights.isEmpty || totalQuestions <= 0) return {};

    // Normalize weights if sum != 1.0
    final totalWeight = domainWeights.fold<double>(0.0, (sum, d) => sum + d.weight);
    final normalized = domainWeights.map((d) {
      final normW = totalWeight > 0 ? (d.weight / totalWeight) : (1.0 / domainWeights.length);
      return (domain: d, weight: normW);
    }).toList();

    // Initial floor distribution and tracking of decimal remainders
    final quotas = <String, int>{};
    final remainders = <({DomainWeightConstraint domain, double remainder})>[];
    int allocated = 0;

    for (final entry in normalized) {
      final exactQuota = totalQuestions * entry.weight;
      final floorCount = exactQuota.floor();
      quotas[entry.domain.domainId] = floorCount;
      allocated += floorCount;
      remainders.add((domain: entry.domain, remainder: exactQuota - floorCount));
    }

    // Distribute remaining questions to domains with largest fractional remainders
    int deficit = totalQuestions - allocated;
    remainders.sort((a, b) => b.remainder.compareTo(a.remainder));

    for (int i = 0; i < deficit; i++) {
      final domainId = remainders[i % remainders.length].domain.domainId;
      quotas[domainId] = (quotas[domainId] ?? 0) + 1;
    }

    return quotas;
  }

  factory MockExamBlueprint.fromJson(Map<String, dynamic> json) {
    final domainList = (json['domain_weights'] as List? ?? [])
        .map((d) => DomainWeightConstraint.fromJson((d as Map).cast<String, dynamic>()))
        .toList();

    return MockExamBlueprint(
      targetVersionId: json['target_version_id'] as String? ?? '',
      examCode: json['exam_code'] as String? ?? '',
      title: json['title'] as String? ?? 'Mock Exam',
      timeLimitMinutes: json['time_limit_minutes'] as int? ?? 90,
      officialPassingScore: json['official_passing_score'] as int? ?? 750,
      officialScoreScale: json['official_score_scale'] as String? ?? '100-900',
      defaultQuestionCount: json['default_question_count'] as int? ?? 50,
      domainWeights: domainList,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'target_version_id': targetVersionId,
        'exam_code': examCode,
        'title': title,
        'time_limit_minutes': timeLimitMinutes,
        'official_passing_score': officialPassingScore,
        'official_score_scale': officialScoreScale,
        'default_question_count': defaultQuestionCount,
        'domain_weights': domainWeights.map((d) => d.toJson()).toList(),
        'metadata': metadata,
      };
}

/// Represents the weight and metadata constraint for a single domain node.
class DomainWeightConstraint {
  final String domainId;
  final String domainCode;
  final String domainTitle;
  final double weight; // Normalized decimal e.g. 0.12 = 12%

  const DomainWeightConstraint({
    required this.domainId,
    required this.domainCode,
    required this.domainTitle,
    required this.weight,
  });

  double get percentage => weight * 100.0;

  factory DomainWeightConstraint.fromJson(Map<String, dynamic> json) {
    return DomainWeightConstraint(
      domainId: json['domain_id'] as String? ?? '',
      domainCode: json['domain_code'] as String? ?? '',
      domainTitle: json['domain_title'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'domain_id': domainId,
        'domain_code': domainCode,
        'domain_title': domainTitle,
        'weight': weight,
      };
}
