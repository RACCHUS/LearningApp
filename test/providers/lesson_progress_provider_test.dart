import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';

void main() {
  group('computeMastery', () {
    test('returns null when there are no items', () {
      expect(computeMastery(const []), isNull);
    });

    test('all items at max level is full mastery', () {
      expect(computeMastery([kMaxMasteryLevel, kMaxMasteryLevel]), 1.0);
    });

    test('all items at level 0 is zero mastery', () {
      expect(computeMastery(const [0, 0, 0]), 0.0);
    });

    test('averages normalized levels', () {
      // Levels 0 and 6 -> (0 + 1) / 2 = 0.5
      expect(computeMastery([0, kMaxMasteryLevel]), 0.5);
    });

    test('clamps levels above the max', () {
      expect(computeMastery([kMaxMasteryLevel + 5]), 1.0);
    });
  });
}
