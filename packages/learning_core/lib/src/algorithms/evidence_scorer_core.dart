/// Quality tier classifying resource educational effectiveness (ECO-09).
enum QualityTier {
  exemplary,
  effective,
  adequate,
  needsImprovement;

  static QualityTier fromScore(double score) {
    if (score >= 0.85) return QualityTier.exemplary;
    if (score >= 0.70) return QualityTier.effective;
    if (score >= 0.50) return QualityTier.adequate;
    return QualityTier.needsImprovement;
  }

  String toDbString() {
    switch (this) {
      case QualityTier.exemplary:
        return 'exemplary';
      case QualityTier.effective:
        return 'effective';
      case QualityTier.adequate:
        return 'adequate';
      case QualityTier.needsImprovement:
        return 'needs_improvement';
    }
  }

  String get label {
    switch (this) {
      case QualityTier.exemplary:
        return 'Exemplary Evidence (EQI >= 0.85)';
      case QualityTier.effective:
        return 'Effective (0.70 <= EQI < 0.85)';
      case QualityTier.adequate:
        return 'Adequate (0.50 <= EQI < 0.70)';
      case QualityTier.needsImprovement:
        return 'Needs Improvement (EQI < 0.50)';
    }
  }
}

/// Structured multi-signal educational quality metric (ECO-09).
///
/// Strictly separates evidence-based outcomes (learning gains, memory retention,
/// psychometric validity, provenance) from superficial engagement metrics (views, likes).
class ContentQualityScore {
  final String resourceId;
  final double diagnosticGainScore;
  final double retentionStabilityScore;
  final double provenanceTrustWeight;
  final double itemPsychometricScore;
  final double educationalQualityIndex;
  final QualityTier qualityTier;

  const ContentQualityScore({
    required this.resourceId,
    required this.diagnosticGainScore,
    required this.retentionStabilityScore,
    required this.provenanceTrustWeight,
    required this.itemPsychometricScore,
    required this.educationalQualityIndex,
    required this.qualityTier,
  });

  Map<String, dynamic> toJson() => {
        'resource_id': resourceId,
        'diagnostic_gain_score': diagnosticGainScore,
        'retention_stability_score': retentionStabilityScore,
        'provenance_trust_weight': provenanceTrustWeight,
        'item_psychometric_score': itemPsychometricScore,
        'educational_quality_index': educationalQualityIndex,
        'quality_tier': qualityTier.toDbString(),
      };
}

/// Evaluates learning resource effectiveness based on empirical learning science metrics.
class EvidenceScorerCore {
  const EvidenceScorerCore._();

  /// Maps catalog provenance vocabulary to trust weights.
  static double resolveProvenanceWeight(String provenanceOrigin) {
    switch (provenanceOrigin.toLowerCase().trim()) {
      case 'official':
        return 1.00;
      case 'catalog':
        return 0.95;
      case 'community_reviewed':
      case 'reviewed':
        return 0.85;
      case 'community_pending':
      case 'pending':
        return 0.50;
      case 'private':
        return 0.30;
      default:
        return 0.60;
    }
  }

  /// Evaluates composite Educational Quality Index (EQI) for a resource.
  ///
  /// Weights:
  /// - 35%: Diagnostic learning gain (normalized change between pre- and post-tests)
  /// - 30%: Spaced retention stability (FSRS retrievability rate across recall intervals)
  /// - 20%: Authoritative provenance trust weight
  /// - 15%: Psychometric health (Haladyna conformity & absence of flawed distractors)
  static ContentQualityScore evaluateResource({
    required String resourceId,
    required double diagnosticGain,
    required double retentionRate,
    required String provenanceOrigin,
    double psychometricHealth = 1.0,
  }) {
    final clampedGain = diagnosticGain.clamp(0.0, 1.0);
    final clampedRetention = retentionRate.clamp(0.0, 1.0);
    final provWeight = resolveProvenanceWeight(provenanceOrigin);
    final clampedPsychometric = psychometricHealth.clamp(0.0, 1.0);

    final composite = (clampedGain * 0.35) +
        (clampedRetention * 0.30) +
        (provWeight * 0.20) +
        (clampedPsychometric * 0.15);

    final roundedComposite = double.parse(composite.toStringAsFixed(4));
    final tier = QualityTier.fromScore(roundedComposite);

    return ContentQualityScore(
      resourceId: resourceId,
      diagnosticGainScore: double.parse(clampedGain.toStringAsFixed(4)),
      retentionStabilityScore: double.parse(clampedRetention.toStringAsFixed(4)),
      provenanceTrustWeight: provWeight,
      itemPsychometricScore: double.parse(clampedPsychometric.toStringAsFixed(4)),
      educationalQualityIndex: roundedComposite,
      qualityTier: tier,
    );
  }

  /// Ranks resources strictly by Educational Quality Index descending.
  static List<ContentQualityScore> rankResources(List<ContentQualityScore> resources) {
    final list = List<ContentQualityScore>.from(resources);
    list.sort((a, b) => b.educationalQualityIndex.compareTo(a.educationalQualityIndex));
    return list;
  }
}
