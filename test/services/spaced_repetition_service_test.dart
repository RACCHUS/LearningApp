import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/spaced_repetition.dart';

void main() {
  group('SpacedRepetitionIntervals', () {
    test('should return correct intervals for each level', () {
      expect(SpacedRepetitionIntervals.getInterval(0), 1);
      expect(SpacedRepetitionIntervals.getInterval(1), 3);
      expect(SpacedRepetitionIntervals.getInterval(2), 7);
      expect(SpacedRepetitionIntervals.getInterval(3), 14);
      expect(SpacedRepetitionIntervals.getInterval(4), 30);
      expect(SpacedRepetitionIntervals.getInterval(5), 60);
      expect(SpacedRepetitionIntervals.getInterval(6), 120);
    });

    test('should clamp negative levels to first interval', () {
      expect(SpacedRepetitionIntervals.getInterval(-1), 1);
      expect(SpacedRepetitionIntervals.getInterval(-10), 1);
    });

    test('should clamp high levels to last interval', () {
      expect(SpacedRepetitionIntervals.getInterval(7), 120);
      expect(SpacedRepetitionIntervals.getInterval(100), 120);
    });

    test('should calculate next review date correctly', () {
      final now = DateTime.now();
      final nextReview = SpacedRepetitionIntervals.getNextReviewDate(2);
      
      // Level 2 = 7 days
      expect(
        nextReview.difference(now).inDays,
        greaterThanOrEqualTo(6), // Allow for timing variations
      );
      expect(
        nextReview.difference(now).inDays,
        lessThanOrEqualTo(7),
      );
    });
  });

  group('RecallQuality', () {
    test('should have correct values for each quality level', () {
      expect(RecallQuality.blackout.value, 0);
      expect(RecallQuality.incorrect.value, 1);
      expect(RecallQuality.difficult.value, 2);
      expect(RecallQuality.hesitant.value, 3);
      expect(RecallQuality.good.value, 4);
      expect(RecallQuality.perfect.value, 5);
    });
  });

  group('ReviewableContentType', () {
    test('should have correct display names', () {
      expect(ReviewableContentType.term.displayName, 'Flashcard');
      expect(ReviewableContentType.question.displayName, 'Question');
      expect(ReviewableContentType.concept.displayName, 'Concept');
      expect(ReviewableContentType.multipleChoice.displayName, 'Multiple Choice');
      expect(ReviewableContentType.trueFalse.displayName, 'True/False');
      expect(ReviewableContentType.fillInBlank.displayName, 'Fill in Blank');
      expect(ReviewableContentType.matching.displayName, 'Matching');
    });

    test('should identify types that have options', () {
      expect(ReviewableContentType.multipleChoice.hasOptions, isTrue);
      expect(ReviewableContentType.trueFalse.hasOptions, isTrue);
      expect(ReviewableContentType.matching.hasOptions, isTrue);
      expect(ReviewableContentType.term.hasOptions, isFalse);
      expect(ReviewableContentType.fillInBlank.hasOptions, isFalse);
    });

    test('should identify types that require text input', () {
      expect(ReviewableContentType.fillInBlank.requiresTextInput, isTrue);
      expect(ReviewableContentType.term.requiresTextInput, isFalse);
      expect(ReviewableContentType.multipleChoice.requiresTextInput, isFalse);
    });
  });

  group('ReviewableItem', () {
    late ReviewableItem item;

    setUp(() {
      item = ReviewableItem(
        id: 'test-id',
        contentId: 'content-1',
        contentType: ReviewableContentType.term,
        lessonId: 'lesson-1',
        title: 'Test Term',
        subtitle: 'Test Definition',
        nextReviewDate: DateTime.now().add(const Duration(days: 1)),
      );
    });

    test('should have correct initial values', () {
      expect(item.repetitionLevel, 0);
      expect(item.easeFactor, 2.5);
      expect(item.totalReviews, 0);
      expect(item.correctReviews, 0);
    });

    test('should identify items due for review', () {
      final dueItem = ReviewableItem(
        id: 'due-id',
        contentId: 'content-2',
        contentType: ReviewableContentType.term,
        lessonId: 'lesson-1',
        title: 'Due Term',
        nextReviewDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      
      expect(dueItem.isDue, isTrue);
      expect(item.isDue, isFalse);
    });

    test('should calculate days until review', () {
      final futureItem = ReviewableItem(
        id: 'future-id',
        contentId: 'content-3',
        contentType: ReviewableContentType.term,
        lessonId: 'lesson-1',
        title: 'Future Term',
        nextReviewDate: DateTime.now().add(const Duration(days: 5)),
      );
      
      expect(futureItem.daysUntilReview, greaterThanOrEqualTo(4));
      expect(futureItem.daysUntilReview, lessThanOrEqualTo(5));
    });

    test('should calculate accuracy correctly', () {
      final reviewedItem = ReviewableItem(
        id: 'reviewed-id',
        contentId: 'content-4',
        contentType: ReviewableContentType.term,
        lessonId: 'lesson-1',
        title: 'Reviewed Term',
        nextReviewDate: DateTime.now(),
        totalReviews: 10,
        correctReviews: 7,
      );
      
      expect(reviewedItem.accuracy, 0.7);
    });

    test('should return 0 accuracy when no reviews', () {
      expect(item.accuracy, 0.0);
    });

    group('processReview', () {
      test('should increase level on correct answer', () {
        final updated = item.processReview(RecallQuality.good);
        
        expect(updated.repetitionLevel, 1);
        expect(updated.totalReviews, 1);
        expect(updated.correctReviews, 1);
      });

      test('should reset level on incorrect answer', () {
        final leveledItem = item.copyWith(repetitionLevel: 3);
        final updated = leveledItem.processReview(RecallQuality.blackout);
        
        expect(updated.repetitionLevel, 0);
        expect(updated.totalReviews, 1);
        expect(updated.correctReviews, 0);
      });

      test('should increase ease factor on perfect recall', () {
        // Start with lower ease factor so it can increase
        final lowEaseItem = item.copyWith(easeFactor: 2.0);
        final updated = lowEaseItem.processReview(RecallQuality.perfect);
        
        expect(updated.easeFactor, greaterThan(lowEaseItem.easeFactor));
      });

      test('should clamp ease factor at max 2.5', () {
        // Start at max - should stay at max
        final updated = item.processReview(RecallQuality.perfect);
        
        expect(updated.easeFactor, 2.5);
      });

      test('should decrease ease factor on difficult recall', () {
        final updated = item.processReview(RecallQuality.difficult);
        
        expect(updated.easeFactor, lessThan(item.easeFactor));
      });

      test('should not let ease factor go below 1.3', () {
        var testItem = item;
        
        // Process many difficult reviews
        for (int i = 0; i < 20; i++) {
          testItem = testItem.processReview(RecallQuality.blackout);
        }
        
        expect(testItem.easeFactor, greaterThanOrEqualTo(1.3));
      });

      test('should update lastReviewedAt', () {
        expect(item.lastReviewedAt, isNull);
        
        final updated = item.processReview(RecallQuality.good);
        
        expect(updated.lastReviewedAt, isNotNull);
      });

      test('should set next review date in the future', () {
        final now = DateTime.now();
        final updated = item.processReview(RecallQuality.good);
        
        expect(updated.nextReviewDate.isAfter(now), isTrue);
      });
    });

    test('should serialize to JSON correctly', () {
      final json = item.toJson();
      
      expect(json['id'], 'test-id');
      expect(json['content_id'], 'content-1');
      expect(json['content_type'], 'term');
      expect(json['lesson_id'], 'lesson-1');
      expect(json['title'], 'Test Term');
      expect(json['subtitle'], 'Test Definition');
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'id': 'json-id',
        'content_id': 'json-content',
        'content_type': 'question',
        'lesson_id': 'json-lesson',
        'title': 'JSON Title',
        'subtitle': 'JSON Subtitle',
        'repetition_level': 2,
        'ease_factor': 2.3,
        'next_review_date': DateTime.now().toIso8601String(),
        'total_reviews': 5,
        'correct_reviews': 4,
      };
      
      final parsed = ReviewableItem.fromJson(json);
      
      expect(parsed.id, 'json-id');
      expect(parsed.contentId, 'json-content');
      expect(parsed.contentType, ReviewableContentType.question);
      expect(parsed.repetitionLevel, 2);
      expect(parsed.easeFactor, 2.3);
      expect(parsed.totalReviews, 5);
      expect(parsed.correctReviews, 4);
    });
  });

  group('ReviewSummary', () {
    test('should create empty summary', () {
      final summary = ReviewSummary.empty();
      
      expect(summary.dueToday, 0);
      expect(summary.dueThisWeek, 0);
      expect(summary.totalItems, 0);
      expect(summary.masteredItems, 0);
      expect(summary.averageAccuracy, 0.0);
      expect(summary.overdueCount, 0);
    });

    test('should calculate summary from items', () {
      final now = DateTime.now();
      final items = [
        ReviewableItem(
          id: '1',
          contentId: 'c1',
          contentType: ReviewableContentType.term,
          lessonId: 'l1',
          title: 'Due today',
          nextReviewDate: now,
          totalReviews: 10,
          correctReviews: 8,
        ),
        ReviewableItem(
          id: '2',
          contentId: 'c2',
          contentType: ReviewableContentType.term,
          lessonId: 'l1',
          title: 'Overdue',
          nextReviewDate: now.subtract(const Duration(days: 2)),
          totalReviews: 5,
          correctReviews: 5,
        ),
        ReviewableItem(
          id: '3',
          contentId: 'c3',
          contentType: ReviewableContentType.term,
          lessonId: 'l1',
          title: 'Due in 3 days',
          nextReviewDate: now.add(const Duration(days: 3)),
        ),
        ReviewableItem(
          id: '4',
          contentId: 'c4',
          contentType: ReviewableContentType.term,
          lessonId: 'l1',
          title: 'Mastered',
          nextReviewDate: now.add(const Duration(days: 30)),
          repetitionLevel: 6, // Max level
        ),
      ];
      
      final summary = ReviewSummary.fromItems(items);
      
      expect(summary.totalItems, 4);
      expect(summary.dueToday, 2); // Today + overdue
      expect(summary.overdueCount, 1);
      expect(summary.masteredItems, 1);
    });
  });
}
