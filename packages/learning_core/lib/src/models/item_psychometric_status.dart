/// Empirical psychometric state separating observation count, heuristic Elo ordering,
/// and IRT calibration per Learning Science §4.
class ItemPsychometricStatus {
  final String status; // unobserved | observed_uncalibrated | preliminary_elo_ordering | calibrated
  final int observationCount;
  final double? difficultyEstimate;
  final double? standardError;
  final double? discriminationEstimate;

  const ItemPsychometricStatus({
    required this.status,
    required this.observationCount,
    this.difficultyEstimate,
    this.standardError,
    this.discriminationEstimate,
  });

  factory ItemPsychometricStatus.fromJson(Map<String, dynamic> json) {
    return ItemPsychometricStatus(
      status: json['status'] as String? ?? 'unobserved',
      observationCount: json['observation_count'] as int? ?? 0,
      difficultyEstimate: (json['difficulty_estimate'] as num?)?.toDouble(),
      standardError: (json['standard_error'] as num?)?.toDouble(),
      discriminationEstimate:
          (json['discrimination_estimate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'observation_count': observationCount,
      if (difficultyEstimate != null) 'difficulty_estimate': difficultyEstimate,
      if (standardError != null) 'standard_error': standardError,
      if (discriminationEstimate != null)
        'discrimination_estimate': discriminationEstimate,
    };
  }

  static const unobserved = ItemPsychometricStatus(
    status: 'unobserved',
    observationCount: 0,
  );
}

