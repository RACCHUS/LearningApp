import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/mcq.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'dart:io';

void main() {
  late HiveService hiveService;
  late Directory testDir;
  
  setUpAll(() async {
    // Register adapters once for all tests
    registerHiveAdapters();
  });
  
  setUp(() async {
    // Create a temporary directory for test Hive storage
    testDir = await Directory.systemTemp.createTemp('hive_test_');
    
    // Initialize Hive with test directory
    Hive.init(testDir.path);
    
    // Initialize HiveService
    hiveService = HiveService();
    await hiveService.init();
  });
  
  tearDown(() async {
    // Close all boxes
    await Hive.close();
    
    // Delete test directory
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('HiveService Tests', () {
    test('cacheLesson should store lesson in Hive', () async {
      // Arrange
      final lesson = Lesson(
        id: '1',
        title: 'Test Lesson',
        description: 'Test Description',
        tags: ['test'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'test@example.com',
        terms: [],
        questions: [],
        concepts: [],
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
        createdAt: DateTime.now(),
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
        order: 0,
        question: 'Test Question',
        options: ['A', 'B', 'C', 'D'],
        correctOption: 0,
        explanation: 'Test Explanation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
        createdAt: DateTime.now(),
      );
      
      final concept2 = Concept(
        id: '2',
        lessonId: '1',
        conceptText: 'Concept 2',
        createdBy: 'test@example.com',
        createdAt: DateTime.now(),
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
        order: 0,
        question: 'Question 1',
        options: ['A', 'B', 'C', 'D'],
        correctOption: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final mcq2 = Mcq(
        id: '2',
        lessonId: '1',
        order: 1,
        question: 'Question 2',
        options: ['A', 'B', 'C', 'D'],
        correctOption: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
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
}
