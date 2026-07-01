import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'dart:convert';

// Mock services for testing
class MockLessonCrudService implements LessonCrudService {
  final List<Lesson> _lessons = [];
  
  @override
  Future<Lesson> addLesson(
    String title,
    String? description,
    String userId, {
    List<String>? tags,
  }) async {
    final lesson = Lesson(
      id: 'mock-lesson-${_lessons.length + 1}',
      title: title,
      description: description,
      tags: tags ?? [],
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      terms: [],
      questions: [],
      concepts: [],
    );
    _lessons.add(lesson);
    return lesson;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLessonContentService implements LessonContentService {
  final Map<String, List<Term>> addedTerms = {};
  final Map<String, List<Question>> addedQuestions = {};
  final Map<String, List<Concept>> addedConcepts = {};

  @override
  Future<void> addTerms(String lessonId, List<Term> terms) async {
    addedTerms.putIfAbsent(lessonId, () => []).addAll(terms);
  }

  @override
  Future<void> addQuestions(String lessonId, List<Question> questions) async {
    addedQuestions.putIfAbsent(lessonId, () => []).addAll(questions);
  }

  @override
  Future<void> addConcepts(String lessonId, List<Concept> concepts) async {
    addedConcepts.putIfAbsent(lessonId, () => []).addAll(concepts);
  }

  @override
  Future<Map<String, int>> getContentCounts(String lessonId) async {
    return {
      'terms': addedTerms[lessonId]?.length ?? 0,
      'questions': addedQuestions[lessonId]?.length ?? 0,
      'concepts': addedConcepts[lessonId]?.length ?? 0,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('LessonImportService', () {
    late LessonImportService service;
    late MockLessonCrudService mockCrudService;
    late MockLessonContentService mockContentService;

    setUp(() {
      mockCrudService = MockLessonCrudService();
      mockContentService = MockLessonContentService();
      service = LessonImportService(
        crudService: mockCrudService,
        contentService: mockContentService,
      );
    });

    group('importLessonFromJson()', () {
      test('parses valid JSON', () async {
        final jsonString = jsonEncode({
          'title': 'Test Lesson',
          'description': 'Test Description',
          'tags': ['test', 'demo'],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson.title, 'Test Lesson');
        expect(lesson.description, 'Test Description');
        expect(lesson.tags, ['test', 'demo']);
      });

      test('throws on missing title', () async {
        final jsonString = jsonEncode({
          'description': 'No title',
        });

        expect(
          () => service.importLessonFromJson(jsonString, 'user-1'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws on empty title', () async {
        final jsonString = jsonEncode({
          'title': '   ',
          'description': 'Empty title',
        });

        expect(
          () => service.importLessonFromJson(jsonString, 'user-1'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('extracts tags as List<String>', () async {
        final jsonString = jsonEncode({
          'title': 'Tagged Lesson',
          'tags': ['tag1', 'tag2', 'tag3'],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson.tags, isA<List<String>>());
        expect(lesson.tags, ['tag1', 'tag2', 'tag3']);
      });

      test('handles missing tags', () async {
        final jsonString = jsonEncode({
          'title': 'No Tags',
          'description': 'Lesson without tags',
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson.tags, isEmpty);
      });

      test('handles null description', () async {
        final jsonString = jsonEncode({
          'title': 'Title Only',
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson.title, 'Title Only');
        expect(lesson.description, isNull);
      });

      test('handles malformed JSON gracefully', () async {
        final badJson = '{invalid json}';

        expect(
          () => service.importLessonFromJson(badJson, 'user-1'),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles non-object JSON', () async {
        final jsonString = jsonEncode(['array', 'not', 'object']);

        expect(
          () => service.importLessonFromJson(jsonString, 'user-1'),
          throwsA(anything), // Will fail when accessing as Map
        );
      });
    });

    group('Content import', () {
      test('imports lesson with terms', () async {
        final jsonString = jsonEncode({
          'title': 'Lesson with Terms',
          'terms': [
            {'term': 'Term 1', 'definition': 'Definition 1'},
            {'term': 'Term 2', 'definition': 'Definition 2'},
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson, isNotNull);
        expect(lesson.title, 'Lesson with Terms');
      });

      test('imports lesson with questions', () async {
        final jsonString = jsonEncode({
          'title': 'Lesson with Questions',
          'questions': [
            {
              'question': 'What is 2+2?',
              'options': ['2', '3', '4', '5'],
              'correctAnswer': 2,
            },
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson, isNotNull);
        expect(lesson.title, 'Lesson with Questions');
      });

      test('imports lesson with concepts', () async {
        final jsonString = jsonEncode({
          'title': 'Lesson with Concepts',
          'concepts': [
            {'text': 'Concept 1', 'example': 'Example 1'},
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson, isNotNull);
        expect(lesson.title, 'Lesson with Concepts');
      });

      test('imports lesson with mixed content', () async {
        final jsonString = jsonEncode({
          'title': 'Complete Lesson',
          'description': 'Has all content types',
          'tags': ['comprehensive'],
          'terms': [
            {'term': 'Term', 'definition': 'Def'},
          ],
          'questions': [
            {
              'question': 'Q?',
              'options': ['a', 'b'],
              'correctAnswer': 0,
            },
          ],
          'concepts': [
            {'text': 'Concept'},
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson, isNotNull);
        expect(lesson.title, 'Complete Lesson');
        expect(lesson.tags, ['comprehensive']);
      });

      test('handles generic content array', () async {
        final jsonString = jsonEncode({
          'title': 'Generic Content',
          'content': [
            {'type': 'term', 'term': 'T', 'definition': 'D'},
            {'type': 'mcq', 'question': 'Q', 'options': ['a', 'b'], 'correctAnswer': 0},
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'user-1',
        );

        expect(lesson, isNotNull);
      });
    });

    group('User ID handling', () {
      test('assigns correct userId to imported lesson', () async {
        final jsonString = jsonEncode({
          'title': 'User Test',
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'specific-user-123',
        );

        expect(lesson.userId, 'specific-user-123');
      });
    });

    group('Error scenarios', () {
      test('rethrows errors during import', () async {
        final jsonString = jsonEncode({
          'title': null, // Invalid title
        });

        expect(
          () => service.importLessonFromJson(jsonString, 'user-1'),
          throwsA(anything),
        );
      });

      test('handles empty JSON object', () async {
        final jsonString = jsonEncode({});

        expect(
          () => service.importLessonFromJson(jsonString, 'user-1'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Integration scenarios', () {
      test('successfully imports complex lesson structure', () async {
        final jsonString = jsonEncode({
          'title': 'Advanced Math',
          'description': 'Learn advanced mathematics',
          'tags': ['math', 'advanced', 'algebra'],
          'terms': [
            {'term': 'Variable', 'definition': 'A symbol representing a value'},
            {'term': 'Equation', 'definition': 'Mathematical statement'},
          ],
          'questions': [
            {
              'question': 'What is x + 5 when x = 3?',
              'options': ['5', '8', '15', '3'],
              'correctAnswer': 1,
            },
          ],
          'concepts': [
            {
              'text': 'Variables are fundamental to algebra',
              'example': 'x = 5',
            },
          ],
        });

        final lesson = await service.importLessonFromJson(
          jsonString,
          'teacher-1',
        );

        expect(lesson.title, 'Advanced Math');
        expect(lesson.description, 'Learn advanced mathematics');
        expect(lesson.tags, hasLength(3));
        expect(lesson.userId, 'teacher-1');
      });
    });
  });
}
