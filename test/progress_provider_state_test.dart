import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/progress_provider.dart';
import 'package:learning_pwa/models/lesson_progress.dart';

void main() {
  group('ProgressProvider States', () {
    group('ProgressInitial', () {
      test('should be a ProgressState', () {
        // Arrange
        const state = ProgressInitial();

        // Assert
        expect(state, isA<ProgressState>());
      });
    });

    group('ProgressLoaded', () {
      test('should store progress and error', () {
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        // Act
        final state = ProgressLoaded(progress, error: 'Test error');

        // Assert
        expect(state.progress, progress);
        expect(state.error, 'Test error');
        expect(state.hasError, true);
      });

      test('should have no error when error is null', () {
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        // Act
        final state = ProgressLoaded(progress);

        // Assert
        expect(state.hasError, false);
        expect(state.error, null);
      });

      test('copyWith should update progress', () {
        // Arrange
        final progress1 = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        final progress2 = UserProgress(
          id: 'test-id-2',
          userId: 'user-2',
          lessonId: 'lesson-2',
          contentId: 'content-2',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 10,
          correctCount: 8,
          lessonCompleted: true,
          studyTimeSeconds: 600,
          isSynced: true,
        );

        final state = ProgressLoaded(progress1);

        // Act
        final newState = state.copyWith(progress: progress2);

        // Assert
        expect(newState.progress, progress2);
        expect(newState.error, null); // unchanged
      });

      test('copyWith should update error', () {
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        final state = ProgressLoaded(progress);

        // Act
        final newState = state.copyWith(error: 'New error');

        // Assert
        expect(newState.error, 'New error');
        expect(newState.hasError, true);
        expect(newState.progress, progress); // unchanged
      });

      test('copyWith should allow clearing error', () {
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        final state = ProgressLoaded(progress, error: 'Old error');

        // Act
        final newState = state.copyWith(error: null);

        // Assert
        expect(newState.error, null);
        expect(newState.hasError, false);
      });
    });

    group('ProgressError', () {
      test('should store error message', () {
        // Arrange
        const message = 'Failed to load progress';

        // Act
        const state = ProgressError(message);

        // Assert
        expect(state.message, message);
        expect(state, isA<ProgressState>());
      });

      test('should be different from ProgressLoaded', () {
        // Arrange
        const errorState = ProgressError('Error');
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );
        final loadedState = ProgressLoaded(progress);

        // Assert
        expect(errorState, isNot(isA<ProgressLoaded>()));
        expect(loadedState, isNot(isA<ProgressError>()));
      });
    });

    group('State Type Checking', () {
      test('should correctly identify state types', () {
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: true,
        );

        const initialState = ProgressInitial();
        final loadedState = ProgressLoaded(progress);
        const errorState = ProgressError('Error');

        // Assert
        expect(initialState, isA<ProgressInitial>());
        expect(initialState, isNot(isA<ProgressLoaded>()));
        expect(initialState, isNot(isA<ProgressError>()));

        expect(loadedState, isNot(isA<ProgressInitial>()));
        expect(loadedState, isA<ProgressLoaded>());
        expect(loadedState, isNot(isA<ProgressError>()));

        expect(errorState, isNot(isA<ProgressInitial>()));
        expect(errorState, isNot(isA<ProgressLoaded>()));
        expect(errorState, isA<ProgressError>());
      });
    });

    group('Error Scenarios', () {
      test('ProgressLoaded should track both progress and errors', () {
        // This models the scenario where we have progress data but an error occurred
        // during sync, allowing the UI to show both the data and error state
        
        // Arrange
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          isSynced: false, // Not synced
        );

        // Act
        final state = ProgressLoaded(
          progress,
          error: 'Failed to sync progress data',
        );

        // Assert
        expect(state.progress, progress);
        expect(state.hasError, true);
        expect(state.error, contains('sync'));
      });
    });
  });
}
