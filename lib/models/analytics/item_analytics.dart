/// Item Analytics & Psychometrics models aligned with Classical Test Theory (CTT)
/// and Architecture Phase 1 evidence-based roadmap.
library;

/// Represents psychometric statistics and moderation flags for an assessment question or item.
class ItemAnalytics {
  final String itemId;
  final String itemType;
  final int responseCount;
  final int correctCount;
  final double pValue;
  final double pointBiserial;
  final Map<String, double> distractorRates;
  final Map<String, int> distractorCounts;
  final int? medianLatencyMs;
  final int? iqrLatencyMs;
  final List<String> flaggedReasons;
  final bool autoFlagged;
  final String? moderationReportId;
  final DateTime lastCalculatedAt;

  const ItemAnalytics({
    required this.itemId,
    this.itemType = 'question',
    required this.responseCount,
    required this.correctCount,
    required this.pValue,
    required this.pointBiserial,
    this.distractorRates = const {},
    this.distractorCounts = const {},
    this.medianLatencyMs,
    this.iqrLatencyMs,
    this.flaggedReasons = const [],
    this.autoFlagged = false,
    this.moderationReportId,
    required this.lastCalculatedAt,
  });

  bool get hasNegativeDiscrimination => pointBiserial < 0.0;
  bool get isExtremelyDifficult => pValue < 0.15;
  bool get isExtremelyEasy => pValue > 0.95;
  bool get hasDeadDistractor => flaggedReasons.contains('dead_distractor');

  String get facilityLabel {
    if (pValue >= 0.80) return 'Easy';
    if (pValue >= 0.50) return 'Moderate';
    if (pValue >= 0.20) return 'Hard';
    return 'Very Hard';
  }

  String get discriminationLabel {
    if (pointBiserial >= 0.35) return 'Excellent';
    if (pointBiserial >= 0.25) return 'Good';
    if (pointBiserial >= 0.15) return 'Marginal';
    if (pointBiserial >= 0.0) return 'Poor';
    return 'Defective';
  }

  factory ItemAnalytics.fromJson(Map<String, dynamic> json) {
    final rawRates = json['distractor_rates'] as Map<String, dynamic>? ?? {};
    final distRates = <String, double>{};
    for (final entry in rawRates.entries) {
      distRates[entry.key] = (entry.value as num).toDouble();
    }

    final rawCounts = json['distractor_counts'] as Map<String, dynamic>? ?? {};
    final distCounts = <String, int>{};
    for (final entry in rawCounts.entries) {
      distCounts[entry.key] = (entry.value as num).toInt();
    }

    final rawFlags = json['flagged_reasons'];
    final flags = <String>[];
    if (rawFlags is List) {
      for (final f in rawFlags) {
        flags.add(f.toString());
      }
    }

    return ItemAnalytics(
      itemId: json['item_id'] as String,
      itemType: json['item_type'] as String? ?? 'question',
      responseCount: (json['response_count'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? 0,
      pValue: (json['p_value'] as num?)?.toDouble() ?? 0.0,
      pointBiserial: (json['point_biserial'] as num?)?.toDouble() ?? 0.0,
      distractorRates: distRates,
      distractorCounts: distCounts,
      medianLatencyMs: (json['median_latency_ms'] as num?)?.toInt(),
      iqrLatencyMs: (json['iqr_latency_ms'] as num?)?.toInt(),
      flaggedReasons: flags,
      autoFlagged: json['auto_flagged'] as bool? ?? false,
      moderationReportId: json['moderation_report_id'] as String?,
      lastCalculatedAt: json['last_calculated_at'] != null
          ? DateTime.parse(json['last_calculated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_type': itemType,
        'response_count': responseCount,
        'correct_count': correctCount,
        'p_value': pValue,
        'point_biserial': pointBiserial,
        'distractor_rates': distractorRates,
        'distractor_counts': distractorCounts,
        'median_latency_ms': medianLatencyMs,
        'iqr_latency_ms': iqrLatencyMs,
        'flagged_reasons': flaggedReasons,
        'auto_flagged': autoFlagged,
        'moderation_report_id': moderationReportId,
        'last_calculated_at': lastCalculatedAt.toIso8601String(),
      };
}

