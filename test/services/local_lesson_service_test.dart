import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/local_lesson.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';
import 'package:learning_pwa/services/hive_service.dart';

class _FakeHiveService implements HiveService {
  @override
  noSuchMethod(Invocation invocation) => null;
  final Map<String, LocalLesson> _store = {};

  Future<void> cacheLocalLesson(LocalLesson lesson) async {
    _store[lesson.id] = lesson;
  }

  Future<void> deleteLocalLesson(String lessonId) async {
    _store.remove(lessonId);
  }

  Future<List<LocalLesson>> getLocalLessons(String userId) async {
    return _store.values.where((l) => l.userId == userId).toList();
  }

  Future<LocalLesson?> getLocalLesson(String lessonId) async {
    return _store[lessonId];
  }
}

void main() {
  group('LocalLessonService', () {
    late LocalLessonService service;
    late _FakeHiveService hive;

    setUp(() {
      hive = _FakeHiveService();
      service = LocalLessonService(hive);
    });

    test('createLesson persists and returns lesson', () async {
      final lesson = await service.createLesson(
        title: 'Title',
        description: 'Desc',
        userId: 'user-1',
        tags: const ['a', 'b'],
      );

      expect(lesson.id, isNotEmpty);
      expect(lesson.title, 'Title');
      expect((await hive.getLocalLesson(lesson.id))?.title, 'Title');
    });

    test('updateLesson bumps updatedAt and persists changes', () async {
      final lesson = await service.createLesson(
        title: 'Old',
        description: 'Desc',
        userId: 'user-1',
      );

      final before = lesson.updatedAt;
      final modified = lesson.copyWith(title: 'New');
      await service.updateLesson(modified);

      final stored = await hive.getLocalLesson(lesson.id);
      expect(stored?.title, 'New');
      expect(stored!.updatedAt.isAfter(before), isTrue);
    });

    test('deleteLesson removes lesson', () async {
      final lesson = await service.createLesson(
        title: 'Delete me',
        description: 'Desc',
        userId: 'user-1',
      );

      await service.deleteLesson(lesson.id);

      expect(await hive.getLocalLesson(lesson.id), isNull);
    });
  });
}

