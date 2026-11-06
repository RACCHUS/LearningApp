import '../models/video_interactive_module.dart';

/// Evaluated learning gain classification based on Hake's normalized gain thresholds.
enum LearningGainCategory {
  high,
  medium,
  low,
  loss;

  String toDbString() {
    switch (this) {
      case LearningGainCategory.high:
        return 'high';
      case LearningGainCategory.medium:
        return 'medium';
      case LearningGainCategory.low:
        return 'low';
      case LearningGainCategory.loss:
        return 'loss';
    }
  }

  String get label {
    switch (this) {
      case LearningGainCategory.high:
        return 'High Gain (g >= 0.7)';
      case LearningGainCategory.medium:
        return 'Medium Gain (0.3 <= g < 0.7)';
      case LearningGainCategory.low:
        return 'Low Gain (0.0 <= g < 0.3)';
      case LearningGainCategory.loss:
        return 'Negative / Regression (g < 0)';
    }
  }
}

/// Result of evaluating pre- and post-instruction performance scores.
class LearningGainResult {
  final double preScore;
  final double postScore;
  final double normalizedGain;
  final LearningGainCategory category;

  const LearningGainResult({
    required this.preScore,
    required this.postScore,
    required this.normalizedGain,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'pre_score': preScore,
        'post_score': postScore,
        'normalized_gain': normalizedGain,
        'category': category.toDbString(),
      };
}

/// Comparison evaluating the ER-10 Prequestion Effect (St. Hilaire et al. 2023/2024).
///
/// Meta-analytic benchmark:
/// - Specific priming effect on targeted material: g = .54 (95% CI [.42, .66])
/// - General spillover on untested material in same lesson: g = .04 (95% CI [-.04, .11])
class PrequestionPrimingComparison {
  final LearningGainResult targetedGain;
  final LearningGainResult untargetedGain;
  final double primingAdvantage;
  final bool confirmsSpecificPriming;

  const PrequestionPrimingComparison({
    required this.targetedGain,
    required this.untargetedGain,
    required this.primingAdvantage,
    required this.confirmsSpecificPriming,
  });

  Map<String, dynamic> toJson() => {
        'targeted_gain': targetedGain.toJson(),
        'untargeted_gain': untargetedGain.toJson(),
        'priming_advantage': primingAdvantage,
        'confirms_specific_priming': confirmsSpecificPriming,
      };
}

/// Aggregate channel-level metrics based on measured learning gain rather than vanity metrics.
class CreatorChannelGainMetric {
  final String channelId;
  final String channelName;
  final int totalModules;
  final int scoredModulesCount;
  final double averageNormalizedGain;
  final LearningGainCategory aggregateCategory;

  const CreatorChannelGainMetric({
    required this.channelId,
    required this.channelName,
    required this.totalModules,
    required this.scoredModulesCount,
    required this.averageNormalizedGain,
    required this.aggregateCategory,
  });

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'channel_name': channelName,
        'total_modules': totalModules,
        'scored_modules_count': scoredModulesCount,
        'average_normalized_gain': averageNormalizedGain,
        'aggregate_category': aggregateCategory.toDbString(),
      };
}

/// Calculates normalized learning gains (Hake 1998; Marx & Cummings 2007) and
/// evaluates prequestion priming effects (ER-10, St. Hilaire et al. 2023/2024).
class LearningGainCalculator {
  const LearningGainCalculator._();

  /// Computes Hake's normalized learning gain / Marx & Cummings normalized change.
  ///
  /// Both [preScore] and [postScore] are expected as proportions between 0.0 and 1.0.
  /// Values are clamped to [0.0, 1.0] for safety.
  static LearningGainResult evaluate({
    required double preScore,
    required double postScore,
  }) {
    final pre = preScore.clamp(0.0, 1.0);
    final post = postScore.clamp(0.0, 1.0);

    final double gain;
    if (post > pre) {
      if (pre == 1.0) {
        gain = 0.0;
      } else {
        gain = (post - pre) / (1.0 - pre);
      }
    } else if (post == pre) {
      gain = 0.0;
    } else {
      // Regression / loss: normalized change relative to initial score
      if (pre > 0.0) {
        gain = (post - pre) / pre;
      } else {
        gain = post - pre;
      }
    }

    final category = categorize(gain);
    return LearningGainResult(
      preScore: pre,
      postScore: post,
      normalizedGain: double.parse(gain.toStringAsFixed(4)),
      category: category,
    );
  }

  /// Classifies normalized gain into Hake's standard educational brackets.
  static LearningGainCategory categorize(double gain) {
    if (gain >= 0.7) return LearningGainCategory.high;
    if (gain >= 0.3) return LearningGainCategory.medium;
    if (gain >= 0.0) return LearningGainCategory.low;
    return LearningGainCategory.loss;
  }

  /// Evaluates specific prequestion priming gain against general untested content.
  ///
  /// In accordance with St. Hilaire, Chan & Ahn (2023/2024) (ER-10), prequestions
  /// strongly elevate retention on targeted concepts (g ≈ .54) with near-zero
  /// spillover on untested material (g ≈ .04).
  static PrequestionPrimingComparison evaluatePrimingEffect({
    required double targetedPreScore,
    required double targetedPostScore,
    required double untargetedPreScore,
    required double untargetedPostScore,
  }) {
    final targeted = evaluate(preScore: targetedPreScore, postScore: targetedPostScore);
    final untargeted = evaluate(preScore: untargetedPreScore, postScore: untargetedPostScore);

    final advantage = double.parse(
        (targeted.normalizedGain - untargeted.normalizedGain).toStringAsFixed(4));

    // Specific priming is confirmed when targeted gain is substantially higher
    // than untargeted gain (advantage >= 0.20), reflecting targeted focus.
    final confirms = advantage >= 0.20 && targeted.normalizedGain >= 0.30;

    return PrequestionPrimingComparison(
      targetedGain: targeted,
      untargetedGain: untargeted,
      primingAdvantage: advantage,
      confirmsSpecificPriming: confirms,
    );
  }

  /// Aggregates and ranks creator channel modules by measured learning gain.
  static CreatorChannelGainMetric calculateChannelMetrics({
    required String channelId,
    required String channelName,
    required List<VideoInteractiveModule> modules,
  }) {
    final scored = modules
        .where((m) => m.measuredLearningGain != null)
        .map((m) => m.measuredLearningGain!)
        .toList();

    if (scored.isEmpty) {
      return CreatorChannelGainMetric(
        channelId: channelId,
        channelName: channelName,
        totalModules: modules.length,
        scoredModulesCount: 0,
        averageNormalizedGain: 0.0,
        aggregateCategory: LearningGainCategory.low,
      );
    }

    final sum = scored.reduce((a, b) => a + b);
    final avg = double.parse((sum / scored.length).toStringAsFixed(4));

    return CreatorChannelGainMetric(
      channelId: channelId,
      channelName: channelName,
      totalModules: modules.length,
      scoredModulesCount: scored.length,
      averageNormalizedGain: avg,
      aggregateCategory: categorize(avg),
    );
  }
}
