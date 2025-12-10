import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'progress_sync_service_test.mocks.dart';

// Generate mocks for these classes
@GenerateMocks([HiveService, SupabaseClient])

void main() {
  group('ProgressSyncService', () {
    late MockHiveService mockHiveService;
    late MockSupabaseClient mockSupabase;
    late ProgressSyncService service;

    setUp(() {
      mockHiveService = MockHiveService();
      mockSupabase = MockSupabaseClient();
      service = ProgressSyncService(mockHiveService, mockSupabase);
    });

    group('mergeProgress', () {
      test('should keep newer progress when new is more recent', () {
        // Arrange
        final existing = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 10,
          correctCount: 7,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          date: DateTime(2024, 1, 1),
          isSynced: true,
        );
        
        final newer = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 15,
          correctCount: 13,
          lessonCompleted: true,
          studyTimeSeconds: 450,
          date: DateTime(2024, 1, 2),
          isSynced: false,
        );

        // Act
        final result = service.mergeProgress(existing, newer);

        // Assert
        expect(result, newer);
        expect(result.questionsAnswered, 15);
        expect(result.lessonCompleted, true);
      });

      test('should keep existing progress when it is more recent', () {
        // Arrange
        final existing = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 15,
          correctCount: 13,
          lessonCompleted: true,
          studyTimeSeconds: 450,
          date: DateTime(2024, 1, 2),
          isSynced: true,
        );
        
        final older = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 10,
          correctCount: 7,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          date: DateTime(2024, 1, 1),
          isSynced: false,
        );

        // Act
        final result = service.mergeProgress(existing, older);

        // Assert
        expect(result, existing);
        expect(result.questionsAnswered, 15);
        expect(result.lessonCompleted, true);
      });

      test('should keep existing when dates are equal', () {
        // Arrange
        final date = DateTime(2024, 1, 1);
        final existing = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 15,
          correctCount: 13,
          lessonCompleted: true,
          studyTimeSeconds: 450,
          date: date,
          isSynced: true,
        );
        
        final duplicate = UserProgress(
          id: '1',
          userId: 'user-1',
          lessonId: 'lesson-1',
          studyMode: StudyMode.lesson,
          questionsAnswered: 10,
          correctCount: 7,
          lessonCompleted: false,
          studyTimeSeconds: 300,
          date: date,
          isSynced: false,
        );

        // Act
        final result = service.mergeProgress(existing, duplicate);

        // Assert
        expect(result, existing);
      });
    });

    group('syncProgress - HiveService mocking', () {
      test('should do nothing when no unsynced progress', () async {
        // Arrange
        when(mockHiveService.getUnsyncedProgress())
            .thenAnswer((_) async => []);

        // Act
        await service.syncProgress();

        // Assert
        verify(mockHiveService.getUnsyncedProgress()).called(1);
        verifyNever(mockHiveService.markProgressAsSynced(any));
      });

      test('should handle empty progress list', () async {
        // Arrange
        when(mockHiveService.getUnsyncedProgress())
            .thenAnswer((_) async => []);

        // Act & Assert - should not throw
        await service.syncProgress();
        
        verify(mockHiveService.getUnsyncedProgress()).called(1);
      });
    });
  });
}