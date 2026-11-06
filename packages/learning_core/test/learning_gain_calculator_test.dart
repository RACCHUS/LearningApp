import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('LearningGainCalculator', () {
    test('computes Hake normalized gain accurately when postScore exceeds preScore', () {
      // Pre: 40%, Post: 80% -> Gain = (0.8 - 0.4) / (1.0 - 0.4) = 0.4 / 0.6 = 0.6667
      final result = LearningGainCalculator.evaluate(preScore: 0.40, postScore: 0.80);

      expect(result.preScore, equals(0.40));
      expect(result.postScore, equals(0.80));
      expect(result.normalizedGain, equals(0.6667));
      expect(result.category, equals(LearningGainCategory.medium));
    });

    test('categorizes high gain when g >= 0.70', () {
      // Pre: 20%, Post: 85% -> Gain = (0.85 - 0.20) / (1.0 - 0.20) = 0.65 / 0.80 = 0.8125
      final result = LearningGainCalculator.evaluate(preScore: 0.20, postScore: 0.85);

      expect(result.normalizedGain, equals(0.8125));
      expect(result.category, equals(LearningGainCategory.high));
    });

    test('handles zero change and ceiling edge cases safely', () {
      final noChange = LearningGainCalculator.evaluate(preScore: 0.50, postScore: 0.50);
      expect(noChange.normalizedGain, equals(0.0));
      expect(noChange.category, equals(LearningGainCategory.low));

      final perfectCeiling = LearningGainCalculator.evaluate(preScore: 1.0, postScore: 1.0);
      expect(perfectCeiling.normalizedGain, equals(0.0));

      final zeroZero = LearningGainCalculator.evaluate(preScore: 0.0, postScore: 0.0);
      expect(zeroZero.normalizedGain, equals(0.0));
    });

    test('computes negative normalized change on performance regression', () {
      // Pre: 60%, Post: 30% -> Drop = (0.3 - 0.6) / 0.6 = -0.5
      final drop = LearningGainCalculator.evaluate(preScore: 0.60, postScore: 0.30);

      expect(drop.normalizedGain, equals(-0.5));
      expect(drop.category, equals(LearningGainCategory.loss));
    });

    test('evaluates ER-10 prequestion priming effect vs general spillover', () {
      // St. Hilaire et al. (2024) effect size benchmark:
      // Targeted concept pre: 25% (random guessing), post: 65.5% (g = (0.655 - 0.25) / 0.75 = 0.54)
      // Untargeted concept pre: 25%, post: 28% (g = (0.28 - 0.25) / 0.75 = 0.04)
      final comparison = LearningGainCalculator.evaluatePrimingEffect(
        targetedPreScore: 0.25,
        targetedPostScore: 0.655,
        untargetedPreScore: 0.25,
        untargetedPostScore: 0.28,
      );

      expect(comparison.targetedGain.normalizedGain, closeTo(0.54, 0.01));
      expect(comparison.untargetedGain.normalizedGain, closeTo(0.04, 0.01));
      expect(comparison.primingAdvantage, closeTo(0.50, 0.01));
      expect(comparison.confirmsSpecificPriming, isTrue);
    });

    test('rejects specific priming when untargeted gain equals targeted gain', () {
      // Both targeted and untargeted improve equally
      final comparison = LearningGainCalculator.evaluatePrimingEffect(
        targetedPreScore: 0.20,
        targetedPostScore: 0.60,
        untargetedPreScore: 0.20,
        untargetedPostScore: 0.60,
      );

      expect(comparison.primingAdvantage, equals(0.0));
      expect(comparison.confirmsSpecificPriming, isFalse);
    });

    test('calculates creator channel aggregate metrics accurately', () {
      final moduleA = VideoInteractiveModule(
        id: 'mod-a',
        title: 'Module A',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://youtube.com/watch?v=a1',
        durationSeconds: 300,
        measuredLearningGain: 0.75,
      );
      final moduleB = VideoInteractiveModule(
        id: 'mod-b',
        title: 'Module B',
        sourceType: VideoSourceType.youtube,
        rawVideoUrl: 'https://youtube.com/watch?v=b1',
        durationSeconds: 400,
        measuredLearningGain: 0.65,
      );
      final moduleUnscored = VideoInteractiveModule(
        id: 'mod-c',
        title: 'Module C',
        sourceType: VideoSourceType.vimeo,
        rawVideoUrl: 'https://vimeo.com/c1',
        durationSeconds: 500,
      );

      final channelMetric = LearningGainCalculator.calculateChannelMetrics(
        channelId: 'channel-math',
        channelName: 'Mathematics Academy',
        modules: [moduleA, moduleB, moduleUnscored],
      );

      expect(channelMetric.channelId, equals('channel-math'));
      expect(channelMetric.totalModules, equals(3));
      expect(channelMetric.scoredModulesCount, equals(2));
      expect(channelMetric.averageNormalizedGain, equals(0.70));
      expect(channelMetric.aggregateCategory, equals(LearningGainCategory.high));
    });

    test('handles channel with zero scored modules gracefully', () {
      final channelMetric = LearningGainCalculator.calculateChannelMetrics(
        channelId: 'empty-channel',
        channelName: 'New Creator',
        modules: [],
      );

      expect(channelMetric.totalModules, equals(0));
      expect(channelMetric.scoredModulesCount, equals(0));
      expect(channelMetric.averageNormalizedGain, equals(0.0));
      expect(channelMetric.aggregateCategory, equals(LearningGainCategory.low));
    });
  });
}
