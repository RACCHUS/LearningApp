import 'package:learning_pwa/models/local_lesson.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:uuid/uuid.dart';

class LocalLessonService {
  final HiveService _hiveService;

  LocalLessonService(this._hiveService);

  Future<LocalLesson> createLesson({
    required String title,
    required String description,
    required String userId,
    List<String> tags = const [],
  }) async {
    final lesson = LocalLesson(
      id: const Uuid().v4(),
      title: title,
      description: description,
      tags: tags,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Store the lesson in Hive
    await _hiveService.cacheLocalLesson(lesson);
    
    return lesson;
  }

  Future<void> updateLesson(LocalLesson lesson) async {
    final updatedLesson = lesson.copyWith(updatedAt: DateTime.now());
    await _hiveService.cacheLocalLesson(updatedLesson);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _hiveService.deleteLocalLesson(lessonId);
  }

  Future<List<LocalLesson>> getUserLessons(String userId) async {
    return await _hiveService.getLocalLessons(userId);
  }

  Future<LocalLesson?> getLesson(String lessonId) async {
    return await _hiveService.getLocalLesson(lessonId);
  }
}
