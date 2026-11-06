import '../user_concept_state.dart';

/// Summary of a weak concept requiring reinforcement prior to an exam.
class WeakestConceptSummary {
  final String conceptId;
  final String title;
  final double score;
  final double? projectedRetrievability;
  final int evidenceCount;

  const WeakestConceptSummary({
    required this.conceptId,
    required this.title,
    required this.score,
    this.projectedRetrievability,
    required this.evidenceCount,
  });

  factory WeakestConceptSummary.fromJson(Map<String, dynamic> json) {
    return WeakestConceptSummary(
      conceptId: json['concept_id'] as String,
      title: json['title'] as String? ?? 'Concept',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      projectedRetrievability: (json['projected_retrievability'] as num?)?.toDouble(),
      evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'concept_id': conceptId,
        'title': title,
        'score': score,
        'projected_retrievability': projectedRetrievability,
        'evidence_count': evidenceCount,
      };
}

/// FSRS-calibrated readiness synthesis at a target exam date.
class CalibratedReadiness {
  final String targetVersionId;
  final DateTime examDate;
  final double readinessScore;
  final TargetReadinessBand band;
  final int totalCoreConcepts;
  final int assessedConceptsCount;
  final double averageRetrievability;
  final Map<RetrievalBand, int> retrievalBands;
  final List<WeakestConceptSummary> weakestConcepts;

  const CalibratedReadiness({
    required this.targetVersionId,
    required this.examDate,
    required this.readinessScore,
    required this.band,
    required this.totalCoreConcepts,
    required this.assessedConceptsCount,
    required this.averageRetrievability,
    required this.retrievalBands,
    this.weakestConcepts = const [],
  });

  factory CalibratedReadiness.fromJson(Map<String, dynamic> json) {
    final rawBands = json['retrieval_bands'] as Map<String, dynamic>? ?? {};
    final bands = <RetrievalBand, int>{
      RetrievalBand.wellEstablished: (rawBands['well_established'] as num?)?.toInt() ?? 0,
      RetrievalBand.wellRetained: (rawBands['well_retained'] as num?)?.toInt() ?? 0,
      RetrievalBand.developing: (rawBands['developing'] as num?)?.toInt() ?? 0,
      RetrievalBand.needsReinforcement: (rawBands['needs_reinforcement'] as num?)?.toInt() ?? 0,
      RetrievalBand.unassessed: (rawBands['unassessed'] as num?)?.toInt() ?? 0,
    };

    final rawWeak = json['weakest_concepts'] as List? ?? [];
    final weakest = rawWeak
        .map((w) => WeakestConceptSummary.fromJson(Map<String, dynamic>.from(w as Map)))
        .toList();

    final bandString = json['readiness_band'] as String? ?? 'notYetAssessed';
    final TargetReadinessBand readinessBand = TargetReadinessBand.values.firstWhere(
      (b) => b.name == bandString,
      orElse: () => TargetReadinessBand.notYetAssessed,
    );

    return CalibratedReadiness(
      targetVersionId: json['target_version_id'] as String,
      examDate: json['exam_date'] != null
          ? DateTime.parse(json['exam_date'] as String)
          : DateTime.now(),
      readinessScore: (json['readiness_score'] as num?)?.toDouble() ?? 0.0,
      band: readinessBand,
      totalCoreConcepts: (json['total_core_concepts'] as num?)?.toInt() ?? 0,
      assessedConceptsCount: (json['assessed_concepts_count'] as num?)?.toInt() ?? 0,
      averageRetrievability: (json['average_retrievability'] as num?)?.toDouble() ?? 0.0,
      retrievalBands: bands,
      weakestConcepts: weakest,
    );
  }

  /// Converts to legacy TargetReadiness for backward compatibility with existing widgets.
  TargetReadiness toTargetReadiness() {
    return TargetReadiness(
      targetVersionId: targetVersionId,
      band: band,
      score: readinessScore,
      totalCoreConcepts: totalCoreConcepts,
      assessedConceptsCount: assessedConceptsCount,
      bandDistribution: retrievalBands,
    );
  }
}

