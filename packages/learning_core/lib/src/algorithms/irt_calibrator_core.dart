import 'dart:math' as math;
import '../models/item_psychometric_status.dart';

/// 2-Parameter Logistic (2PL) Item Response Theory (IRT) model parameters.
///
/// Models response probability as:
/// P(θ) = 1 / (1 + e^(-a * (θ - b)))
/// where:
/// - a is discrimination (typically 0.2 to 3.0)
/// - b is item difficulty on the logit scale (typically -4.0 to +4.0)
/// - θ (theta) is learner latent ability on the logit scale
class IrtParameters2Pl {
  final double discrimination;
  final double difficulty;
  final double? standardError;
  final bool converged;

  const IrtParameters2Pl({
    required this.discrimination,
    required this.difficulty,
    this.standardError,
    this.converged = true,
  });

  /// Calculates the probability of a correct response for a learner with latent ability [theta].
  double probability(double theta) {
    final logit = discrimination * (theta - difficulty);
    if (logit > 20.0) return 1.0;
    if (logit < -20.0) return 0.0;
    return 1.0 / (1.0 + math.exp(-logit));
  }

  /// Calculates the Fisher Item Information function at ability level [theta].
  ///
  /// I(θ) = a² * P(θ) * (1 - P(θ))
  /// Maximum information is achieved at θ = b with value a² / 4.
  double information(double theta) {
    final p = probability(theta);
    return discrimination * discrimination * p * (1.0 - p);
  }

  Map<String, dynamic> toJson() => {
        'discrimination': discrimination,
        'difficulty': difficulty,
        if (standardError != null) 'standard_error': standardError,
        'converged': converged,
      };

  factory IrtParameters2Pl.fromJson(Map<String, dynamic> json) {
    return IrtParameters2Pl(
      discrimination: (json['discrimination'] as num?)?.toDouble() ?? 1.0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 0.0,
      standardError: (json['standard_error'] as num?)?.toDouble(),
      converged: json['converged'] as bool? ?? true,
    );
  }
}

/// Core item difficulty calibrator implementing empirical Elo tracking
/// and 2PL IRT calibration under ER-09a (König et al., 2020) and ER-09b (Bolsinova et al., 2026).
class IrtCalibratorCore {
  /// Default policy threshold for minimal observation count before low-stakes
  /// preliminary Elo ordering becomes eligible (ER-09b).
  static const int defaultEloMinObservations = 30;

  /// Default policy threshold for maximum standard error allowable before
  /// an item can be promoted to 'calibrated' IRT status (ER-09a).
  static const double defaultCalibrationMaxSe = 0.30;

  final int eloMinObservations;
  final double calibrationMaxSe;
  final bool isEloOrderingActive;
  final bool isCalibrationActive;

  const IrtCalibratorCore({
    this.eloMinObservations = defaultEloMinObservations,
    this.calibrationMaxSe = defaultCalibrationMaxSe,
    this.isEloOrderingActive = true,
    this.isCalibrationActive = true,
  });

  /// Evaluates empirical item psychometric status across the 4-stage lifecycle:
  /// 1. 'unobserved': N = 0
  /// 2. 'observed_uncalibrated': N >= 1, but N < eloMinObservations or Elo ordering is inactive.
  ///    (Observation-existence label only; a single observation is not a valid difficulty estimate).
  /// 3. 'preliminary_elo_ordering': N >= eloMinObservations with online Elo updates.
  ///    (Low-stakes ordering heuristic per Pelánek 2016, qualified by Bolsinova et al. 2026).
  /// 4. 'calibrated': Empirical IRT 2PL parameters estimated with SE(b) <= calibrationMaxSe.
  ItemPsychometricStatus evaluateLifecycleStatus({
    required int observationCount,
    double? difficultyEstimate,
    double? standardError,
    double? discriminationEstimate,
    bool modelConverged = true,
  }) {
    if (observationCount <= 0) {
      return ItemPsychometricStatus.unobserved;
    }

    // Check if item meets full IRT calibration criteria
    final meetsCalibration = isCalibrationActive &&
        observationCount >= eloMinObservations &&
        standardError != null &&
        standardError <= calibrationMaxSe &&
        modelConverged &&
        difficultyEstimate != null;

    if (meetsCalibration) {
      return ItemPsychometricStatus(
        status: 'calibrated',
        observationCount: observationCount,
        difficultyEstimate: difficultyEstimate,
        standardError: standardError,
        discriminationEstimate: discriminationEstimate ?? 1.0,
      );
    }

    // Check if item qualifies for preliminary Elo heuristic ordering
    final meetsElo = isEloOrderingActive &&
        observationCount >= eloMinObservations &&
        difficultyEstimate != null;

    if (meetsElo) {
      return ItemPsychometricStatus(
        status: 'preliminary_elo_ordering',
        observationCount: observationCount,
        difficultyEstimate: difficultyEstimate,
        standardError: standardError,
        discriminationEstimate: discriminationEstimate,
      );
    }

    // Default to observed_uncalibrated: observation exists but cannot be calibrated
    return ItemPsychometricStatus(
      status: 'observed_uncalibrated',
      observationCount: observationCount,
      difficultyEstimate: difficultyEstimate,
      standardError: standardError,
      discriminationEstimate: discriminationEstimate,
    );
  }

  /// Calculates online Elo rating update on the logit scale [-4.0, +4.0].
  ///
  /// Δb = -K_I * (score - P)
  /// where score is 1.0 if learner is correct, 0.0 if incorrect.
  /// When learner is correct (score = 1.0), item difficulty b decreases.
  /// When learner fails (score = 0.0), item difficulty b increases.
  double updateEloDifficulty({
    required double currentDifficulty,
    required double learnerAbility,
    required double learnerScore,
    double baseK = 0.30,
    int? observationCount,
  }) {
    final effectiveK = observationCount != null
        ? baseK / (1.0 + 0.04 * observationCount)
        : baseK;

    final logit = learnerAbility - currentDifficulty;
    final p = 1.0 / (1.0 + math.exp(-logit.clamp(-20.0, 20.0)));
    final error = learnerScore - p;

    final newDifficulty = (currentDifficulty - effectiveK * error).clamp(-4.0, 4.0);
    return double.parse(newDifficulty.toStringAsFixed(4));
  }

  /// Estimates 2PL item parameters (discrimination a, difficulty b) and standard error
  /// from a collection of learner ability estimates [thetas] and binary outcomes [responses].
  ///
  /// Uses bounded Newton-Raphson maximum likelihood estimation (MLE).
  IrtParameters2Pl estimate2PlParameters({
    required List<double> thetas,
    required List<bool> responses,
    double initialA = 1.0,
    double initialB = 0.0,
    int maxIterations = 50,
    double tolerance = 1e-4,
  }) {
    if (thetas.isEmpty || thetas.length != responses.length) {
      return IrtParameters2Pl(
        discrimination: initialA,
        difficulty: initialB,
        converged: false,
      );
    }

    final n = thetas.length;
    double a = initialA.clamp(0.2, 3.0);
    double b = initialB.clamp(-4.0, 4.0);
    bool converged = false;

    for (int iter = 0; iter < maxIterations; iter++) {
      double dLda = 0.0;
      double dLdb = 0.0;
      double d2Lda2 = 0.0;
      double d2Ldb2 = 0.0;
      double d2Ldadb = 0.0;

      for (int i = 0; i < n; i++) {
        final theta = thetas[i];
        final y = responses[i] ? 1.0 : 0.0;
        final logit = (a * (theta - b)).clamp(-20.0, 20.0);
        final p = 1.0 / (1.0 + math.exp(-logit));
        final w = p * (1.0 - p); // variance

        final diff = theta - b;
        final residual = y - p;

        dLda += diff * residual;
        dLdb += -a * residual;

        d2Lda2 -= diff * diff * w;
        d2Ldb2 -= a * a * w;
        d2Ldadb -= (-residual - a * diff * w);
      }

      // Safeguard determinant against singularity
      final det = (d2Lda2 * d2Ldb2) - (d2Ldadb * d2Ldadb);
      if (det.abs() < 1e-12) {
        break;
      }

      final deltaA = (d2Ldb2 * dLda - d2Ldadb * dLdb) / det;
      final deltaB = (d2Lda2 * dLdb - d2Ldadb * dLda) / det;

      a = (a - deltaA).clamp(0.2, 3.0);
      b = (b - deltaB).clamp(-4.0, 4.0);

      if (deltaA.abs() < tolerance && deltaB.abs() < tolerance) {
        converged = true;
        break;
      }
    }

    // Estimate Fisher Information for difficulty b at mean ability
    double fisherB = 0.0;
    for (int i = 0; i < n; i++) {
      final theta = thetas[i];
      final logit = (a * (theta - b)).clamp(-20.0, 20.0);
      final p = 1.0 / (1.0 + math.exp(-logit));
      fisherB += a * a * p * (1.0 - p);
    }

    final double? standardError = fisherB > 0.0
        ? double.parse((1.0 / math.sqrt(fisherB)).toStringAsFixed(4))
        : null;

    return IrtParameters2Pl(
      discrimination: double.parse(a.toStringAsFixed(4)),
      difficulty: double.parse(b.toStringAsFixed(4)),
      standardError: standardError,
      converged: converged,
    );
  }
}

