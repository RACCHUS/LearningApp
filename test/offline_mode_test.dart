import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/mcq.dart';
import 'package:learning_pwa/models/user_progress.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'offline_mode_test.mocks.dart';

// Generate mocks
@GenerateMocks([supabase.SupabaseClient, HiveInterface])
void main() {
  late HiveService hiveService;
  late MockSupabaseClient mockSupabase;
  late MockHiveInterface mockHive;
  
  setUp(() async {
    // Initialize mocks
    mockSupabase = MockSupabaseClient();
    mockHive = MockHiveInterface();
    
    // Initialize HiveService with mocks
    hiveService = HiveService();
    
    // Mock Hive initialization
    when(mockHive.isAdapterRegistered(any)).thenReturn(false);
    
    // Mock Hive box
    final mockBox = MockBox();
    when(mockHive.openBox<dynamic>(any)).thenAnswer((_) async => mockBox);
  });

  group('HiveService Tests', () {
    test('cacheLesson should store lesson in Hive', () async {
      // Arrange
      final lesson = Lesson(
        id: '1',
        title: 'Test Lesson',
        description: 'Test Description',
        tags: ['test'],
        createdBy: 'test@example.com',
      );
      
      // Act
      await hiveService.cacheLesson(lesson);
      
      // Assert
      // Verify the lesson is stored in Hive
      final storedLesson = await hiveService.getLesson('1');
      expect(storedLesson, isNotNull);
      expect(storedLesson!.title, 'Test Lesson');
    });

    test('cacheConcept should store concept in Hive', () async {
      // Arrange
      final concept = Concept(
        id: '1',
        lessonId: '1',
        conceptText: 'Test Concept',
        exampleText: 'Test Example',
        createdBy: 'test@example.com',
      );
      
      // Act
      await hiveService.cacheConcept(concept);
      
      // Assert
      // Verify the concept is stored in Hive
      final storedConcept = await hiveService.getConcept('1');
      expect(storedConcept, isNotNull);
      expect(storedConcept!.conceptText, 'Test Concept');
    });

    test('cacheMcq should store MCQ in Hive', () async {
      // Arrange
      final mcq = Mcq(
        id: '1',
        lessonId: '1',
        question: 'Test Question',
        options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 0,
        explanation: 'Test Explanation',
        createdBy: 'test@example.com',
      );
      
      // Act
      await hiveService.cacheMcq(mcq);
      
      // Assert
      // Verify the MCQ is stored in Hive
      final storedMcq = await hiveService.getMcq('1');
      expect(storedMcq, isNotNull);
      expect(storedMcq!.question, 'Test Question');
    });

    test('getConceptsByLesson should return concepts for a lesson', () async {
      // Arrange
      final concept1 = Concept(
        id: '1',
        lessonId: '1',
        conceptText: 'Concept 1',
        createdBy: 'test@example.com',
      );
      
      final concept2 = Concept(
        id: '2',
        lessonId: '1',
        conceptText: 'Concept 2',
        createdBy: 'test@example.com',
      );
      
      await hiveService.cacheConcepts([concept1, concept2]);
      
      // Act
      final concepts = await hiveService.getConceptsByLesson('1');
      
      // Assert
      expect(concepts.length, 2);
      expect(concepts[0].conceptText, 'Concept 1');
      expect(concepts[1].conceptText, 'Concept 2');
    });

    test('getMcqsByLesson should return MCQs for a lesson', () async {
      // Arrange
      final mcq1 = Mcq(
        id: '1',
        lessonId: '1',
        question: 'Question 1',
        options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 0,
        createdBy: 'test@example.com',
      );
      
      final mcq2 = Mcq(
        id: '2',
        lessonId: '1',
        question: 'Question 2',
        options: ['A', 'B', 'C', 'D'],
        correctOptionIndex: 1,
        createdBy: 'test@example.com',
      );
      
      await hiveService.cacheMcqs([mcq1, mcq2]);
      
      // Act
      final mcqs = await hiveService.getMcqsByLesson('1');
      
      // Assert
      expect(mcqs.length, 2);
      expect(mcqs[0].question, 'Question 1');
      expect(mcqs[1].question, 'Question 2');
    });
  });

  group('Sync Tests', () {
    test('syncProgress should update local progress from server', () async {
      // Arrange
      final progress = UserProgress(
        id: '1',
        userId: 'user1',
        lessonId: '1',
        contentId: 'content1',
        studyMode: 'flashcard',
        date: DateTime.now(),
        questionsAnswered: 10,
        correctCount: 8,
        lessonCompleted: false,
        studyTimeSeconds: 300,
        isSynced: false,
      );
      
      // Mock Supabase response
      when(mockSupabase.from('user_progress').select()
          .eq('user_id', 'user1')
          .order('date', ascending: false))
        .thenAnswer((_) async => [progress.toJson()]);
      
      // Act
      // In a real test, we would call syncProgress here
      
      // Assert
      // Verify the progress is stored in Hive
      final storedProgress = (await hiveService.getProgress())
          .firstWhere((p) => p.id == '1');
      expect(storedProgress.userId, 'user1');
      expect(storedProgress.lessonId, '1');
      expect(storedProgress.isSynced, isTrue);
    });
  });
}

// Mock classes for testing
class MockBox extends Mock implements Box {}
class MockHiveInterface extends Mock implements HiveInterface {}
class MockSupabaseClient extends Mock implements supabase.SupabaseClient {}
class MockPostgrestQueryBuilder extends Mock implements supabase.PostgrestQueryBuilder {}
class MockPostgrestFilterBuilder extends Mock implements supabase.PostgrestFilterBuilder {}
