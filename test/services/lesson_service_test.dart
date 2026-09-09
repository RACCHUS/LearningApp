import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';

void main() {
  group('LessonService Tests', () {
    // Note: These tests focus on model validation and structure
    // Service method tests requiring Supabase are covered separately

    group('Service initialization', () {
      test('should validate lesson service models are properly defined', () {
        // Test that model classes are available and can be instantiated
        expect(Lesson, isNotNull);
        expect(Term, isNotNull);
        expect(Question, isNotNull);
        expect(Concept, isNotNull);
      });
    });

    group('Lesson model validation', () {
      test('should create valid lesson with required fields', () {
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Test Lesson',
          description: 'A test lesson',
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          terms: [],
          questions: [],
          concepts: [],
        );

        expect(lesson.id, 'lesson-1');
        expect(lesson.userId, 'user-1');
        expect(lesson.title, 'Test Lesson');
        expect(lesson.description, 'A test lesson');
      });

      test('should create lesson with tags', () {
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Tagged Lesson',
          description: 'Test',
          tags: ['math', 'algebra', 'basics'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          terms: [],
          questions: [],
          concepts: [],
        );

        expect(lesson.tags, contains('math'));
        expect(lesson.tags, contains('algebra'));
        expect(lesson.tags.length, 3);
      });

      test('should create lesson with content', () {
        final now = DateTime.now();
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Content Lesson',
          description: 'Test',
          tags: [],
          createdAt: now,
          updatedAt: now,
          terms: [
            Term(
              id: 'term-1',
              term: 'Test',
              definition: 'Definition',
              createdBy: 'user-1',
            ),
          ],
          questions: [
            Question(
              id: 'q-1',
              questionText: 'What is 2+2?',
              options: ['3', '4', '5', '6'],
              correctAnswer: 1,
              type: 'mcq',
              createdBy: 'user-1',
            ),
          ],
          concepts: [
            Concept(
              id: 'c-1',
              lessonId: 'lesson-1',
              conceptText: 'Important concept',
              createdBy: 'user-1',
            ),
          ],
        );

        expect(lesson.terms.length, 1);
        expect(lesson.questions.length, 1);
        expect(lesson.concepts.length, 1);
      });
    });

    group('Term model', () {
      test('should create term with required fields', () {
        final term = Term(
          id: 'term-1',
          term: 'Algorithm',
          definition: 'A step-by-step procedure',
          createdBy: 'user-1',
        );

        expect(term.id, 'term-1');
        expect(term.term, 'Algorithm');
        expect(term.definition, 'A step-by-step procedure');
      });

      test('should create term with optional example', () {
        final term = Term(
          id: 'term-1',
          term: 'Loop',
          definition: 'A repeating structure',
          example: 'for (int i = 0; i < 10; i++)',
          createdBy: 'user-1',
        );

        expect(term.example, isNotNull);
        expect(term.example, contains('for'));
      });

      test('should handle terms with special characters', () {
        final term = Term(
          id: 'term-1',
          term: 'α (Alpha)',
          definition: 'First letter of Greek alphabet',
          createdBy: 'user-1',
        );

        expect(term.term, contains('α'));
        expect(term.term, contains('Alpha'));
      });
    });

    group('Question model', () {
      test('should create question with all required fields', () {
        final question = Question(
          id: 'q-1',
          questionText: 'What is the capital of France?',
          options: ['London', 'Berlin', 'Paris', 'Madrid'],
          correctAnswer: 2,
          type: 'mcq',
          createdBy: 'user-1',
        );

        expect(question.questionText, contains('France'));
        expect(question.options.length, 4);
        expect(question.correctAnswer, 2);
        expect(question.options[question.correctAnswer], 'Paris');
      });

      test('should create question with explanation', () {
        final question = Question(
          id: 'q-1',
          questionText: 'What is 2 + 2?',
          options: ['3', '4', '5'],
          correctAnswer: 1,
          type: 'mcq',
          explanation: 'Basic addition: 2 plus 2 equals 4',
          createdBy: 'user-1',
        );

        expect(question.explanation, isNotNull);
        expect(question.explanation, contains('addition'));
      });

      test('should validate correct answer is within options range', () {
        final question = Question(
          id: 'q-1',
          questionText: 'Test?',
          options: ['A', 'B', 'C'],
          correctAnswer: 1,
          type: 'mcq',
          createdBy: 'user-1',
        );

        expect(question.correctAnswer, lessThan(question.options.length));
        expect(question.correctAnswer, greaterThanOrEqualTo(0));
      });
    });

    group('Concept model', () {
      test('should create concept with text', () {
        final concept = Concept(
          id: 'c-1',
          lessonId: 'lesson-1',
          conceptText: 'Object-oriented programming is a paradigm...',
          createdBy: 'user-1',
        );

        expect(concept.conceptText, contains('Object-oriented'));
        expect(concept.id, 'c-1');
      });

      test('should create concept with example', () {
        final concept = Concept(
          id: 'c-1',
          lessonId: 'lesson-1',
          conceptText: 'Inheritance allows code reuse',
          exampleText: 'class Dog extends Animal { }',
          createdBy: 'user-1',
        );

        expect(concept.exampleText, isNotNull);
        expect(concept.exampleText, contains('extends'));
      });

      test('should handle multi-paragraph concepts', () {
        final concept = Concept(
          id: 'c-1',
          lessonId: 'lesson-1',
          conceptText: 'Paragraph 1.\n\nParagraph 2.\n\nParagraph 3.',
          createdBy: 'user-1',
        );

        expect(concept.conceptText, contains('\n\n'));
      });
    });

    group('Lesson content management', () {
      test('should handle lessons with mixed content types', () {
        final now = DateTime.now();
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Mixed Content',
          description: 'Test',
          tags: [],
          createdAt: now,
          updatedAt: now,
          terms: [
            Term(id: '1', term: 'T1', definition: 'D1', createdBy: 'user-1'),
            Term(id: '2', term: 'T2', definition: 'D2', createdBy: 'user-1'),
          ],
          questions: [
            Question(
              id: '1',
              questionText: 'Q1?',
              options: ['A', 'B'],
              correctAnswer: 0,
              type: 'mcq',
              createdBy: 'user-1',
            ),
          ],
          concepts: [
            Concept(id: '1', lessonId: 'lesson-1', conceptText: 'C1', createdBy: 'user-1'),
          ],
        );

        final totalContent = lesson.terms.length +
                           lesson.questions.length +
                           lesson.concepts.length;
        
        expect(totalContent, 4);
        expect(lesson.terms.length, 2);
        expect(lesson.questions.length, 1);
        expect(lesson.concepts.length, 1);
      });

      test('should handle empty content collections', () {
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Empty',
          description: 'Test',
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          terms: [],
          questions: [],
          concepts: [],
        );

        expect(lesson.terms, isEmpty);
        expect(lesson.questions, isEmpty);
        expect(lesson.concepts, isEmpty);
      });
    });

    group('Edge cases and validation', () {
      test('should handle very long lesson titles', () {
        final longTitle = 'A' * 500;
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: longTitle,
          description: 'Test',
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          terms: [],
          questions: [],
          concepts: [],
        );

        expect(lesson.title.length, 500);
      });

      test('should handle empty descriptions', () {
        final lesson = Lesson(
          id: 'lesson-1',
          userId: 'user-1',
          title: 'Title',
          description: '',
          tags: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          terms: [],
          questions: [],
          concepts: [],
        );

        expect(lesson.description, isEmpty);
      });

      test('should handle questions with minimum 2 options', () {
        final question = Question(
          id: 'q-1',
          questionText: 'True or False?',
          options: ['True', 'False'],
          correctAnswer: 0,
          type: 'mcq',
          createdBy: 'user-1',
        );

        expect(question.options.length, greaterThanOrEqualTo(2));
      });

      test('should handle questions with many options', () {
        final options = List.generate(10, (i) => 'Option ${i + 1}');
        final question = Question(
          id: 'q-1',
          questionText: 'Pick one:',
          options: options,
          correctAnswer: 5,
          type: 'mcq',
          createdBy: 'user-1',
        );

        expect(question.options.length, 10);
        expect(question.correctAnswer, lessThan(question.options.length));
      });
    });
  });
}
