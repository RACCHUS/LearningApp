import 'dart:math' as math;

/// Pelánek (2016) Elo rating engine for adaptive item difficulty and learner ability estimation.
///
/// Provides robust, low-data parameter estimation prior to graduating to 2PL IRT
/// when item response volume is large (ER-09b, ARCH-4).
class EloRatingEngine {
  /// Logistic probability that a learner with ability θ correctly answers an item with difficulty b:
  /// P(correct | θ, b) = 1 / (1 + e^-(θ - b))
  static double predictProbability({
    required double ability,
    required double difficulty,
  }) {
    final logit = ability - difficulty;
    // Guard against overflow
    if (logit > 20.0) return 1.0;
    if (logit < -20.0) return 0.0;
    return 1.0 / (1.0 + math.exp(-logit));
  }

  /// Updates learner ability θ and item difficulty b after an observed interaction.
  ///
  /// Δθ = K_L * (score - P)
  /// Δb = -K_I * (score - P)
  ///
  /// [score] is typically 1.0 for correct, 0.0 for incorrect.
  /// [kLearner] update step size for learner ability (default 0.4).
  /// [kItem] update step size for item difficulty (default 0.2).
  static ({double updatedAbility, double updatedDifficulty}) updateRatings({
    required double learnerAbility,
    required double itemDifficulty,
    required double score,
    double kLearner = 0.40,
    double kItem = 0.20,
    int? learnerResponseCount,
    int? itemResponseCount,
  }) {
    // Dynamic uncertainty scaling: K(N) = K_0 / (1 + 0.05 * N)
    final effectiveKLearner = learnerResponseCount != null
        ? kLearner / (1.0 + 0.05 * learnerResponseCount)
        : kLearner;
    final effectiveKItem = itemResponseCount != null
        ? kItem / (1.0 + 0.05 * itemResponseCount)
        : kItem;

    final p = predictProbability(ability: learnerAbility, difficulty: itemDifficulty);
    final error = score - p;

    final newAbility = (learnerAbility + effectiveKLearner * error).clamp(-4.0, 4.0);
    final newDifficulty = (itemDifficulty - effectiveKItem * error).clamp(-4.0, 4.0);

    return (
      updatedAbility: double.parse(newAbility.toStringAsFixed(4)),
      updatedDifficulty: double.parse(newDifficulty.toStringAsFixed(4)),
    );
  }

  /// Evaluates model calibration across probability bins (e.g., [0.0-0.2], [0.2-0.4], ...).
  /// Returns expected vs actual proportion correct to assess calibration curvature.
  static List<({double predictedMidpoint, double actualMean, int count})> computeCalibrationCurve({
    required List<({double predictedP, double actualScore})> observations,
    int binCount = 5,
  }) {
    if (observations.isEmpty) return const [];

    final binSize = 1.0 / binCount;
    final bins = List.generate(binCount, (_) => <double>[]);

    for (final obs in observations) {
      final binIndex = (obs.predictedP / binSize).floor().clamp(0, binCount - 1);
      bins[binIndex].add(obs.actualScore);
    }

    final result = <({double predictedMidpoint, double actualMean, int count})>[];
    for (int i = 0; i < binCount; i++) {
      final midpoint = (i + 0.5) * binSize;
      final scores = bins[i];
      final actualMean = scores.isNotEmpty
          ? scores.fold(0.0, (acc, s) => acc + s) / scores.length
          : midpoint;
      result.add((
        predictedMidpoint: double.parse(midpoint.toStringAsFixed(3)),
        actualMean: double.parse(actualMean.toStringAsFixed(3)),
        count: scores.length,
      ));
    }

    return result;
  }
}

