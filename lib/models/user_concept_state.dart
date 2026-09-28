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
}
