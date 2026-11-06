import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/analytics/item_analytics_calculator.dart';

void main() {
  group('ItemAnalyticsCalculator Psychometrics Tests', () {
    test('computePValue calculates correct fraction', () {
      expect(ItemAnalyticsCalculator.computePValue([]), 0.0);
      expect(ItemAnalyticsCalculator.computePValue([1.0, 1.0, 1.0]), 1.0);
      expect(ItemAnalyticsCalculator.computePValue([1.0, 0.0, 1.0, 0.0]), 0.5);
      expect(ItemAnalyticsCalculator.computePValue([1.0, 1.0, 1.0, 0.0]), 0.75);
    });

    test('computePointBiserial returns positive correlation for discriminating item', () {
      // Learners with high total scores get the item right; learners with low total scores miss it
      final itemScores = [1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0];
      final totalScores = [0.90, 0.85, 0.80, 0.75, 0.40, 0.35, 0.30, 0.25];

      final r = ItemAnalyticsCalculator.computePointBiserial(
        itemScores: itemScores,
        learnerTotalScores: totalScores,
      );

      expect(r, greaterThan(0.70));
    });

    test('computePointBiserial returns negative correlation for miskeyed defective item', () {
      // Learners with high total scores miss the item; learners with low total scores guess/get it right
      final itemScores = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0];
      final totalScores = [0.90, 0.85, 0.80, 0.75, 0.40, 0.35, 0.30, 0.25];

      final r = ItemAnalyticsCalculator.computePointBiserial(
        itemScores: itemScores,
        learnerTotalScores: totalScores,
      );

      expect(r, lessThan(-0.70));
    });

    test('computeDistractorStats aggregates counts and rates', () {
      final choices = ['A', 'A', 'A', 'B', 'C', null];
      final stats = ItemAnalyticsCalculator.computeDistractorStats(choices);

      expect(stats.counts['A'], 3);
      expect(stats.counts['B'], 1);
      expect(stats.counts['C'], 1);
      expect(stats.counts['unanswered'], 1);

      expect(stats.rates['A'], closeTo(0.50, 0.01));
      expect(stats.rates['B'], closeTo(0.1667, 0.01));
    });

    test('computeLatencyStats computes median and IQR', () {
      final latencies = [1000, 2000, 3000, 4000, 5000, 6000, 7000];
      final stats = ItemAnalyticsCalculator.computeLatencyStats(latencies);

      expect(stats.median, 4000);
      expect(stats.iqr, isNotNull);
    });

    test('evaluateFlags triggers negative discrimination and dead distractor', () {
      final flags = ItemAnalyticsCalculator.evaluateFlags(
        responseCount: 25,
        pValue: 0.12,
        pointBiserial: -0.15,
        distractorRates: {'0': 0.12, '1': 0.87, '2': 0.01, '3': 0.0},
        medianLatencyMs: 2500,
      );

      expect(flags, contains('negative_discrimination'));
      expect(flags, contains('extreme_difficulty'));
      expect(flags, contains('dead_distractor'));
      expect(flags, contains('suspicious_low_latency'));
    });
  });
}

