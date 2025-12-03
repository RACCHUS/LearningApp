import 'package:learning_pwa/models/local_lesson.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/services/local_lesson_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class LessonCreationService {
  final LocalLessonService _localLessonService;
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  LessonCreationService(this._localLessonService);

  Future<LocalLesson> createLessonWithContent({
    required String title,
    required String description,
    required List<String> tags,
    required List<LessonContent> contents,
    required String userId,
  }) async {
    // Validate input data
    if (!validateLessonData(title: title, contents: contents)) {
      throw Exception('Invalid lesson data: title and contents are required');
    }

    // Create the lesson first
    final lesson = await _localLessonService.createLesson(
      title: title,
      description: description,
      userId: userId,
      tags: tags,
    );

    // Store content in Supabase based on type
    try {
      await _storeContentInSupabase(lesson.id, contents, userId);
    } catch (e) {
      // If content storage fails, we should clean up the lesson
      await _localLessonService.deleteLesson(lesson.id);
      throw Exception('Failed to store lesson content: $e');
    }
    
    return lesson;
  }

  /// Store lesson content in appropriate Supabase tables
  Future<void> _storeContentInSupabase(
    String lessonId,
    List<LessonContent> contents,
    String userId,
  ) async {
    final terms = <Map<String, dynamic>>[];
    final concepts = <Map<String, dynamic>>[];
    final questions = <Map<String, dynamic>>[];

    // Organize content by type
    for (var i = 0; i < contents.length; i++) {
      final content = contents[i];
      
      if (content is TermContent) {
        terms.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'term': content.term,
          'definition': content.definition,
          'example': content.example,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else if (content is ConceptContent) {
        concepts.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'concept_text': content.conceptText,
          'example_text': content.exampleText,
          'key_points': content.keyPoints ?? [],
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else if (content is QuestionContent) {
        questions.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'question_text': content.questionText,
          'options': content.options,
          'correct_answer': content.correctAnswer,
          'type': content.type,
          'explanation': content.explanation,
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    // Batch insert into Supabase
    if (terms.isNotEmpty) {
      await _supabase.from('terms').insert(terms);
    }
    if (concepts.isNotEmpty) {
      await _supabase.from('concepts').insert(concepts);
    }
    if (questions.isNotEmpty) {
      await _supabase.from('questions').insert(questions);
    }
  }

  /// Update existing lesson content
  Future<void> updateLessonContent({
    required String lessonId,
    required List<LessonContent> contents,
    required String userId,
  }) async {
    // Delete existing content for this lesson
    await _supabase.from('terms').delete().eq('lesson_id', lessonId);
    await _supabase.from('concepts').delete().eq('lesson_id', lessonId);
    await _supabase.from('questions').delete().eq('lesson_id', lessonId);

    // Re-insert updated content
    await _storeContentInSupabase(lessonId, contents, userId);
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
