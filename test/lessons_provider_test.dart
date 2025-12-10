import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lessons_provider.dart';
import 'package:learning_pwa/models/lesson.dart';

void main() {
  group('LessonsProvider', () {
    group('LessonsState', () {
      test('should have correct initial state', () {
        // Arrange
        const state = LessonsState();

        // Assert
        expect(state.lessons, isEmpty);
        expect(state.selectedTags, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, null);
      });

      test('copyWith should update specified fields', () {
        // Arrange
        const state = LessonsState();
        final lessons = [
          Lesson(
            id: '1',
            title: 'Test Lesson',
            userId: 'user-1',
            tags: const [],
            terms: const [],
            questions: const [],
            concepts: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        // Act
        final newState = state.copyWith(
          lessons: lessons,
          isLoading: true,
          error: 'Test error',
        );

        // Assert
        expect(newState.lessons, lessons);
        expect(newState.isLoading, true);
        expect(newState.error, 'Test error');
        expect(newState.selectedTags, isEmpty); // unchanged
      });

      test('copyWith should allow null error to clear errors', () {
        // Arrange
        const state = LessonsState(error: 'Previous error');

        // Act
        final newState = state.copyWith(error: null);

        // Assert
        expect(newState.error, null);
      });

      test('copyWith should preserve lessons when not specified', () {
        // Arrange
        final lessons = [
          Lesson(
            id: '1',
            title: 'Test Lesson',
            userId: 'user-1',
            tags: const ['tag1'],
            terms: const [],
            questions: const [],
            concepts: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        final state = LessonsState(lessons: lessons);

        // Act
        final newState = state.copyWith(isLoading: true);

        // Assert
        expect(newState.lessons, lessons);
        expect(newState.isLoading, true);
      });

      test('should handle multiple lessons', () {
        // Arrange
        final lessons = List.generate(
          5,
          (i) => Lesson(
            id: '$i',
            title: 'Lesson $i',
            userId: 'user-1',
            tags: ['tag$i'],
            terms: const [],
            questions: const [],
            concepts: const [],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Act
        const initialState = LessonsState();
        final newState = initialState.copyWith(lessons: lessons);

        // Assert
        expect(newState.lessons.length, 5);
        expect(newState.lessons[0].title, 'Lesson 0');
        expect(newState.lessons[4].title, 'Lesson 4');
      });

      test('should handle tag selection', () {
        // Arrange
        const state = LessonsState();
        final tags = ['flutter', 'dart', 'mobile'];

        // Act
        final newState = state.copyWith(selectedTags: tags);

        // Assert
        expect(newState.selectedTags, tags);
        expect(newState.selectedTags.length, 3);
      });

      test('should handle loading states', () {
        // Arrange
        const state = LessonsState();

        // Act
        final loadingState = state.copyWith(isLoading: true);
        final loadedState = loadingState.copyWith(isLoading: false);

        // Assert
        expect(state.isLoading, false);
        expect(loadingState.isLoading, true);
        expect(loadedState.isLoading, false);
      });

      test('should handle error states', () {
        // Arrange
        const state = LessonsState();

        // Act
        final errorState = state.copyWith(error: 'Network error');
        final clearedState = errorState.copyWith(error: null);

        // Assert
        expect(state.error, null);
        expect(errorState.error, 'Network error');
        expect(clearedState.error, null);
      });
    });
  });
}
