/// How much of a target's blueprint weight has enough held-out check items
/// for a readiness estimate to mean something (ingestion plan v1.2 §8.6,
/// owner decision D-14). Served by `get_target_readiness_coverage`.
enum ReadinessCoverageState {
  /// Under 60% of blueprint weight covered: show study progress, not readiness.
  hidden,

  /// 60% up to 90%: show readiness, labelled provisional.
  provisional,

  /// 90% or more: show readiness normally.
  full,
}

class ReadinessCoverage {
  final ReadinessCoverageState state;

  /// Share of blueprint weight (0.0 to 1.0) whose objectives have enough
  /// held-out checks. Null when coverage could not be confirmed.
  final double? coveredWeight;
  final int objectivesTotal;
  final int objectivesCovered;
  final int minHeldOutItems;
  final double provisionalThreshold;

  /// True when domain weights were missing and domains shared equally.
  final bool weightsEditorial;

  /// Who reviewed the counted held-out checks: 'human', 'ai', 'mixed', or
  /// null when none count (decision D-16). Never shown as a person's review
  /// unless it is 'human'.
  final String? reviewBasis;

  const ReadinessCoverage({
    required this.state,
    required this.coveredWeight,
    required this.objectivesTotal,
    required this.objectivesCovered,
    this.minHeldOutItems = 6,
    this.provisionalThreshold = 0.6,
    this.weightsEditorial = false,
    this.reviewBasis,
  });

  /// Coverage could not be read while the gate is on: fail closed, so an
  /// unconfirmed readiness band is never shown.
  const ReadinessCoverage.unavailable()
      : state = ReadinessCoverageState.hidden,
        coveredWeight = null,
        objectivesTotal = 0,
        objectivesCovered = 0,
        minHeldOutItems = 6,
        provisionalThreshold = 0.6,
        weightsEditorial = false,
        reviewBasis = null;

  bool get isUnavailable => coveredWeight == null;

  /// Null when the server reports the gate is off (readiness shows as before).
  /// An unknown state fails closed to [ReadinessCoverageState.hidden].
  static ReadinessCoverage? fromJson(Map<String, dynamic> json) {
    if (json['enabled'] != true) return null;
    final state = switch (json['state']) {
      'full' => ReadinessCoverageState.full,
      'provisional' => ReadinessCoverageState.provisional,
      _ => ReadinessCoverageState.hidden,
    };
    double? asDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');
    int asInt(Object? v, int fallback) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
    final covered = asDouble(json['covered_weight']);
    return ReadinessCoverage(
      state: covered == null ? ReadinessCoverageState.hidden : state,
      coveredWeight: covered?.clamp(0.0, 1.0),
      objectivesTotal: asInt(json['objectives_total'], 0),
      objectivesCovered: asInt(json['objectives_covered'], 0),
      minHeldOutItems: asInt(json['min_held_out_items'], 6),
      provisionalThreshold: asDouble(json['provisional_threshold']) ?? 0.6,
      weightsEditorial: json['weights_editorial'] == true,
      reviewBasis: switch (json['review_basis']) {
        'human' => 'human',
        'ai' => 'ai',
        'mixed' => 'mixed',
        _ => null,
      },
    );
  }

  /// True when some counted checks were reviewed by AI rather than a person.
  bool get aiReviewed => reviewBasis == 'ai' || reviewBasis == 'mixed';

  /// Whole-number percentage of blueprint weight covered, for display.
  int get coveredPercent => ((coveredWeight ?? 0) * 100).floor();
}
