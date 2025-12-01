import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/study_provider.dart';

void main() {
  group('StudyProvider State Tests', () {
    test('initial state should be empty', () {
      final state = StudyState.initial();
      
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.currentLessonId, isNull);
      expect(state.currentMode, isNull);
      expect(state.currentContent, isNull);
      expect(state.currentIndex, 0);
      expect(state.correctAnswers, 0);
      expect(state.incorrectAnswers, 0);
      expect(state.cardsStudied, 0);
      expect(state.lastStudied, isNotNull);
      expect(state.completedLessons, isEmpty);
    });

    test('copyWith should update specified fields', () {
      final state = StudyState.initial();
      
      final updatedState = state.copyWith(
        isLoading: true,
        currentLessonId: 'lesson1',
        currentMode: StudyMode.flashcard,
      );
      
      expect(updatedState.isLoading, isTrue);
      expect(updatedState.currentLessonId, 'lesson1');
      expect(updatedState.currentMode, StudyMode.flashcard);
      expect(updatedState.error, isNull); // Unchanged
      expect(updatedState.currentIndex, 0); // Unchanged
    });

    test('copyWith should handle all fields', () {
      final state = StudyState.initial();
      
      final content = [1, 2, 3];
      final termStatus = {'term1': true, 'term2': false};
      final questionAnswers = {'q1': 0, 'q2': 1};
      final completedLessons = {'lesson1': DateTime.now()};
      
      final updatedState = state.copyWith(
        isLoading: true,
        error: 'Test error',
        currentLessonId: 'lesson123',
        currentMode: StudyMode.mcq,
        currentContent: content,
        currentIndex: 5,
        correctAnswers: 10,
        incorrectAnswers: 2,
        cardsStudied: 12,
        termStatus: termStatus,
        questionAnswers: questionAnswers,
        completedLessons: completedLessons,
      );
      
      expect(updatedState.isLoading, isTrue);
      expect(updatedState.error, 'Test error');
      expect(updatedState.currentLessonId, 'lesson123');
      expect(updatedState.currentMode, StudyMode.mcq);
      expect(updatedState.currentContent, content);
      expect(updatedState.currentIndex, 5);
      expect(updatedState.correctAnswers, 10);
      expect(updatedState.incorrectAnswers, 2);
      expect(updatedState.cardsStudied, 12);
      expect(updatedState.termStatus, termStatus);
      expect(updatedState.questionAnswers, questionAnswers);
      expect(updatedState.completedLessons, completedLessons);
    });

    test('accuracy should calculate correctly', () {
      final state = StudyState(
        isLoading: false,
        error: null,
        currentLessonId: null,
        currentMode: null,
        currentContent: [],
        currentIndex: 0,
        correctAnswers: 8,
        incorrectAnswers: 2,
        cardsStudied: 10,
        termStatus: {},
        questionAnswers: {},
      );
      
      expect(state.accuracy, 0.8);
    });

    test('accuracy should be 0 when no cards studied', () {
      final state = StudyState.initial();
      expect(state.accuracy, 0.0);
    });

    test('accuracy should be 1.0 when all correct', () {
      final state = StudyState(
        isLoading: false,
        error: null,
        currentLessonId: null,
        currentMode: null,
        currentContent: [],
        currentIndex: 0,
        correctAnswers: 10,
        incorrectAnswers: 0,
        cardsStudied: 10,
        termStatus: {},
        questionAnswers: {},
      );
      
      expect(state.accuracy, 1.0);
    });

    test('accuracy should be 0.0 when all incorrect', () {
      final state = StudyState(
        isLoading: false,
        error: null,
        currentLessonId: null,
        currentMode: null,
        currentContent: [],
        currentIndex: 0,
        correctAnswers: 0,
        incorrectAnswers: 10,
        cardsStudied: 10,
        termStatus: {},
        questionAnswers: {},
      );
      
      expect(state.accuracy, 0.0);
    });
  });

  group('StudyMode Tests', () {
    test('should have all study modes', () {
      expect(StudyMode.values.length, 4);
      expect(StudyMode.values, contains(StudyMode.flashcard));
      expect(StudyMode.values, contains(StudyMode.mcq));
      expect(StudyMode.values, contains(StudyMode.concept));
      expect(StudyMode.values, contains(StudyMode.lesson));
    });

    test('study modes should have correct names', () {
      expect(StudyMode.flashcard.name, 'flashcard');
      expect(StudyMode.mcq.name, 'mcq');
      expect(StudyMode.concept.name, 'concept');
      expect(StudyMode.lesson.name, 'lesson');
    });
  });

  group('StudyState Edge Cases', () {
    test('should handle very large numbers', () {
      final state = StudyState(
        isLoading: false,
        error: null,
        currentLessonId: null,
        currentMode: null,
        currentContent: [],
        currentIndex: 0,
        correctAnswers: 1000000,
        incorrectAnswers: 1,
        cardsStudied: 1000001,
        termStatus: {},
        questionAnswers: {},
      );
      
      expect(state.accuracy, closeTo(0.999999, 0.000001));
    });

    test('should handle empty term status', () {
      final state = StudyState.initial();
      expect(state.termStatus, isEmpty);
    });

    test('should handle empty question answers', () {
      final state = StudyState.initial();
      expect(state.questionAnswers, isEmpty);
    });

    test('should preserve content list order', () {
      final content = ['a', 'b', 'c', 'd'];
      final state = StudyState.initial().copyWith(currentContent: content);
      
      expect(state.currentContent, equals(content));
      expect(state.currentContent![0], 'a');
      expect(state.currentContent![3], 'd');
    });

    test('should handle negative index edge case', () {
      final state = StudyState.initial().copyWith(currentIndex: -1);
      expect(state.currentIndex, -1);
    });

    test('should handle large index', () {
      final state = StudyState.initial().copyWith(currentIndex: 1000);
      expect(state.currentIndex, 1000);
    });
  });
}
