import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/progress_provider.dart';
import 'package:learning_pwa/models/lesson_progress.dart';

void main() {
  group('ProgressProvider Tests', () {
    group('ProgressState classes', () {
      test('ProgressInitial should be created', () {
        const state = ProgressInitial();
        
        expect(state, isA<ProgressState>());
        expect(state, isA<ProgressInitial>());
      });

      test('ProgressLoaded should contain progress data', () {
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 120,
        );

        final state = ProgressLoaded(progress);

        expect(state, isA<ProgressState>());
        expect(state, isA<ProgressLoaded>());
        expect(state.progress, progress);
        expect(state.error, null);
        expect(state.hasError, false);
      });

      test('ProgressLoaded should handle error state', () {
        final progress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: false,
          studyTimeSeconds: 0,
        );

        final state = ProgressLoaded(progress, error: 'Test error');

        expect(state.error, 'Test error');
        expect(state.hasError, true);
      });

      test('ProgressError should contain error message', () {
        const state = ProgressError('Failed to load');

        expect(state, isA<ProgressState>());
        expect(state, isA<ProgressError>());
        expect(state.message, 'Failed to load');
      });
    });

    group('ProgressLoaded copyWith', () {
      late UserProgress originalProgress;
      late ProgressLoaded originalState;

      setUp(() {
        originalProgress = UserProgress(
          id: 'test-id',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 120,
        );
        originalState = ProgressLoaded(originalProgress);
      });

      test('should copy with new progress', () {
        final newProgress = UserProgress(
          id: 'new-id',
          userId: 'user-2',
          lessonId: 'lesson-2',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 10,
          correctCount: 8,
          lessonCompleted: true,
          studyTimeSeconds: 300,
        );

        final newState = originalState.copyWith(progress: newProgress);

        expect(newState.progress, newProgress);
        expect(newState.error, null);
      });

      test('should copy with error', () {
        final newState = originalState.copyWith(error: 'Sync failed');

        expect(newState.progress, originalProgress);
        expect(newState.error, 'Sync failed');
        expect(newState.hasError, true);
      });

      test('should copy with both progress and error', () {
        final newProgress = UserProgress(
          id: 'new-id',
          userId: 'user-2',
          lessonId: 'lesson-2',
          studyMode: StudyMode.concept,
          date: DateTime.now(),
          questionsAnswered: 3,
          correctCount: 2,
          lessonCompleted: false,
          studyTimeSeconds: 60,
        );

        final newState = originalState.copyWith(
          progress: newProgress,
          error: 'Warning',
        );

        expect(newState.progress, newProgress);
        expect(newState.error, 'Warning');
      });

      test('should maintain original values when no parameters provided', () {
        final newState = originalState.copyWith();

        expect(newState.progress, originalProgress);
        expect(newState.error, null);
      });

      test('should clear error by setting to null', () {
        final stateWithError = ProgressLoaded(originalProgress, error: 'Error');
        final newState = stateWithError.copyWith(error: null);

        expect(newState.error, null);
        expect(newState.hasError, false);
      });
    });

    group('UserProgress model', () {
      test('should create progress with all required fields', () {
        final progress = UserProgress(
          id: 'progress-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 10,
          correctCount: 8,
          lessonCompleted: true,
          studyTimeSeconds: 300,
        );

        expect(progress.id, 'progress-1');
        expect(progress.userId, 'user-1');
        expect(progress.lessonId, 'lesson-1');
        expect(progress.studyMode, StudyMode.flashcard);
        expect(progress.questionsAnswered, 10);
        expect(progress.correctCount, 8);
        expect(progress.lessonCompleted, true);
        expect(progress.studyTimeSeconds, 300);
      });

      test('should create progress with optional fields', () {
        final metadata = {'key': 'value'};
        final progress = UserProgress(
          id: 'progress-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          contentId: 'content-1',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 3,
          lessonCompleted: false,
          studyTimeSeconds: 120,
          metadata: metadata,
          isSynced: true,
        );

        expect(progress.contentId, 'content-1');
        expect(progress.metadata, metadata);
        expect(progress.isSynced, true);
      });

      test('should support copyWith for incremental updates', () {
        final original = UserProgress(
          id: 'progress-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 120,
        );

        final updated = original.copyWith(
          questionsAnswered: 6,
          correctCount: 5,
        );

        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.lessonId, original.lessonId);
        expect(updated.questionsAnswered, 6);
        expect(updated.correctCount, 5);
        expect(updated.lessonCompleted, false);
        expect(updated.studyTimeSeconds, 120);
      });

      test('should update lessonCompleted status', () {
        final original = UserProgress(
          id: 'progress-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          date: DateTime.now(),
          questionsAnswered: 10,
          correctCount: 8,
          lessonCompleted: false,
          studyTimeSeconds: 300,
        );

        final completed = original.copyWith(
          lessonCompleted: true,
          metadata: {'completed_at': DateTime.now().toIso8601String()},
        );

        expect(completed.lessonCompleted, true);
        expect(completed.metadata, isNotNull);
        expect(completed.metadata!.containsKey('completed_at'), true);
      });

      test('should update studyTimeSeconds incrementally', () {
        final original = UserProgress(
          id: 'progress-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 3,
          correctCount: 2,
          lessonCompleted: false,
          studyTimeSeconds: 60,
        );

        final updated = original.copyWith(
          studyTimeSeconds: original.studyTimeSeconds + 30,
        );

        expect(updated.studyTimeSeconds, 90);
      });
    });

    group('StudyMode enum', () {
      test('should have all expected study modes', () {
        expect(StudyMode.values.length, 4);
        expect(StudyMode.values, contains(StudyMode.flashcard));
        expect(StudyMode.values, contains(StudyMode.mcq));
        expect(StudyMode.values, contains(StudyMode.concept));
        expect(StudyMode.values, contains(StudyMode.lesson));
      });

      test('should convert to string correctly', () {
        expect(StudyMode.flashcard.toString(), 'StudyMode.flashcard');
        expect(StudyMode.mcq.toString(), 'StudyMode.mcq');
        expect(StudyMode.concept.toString(), 'StudyMode.concept');
        expect(StudyMode.lesson.toString(), 'StudyMode.lesson');
      });
    });

    group('Progress tracking scenarios', () {
      test('should track a complete study session', () {
        // Start with initial progress
        var progress = UserProgress(
          id: 'session-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: false,
          studyTimeSeconds: 0,
        );

        // Answer first question correctly
        progress = progress.copyWith(
          questionsAnswered: 1,
          correctCount: 1,
          studyTimeSeconds: 10,
        );
        expect(progress.questionsAnswered, 1);
        expect(progress.correctCount, 1);

        // Answer second question incorrectly
        progress = progress.copyWith(
          questionsAnswered: 2,
          studyTimeSeconds: 25,
        );
        expect(progress.questionsAnswered, 2);
        expect(progress.correctCount, 1);

        // Complete the lesson
        progress = progress.copyWith(
          lessonCompleted: true,
          studyTimeSeconds: 180,
        );
        expect(progress.lessonCompleted, true);
        expect(progress.studyTimeSeconds, 180);
      });

      test('should track accuracy over time', () {
        final progress = UserProgress(
          id: 'session-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 20,
          correctCount: 15,
          lessonCompleted: true,
          studyTimeSeconds: 600,
        );

        final accuracy = progress.correctCount / progress.questionsAnswered;
        expect(accuracy, 0.75);
      });
    });

    group('ProgressNotifier business logic simulation', () {
      test('answerQuestion logic - correct answer increments both counters', () {
        // Simulate the logic from ProgressNotifier.answerQuestion
        final initialProgress = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 3,
          lessonCompleted: false,
          studyTimeSeconds: 120,
        );

        // Simulate answering correctly
        final isCorrect = true;
        final elapsedSeconds = 15;
        
        final updatedProgress = initialProgress.copyWith(
          questionsAnswered: initialProgress.questionsAnswered + 1,
          correctCount: isCorrect ? initialProgress.correctCount + 1 : initialProgress.correctCount,
          studyTimeSeconds: initialProgress.studyTimeSeconds + elapsedSeconds,
        );

        expect(updatedProgress.questionsAnswered, 6);
        expect(updatedProgress.correctCount, 4);
        expect(updatedProgress.studyTimeSeconds, 135);
      });

      test('answerQuestion logic - incorrect answer only increments questions counter', () {
        final initialProgress = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 10,
          correctCount: 7,
          lessonCompleted: false,
          studyTimeSeconds: 200,
        );

        // Simulate answering incorrectly
        final isCorrect = false;
        final elapsedSeconds = 20;
        
        final updatedProgress = initialProgress.copyWith(
          questionsAnswered: initialProgress.questionsAnswered + 1,
          correctCount: isCorrect ? initialProgress.correctCount + 1 : initialProgress.correctCount,
          studyTimeSeconds: initialProgress.studyTimeSeconds + elapsedSeconds,
        );

        expect(updatedProgress.questionsAnswered, 11);
        expect(updatedProgress.correctCount, 7); // Should not increment
        expect(updatedProgress.studyTimeSeconds, 220);
      });

      test('completeLesson logic - sets lessonCompleted and adds metadata', () {
        final initialProgress = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          date: DateTime.now(),
          questionsAnswered: 15,
          correctCount: 12,
          lessonCompleted: false,
          studyTimeSeconds: 480,
        );

        // Simulate completing lesson
        final elapsedSeconds = 60;
        final completedAt = DateTime.now().toIso8601String();
        
        final updatedProgress = initialProgress.copyWith(
          lessonCompleted: true,
          studyTimeSeconds: initialProgress.studyTimeSeconds + elapsedSeconds,
          metadata: {
            ...?initialProgress.metadata,
            'completed_at': completedAt,
          },
        );

        expect(updatedProgress.lessonCompleted, true);
        expect(updatedProgress.studyTimeSeconds, 540);
        expect(updatedProgress.metadata?['completed_at'], isNotNull);
      });

      test('progress calculations - accuracy percentage', () {
        final progress = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.mcq,
          date: DateTime.now(),
          questionsAnswered: 25,
          correctCount: 20,
          lessonCompleted: true,
          studyTimeSeconds: 600,
        );

        final accuracy = (progress.correctCount / progress.questionsAnswered * 100);
        expect(accuracy, 80.0);
      });

      test('progress calculations - mastery level determination', () {
        // High mastery (90%+)
        final highMastery = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 20,
          correctCount: 19,
          lessonCompleted: true,
          studyTimeSeconds: 400,
        );
        final highAccuracy = (highMastery.correctCount / highMastery.questionsAnswered);
        expect(highAccuracy, greaterThan(0.9));

        // Medium mastery (70-89%)
        final mediumMastery = UserProgress(
          id: 'test-2',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 20,
          correctCount: 16,
          lessonCompleted: true,
          studyTimeSeconds: 450,
        );
        final mediumAccuracy = (mediumMastery.correctCount / mediumMastery.questionsAnswered);
        expect(mediumAccuracy, greaterThanOrEqualTo(0.7));
        expect(mediumAccuracy, lessThan(0.9));

        // Low mastery (<70%)
        final lowMastery = UserProgress(
          id: 'test-3',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.flashcard,
          date: DateTime.now(),
          questionsAnswered: 20,
          correctCount: 12,
          lessonCompleted: true,
          studyTimeSeconds: 500,
        );
        final lowAccuracy = (lowMastery.correctCount / lowMastery.questionsAnswered);
        expect(lowAccuracy, lessThan(0.7));
      });

      test('metadata merging - preserves existing and adds new', () {
        final progress = UserProgress(
          id: 'test-1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          date: DateTime.now(),
          questionsAnswered: 5,
          correctCount: 4,
          lessonCompleted: false,
          studyTimeSeconds: 120,
          metadata: {'started_at': '2025-12-12T10:00:00Z', 'session': 'first'},
        );

        // Simulate metadata merge
        final newMetadata = {
          'hint_used': true,
          'difficulty': 'medium',
        };
        
        final updatedProgress = progress.copyWith(
          metadata: {
            ...?progress.metadata,
            ...newMetadata,
          },
        );

        expect(updatedProgress.metadata?['started_at'], '2025-12-12T10:00:00Z');
        expect(updatedProgress.metadata?['session'], 'first');
        expect(updatedProgress.metadata?['hint_used'], true);
        expect(updatedProgress.metadata?['difficulty'], 'medium');
      });
    });
  });
}
