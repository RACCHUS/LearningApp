import 'dart:math' as math;
import '../../models/assessment_engine/adaptive_practice_state.dart';
import '../../models/assessment_item.dart';

/// Implements Computerized Adaptive Testing (CAT-style practice mode).
/// Adapts item difficulty and measures concept competence dynamically.
class AdaptivePracticeService {
  /// Initializes a new adaptive practice session.
  AdaptivePracticeState initSession({
    required String userId,
    required String targetVersionId,
    int maxItems = 25,
    double targetStandardError = 0.35,
  }) {
    return AdaptivePracticeState(
      userId: userId,
      targetVersionId: targetVersionId,
      theta: 0.0,
      standardError: 1.0,
      maxItems: maxItems,
      targetStandardError: targetStandardError,
    );
  }

  /// Maps textual difficulty to numerical item difficulty parameter (b_i on logit scale).
  double getDifficultyParameter(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return -1.0;
      case 'advanced':
        return 1.0;
      case 'intermediate':
      default:
        return 0.0;
    }
  }

  /// Calculates the 1-Parameter Logistic (Rasch) probability of a correct response.
  /// P(y = 1 | θ, b) = 1 / (1 + e^-(θ - b))
  double computeProbability(double theta, double b) {
    final logitDiff = theta - b;
    return 1.0 / (1.0 + math.exp(-logitDiff));
  }

  /// Selects the next optimal assessment item from the unserved pool.
  /// Targets items whose difficulty parameter b_i is closest to the learner's estimated θ.
  AssessmentItem? selectNextItem({
    required AdaptivePracticeState state,
    required List<AssessmentItem> pool,
  }) {
    final unserved = pool.where((item) => !state.servedItemIds.contains(item.id)).toList();
    if (unserved.isEmpty) return null;

    unserved.sort((a, b) {
      final bA = getDifficultyParameter(a.difficulty);
      final bB = getDifficultyParameter(b.difficulty);
      final distA = (bA - state.theta).abs();
      final distB = (bB - state.theta).abs();
      return distA.compareTo(distB);
    });

    return unserved.first;
  }

  /// Records the learner's response and updates the ability estimate θ and standard error SE.
  AdaptivePracticeState recordResponse({
    required AdaptivePracticeState currentState,
    required AssessmentItem item,
    required dynamic userResponse,
    required bool isCorrect,
    double? scoreEarned,
    String domainCode = '1.0',
  }) {
    final b = getDifficultyParameter(item.difficulty);
    final p = computeProbability(currentState.theta, b);
    final y = scoreEarned ?? (isCorrect ? 1.0 : 0.0);

    // Stochastic gradient update with diminishing step size
    final n = currentState.itemCount + 1;
    final learningRate = 1.0 / math.sqrt(n + 1);
    final thetaDelta = learningRate * (y - p);
    final newTheta = (currentState.theta + thetaDelta).clamp(-3.0, 3.0);

    // Calculate Fisher information
    // I_i = P * (1 - P)
    double totalInformation = 1.0; // Baseline prior corresponding to SE = 1.0
    for (final past in currentState.responses) {
      final pastB = past.difficulty == 'beginner'
          ? -1.0
          : past.difficulty == 'advanced'
              ? 1.0
              : 0.0;
      final pastP = computeProbability(past.thetaBefore, pastB);
      totalInformation += pastP * (1.0 - pastP);
    }
    totalInformation += p * (1.0 - p);

    final newStandardError = 1.0 / math.sqrt(totalInformation);

    final responseRecord = AdaptiveItemResponse(
      itemId: item.id,
      domainCode: domainCode,
      difficulty: item.difficulty,
      isCorrect: isCorrect,
      scoreEarned: y,
      thetaBefore: currentState.theta,
      thetaAfter: newTheta,
      answeredAt: DateTime.now(),
    );

    final updatedResponses = List<AdaptiveItemResponse>.from(currentState.responses)
      ..add(responseRecord);

    final reachedLimit = updatedResponses.length >= currentState.maxItems;
    final isConverged = newStandardError <= currentState.targetStandardError && updatedResponses.length >= 8;

    return currentState.copyWith(
      theta: newTheta,
      standardError: newStandardError,
      responses: updatedResponses,
      isFinished: reachedLimit || isConverged,
    );
  }
}
