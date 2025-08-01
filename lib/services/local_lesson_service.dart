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

    // Note: For now, we'll store this as a regular lesson since HiveService expects Lesson type
    // TODO: Update HiveService to handle LocalLesson or create a separate storage method
    
    return lesson;
  }

  Future<void> updateLesson(LocalLesson lesson) async {
    // TODO: Implement update logic with timestamp
    // final updatedLesson = lesson.copyWith(updatedAt: DateTime.now());
  }

  Future<void> deleteLesson(String lessonId) async {
    await _hiveService.deleteLessonOffline(lessonId);
  }

  Future<List<LocalLesson>> getUserLessons(String userId) async {
    // TODO: Implement proper filtering for local lessons
    return [];
  }

  Future<LocalLesson?> getLesson(String lessonId) async {
    // TODO: Implement proper local lesson retrieval
    return null;
  }
}
