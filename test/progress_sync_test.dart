import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:learning_pwa/services/supabase_service.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockHiveService extends Mock implements HiveService {}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockHiveService mockHiveService;
  late ProgressSyncService progressSyncService;
  
  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockHiveService = MockHiveService();
    
    // Initialize SupabaseService with mock client
    SupabaseService.instance = SupabaseService(mockSupabaseClient);
    
    // Create test progress items
    final testProgress = [
      UserProgress(
        id: '1',
        userId: 'user1',
        lessonId: 'lesson1',
        studyMode: StudyMode.flashcard,
        date: DateTime.now(),
        questionsAnswered: 5,
        correctCount: 4,
        lessonCompleted: false,
        studyTimeSeconds: 300,
        isSynced: false,
      ),
      UserProgress(
        id: '2',
        userId: 'user1',
        lessonId: 'lesson2',
        studyMode: StudyMode.mcq,
        date: DateTime.now(),
        questionsAnswered: 10,
        correctCount: 8,
        lessonCompleted: true,
        studyTimeSeconds: 600,
        isSynced: false,
      ),
    ];
    
    // Setup mock HiveService
    when(mockHiveService.getUnsyncedProgress())
        .thenAnswer((_) async => testProgress);
    
    // Setup mock Supabase response
    when(mockSupabaseClient.from('user_progress').upsert(
      any,
      onConflict: 'user_id, lesson_id, study_mode, date',
    )).thenThrow(Exception('Test error'));
    
    progressSyncService = ProgressSyncService(mockHiveService);
  });
  
  group('ProgressSyncService Tests', () {
    test('syncProgress should fetch unsynced progress', () async {
      // Act
      await progressSyncService.syncProgress();
      
      // Assert
      verify(mockHiveService.getUnsyncedProgress()).called(1);
    });
    
    test('syncProgress should handle empty unsynced progress', () async {
      // Arrange
      when(mockHiveService.getUnsyncedProgress())
          .thenAnswer((_) async => []);
      
      // Act
      await progressSyncService.syncProgress();
      
      // Assert - No progress to sync, so markAsSynced shouldn't be called
      verifyNever(mockHiveService.markProgressAsSynced(any));
    });
    
    test('syncProgress should handle sync errors', () async {
      // Act & Assert
      expect(() => progressSyncService.syncProgress(), throwsException);
    });
  });
  
  test('mergeProgress should combine progress data correctly', () {
    // Arrange
    final progress1 = UserProgress(
      id: '1',
      userId: 'user1',
      lessonId: 'lesson1',
      studyMode: StudyMode.flashcard,
      date: DateTime.now(),
      questionsAnswered: 5,
      correctCount: 4,
      lessonCompleted: false,
      studyTimeSeconds: 300,
      isSynced: false,
    );
    
    final progress2 = UserProgress(
      id: '1',
      userId: 'user1',
      lessonId: 'lesson1',
      studyMode: StudyMode.flashcard,
      date: DateTime.now(),
      questionsAnswered: 3,
      correctCount: 2,
      lessonCompleted: true, // This should be preserved
      studyTimeSeconds: 200,
      isSynced: false,
    );
    
    // Act
    final merged = progressSyncService.mergeProgress(progress1, progress2);
    
    // Assert
    expect(merged.questionsAnswered, 8);
    expect(merged.correctCount, 6);
    expect(merged.studyTimeSeconds, 500);
    expect(merged.lessonCompleted, true);
  });
}
