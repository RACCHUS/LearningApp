/// Field Occupation Metric model
/// Represents empirical labor market analytics with strict dimensionality and fail-closed privacy safeguards.
class FieldOccupationMetric {
  final String id;
  final String fieldId;
  final String occupationId;
  final String metricType; // 'observed_worker_field_share', 'graduate_transition_share', 'derived_education_alignment_score', 'app_user_transition_share'
  final double metricValue; // 0.0 to 1.0
  final String population;
  final String geography;
  final int dataYear;
  final String? sourceReleaseId;
  final String methodologyVersion;
  final int? sampleSize;
  final bool isPublished;
  final bool privacyThresholdMet;
  final String? notes;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;

  const FieldOccupationMetric({
    required this.id,
    required this.fieldId,
    required this.occupationId,
    required this.metricType,
    required this.metricValue,
    this.population = 'all_applicable',
    this.geography = 'US',
    required this.dataYear,
    this.sourceReleaseId,
    this.methodologyVersion = 'source_native_v1',
    this.sampleSize,
    this.isPublished = false,
    this.privacyThresholdMet = false,
    this.notes,
    this.metadata = const {},
    this.createdAt,
  });

  /// Whether this metric is safe and compliant to render in user-facing surfaces.
  /// Enforces Section 15.6 and Section 5.2 fail-closed privacy safeguards.
  bool get isUserDisplayable {
    if (!isPublished) return false;
    if (metricType == 'app_user_transition_share') {
      return (sampleSize ?? 0) >= 50 && privacyThresholdMet;
    }
    return true;
  }

  factory FieldOccupationMetric.fromJson(Map<String, dynamic> json) {
    return FieldOccupationMetric(
      id: json['id'] as String,
      fieldId: json['field_id'] as String,
      occupationId: json['occupation_id'] as String,
      metricType: json['metric_type'] as String,
      metricValue: (json['metric_value'] as num).toDouble(),
      population: json['population'] as String? ?? 'all_applicable',
      geography: json['geography'] as String? ?? 'US',
      dataYear: (json['data_year'] as num).toInt(),
      sourceReleaseId: json['source_release_id'] as String?,
      methodologyVersion:
          json['methodology_version'] as String? ?? 'source_native_v1',
      sampleSize: (json['sample_size'] as num?)?.toInt(),
      isPublished: json['is_published'] as bool? ?? false,
      privacyThresholdMet: json['privacy_threshold_met'] as bool? ?? false,
      notes: json['notes'] as String?,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'field_id': fieldId,
        'occupation_id': occupationId,
        'metric_type': metricType,
        'metric_value': metricValue,
        'population': population,
        'geography': geography,
        'data_year': dataYear,
        'source_release_id': sourceReleaseId,
        'methodology_version': methodologyVersion,
        'sample_size': sampleSize,
        'is_published': isPublished,
        'privacy_threshold_met': privacyThresholdMet,
        'notes': notes,
        'metadata': metadata,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
