import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('FsrsSchedulerCore', () {
    late FsrsSchedulerCore scheduler;

    setUp(() {
      scheduler = FsrsSchedulerCore(desiredRetention: 0.9);
    });

    test('first review with Good rating computes valid initial stability and interval', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0, 0);
      final result = scheduler.scheduleReview(
        rating: MemoryRatingCore.good,
        reviewTimestamp: now,
      );

      expect(result.stability, isPositive);
      expect(result.difficulty, inInclusiveRange(1.0, 10.0));
      expect(result.intervalDays, greaterThanOrEqualTo(0));
      expect(result.nextReviewDate.isAfter(now) || result.nextReviewDate.isAtSameMomentAs(now), isTrue);
    });

    test('rating Again reduces stability and resets interval to immediate review', () {
      final now = DateTime.utc(2026, 11, 6, 12, 0, 0);
      final result = scheduler.scheduleReview(
        rating: MemoryRatingCore.again,
        reviewTimestamp: now,
      );

      expect(result.intervalDays, equals(0));
      expect(result.difficulty, greaterThanOrEqualTo(5.0));
    });

    test('consecutive successful reviews increase stability and lengthen intervals', () {
      final t1 = DateTime.utc(2026, 11, 1, 12, 0, 0);
      final r1 = scheduler.scheduleReview(
        rating: MemoryRatingCore.good,
        reviewTimestamp: t1,
      );

      final t2 = t1.add(Duration(days: r1.intervalDays));
      final r2 = scheduler.scheduleReview(
        currentStability: r1.stability,
        currentDifficulty: r1.difficulty,
        lastReviewDate: t1,
        rating: MemoryRatingCore.easy,
        reviewTimestamp: t2,
      );

      expect(r2.stability, greaterThan(r1.stability));
      expect(r2.intervalDays, greaterThan(r1.intervalDays));
    });
  });
}
