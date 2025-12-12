import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/services/lesson_creation_service.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';
import 'package:learning_pwa/services/hive_service.dart';

class _NoopLocalLessonService extends LocalLessonService {
  _NoopLocalLessonService() : super(_DummyHiveService());
}

class _DummyHiveService implements HiveService {
  @override
  noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('LessonCreationService - validation', () {
    final service = LessonCreationService(_NoopLocalLessonService());

    test('parseTags splits and trims', () {
      final tags = service.parseTags(' math, science , , ');
      expect(tags, ['math', 'science']);
    });

    test('validateLessonData requires title and at least one content item', () {
      final valid = service.validateLessonData(
        title: 'My Lesson',
        contents: [TermContent(
          id: 'test_id',
          lessonId: 'test_lesson',
          order: 0,
          term: 't',
          definition: 'd',
          example: 'e',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )],
      );
      final missingTitle = service.validateLessonData(title: '', contents: []);

      expect(valid, isTrue);
      expect(missingTitle, isFalse);
    });
  });
}

