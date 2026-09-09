import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';

void main() {
  group('LessonContent Subtypes Tests', () {
    group('TermContent', () {
      test('should create TermContent', () {
        final content = TermContent(
          id: 'tc1',
          lessonId: 'lesson1',
          order: 0,
          term: 'Test Term',
          definition: 'Test Definition',
          example: 'Test Example',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(content.term, 'Test Term');
        expect(content.definition, 'Test Definition');
        expect(content.example, 'Test Example');
      });

      test('should serialize TermContent to JSON', () {
        final content = TermContent(
          id: 'tc2',
          lessonId: 'lesson1',
          order: 1,
          term: 'Term',
          definition: 'Definition',
          example: 'Example',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final json = content.toJson();
        expect(json['type'], 'term');
        expect(json['term'], 'Term');
        expect(json['definition'], 'Definition');
      });
    });

    group('QuestionContent', () {
      test('should create QuestionContent', () {
        final content = QuestionContent(
          id: 'qc1',
          lessonId: 'lesson1',
          order: 0,
          questionText: 'What is 2+2?',
          options: ['3', '4', '5'],
          correctAnswer: 1,
          explanation: 'Basic math',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(content.questionText, 'What is 2+2?');
        expect(content.options.length, 3);
        expect(content.correctAnswer, 1);
        expect(content.type, 'question');
      });

      test('should serialize QuestionContent to JSON', () {
        final content = QuestionContent(
          id: 'qc2',
          lessonId: 'lesson1',
          order: 1,
          questionText: 'Question?',
          options: ['A', 'B'],
          correctAnswer: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final json = content.toJson();
        expect(json['type'], 'question');
        expect(json['questionText'], 'Question?');
        expect(json['options'], ['A', 'B']);
        expect(json['correctAnswer'], 0);
      });
    });

    group('ConceptContent', () {
      test('should create ConceptContent', () {
        final content = ConceptContent(
          id: 'cc1',
          lessonId: 'lesson1',
          order: 0,
          conceptText: 'Test Concept',
          exampleText: 'Test Example',
          keyPoints: ['Point 1', 'Point 2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        expect(content.conceptText, 'Test Concept');
        expect(content.exampleText, 'Test Example');
        expect(content.keyPoints?.length, 2);
      });

      test('should serialize ConceptContent to JSON', () {
        final content = ConceptContent(
          id: 'cc2',
          lessonId: 'lesson1',
          order: 1,
          conceptText: 'Concept',
          exampleText: 'Example',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final json = content.toJson();
        expect(json['type'], 'concept');
        expect(json['conceptText'], 'Concept');
        expect(json['exampleText'], 'Example');
      });
    });
  });
}

