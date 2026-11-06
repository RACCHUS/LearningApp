import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/analytics/item_analytics.dart';

void main() {
  group('ItemAnalytics Model Tests', () {
    test('JSON serialization & deserialization round-trip', () {
      final now = DateTime.now();
      final original = ItemAnalytics(
        itemId: '11111111-2222-3333-4444-555555555555',
        itemType: 'question',
        responseCount: 42,
        correctCount: 28,
        pValue: 0.667,
        pointBiserial: 0.385,
        distractorRates: {'0': 0.667, '1': 0.190, '2': 0.143, '3': 0.0},
        distractorCounts: {'0': 28, '1': 8, '2': 6, '3': 0},
        medianLatencyMs: 4500,
        iqrLatencyMs: 2100,
        flaggedReasons: ['dead_distractor'],
        autoFlagged: true,
        moderationReportId: '99999999-8888-7777-6666-555555555555',
        lastCalculatedAt: now,
      );

      final json = original.toJson();
      final parsed = ItemAnalytics.fromJson(json);

      expect(parsed.itemId, original.itemId);
      expect(parsed.itemType, 'question');
      expect(parsed.responseCount, 42);
      expect(parsed.correctCount, 28);
      expect(parsed.pValue, 0.667);
      expect(parsed.pointBiserial, 0.385);
      expect(parsed.distractorRates['0'], 0.667);
      expect(parsed.distractorRates['3'], 0.0);
      expect(parsed.distractorCounts['0'], 28);
      expect(parsed.medianLatencyMs, 4500);
      expect(parsed.iqrLatencyMs, 2100);
      expect(parsed.flaggedReasons, contains('dead_distractor'));
      expect(parsed.autoFlagged, isTrue);
      expect(parsed.moderationReportId, '99999999-8888-7777-6666-555555555555');
    });

    test('Helper getters correctly classify difficulty and discrimination', () {
      final easyGood = ItemAnalytics(
        itemId: 'id1',
        responseCount: 50,
        correctCount: 45,
        pValue: 0.90,
        pointBiserial: 0.40,
        lastCalculatedAt: DateTime.now(),
      );
      expect(easyGood.facilityLabel, 'Easy');
      expect(easyGood.discriminationLabel, 'Excellent');
      expect(easyGood.hasNegativeDiscrimination, isFalse);
      expect(easyGood.isExtremelyDifficult, isFalse);

      final defective = ItemAnalytics(
        itemId: 'id2',
        responseCount: 30,
        correctCount: 3,
        pValue: 0.10,
        pointBiserial: -0.22,
        flaggedReasons: const ['negative_discrimination', 'extreme_difficulty'],
        autoFlagged: true,
        lastCalculatedAt: DateTime.now(),
      );
      expect(defective.facilityLabel, 'Very Hard');
      expect(defective.discriminationLabel, 'Defective');
      expect(defective.hasNegativeDiscrimination, isTrue);
      expect(defective.isExtremelyDifficult, isTrue);
    });
  });
}

