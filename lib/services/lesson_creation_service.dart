import 'package:learning_pwa/models/local_lesson.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';

class LessonCreationService {
  final LocalLessonService _localLessonService;

  LessonCreationService(this._localLessonService);

  Future<LocalLesson> createLessonWithContent({
    required String title,
    required String description,
    required List<String> tags,
    required List<LessonContent> contents,
    required String userId,
  }) async {
    // TODO: Implement proper content handling with lesson ID generation
    // final uuid = const Uuid();
    // final lessonId = uuid.v4();

    // Update content with lesson ID and proper order (TODO: implement content storage)
    // final updatedContents = contents.asMap().entries.map((entry) {
    //   final index = entry.key;
    //   final content = entry.value;
    //   
    //   // Create new content with proper lesson ID and order
    //   return _updateContentWithLessonData(content, lessonId, index);
    // }).toList();

    // Create the lesson
    final lesson = await _localLessonService.createLesson(
      title: title,
      description: description,
      userId: userId,
      tags: tags,
    );

    // Note: For now, we don't store content separately
    // In a full implementation, you'd save contents to their respective storage
    
    return lesson;
  }

  List<String> parseTags(String tagsText) {
    if (tagsText.trim().isEmpty) return [];
    
    return tagsText
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }

  bool validateLessonData({
    required String title,
    required List<LessonContent> contents,
  }) {
    if (title.trim().isEmpty) return false;
    if (contents.isEmpty) return false;
    return true;
  }
}
