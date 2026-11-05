import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';

void main() {
  group('FSRS Spaced Repetition Behavior Tests (ARCH-1)', () {
    late DateTime baseTime;
    late ReviewableItem brandNewItem;

    setUp(() {
      baseTime = DateTime.utc(2026, 11, 2, 12, 0, 0);
      brandNewItem = ReviewableItem(
        id: 'fsrs-test-item-1',
        contentId: 'content-1',
        contentType: ReviewableContentType.term,
        title: 'Photosynthesis',
        subtitle: 'Process by which plants convert light to energy',
        repetitionLevel: 0,
        easeFactor: 2.5,
        nextReviewDate: baseTime,
        lastReviewedAt: null,
        totalReviews: 0,
        correctReviews: 0,
        stability: null,
        difficulty: null,
        fsrsState: 1, // Learning
        step: 0,
      );
    });

    group('Initial rating progression (Again, Hard, Good, Easy)', () {
      test('initial review sets stability and difficulty based on rating quality', () {
        final again = brandNewItem.processReview(RecallQuality.blackout, reviewDateTime: baseTime);
        final hard = brandNewItem.processReview(RecallQuality.difficult, reviewDateTime: baseTime);
        final good = brandNewItem.processReview(RecallQuality.good, reviewDateTime: baseTime);
        final easy = brandNewItem.processReview(RecallQuality.perfect, reviewDateTime: baseTime);

        // All should have initialized FSRS parameters
        expect(again.stability, isNotNull);
        expect(hard.stability, isNotNull);
        expect(good.stability, isNotNull);
        expect(easy.stability, isNotNull);

        // Stability must scale strictly: Again < Hard < Good < Easy
        expect(again.stability!, lessThan(hard.stability!));
        expect(hard.stability!, lessThan(good.stability!));
        expect(good.stability!, lessThan(easy.stability!));

        // Difficulty must scale inversely: Easy < Good < Hard <= Again
        expect(easy.difficulty!, lessThan(good.difficulty!));
        expect(good.difficulty!, lessThan(hard.difficulty!));
        expect(hard.difficulty!, lessThanOrEqualTo(again.difficulty!));
      });
    });

    group('State transitions (Learning -> Review -> Relearning)', () {
      test('graduates directly to Review state on Easy (perfect) rating', () {
        final easy = brandNewItem.processReview(RecallQuality.perfect, reviewDateTime: baseTime);

        expect(easy.fsrsState, equals(2)); // State.review = 2
        expect(easy.repetitionLevel, equals(1));
        expect(easy.totalReviews, equals(1));
        expect(easy.correctReviews, equals(1));
      });

      test('graduates to Review state after completing learning steps with Good ratings', () {
        // Step 1: First Good rating advances learning step
        final step1 = brandNewItem.processReview(RecallQuality.good, reviewDateTime: baseTime);
        expect(step1.step, greaterThanOrEqualTo(1));

        // Step 2: Next review after interval graduates card to Review
        final step2Time = baseTime.add(const Duration(minutes: 15));
        final step2 = step1.processReview(RecallQuality.good, reviewDateTime: step2Time);

        expect(step2.fsrsState, equals(2)); // State.review = 2
        expect(step2.repetitionLevel, equals(2));
      });

      test('lapses to Relearning state when a graduated Review item is failed (Again)', () {
        // Step 1: Graduate card to Review state using Easy
        final reviewCard = brandNewItem.processReview(RecallQuality.perfect, reviewDateTime: baseTime);
        expect(reviewCard.fsrsState, equals(2)); // State.review = 2

        // Step 2: Review after 4 days, fail with blackout (Again)
        final lapseTime = baseTime.add(const Duration(days: 4));
        final lapsed = reviewCard.processReview(RecallQuality.blackout, reviewDateTime: lapseTime);

        expect(lapsed.fsrsState, equals(3)); // State.relearning = 3
        expect(lapsed.repetitionLevel, equals(0)); // SM-2 resets to 0
        expect(lapsed.stability!, lessThan(reviewCard.stability!)); // Stability drops
        expect(lapsed.difficulty!, greaterThanOrEqualTo(reviewCard.difficulty!)); // Difficulty rises
      });

      test('re-graduates back to Review state after successful relearning review', () {
        final reviewCard = brandNewItem.processReview(RecallQuality.perfect, reviewDateTime: baseTime);
        final lapseTime = baseTime.add(const Duration(days: 4));
        final lapsed = reviewCard.processReview(RecallQuality.blackout, reviewDateTime: lapseTime);
        expect(lapsed.fsrsState, equals(3)); // Relearning

        final recoveryTime = lapseTime.add(const Duration(minutes: 10));
        final recovered = lapsed.processReview(RecallQuality.perfect, reviewDateTime: recoveryTime);

        expect(recovered.fsrsState, equals(2)); // Review
        expect(recovered.repetitionLevel, equals(1));
      });
    });

    group('Retrievability decay over time', () {
      test('retrievability is highest immediately after review and decays monotonically', () {
        final reviewed = brandNewItem.processReview(RecallQuality.good, reviewDateTime: baseTime);

        final r0 = reviewed.currentRetrievability(asOf: baseTime);
        final r1Day = reviewed.currentRetrievability(asOf: baseTime.add(const Duration(days: 1)));
        final r7Days = reviewed.currentRetrievability(asOf: baseTime.add(const Duration(days: 7)));
        final r30Days = reviewed.currentRetrievability(asOf: baseTime.add(const Duration(days: 30)));

        expect(r0, greaterThanOrEqualTo(0.99));
        expect(r0, greaterThan(r1Day));
        expect(r1Day, greaterThan(r7Days));
        expect(r7Days, greaterThan(r30Days));
        expect(r30Days, greaterThan(0.0));
      });

      test('higher stability items decay slower than lower stability items', () {
        final goodItem = brandNewItem.processReview(RecallQuality.good, reviewDateTime: baseTime);
        final easyItem = brandNewItem.processReview(RecallQuality.perfect, reviewDateTime: baseTime);

        final checkTime = baseTime.add(const Duration(days: 5));
        final rGood = goodItem.currentRetrievability(asOf: checkTime);
        final rEasy = easyItem.currentRetrievability(asOf: checkTime);

        // Easy item has higher stability, so its retrievability after 5 days should be higher
        expect(rEasy, greaterThan(rGood));
      });
    });

    group('Legacy SM-2 migration and compatibility seeding', () {
      test('correctly seeds FSRS from existing card with SM-2 history without crashing', () {
        final legacyCard = ReviewableItem(
          id: 'legacy-item-42',
          contentId: 'content-legacy',
          contentType: ReviewableContentType.term,
          title: 'Legacy Term',
          repetitionLevel: 4,
          easeFactor: 2.3,
          nextReviewDate: baseTime,
          lastReviewedAt: baseTime.subtract(const Duration(days: 6)),
          totalReviews: 4,
          correctReviews: 4,
          stability: null, // Legacy: uninitialized FSRS
          difficulty: null,
          fsrsState: 2, // Treated as Review
          step: 0,
        );

        final reviewed = legacyCard.processReview(RecallQuality.good, reviewDateTime: baseTime);

        expect(reviewed.stability, isNotNull);
        expect(reviewed.difficulty, isNotNull);
        expect(reviewed.stability!, greaterThan(0.0));
        expect(reviewed.repetitionLevel, equals(5));
        expect(reviewed.totalReviews, equals(5));
        expect(reviewed.correctReviews, equals(5));
      });
    });

    group('JSON serialization & server projection consistency', () {
      test('round-trips all FSRS fields through JSON serialization', () {
        final reviewed = brandNewItem.processReview(RecallQuality.good, reviewDateTime: baseTime);
        final json = reviewed.toJson();

        expect(json['stability'], equals(reviewed.stability));
        expect(json['difficulty'], equals(reviewed.difficulty));
        expect(json['fsrs_state'], equals(reviewed.fsrsState));
        expect(json['step'], equals(reviewed.step));
        expect(json['retrievability'], equals(reviewed.retrievability));

        final reconstructed = ReviewableItem.fromJson(json);
        expect(reconstructed.stability, equals(reviewed.stability));
        expect(reconstructed.difficulty, equals(reviewed.difficulty));
        expect(reconstructed.fsrsState, equals(reviewed.fsrsState));
        expect(reconstructed.step, equals(reviewed.step));
        expect(reconstructed.retrievability, equals(reviewed.retrievability));
      });
    });
  });
}
