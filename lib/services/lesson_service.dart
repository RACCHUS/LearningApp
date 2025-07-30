import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class LessonService {
  final _supabase = Supabase.instance.client;

  // Add a new lesson
  Future<Lesson> addLesson(Lesson lesson) async {
    try {
      final response = await _supabase
          .from('lessons')
          .insert({
            'title': lesson.title,
            'description': lesson.description,
            'tags': lesson.tags,
            'created_by': lesson.createdBy,
          })
          .select()
          .single();
      
      return Lesson.fromJson(response);
    } catch (e) {
      debugPrint('Error adding lesson: $e');
      rethrow;
    }
  }

  // Add lesson content (terms, questions, concepts)
  Future<void> addLessonContent(String lessonId, List<LessonContent> content) async {
    try {
      for (var item in content) {
        final contentMap = item.toJson();
        contentMap['id'] = const Uuid().v4();
        contentMap['lesson_id'] = lessonId;
        contentMap['created_at'] = DateTime.now().toIso8601String();
        
        // Remove the type field as it's not a column in the database
        final type = contentMap.remove('type');
        
        // Insert into the appropriate table based on the content type
        switch (type) {
          case 'term':
            await _supabase.from('terms').insert(contentMap);
            break;
          case 'question':
            await _supabase.from('questions').insert(contentMap);
            break;
          case 'concept':
            await _supabase.from('concepts').insert(contentMap);
            break;
        }
      }
    } catch (e) {
      debugPrint('Error adding lesson content: $e');
      rethrow;
    }
  }

  // Import lesson from JSON
  Future<Lesson> importLessonFromJson(String jsonString, String userId) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Create lesson
      final lesson = await addLesson(Lesson(
        id: '', // Let the database generate the ID
        title: json['title'] as String,
        description: json['description'] as String?,
        tags: List<String>.from(json['tags'] as List),
        createdBy: userId,
        createdAt: DateTime.now(),
      ));

      // Process content
      final List<LessonContent> content = [];
      
      // Add terms
      if (json['terms'] != null) {
        for (var term in json['terms'] as List) {
          content.add(TermContent(
            id: term['id'] ?? const Uuid().v4(),
            term: term['term'] as String,
            definition: term['definition'] as String,
            example: term['example'] as String?,
            createdBy: userId,
          ));
        }
      }

      // Add questions
      if (json['questions'] != null) {
        for (var (index, question) in (json['questions'] as List).indexed) {
          content.add(QuestionContent(
            id: question['id'] ?? const Uuid().v4(),
            questionText: question['question'] as String,
            options: List<String>.from(question['options'] as List),
            correctAnswer: question['correctAnswer'] as int,
            explanation: question['explanation'] as String?,
            createdBy: userId,
            orderIndex: index,
          ));
        }
      }

      // Add concepts
      if (json['concepts'] != null) {
        for (var concept in json['concepts'] as List) {
          content.add(ConceptContent(
            id: concept['id'] ?? const Uuid().v4(),
            conceptText: concept['text'] as String,
            exampleText: concept['example'] as String?,
            keyPoints: concept['keyPoints'] != null 
                ? List<String>.from(concept['keyPoints'] as List) 
                : null,
            createdBy: userId,
          ));
        }
      }

      // Add all content to the lesson
      await addLessonContent(lesson.id, content);
      
      return lesson;
    } catch (e) {
      debugPrint('Error importing lesson from JSON: $e');
      rethrow;
    }
  }
}
