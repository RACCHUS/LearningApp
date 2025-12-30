import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/recommendation_service.dart';

void main() {
  group('RecommendationType', () {
    test('should have correct display titles', () {
      expect(RecommendationType.popularInTag.displayTitle, 'Popular in');
      expect(
        RecommendationType.becauseYouStudied.displayTitle,
        'Because you studied',
      );
      expect(
        RecommendationType.continueProgress.displayTitle,
        'Continue where you left off',
      );
      expect(RecommendationType.newContent.displayTitle, 'New for you');
      expect(RecommendationType.trending.displayTitle, 'Trending now');
    });
  });

  group('Recommendation', () {
    test('should create recommendation with all fields', () {
      final recommendation = Recommendation(
        id: 'rec-1',
        title: 'Test Lesson',
        description: 'A test lesson description',
        type: RecommendationType.popularInTag,
        context: 'Grammar',
        targetId: 'lesson-1',
        targetType: 'lesson',
        score: 0.85,
        studyCount: 150,
      );

      expect(recommendation.id, 'rec-1');
      expect(recommendation.title, 'Test Lesson');
      expect(recommendation.description, 'A test lesson description');
      expect(recommendation.type, RecommendationType.popularInTag);
      expect(recommendation.context, 'Grammar');
      expect(recommendation.targetId, 'lesson-1');
      expect(recommendation.targetType, 'lesson');
      expect(recommendation.score, 0.85);
      expect(recommendation.studyCount, 150);
    });

    test('should handle null optional fields', () {
      final recommendation = Recommendation(
        id: 'rec-2',
        title: 'Minimal Lesson',
        type: RecommendationType.newContent,
        targetId: 'lesson-2',
        targetType: 'lesson',
        score: 0.5,
      );

      expect(recommendation.description, isNull);
      expect(recommendation.context, isNull);
      expect(recommendation.studyCount, isNull);
    });

    test('should create from lesson JSON', () {
      final json = {
        'id': 'lesson-123',
        'title': 'French Basics',
        'description': 'Learn French fundamentals',
        'study_count': 500,
      };

      final recommendation = Recommendation.fromLessonJson(
        json,
        type: RecommendationType.trending,
        context: 'Languages',
        score: 0.9,
      );

      expect(recommendation.id, 'lesson-123');
      expect(recommendation.title, 'French Basics');
      expect(recommendation.description, 'Learn French fundamentals');
      expect(recommendation.type, RecommendationType.trending);
      expect(recommendation.context, 'Languages');
      expect(recommendation.targetId, 'lesson-123');
      expect(recommendation.targetType, 'lesson');
      expect(recommendation.score, 0.9);
      expect(recommendation.studyCount, 500);
    });
  });

  group('RecommendationGroup', () {
    test('should create group with recommendations', () {
      final items = [
        Recommendation(
          id: 'r1',
          title: 'Lesson 1',
          type: RecommendationType.popularInTag,
          targetId: 'l1',
          targetType: 'lesson',
          score: 0.9,
        ),
        Recommendation(
          id: 'r2',
          title: 'Lesson 2',
          type: RecommendationType.popularInTag,
          targetId: 'l2',
          targetType: 'lesson',
          score: 0.8,
        ),
      ];

      final group = RecommendationGroup(
        type: RecommendationType.popularInTag,
        title: 'Popular in Grammar',
        context: 'Grammar',
        items: items,
      );

      expect(group.type, RecommendationType.popularInTag);
      expect(group.title, 'Popular in Grammar');
      expect(group.context, 'Grammar');
      expect(group.items.length, 2);
    });

    test('should handle empty items list', () {
      final group = RecommendationGroup(
        type: RecommendationType.newContent,
        title: 'New Content',
        items: [],
      );

      expect(group.items.isEmpty, isTrue);
    });
  });

  group('Recommendation Scoring', () {
    test('should sort recommendations by score descending', () {
      final recommendations = [
        Recommendation(
          id: 'low',
          title: 'Low Score',
          type: RecommendationType.newContent,
          targetId: 'low',
          targetType: 'lesson',
          score: 0.3,
        ),
        Recommendation(
          id: 'high',
          title: 'High Score',
          type: RecommendationType.popularInTag,
          targetId: 'high',
          targetType: 'lesson',
          score: 0.9,
        ),
        Recommendation(
          id: 'medium',
          title: 'Medium Score',
          type: RecommendationType.trending,
          targetId: 'medium',
          targetType: 'lesson',
          score: 0.6,
        ),
      ];

      final sorted = List<Recommendation>.from(recommendations)
        ..sort((a, b) => b.score.compareTo(a.score));

      expect(sorted[0].id, 'high');
      expect(sorted[1].id, 'medium');
      expect(sorted[2].id, 'low');
    });

    test('should handle equal scores', () {
      final recommendations = [
        Recommendation(
          id: 'first',
          title: 'First',
          type: RecommendationType.newContent,
          targetId: 'first',
          targetType: 'lesson',
          score: 0.5,
        ),
        Recommendation(
          id: 'second',
          title: 'Second',
          type: RecommendationType.newContent,
          targetId: 'second',
          targetType: 'lesson',
          score: 0.5,
        ),
      ];

      final sorted = List<Recommendation>.from(recommendations)
        ..sort((a, b) => b.score.compareTo(a.score));

      // Both should be present
      expect(sorted.length, 2);
    });
  });

  group('Recommendation Type Parsing', () {
    test('should parse all recommendation types from string', () {
      final types = {
        'popularInTag': RecommendationType.popularInTag,
        'becauseYouStudied': RecommendationType.becauseYouStudied,
        'continueProgress': RecommendationType.continueProgress,
        'newContent': RecommendationType.newContent,
        'trending': RecommendationType.trending,
      };

      for (final entry in types.entries) {
        final parsed = RecommendationType.values.firstWhere(
          (t) => t.name == entry.key,
        );
        expect(parsed, entry.value);
      }
    });
  });
}
