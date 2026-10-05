import 'dart:math' as math;

/// Single response log inside an adaptive practice session.
class AdaptiveItemResponse {
  final String itemId;
  final String domainCode;
  final String difficulty;
  final bool isCorrect;
  final double scoreEarned;
  final double thetaBefore;
  final double thetaAfter;
  final DateTime answeredAt;

  const AdaptiveItemResponse({
    required this.itemId,
    required this.domainCode,
    required this.difficulty,
    required this.isCorrect,
    required this.scoreEarned,
    required this.thetaBefore,
    required this.thetaAfter,
    required this.answeredAt,
  });
}

/// State tracking for Computerized Adaptive Testing (CAT-style practice mode).
class AdaptivePracticeState {
  final String userId;
  final String targetVersionId;
  final double theta; // Ability parameter θ (-3.0 to +3.0 scale, default 0.0)
  final double standardError; // Standard error of measurement (SE)
  final List<AdaptiveItemResponse> responses;
  final int maxItems;
  final double targetStandardError;
  final bool isFinished;

  const AdaptivePracticeState({
    required this.userId,
    required this.targetVersionId,
    this.theta = 0.0,
    this.standardError = 1.0,
    this.responses = const [],
    this.maxItems = 25,
    this.targetStandardError = 0.35,
    this.isFinished = false,
  });

  int get itemCount => responses.length;

  bool get isConverged => standardError <= targetStandardError;
  bool get hasReachedMaxItems => itemCount >= maxItems;
  bool get isSessionComplete => isFinished || hasReachedMaxItems || (itemCount >= 10 && isConverged);

  List<String> get servedItemIds => responses.map((r) => r.itemId).toList();

  int get correctCount => responses.where((r) => r.isCorrect).length;

  double get accuracy => itemCount > 0 ? (correctCount / itemCount) : 0.0;

  /// Translates ability logit θ (-3.0 to +3.0) to an intuitive estimated readiness percentage (0% to 100%).
  double get estimatedReadinessPercentage {
    // Logistic sigmoid transformation: 1 / (1 + e^-θ)
    final sigmoid = 1.0 / (1.0 + math.exp(-theta));
    return (sigmoid * 100.0).clamp(0.0, 100.0);
  }

  AdaptivePracticeState copyWith({
    String? userId,
    String? targetVersionId,
    double? theta,
    double? standardError,
    List<AdaptiveItemResponse>? responses,
    int? maxItems,
    double? targetStandardError,
    bool? isFinished,
  }) {
    return AdaptivePracticeState(
      userId: userId ?? this.userId,
      targetVersionId: targetVersionId ?? this.targetVersionId,
      theta: theta ?? this.theta,
      standardError: standardError ?? this.standardError,
      responses: responses ?? this.responses,
      maxItems: maxItems ?? this.maxItems,
      targetStandardError: targetStandardError ?? this.targetStandardError,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}
