import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lessons_provider.dart';
import 'package:learning_pwa/models/lesson.dart';

void main() {
  group('LessonsProvider', () {
    // Note: LessonsNotifier tests are skipped because they require Supabase initialization
    // Testing the notifier would require mocking SupabaseService
    
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
    });

    group('filterByTags', () {
      test('should update selected tags', () {
        // Note: Requires Supabase mock
      }, skip: 'Requires Supabase initialization');

      test('should clear tags when empty list provided', () {
        // Note: Requires Supabase mock
      }, skip: 'Requires Supabase initialization');
    });

    group('filteredLessons', () {
      test('should return all lessons when no tags selected', () {
        // Note: Requires Supabase mock for notifier creation
      }, skip: 'Requires Supabase initialization');

      test('should filter lessons by single tag', () {
        // Note: Requires Supabase mock for notifier creation  
      }, skip: 'Requires Supabase initialization');

      test('should filter lessons by multiple tags (OR logic)', () {
        // Note: Requires Supabase mock for notifier creation
      }, skip: 'Requires Supabase initialization');

      test('should return empty list when no lessons match tags', () {
        // Note: Requires Supabase mock for notifier creation
      }, skip: 'Requires Supabase initialization');
    });
  });
}
