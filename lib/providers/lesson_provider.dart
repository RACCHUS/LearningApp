import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider for creating and managing lessons
final lessonCreationProvider = Provider<LessonRepository>((ref) {
  return LessonRepository();
});

class LessonRepository {
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Create a new lesson with its content
  Future<String> createLesson({
    required String title,
    required String createdBy,
    String? description,
    List<String> tags = const [],
    List<Map<String, dynamic>> content = const [],
  }) async {
    try {
      // Create the lesson
      final lessonId = _uuid.v4();
      
      // First, insert the lesson
      await _supabase.from('lessons').insert({
        'id': lessonId,
        'title': title,
        'description': description,
        'tags': tags,
        'created_by': createdBy,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Process and save content
      for (var item in content) {
        final type = item['type'] as String;
        final contentId = _uuid.v4();
        
        try {
          switch (type) {
            case 'text':
              await _supabase.from('lesson_texts').insert({
                'id': contentId,
                'lesson_id': lessonId,
                'text': item['text'],
                'created_by': createdBy,
                'created_at': DateTime.now().toIso8601String(),
              });
              break;
              
            case 'term':
              // First insert the term
              await _supabase.from('terms').insert({
                'id': contentId,
                'term': item['term'],
                'definition': item['definition'],
                'example': item['example'],
                'created_by': createdBy,
                'created_at': DateTime.now().toIso8601String(),
              });
              
              // Then create the relationship
              await _supabase.from('lesson_terms').insert({
                'lesson_id': lessonId,
                'term_id': contentId,
              });
              break;
              
            // Add cases for other content types (concept, mcq) as needed
          }
        } catch (e) {
          // Log the error but continue with other content items
          log('Error saving content item: $e', name: 'LessonRepository');
          // You might want to collect these errors and show them to the user
        }
      }
      
      return lessonId;
      
    } catch (e) {
      log('Error creating lesson: $e', name: 'LessonRepository');
      rethrow;
    }
  }
}

final lessonProvider =
    FutureProvider.family<FullLesson, String>((ref, lessonId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('lessons')
      .select(
          '*, lesson_terms(terms(*)), lesson_questions(order_index, questions(*)), lesson_concepts(concepts(*))')
      .eq('id', lessonId)
      .single();

  final lesson = Lesson.fromJson(response);
  final terms = (response['lesson_terms'] as List?)
      ?.map((e) => TermContent(
            id: e['terms']['id'],
            lessonId: lesson.id,
            order: e['order_index'] ?? 0,
            term: e['terms']['term'],
            definition: e['terms']['definition'],
            example: e['terms']['example'],
            createdAt: DateTime.parse(e['terms']['created_at'] ?? DateTime.now().toIso8601String()),
            updatedAt: DateTime.parse(e['terms']['updated_at'] ?? DateTime.now().toIso8601String()),
          ))
      .toList() ?? [];
  final questions = (response['lesson_questions'] as List?)
      ?.map((e) => QuestionContent(
            id: e['questions']['id'],
            lessonId: lesson.id,
            order: e['order_index'] ?? 0,
            questionText: e['questions']['question_text'],
            options: List<String>.from(e['questions']['options'] ?? []),
            correctAnswer: e['questions']['correct_answer'],
            explanation: e['questions']['explanation'],
            createdAt: DateTime.parse(e['questions']['created_at'] ?? DateTime.now().toIso8601String()),
            updatedAt: DateTime.parse(e['questions']['updated_at'] ?? DateTime.now().toIso8601String()),
          ))
      .toList() ?? [];
  
  final concepts = (response['lesson_concepts'] as List?)
      ?.map((e) => ConceptContent(
            id: e['concepts']['id'],
            lessonId: lesson.id,
            order: e['order_index'] ?? 0,
            conceptText: e['concepts']['concept_text'],
            exampleText: e['concepts']['example_text'],
            keyPoints: e['concepts']['key_points'] != null 
                ? List<String>.from(e['concepts']['key_points']) 
                : null,
            createdAt: DateTime.parse(e['concepts']['created_at'] ?? DateTime.now().toIso8601String()),
            updatedAt: DateTime.parse(e['concepts']['updated_at'] ?? DateTime.now().toIso8601String()),
          ))
      .toList() ?? [];

  final List<LessonContent> lessonContent = [...terms, ...questions, ...concepts];
  lessonContent.sort((a, b) => a.order.compareTo(b.order));

  return FullLesson(
    lesson: lesson,
    lessonContent: lessonContent,
  );
});

class FullLesson {
  final Lesson lesson;
  final List<LessonContent> lessonContent;

  FullLesson({required this.lesson, required this.lessonContent});
}
