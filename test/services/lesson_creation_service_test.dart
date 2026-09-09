import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/services/lesson_creation_service.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';
import 'package:learning_pwa/services/hive_service.dart';
import '../test_helpers/fake_supabase_client.dart';

class _NoopLocalLessonService extends LocalLessonService {
  _NoopLocalLessonService() : super(_DummyHiveService());
}

class _DummyHiveService implements HiveService {
  @override
  noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('LessonCreationService', () {
    late LessonCreationService service;

    setUp(() {
      service = LessonCreationService(
        _NoopLocalLessonService(),
        supabase: FakeSupabaseClient(),
      );
    });

    group('parseTags', () {
      test('splits tags by comma and trims whitespace', () {
        final tags = service.parseTags(' math, science , , ');
        expect(tags, ['math', 'science']);
      });

      test('handles tags with no spaces', () {
        final tags = service.parseTags('math,science,physics');
        expect(tags, ['math', 'science', 'physics']);
      });

      test('removes empty tags', () {
        final tags = service.parseTags('math,,science,,,');
        expect(tags, ['math', 'science']);
      });

      test('handles single tag', () {
        final tags = service.parseTags('mathematics');
        expect(tags, ['mathematics']);
      });

      test('handles empty string', () {
        final tags = service.parseTags('');
        expect(tags, isEmpty);
      });

      test('handles only commas and spaces', () {
        final tags = service.parseTags(', , , ');
        expect(tags, isEmpty);
      });

      test('preserves tag casing', () {
        final tags = service.parseTags('Math, SCIENCE, Physics');
        expect(tags, ['Math', 'SCIENCE', 'Physics']);
      });
    });

    group('validateLessonData', () {
      test('returns true for valid lesson with title and content', () {
        final valid = service.validateLessonData(
          title: 'My Lesson',
          contents: [
            TermContent(
              id: 'test_id',
              lessonId: 'test_lesson',
              order: 0,
              term: 'term',
              definition: 'definition',
              example: 'example',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          ],
        );
        expect(valid, isTrue);
      });

      test('returns false for empty title', () {
        final invalid = service.validateLessonData(
          title: '',
          contents: [
            TermContent(
              id: 'test_id',
              lessonId: 'test_lesson',
              order: 0,
              term: 'term',
              definition: 'definition',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          ],
        );
        expect(invalid, isFalse);
      });

      test('returns false for whitespace-only title', () {
        final invalid = service.validateLessonData(
          title: '   ',
          contents: [
            TermContent(
              id: 'test_id',
              lessonId: 'test_lesson',
              order: 0,
              term: 'term',
              definition: 'definition',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          ],
        );
        expect(invalid, isFalse);
      });

      test('returns false for empty contents list', () {
        final invalid = service.validateLessonData(
          title: 'Valid Title',
          contents: [],
        );
        expect(invalid, isFalse);
      });

      test('returns false for both empty title and contents', () {
        final invalid = service.validateLessonData(
          title: '',
          contents: [],
        );
        expect(invalid, isFalse);
      });

      test('accepts multiple content items', () {
        final valid = service.validateLessonData(
          title: 'Multi-content Lesson',
          contents: [
            TermContent(
              id: '1',
              lessonId: 'test',
              order: 0,
              term: 'term1',
              definition: 'def1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            QuestionContent(
              id: '2',
              lessonId: 'test',
              order: 1,
              questionText: 'Question?',
              options: ['A', 'B', 'C'],
              correctAnswer: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            ConceptContent(
              id: '3',
              lessonId: 'test',
              order: 2,
              conceptText: 'Concept',
              exampleText: 'Example',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
        );
        expect(valid, isTrue);
      });

      test('accepts question content', () {
        final valid = service.validateLessonData(
          title: 'Quiz Lesson',
          contents: [
            QuestionContent(
              id: 'q1',
              lessonId: 'test',
              order: 0,
              questionText: 'What is 2+2?',
              options: ['3', '4', '5'],
              correctAnswer: 1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
        );
        expect(valid, isTrue);
      });

      test('accepts concept content', () {
        final valid = service.validateLessonData(
          title: 'Concept Lesson',
          contents: [
            ConceptContent(
              id: 'c1',
              lessonId: 'test',
              order: 0,
              conceptText: 'Important concept',
              exampleText: 'Example usage',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ],
        );
        expect(valid, isTrue);
      });
    });

    group('service instantiation', () {
      test('requires LocalLessonService dependency', () {
        expect(
          () => LessonCreationService(
            _NoopLocalLessonService(),
            supabase: FakeSupabaseClient(),
          ),
          returnsNormally,
        );
      });

      test('accepts optional Supabase client for DI', () {
        final fakeClient = FakeSupabaseClient();
        expect(
          () => LessonCreationService(
            _NoopLocalLessonService(),
            supabase: fakeClient,
          ),
          returnsNormally,
        );
      });
    });
  });
}
