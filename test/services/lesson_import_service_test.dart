import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:learning_pwa/models/answer_key.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'dart:convert';

// Mock services for testing
class MockLessonCrudService implements LessonCrudService {
  final List<Lesson> lessons = [];
  final List<String> deletedLessonIds = [];
  bool failDelete = false;

  @override
  Future<void> deleteLessonFromSupabase(String lessonId) async {
    if (failDelete) throw StateError('delete failed');
    deletedLessonIds.add(lessonId);
  }
  
  @override
  Future<Lesson> addLesson(
    String title,
    String? description,
    String userId, {
    List<String>? tags,
  }) async {
    final lesson = Lesson(
      id: 'mock-lesson-${lessons.length + 1}',
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
    lessons.add(lesson);
    return lesson;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLessonContentService implements LessonContentService {
  final Map<String, List<Term>> addedTerms = {};
  final Map<String, List<Question>> addedQuestions = {};
  final Map<String, List<Concept>> addedConcepts = {};
  bool failQuestions = false;

  @override
  Future<void> addTerms(String lessonId, List<Term> terms) async {
    addedTerms.putIfAbsent(lessonId, () => []).addAll(terms);
  }

  @override
  Future<void> addQuestions(String lessonId, List<Question> questions) async {
    if (failQuestions) throw StateError('network down');
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
        const badJson = '{invalid json}';

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
              'correct_answer': 2,
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
            {'concept_text': 'Concept 1', 'example': 'Example 1'},
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
              'correct_answer': 0,
            },
          ],
          'concepts': [
            {'concept_text': 'Concept'},
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
            {'type': 'mcq', 'question': 'Q', 'options': ['a', 'b'], 'correct_answer': 0},
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
              'correct_answer': 1,
            },
          ],
          'concepts': [
            {
              'concept_text': 'Variables are fundamental to algebra',
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

    // PR-0a (plan v2.6 §14.8, Appendix G.3): whole-payload preflight, no
    // fabricated answer 0, no silent drops, honest partial writes.
    group('PR-0a answer integrity and preflight', () {
      Future<Object?> importError(Map<String, dynamic> payload) async {
        try {
          await service.importLessonFromJson(jsonEncode(payload), 'u');
          return null;
        } catch (e) {
          return e;
        }
      }

      test('explicit correct_answer 0 imports as 0', () async {
        final lesson = await service.importLessonFromJson(
          jsonEncode({
            'title': 'Zero',
            'questions': [
              {'question': 'Q', 'options': ['a', 'b'], 'correct_answer': 0},
            ],
          }),
          'u',
        );
        expect(
          mockContentService.addedQuestions[lesson.id]!.single.correctAnswer,
          0,
        );
      });

      final badKeys = <String, Object?>{
        'missing': null,
        'blank string': '',
        'non-numeric string': 'b',
        'strict "1" string': '1',
        'out of range': 2,
        'negative': -1,
      };
      for (final entry in badKeys.entries) {
        test('rejects ${entry.key} correct_answer and writes nothing',
            () async {
          final q = <String, dynamic>{
            'question': 'Q',
            'options': ['a', 'b'],
          };
          if (entry.value != null) q['correct_answer'] = entry.value;
          final error = await importError({
            'title': 'Bad',
            'questions': [q],
          });
          expect(error, isA<LessonImportValidationException>());
          final issue =
              (error as LessonImportValidationException).issues.single;
          expect(issue.path, 'questions[0].correct_answer');
          expect(mockContentService.addedQuestions, isEmpty);
          expect(mockCrudService.lessons, isEmpty,
              reason: 'preflight must run before addLesson');
        });
      }

      test('generic content items are validated too, with item paths',
          () async {
        final error = await importError({
          'title': 'Generic',
          'content': [
            {'type': 'term', 'term': 'T', 'definition': 'D'},
            {'type': 'mcq', 'question': 'Q', 'options': ['a', 'b']},
            {'type': 'mystery'},
          ],
        });
        final issues = (error as LessonImportValidationException).issues;
        expect(issues.map((i) => i.path),
            ['content[1].correct_answer', 'content[2].type']);
        expect(mockContentService.addedTerms, isEmpty);
      });

      test('mixed valid/invalid batch imports nothing', () async {
        final error = await importError({
          'title': 'Mixed',
          'questions': [
            {'question': 'ok', 'options': ['a', 'b'], 'correct_answer': 1},
            {'question': 'bad', 'options': ['a', 'b'], 'correct_answer': 5},
          ],
        });
        expect(error, isA<LessonImportValidationException>());
        expect(mockContentService.addedQuestions, isEmpty);
      });

      test('empty terms and concepts are reported, not silently dropped',
          () async {
        final error = await importError({
          'title': 'Drops',
          'terms': [
            {'term': 'T', 'definition': ''},
          ],
          'concepts': [
            {'text': 'wrong key'},
          ],
        });
        expect(
          (error as LessonImportValidationException).issues.map((i) => i.path),
          ['terms[0]', 'concepts[0]'],
        );
      });

      test('guided _answer_error marker blocks import', () async {
        final error = await importError({
          'title': 'Guided',
          'questions': [
            {
              'question': 'Q',
              'options': ['a', 'b'],
              'correct_answer': null,
              '_answer_error': 'invalid_key',
            },
          ],
        });
        expect((error as LessonImportValidationException).issues.single.code,
            'invalid_key');
      });

      test('true_false requires one True and one False label', () async {
        final error = await importError({
          'title': 'TF',
          'questions': [
            {
              'type': 'true_false',
              'question': 'Q',
              'options': ['Yes', 'Maybe'],
              'correct_answer': 0,
            },
          ],
        });
        expect((error as LessonImportValidationException).issues.single.code,
            'unsupported_type');
      });

      test('short answer without accepted answers is rejected', () async {
        final error = await importError({
          'title': 'SA',
          'questions': [
            {'type': 'short_answer', 'question': 'Q', 'options': []},
          ],
        });
        expect((error as LessonImportValidationException).issues.single.code,
            'missing_key');
      });

      test('short answer stores no fabricated MCQ index', () async {
        final lesson = await service.importLessonFromJson(
          jsonEncode({
            'title': 'SA ok',
            'questions': [
              {
                'type': 'short_answer',
                'question': '2+2?',
                'accepted_answers': ['4'],
              },
            ],
          }),
          'u',
        );
        final q = mockContentService.addedQuestions[lesson.id]!.single;
        expect(q.correctAnswer, AnswerKey.unscorableIndex);
        expect(q.acceptedAnswers, ['4']);
      });

      test('write failure after addLesson is reported honestly and cleaned up',
          () async {
        mockContentService.failQuestions = true;
        final error = await importError({
          'title': 'Partial',
          'terms': [
            {'term': 'T', 'definition': 'D'},
          ],
          'questions': [
            {'question': 'Q', 'options': ['a', 'b'], 'correct_answer': 1},
          ],
        });
        expect(error, isA<LessonImportIncompleteException>());
        final incomplete = error as LessonImportIncompleteException;
        expect(incomplete.stage, 'questions');
        expect(incomplete.cleanedUp, isTrue);
        expect(mockCrudService.deletedLessonIds, [incomplete.lessonId]);
      });

      test('failed cleanup says a partial lesson may remain', () async {
        mockContentService.failQuestions = true;
        mockCrudService.failDelete = true;
        final error = await importError({
          'title': 'Partial',
          'questions': [
            {'question': 'Q', 'options': ['a', 'b'], 'correct_answer': 1},
          ],
        });
        final incomplete = error as LessonImportIncompleteException;
        expect(incomplete.cleanedUp, isFalse);
        expect(incomplete.toString(), contains('partial lesson may remain'));
      });
    });
  });
}
