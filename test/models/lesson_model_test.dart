import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';

void main() {
  group('Lesson Model Tests', () {
    final testLesson = Lesson(
      id: 'lesson_001',
      title: 'Test Lesson',
      description: 'Test Description',
      tags: ['test', 'example'],
      createdAt: DateTime(2023, 1, 1),
      updatedAt: DateTime(2023, 1, 2),
      userId: 'user_001',
      terms: [],
      questions: [],
      concepts: [],
    );

    test('should create lesson with all fields', () {
      expect(testLesson.id, 'lesson_001');
      expect(testLesson.title, 'Test Lesson');
      expect(testLesson.description, 'Test Description');
      expect(testLesson.tags, ['test', 'example']);
      expect(testLesson.userId, 'user_001');
    });

    test('should serialize to JSON', () {
      final json = testLesson.toJson();
      
      expect(json['id'], 'lesson_001');
      expect(json['title'], 'Test Lesson');
      expect(json['description'], 'Test Description');
      expect(json['tags'], ['test', 'example']);
      expect(json['user_id'], 'user_001');
      expect(json['terms'], isA<List>());
      expect(json['questions'], isA<List>());
      expect(json['concepts'], isA<List>());
    });

    test('should deserialize from JSON', () {
      final json = {
        'id': 'lesson_002',
        'title': 'Another Lesson',
        'description': 'Another Description',
        'tags': ['tag1', 'tag2'],
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
        'user_id': 'user_002',
        'terms': [],
        'questions': [],
        'concepts': [],
      };
      
      final lesson = Lesson.fromJson(json);
      
      expect(lesson.id, 'lesson_002');
      expect(lesson.title, 'Another Lesson');
      expect(lesson.description, 'Another Description');
      expect(lesson.tags, ['tag1', 'tag2']);
    });

    test('should create copy with modified fields', () {
      final modified = testLesson.copyWith(
        title: 'Modified Title',
        description: 'Modified Description',
      );
      
      expect(modified.title, 'Modified Title');
      expect(modified.description, 'Modified Description');
      expect(modified.id, testLesson.id); // Unchanged
      expect(modified.tags, testLesson.tags); // Unchanged
    });

    test('should handle lesson with content', () {
      final lessonWithContent = Lesson(
        id: 'lesson_003',
        title: 'Content Lesson',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        userId: 'user_001',
        terms: [
          Term(
            id: 'term_001',
            term: 'Test Term',
            definition: 'Test Definition',
            createdBy: 'user_001',
          ),
        ],
        questions: [
          Question(
            id: 'q_001',
            questionText: 'Test Question?',
            options: ['Option 1', 'Option 2'],
            correctAnswer: 0,
            type: 'multiple_choice',
            createdBy: 'user_001',
          ),
        ],
        concepts: [
          Concept(
            id: 'c_001',
            lessonId: 'lesson_003',
            conceptText: 'Test Concept',
            exampleText: 'Test Example',
            createdBy: 'user_001',
          ),
        ],
      );
      
      expect(lessonWithContent.terms.length, 1);
      expect(lessonWithContent.questions.length, 1);
      expect(lessonWithContent.concepts.length, 1);
      
      final json = lessonWithContent.toJson();
      expect(json['terms'].length, 1);
      expect(json['questions'].length, 1);
      expect(json['concepts'].length, 1);
    });
  });
}

