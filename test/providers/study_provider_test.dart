import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/study_provider.dart';

void main() {
  group('StudyProvider Tests', () {
    group('StudyState', () {
      test('initial state should have correct default values', () {
        final state = StudyState.initial();

        expect(state.isLoading, false);
        expect(state.error, null);
        expect(state.cardsStudied, 0);
        expect(state.correctAnswers, 0);
        expect(state.incorrectAnswers, 0);
        expect(state.termStatus, isEmpty);
        expect(state.questionAnswers, isEmpty);
        expect(state.completedLessons, isEmpty);
        expect(state.currentLessonId, null);
        expect(state.currentMode, null);
        expect(state.currentIndex, 0);
        expect(state.currentContent, null);
      });

      test('lastStudied should be set to current date', () {
        final state = StudyState.initial();
        
        expect(state.lastStudied, isNotNull);
        expect(state.lastStudied!.difference(DateTime.now()).inMinutes, lessThan(1));
      });

      test('should calculate accuracy correctly when no answers', () {
        final state = StudyState();
        
        expect(state.accuracy, 0.0);
        expect(state.totalQuestions, 0);
      });

      test('should calculate accuracy correctly with mixed answers', () {
        final state = StudyState(
          correctAnswers: 3,
          incorrectAnswers: 1,
        );
        
        expect(state.accuracy, 0.75);
        expect(state.totalQuestions, 4);
      });

      test('should calculate accuracy with only correct answers', () {
        final state = StudyState(
          correctAnswers: 5,
          incorrectAnswers: 0,
        );
        
        expect(state.accuracy, 1.0);
        expect(state.totalQuestions, 5);
      });

      test('should calculate accuracy with only incorrect answers', () {
        final state = StudyState(
          correctAnswers: 0,
          incorrectAnswers: 5,
        );
        
        expect(state.accuracy, 0.0);
        expect(state.totalQuestions, 5);
      });
    });

    group('StudyState copyWith', () {
      test('should copy state with updated values', () {
        final original = StudyState(
          cardsStudied: 5,
          correctAnswers: 3,
        );

        final updated = original.copyWith(
          cardsStudied: 10,
          incorrectAnswers: 2,
        );

        expect(updated.cardsStudied, 10);
        expect(updated.correctAnswers, 3); // Unchanged
        expect(updated.incorrectAnswers, 2);
      });

      test('should copy state with new content', () {
        final original = StudyState();
        final content = ['item1', 'item2'];

        final updated = original.copyWith(
          currentContent: content,
          currentIndex: 1,
        );

        expect(updated.currentContent, content);
        expect(updated.currentIndex, 1);
      });
    });

    group('StudyState helper methods', () {
      test('isTermKnown should return correct status for known term', () {
        final state = StudyState(
          termStatus: {'term1': true, 'term2': false},
        );

        expect(state.isTermKnown('term1'), true);
        expect(state.isTermKnown('term2'), false);
      });

      test('isTermKnown should return false for unknown term', () {
        final state = StudyState();
        
        expect(state.isTermKnown('unknown'), false);
      });
    });

    group('StudyMode Enum', () {
      test('should have all expected study modes', () {
        expect(StudyMode.values.length, 4);
        expect(StudyMode.values, contains(StudyMode.flashcard));
        expect(StudyMode.values, contains(StudyMode.mcq));
        expect(StudyMode.values, contains(StudyMode.concept));
        expect(StudyMode.values, contains(StudyMode.lesson));
      });
    });

    // Note: Testing StudyNotifier business logic requires dependency injection
    // refactoring to decouple from LessonService/Supabase initialization.
    // The StudyState class tests above provide comprehensive coverage of
    // the core state management logic.
  });
}
