import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/lessons_provider.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/supabase_service.dart';

// Mock SupabaseService for testing
class _FakeSupabaseService implements SupabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

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

    group('LessonsNotifier', () {
      late LessonsNotifier notifier;

      setUp(() {
        notifier = LessonsNotifier(supabaseService: _FakeSupabaseService());
      });

      test('should initialize with empty state', () {
        expect(notifier.state.lessons, isEmpty);
        expect(notifier.state.selectedTags, isEmpty);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, null);
      });

      group('filterByTags', () {
        test('should update selectedTags in state', () {
          // Act
          notifier.filterByTags(['flutter', 'dart']);

          // Assert
          expect(notifier.state.selectedTags, ['flutter', 'dart']);
        });

        test('should replace previous tags', () {
          // Arrange
          notifier.filterByTags(['tag1', 'tag2']);

          // Act
          notifier.filterByTags(['tag3']);

          // Assert
          expect(notifier.state.selectedTags, ['tag3']);
        });

        test('should handle empty tag list', () {
          // Arrange
          notifier.filterByTags(['tag1']);

          // Act
          notifier.filterByTags([]);

          // Assert
          expect(notifier.state.selectedTags, isEmpty);
        });
      });

      group('filteredLessons', () {
        late List<Lesson> testLessons;

        setUp(() {
          testLessons = [
            Lesson(
              id: '1',
              title: 'Flutter Basics',
              userId: 'user-1',
              tags: const ['flutter', 'mobile'],
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            Lesson(
              id: '2',
              title: 'Dart Fundamentals',
              userId: 'user-1',
              tags: const ['dart', 'programming'],
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            Lesson(
              id: '3',
              title: 'Flutter & Dart',
              userId: 'user-1',
              tags: const ['flutter', 'dart'],
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            Lesson(
              id: '4',
              title: 'Web Development',
              userId: 'user-1',
              tags: const ['web', 'javascript'],
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          // Set lessons directly in state for testing filter logic
          notifier.state = notifier.state.copyWith(lessons: testLessons);
        });

        test('should return all lessons when no tags selected', () {
          // Act
          final filtered = notifier.filteredLessons;

          // Assert
          expect(filtered.length, 4);
        });

        test('should filter lessons by single tag', () {
          // Arrange
          notifier.filterByTags(['flutter']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert
          expect(filtered.length, 2);
          expect(filtered[0].id, '1');
          expect(filtered[1].id, '3');
        });

        test('should filter lessons by multiple tags (OR logic)', () {
          // Arrange
          notifier.filterByTags(['dart', 'web']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert
          expect(filtered.length, 3);
          final ids = filtered.map((l) => l.id).toList();
          expect(ids, containsAll(['2', '3', '4']));
        });

        test('should return empty list when no lessons match tags', () {
          // Arrange
          notifier.filterByTags(['nonexistent']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert
          expect(filtered, isEmpty);
        });

        test('should handle lessons with multiple matching tags', () {
          // Arrange
          notifier.filterByTags(['flutter', 'dart']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert - Lesson 3 has both tags, should appear once
          expect(filtered.length, 3);
          expect(filtered.any((l) => l.id == '3'), true);
        });

        test('should handle empty lessons list', () {
          // Arrange
          notifier.state = notifier.state.copyWith(lessons: []);
          notifier.filterByTags(['flutter']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert
          expect(filtered, isEmpty);
        });

        test('should be case-sensitive for tag matching', () {
          // Arrange
          notifier.filterByTags(['Flutter']); // Capital F

          // Act
          final filtered = notifier.filteredLessons;

          // Assert - Should not match 'flutter' (lowercase)
          expect(filtered, isEmpty);
        });

        test('should update filtered results when tags change', () {
          // Arrange
          notifier.filterByTags(['flutter']);
          final firstFilter = notifier.filteredLessons;

          // Act
          notifier.filterByTags(['dart']);
          final secondFilter = notifier.filteredLessons;

          // Assert
          expect(firstFilter.length, 2);
          expect(secondFilter.length, 2);
          expect(firstFilter[0].id, '1');
          expect(secondFilter[0].id, '2');
        });

        test('should preserve lesson order after filtering', () {
          // Arrange
          notifier.filterByTags(['flutter', 'dart']);

          // Act
          final filtered = notifier.filteredLessons;

          // Assert - Order should be maintained from original list
          expect(filtered[0].id, '1'); // Flutter Basics (index 0)
          expect(filtered[1].id, '2'); // Dart Fundamentals (index 1)
          expect(filtered[2].id, '3'); // Flutter & Dart (index 2)
        });
      });

      group('state transitions', () {
        test('should handle loading state transitions', () {
          // Initial state
          expect(notifier.state.isLoading, false);

          // Set loading state manually for testing
          notifier.state = notifier.state.copyWith(isLoading: true);
          expect(notifier.state.isLoading, true);

          // Complete loading
          notifier.state = notifier.state.copyWith(isLoading: false);
          expect(notifier.state.isLoading, false);
        });

        test('should clear error when setting new error', () {
          // Arrange
          notifier.state = notifier.state.copyWith(error: 'First error');

          // Act
          notifier.state = notifier.state.copyWith(error: 'Second error');

          // Assert
          expect(notifier.state.error, 'Second error');
        });

        test('should preserve lessons when updating other fields', () {
          // Arrange
          final lessons = [
            Lesson(
              id: '1',
              title: 'Test',
              userId: 'user-1',
              tags: const [],
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];
          notifier.state = notifier.state.copyWith(lessons: lessons);

          // Act
          notifier.filterByTags(['tag1']);

          // Assert
          expect(notifier.state.lessons, lessons);
          expect(notifier.state.selectedTags, ['tag1']);
        });
      });
    });
  });
}
