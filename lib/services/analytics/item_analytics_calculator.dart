import 'dart:math' as math;

/// Pure mathematical and psychometric calculations for item analytics.
/// Follows Classical Test Theory (CTT) and Pelánek (2016) formulations.
class ItemAnalyticsCalculator {
  /// Computes item facility / difficulty index p (fraction of correct responses).
  /// p = Σ scores / N.
  static double computePValue(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    final sum = scores.fold(0.0, (acc, s) => acc + s);
    return (sum / scores.length).clamp(0.0, 1.0);
  }

  /// Computes point-biserial discrimination r_pbis.
  ///
  /// r_pbis = ((X̄₁ - X̄) / s_X) * sqrt(p / (1 - p))
  /// where:
  ///   - X̄₁ is the mean total/benchmark score of learners answering correctly.
  ///   - X̄ is the mean total score of all learners attempting the item.
  ///   - s_X is the sample standard deviation of total scores.
  ///   - p is the proportion of learners answering correctly.
  static double computePointBiserial({
    required List<double> itemScores,
    required List<double> learnerTotalScores,
  }) {
    if (itemScores.isEmpty || itemScores.length != learnerTotalScores.length) {
      return 0.0;
    }
    final n = itemScores.length;
    if (n < 3) return 0.0;

    final p = computePValue(itemScores);
    if (p <= 0.0 || p >= 1.0) return 0.0;

    final meanTotal = learnerTotalScores.fold(0.0, (acc, s) => acc + s) / n;

    // Variance & sample standard deviation of total scores
    double sumSqDiff = 0.0;
    for (final score in learnerTotalScores) {
      final diff = score - meanTotal;
      sumSqDiff += diff * diff;
    }
    final variance = sumSqDiff / (n - 1);
    if (variance <= 0.0) return 0.0;
    final stdDevTotal = math.sqrt(variance);

    // Mean total score for learners who got this item correct (score >= 0.5)
    double correctTotalSum = 0.0;
    int correctCount = 0;
    for (int i = 0; i < n; i++) {
      if (itemScores[i] >= 0.5) {
        correctTotalSum += learnerTotalScores[i];
        correctCount++;
      }
    }
    if (correctCount == 0 || correctCount == n) return 0.0;
    final meanCorrect = correctTotalSum / correctCount;

    final r = ((meanCorrect - meanTotal) / stdDevTotal) * math.sqrt(p / (1.0 - p));
    return r.clamp(-1.0, 1.0);
  }

  /// Computes distractor choice frequencies and selection rates.
  static ({Map<String, int> counts, Map<String, double> rates}) computeDistractorStats(
    List<String?> choices,
  ) {
    if (choices.isEmpty) {
      return (counts: const {}, rates: const {});
    }
    final counts = <String, int>{};
    for (final choice in choices) {
      final key = choice ?? 'unanswered';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final total = choices.length;
    final rates = <String, double>{};
    for (final entry in counts.entries) {
      rates[entry.key] = double.parse((entry.value / total).toStringAsFixed(4));
    }

    return (counts: counts, rates: rates);
  }

  /// Computes median latency and interquartile range (IQR) in milliseconds.
  static ({int? median, int? iqr}) computeLatencyStats(List<int> latenciesMs) {
    if (latenciesMs.isEmpty) {
      return (median: null, iqr: null);
    }
    final sorted = List<int>.from(latenciesMs)..sort();
    final n = sorted.length;

    int median;
    if (n.isOdd) {
      median = sorted[n ~/ 2];
    } else {
      median = ((sorted[(n ~/ 2) - 1] + sorted[n ~/ 2]) / 2).round();
    }

    final q1 = sorted[(n * 0.25).floor()];
    final q3 = sorted[(n * 0.75).floor()];
    final iqr = q3 - q1;

    return (median: median, iqr: iqr);
  }

  /// Evaluates whether an item should be flagged for psychometric defects.
  static List<String> evaluateFlags({
    required int responseCount,
    required double pValue,
    required double pointBiserial,
    required Map<String, double> distractorRates,
    int? medianLatencyMs,
  }) {
    final flags = <String>[];

    // 1. Negative discrimination: higher-ability learners miss it more often
    if (pointBiserial < 0.0 && responseCount >= 8) {
      flags.add('negative_discrimination');
    }

    // 2. Extreme difficulty: p < 0.15 (below chance guessing on 4-option MCQ)
    if (pValue < 0.15 && responseCount >= 8) {
      flags.add('extreme_difficulty');
    }

    // 3. Extreme ease: p > 0.95 with substantial sample size (ceiling effect)
    if (pValue > 0.95 && responseCount >= 20) {
      flags.add('extreme_ease');
    }

    // 4. Dead distractor: an option selected < 3% of the time when N >= 20
    if (responseCount >= 20) {
      for (final rate in distractorRates.values) {
        if (rate < 0.03) {
          flags.add('dead_distractor');
          break;
        }
      }
    }

    // 5. Latency anomalies
    if (medianLatencyMs != null && responseCount >= 10) {
      if (medianLatencyMs < 3000) {
        flags.add('suspicious_low_latency');
      } else if (medianLatencyMs > 180000) {
        flags.add('high_latency_outlier');
      }
    }

    return flags;
  }
}
