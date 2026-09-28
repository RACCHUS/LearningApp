enum RetrievalBand {
  unassessed,
  needsReinforcement,
  developing,
  wellRetained,
  wellEstablished;

  static RetrievalBand fromString(String value) {
    switch (value) {
      case 'unassessed':
        return RetrievalBand.unassessed;
      case 'needs_reinforcement':
        return RetrievalBand.needsReinforcement;
      case 'developing':
        return RetrievalBand.developing;
      case 'well_retained':
        return RetrievalBand.wellRetained;
      case 'well_established':
        return RetrievalBand.wellEstablished;
      default:
        return RetrievalBand.unassessed;
    }
  }

  String toDbString() {
    switch (this) {
      case RetrievalBand.unassessed:
        return 'unassessed';
      case RetrievalBand.needsReinforcement:
        return 'needs_reinforcement';
      case RetrievalBand.developing:
        return 'developing';
      case RetrievalBand.wellRetained:
        return 'well_retained';
      case RetrievalBand.wellEstablished:
        return 'well_established';
    }
  }

  String get displayName {
    switch (this) {
      case RetrievalBand.unassessed:
        return 'Not Yet Assessed';
      case RetrievalBand.needsReinforcement:
        return 'Needs Reinforcement';
      case RetrievalBand.developing:
        return 'Developing';
      case RetrievalBand.wellRetained:
        return 'Well Retained';
      case RetrievalBand.wellEstablished:
        return 'Well Established';
    }
  }
}

enum ConceptConfidence {
  low,
  medium,
  high;

  static ConceptConfidence fromString(String value) {
    return ConceptConfidence.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConceptConfidence.low,
    );
  }
}

class UserConceptState {
  final String userId;
  final String conceptId;
  final RetrievalBand retrievalBand;
  final ConceptConfidence confidence;
  final int evidenceCount;
  final double weightedCorrect;
  final double weightedTotal;
  final DateTime? lastEvidenceAt;
  final DateTime updatedAt;

  const UserConceptState({
    required this.userId,
    required this.conceptId,
    this.retrievalBand = RetrievalBand.unassessed,
    this.confidence = ConceptConfidence.low,
    this.evidenceCount = 0,
    this.weightedCorrect = 0.0,
    this.weightedTotal = 0.0,
    this.lastEvidenceAt,
    required this.updatedAt,
  });

  double get accuracy =>
      weightedTotal > 0 ? (weightedCorrect / weightedTotal).clamp(0.0, 1.0) : 0.0;

  factory UserConceptState.fromJson(Map<String, dynamic> json) {
    return UserConceptState(
      userId: json['user_id'] as String,
      conceptId: json['concept_id'] as String,
      retrievalBand: RetrievalBand.fromString(
        json['retrieval_band'] as String? ?? 'unassessed',
      ),
      confidence: ConceptConfidence.fromString(
        json['confidence'] as String? ?? 'low',
      ),
      evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
      weightedCorrect: (json['weighted_correct'] as num?)?.toDouble() ?? 0.0,
      weightedTotal: (json['weighted_total'] as num?)?.toDouble() ?? 0.0,
      lastEvidenceAt: json['last_evidence_at'] != null
          ? DateTime.tryParse(json['last_evidence_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'concept_id': conceptId,
      'retrieval_band': retrievalBand.toDbString(),
      'confidence': confidence.name,
      'evidence_count': evidenceCount,
      'weighted_correct': weightedCorrect,
      'weighted_total': weightedTotal,
      'last_evidence_at': lastEvidenceAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserConceptState copyWith({
    String? userId,
    String? conceptId,
    RetrievalBand? retrievalBand,
    ConceptConfidence? confidence,
    int? evidenceCount,
    double? weightedCorrect,
    double? weightedTotal,
    DateTime? lastEvidenceAt,
    DateTime? updatedAt,
  }) {
    return UserConceptState(
      userId: userId ?? this.userId,
      conceptId: conceptId ?? this.conceptId,
      retrievalBand: retrievalBand ?? this.retrievalBand,
      confidence: confidence ?? this.confidence,
      evidenceCount: evidenceCount ?? this.evidenceCount,
      weightedCorrect: weightedCorrect ?? this.weightedCorrect,
      weightedTotal: weightedTotal ?? this.weightedTotal,
      lastEvidenceAt: lastEvidenceAt ?? this.lastEvidenceAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Calculates updated band and confidence given accuracy and evidence count per spec §8.2
  static ({RetrievalBand band, ConceptConfidence confidence}) computeBandAndConfidence({
    required double accuracy,
    required int evidenceCount,
  }) {
    if (evidenceCount == 0) {
      return (band: RetrievalBand.unassessed, confidence: ConceptConfidence.low);
    }

    final ConceptConfidence confidence;
    if (evidenceCount >= 5) {
      confidence = ConceptConfidence.high;
    } else if (evidenceCount >= 2) {
      confidence = ConceptConfidence.medium;
    } else {
      confidence = ConceptConfidence.low;
    }

    final RetrievalBand band;
    if (accuracy >= 0.90 && evidenceCount >= 5 && confidence == ConceptConfidence.high) {
      band = RetrievalBand.wellEstablished;
    } else if (accuracy >= 0.85 && evidenceCount >= 3) {
      band = RetrievalBand.wellRetained;
    } else if (accuracy >= 0.60) {
      band = RetrievalBand.developing;
    } else {
      band = RetrievalBand.needsReinforcement;
    }

    return (band: band, confidence: confidence);
  }
}

/// Qualitative Target Readiness bands per spec §9.
enum TargetReadinessBand {
  strongCoverage,
  developing,
  needsReinforcement,
  notYetAssessed;

  String get displayName {
    switch (this) {
      case TargetReadinessBand.strongCoverage:
        return 'Strong Coverage';
      case TargetReadinessBand.developing:
        return 'Developing';
      case TargetReadinessBand.needsReinforcement:
        return 'Needs Reinforcement';
      case TargetReadinessBand.notYetAssessed:
        return 'Not Yet Assessed';
    }
  }
}

/// Qualitative evaluation of learner readiness for a TargetVersion per spec §9.
class TargetReadiness {
  final String targetVersionId;
  final TargetReadinessBand band;
  final double score; // 0.0 to 1.0 weighted readiness score
  final int totalCoreConcepts;
  final int assessedConceptsCount;
  final Map<RetrievalBand, int> bandDistribution;

  const TargetReadiness({
    required this.targetVersionId,
    required this.band,
    required this.score,
    required this.totalCoreConcepts,
    required this.assessedConceptsCount,
    required this.bandDistribution,
  });

  /// Evaluates readiness for core concepts per the formula in spec §9
  factory TargetReadiness.evaluate({
    required String targetVersionId,
    required List<({String conceptId, double weight})> coreConcepts,
    required Map<String, UserConceptState> userConceptStates,
  }) {
    if (coreConcepts.isEmpty) {
      return TargetReadiness(
        targetVersionId: targetVersionId,
        band: TargetReadinessBand.notYetAssessed,
        score: 0.0,
        totalCoreConcepts: 0,
        assessedConceptsCount: 0,
        bandDistribution: {for (final b in RetrievalBand.values) b: 0},
      );
    }

    double totalWeight = 0.0;
    double weightedReadinessSum = 0.0;
    int assessedCount = 0;
    final distribution = {for (final b in RetrievalBand.values) b: 0};

    for (final item in coreConcepts) {
      final w = item.weight.clamp(0.0, 1.0);
      totalWeight += w;

      final state = userConceptStates[item.conceptId];
      final band = state?.retrievalBand ?? RetrievalBand.unassessed;
      distribution[band] = (distribution[band] ?? 0) + 1;

      double conceptReadiness = 0.0;
      if (state != null && state.evidenceCount > 0) {
        assessedCount++;
        switch (band) {
          case RetrievalBand.wellEstablished:
            conceptReadiness = 1.0;
            break;
          case RetrievalBand.wellRetained:
            conceptReadiness = 0.85;
            break;
          case RetrievalBand.developing:
            conceptReadiness = 0.60;
            break;
          case RetrievalBand.needsReinforcement:
            conceptReadiness = 0.25;
            break;
          case RetrievalBand.unassessed:
            conceptReadiness = 0.0;
            break;
        }
      }
      weightedReadinessSum += conceptReadiness * w;
    }

    final double score = totalWeight > 0 ? (weightedReadinessSum / totalWeight).clamp(0.0, 1.0) : 0.0;

    final TargetReadinessBand readinessBand;
    if (assessedCount == 0) {
      readinessBand = TargetReadinessBand.notYetAssessed;
    } else if (score >= 0.85) {
      readinessBand = TargetReadinessBand.strongCoverage;
    } else if (score >= 0.60) {
      readinessBand = TargetReadinessBand.developing;
    } else {
      readinessBand = TargetReadinessBand.needsReinforcement;
    }

    return TargetReadiness(
      targetVersionId: targetVersionId,
      band: readinessBand,
      score: score,
      totalCoreConcepts: coreConcepts.length,
      assessedConceptsCount: assessedCount,
      bandDistribution: distribution,
    );
  }
}

