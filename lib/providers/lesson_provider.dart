import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// Provider to fetch all lessons (for home screen, not filtered by user_id)
final allLessonsProvider = FutureProvider<List<Lesson>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('lessons')
      .select('*')
      .order('created_at', ascending: false);
  // Defensive: ensure response is a List (Supabase returns List)
  return (response as List).map((e) => Lesson(
    id: e['id'] as String,
    title: e['title'] as String,
    description: e['description'] as String?,
    tags: e['tags'] != null ? List<String>.from(e['tags']) : <String>[],
    createdAt: DateTime.parse(e['created_at'] as String),
    updatedAt: DateTime.parse(e['updated_at'] as String),
    userId: e['user_id'] as String? ?? '00000000-0000-0000-0000-000000000000',
    terms: <Term>[],
    questions: <Question>[],
    concepts: <Concept>[],
  )).toList();
});

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
        'user_id': createdBy,  // Use user_id as per schema
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
              // Insert term with direct lesson_id foreign key
              await _supabase.from('terms').insert({
                'id': contentId,
                'lesson_id': lessonId,  // Direct foreign key
                'term': item['term'],
                'definition': item['definition'],
                'example': item['example'],
                'user_id': createdBy,
                'created_at': DateTime.now().toIso8601String(),
              });
              break;
              
            case 'question':
              // Insert question with direct lesson_id foreign key
              await _supabase.from('questions').insert({
                'id': contentId,
                'lesson_id': lessonId,  // Direct foreign key
                'question_text': item['question_text'],
                'options': item['options'],
                'correct_answer': item['correct_answer'],
                'explanation': item['explanation'],
                'user_id': createdBy,
                'created_at': DateTime.now().toIso8601String(),
              });
              break;
              
            case 'concept':
              // Insert concept with direct lesson_id foreign key
              await _supabase.from('concepts').insert({
                'id': contentId,
                'lesson_id': lessonId,  // Direct foreign key
                'concept_text': item['concept_text'],
                'example_text': item['example_text'],
                'key_points': item['key_points'],
                'user_id': createdBy,
                'created_at': DateTime.now().toIso8601String(),
              });
              break;
              
            // Add cases for other content types as needed
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
  
  try {
    log('🚀 Starting lesson load for ID: $lessonId', name: 'LessonProvider');
    
    // Get lesson with content using direct foreign key relationships
    final response = await supabase
        .from('lessons')
        .select('*')
        .eq('id', lessonId)
        .single();

    log('✅ Lesson data loaded successfully', name: 'LessonProvider');

    // Get related content separately using direct foreign keys with individual error handling
    dynamic termsData;
    dynamic questionsData;
    dynamic conceptsData;
    
    try {
      termsData = await supabase
          .from('terms')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');
      log('✅ Terms query completed. Type: ${termsData.runtimeType}, Data: $termsData', name: 'LessonProvider');
    } catch (e) {
      log('❌ Terms query failed: $e', name: 'LessonProvider');
      termsData = <dynamic>[];
    }
    
    try {
      questionsData = await supabase
          .from('questions')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');
      log('✅ Questions query completed. Type: ${questionsData.runtimeType}, Data: $questionsData', name: 'LessonProvider');
    } catch (e) {
      log('❌ Questions query failed: $e', name: 'LessonProvider');
      questionsData = <dynamic>[];
    }
        
    try {
      conceptsData = await supabase
          .from('concepts')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');
      log('✅ Concepts query completed. Type: ${conceptsData.runtimeType}, Data: $conceptsData', name: 'LessonProvider');
    } catch (e) {
      log('❌ Concepts query failed: $e', name: 'LessonProvider');
      conceptsData = <dynamic>[];
    }
    
    // Fetch text content
    List<dynamic> textsData = <dynamic>[];
    try {
      textsData = await supabase
          .from('lesson_texts')
          .select('*')
          .eq('lesson_id', lessonId)
          .order('created_at');
      log('✅ Texts query completed. Type: ${textsData.runtimeType}, Data: $textsData', name: 'LessonProvider');
    } catch (e) {
      log('❌ Texts query failed: $e', name: 'LessonProvider');
      textsData = <dynamic>[];
    }

    // Create lesson manually instead of using fromJson (which expects embedded content)
    final lesson = Lesson(
      id: response['id'] as String,
      title: response['title'] as String,
      description: response['description'] as String?,
      tags: response['tags'] != null ? List<String>.from(response['tags']) : <String>[],
      createdAt: DateTime.parse(response['created_at'] as String),
      updatedAt: DateTime.parse(response['updated_at'] as String),
      userId: response['user_id'] as String? ?? '00000000-0000-0000-0000-000000000000',
      terms: <Term>[], // We'll populate these separately
      questions: <Question>[],
      concepts: <Concept>[],
    );
    
    // Process the responses as Lists with explicit null checks
    final List<dynamic> termsResponse = (termsData is List) ? termsData : [];
    final List<dynamic> questionsResponse = (questionsData is List) ? questionsData : [];
    final List<dynamic> conceptsResponse = (conceptsData is List) ? conceptsData : [];
    final List<dynamic> textsResponse = (textsData is List) ? textsData : [];
    
    log('📊 Processing ${termsResponse.length} terms', name: 'LessonProvider');
    log('📊 Processing ${questionsResponse.length} questions', name: 'LessonProvider');
    log('📊 Processing ${conceptsResponse.length} concepts', name: 'LessonProvider');
    log('📊 Processing ${textsResponse.length} texts', name: 'LessonProvider');
    
    // Map terms directly from response with defensive programming
    final terms = <TermContent>[];
    for (var e in termsResponse) {
      try {
        if (e != null && e is Map<String, dynamic>) {
          terms.add(TermContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: 0, // Default order
            term: e['term']?.toString() ?? '',
            definition: e['definition']?.toString() ?? '',
            example: e['example']?.toString() ?? '',
            createdAt: e['created_at'] != null 
                ? DateTime.tryParse(e['created_at']) ?? DateTime.now()
                : DateTime.now(),
            updatedAt: e['updated_at'] != null 
                ? DateTime.tryParse(e['updated_at']) ?? DateTime.now()
                : DateTime.now(),
          ));
        }
      } catch (e) {
        log('Error processing term: $e', name: 'LessonProvider');
      }
    }
        
    // Map questions directly from response with defensive programming
    final questions = <QuestionContent>[];
    for (var e in questionsResponse) {
      try {
        if (e != null && e is Map<String, dynamic>) {
          questions.add(QuestionContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: 0, // Default order
            questionText: e['question_text']?.toString() ?? '',
            options: e['options'] is List 
                ? List<String>.from(e['options'].map((o) => o?.toString() ?? ''))
                : <String>[],
            correctAnswer: e['correct_answer'] is int ? e['correct_answer'] : 0,
            explanation: e['explanation']?.toString() ?? '',
            createdAt: e['created_at'] != null 
                ? DateTime.tryParse(e['created_at']) ?? DateTime.now()
                : DateTime.now(),
            updatedAt: e['updated_at'] != null 
                ? DateTime.tryParse(e['updated_at']) ?? DateTime.now()
                : DateTime.now(),
          ));
        }
      } catch (e) {
        log('Error processing question: $e', name: 'LessonProvider');
      }
    }
    
    // Map concepts directly from response with defensive programming
    final concepts = <ConceptContent>[];
    for (var e in conceptsResponse) {
      try {
        if (e != null && e is Map<String, dynamic>) {
          concepts.add(ConceptContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: 0, // Default order
            conceptText: e['concept_text']?.toString() ?? '',
            exampleText: e['example_text']?.toString() ?? '',
            keyPoints: e['key_points'] is List 
                ? List<String>.from(e['key_points'].map((k) => k?.toString() ?? ''))
                : null,
            createdAt: e['created_at'] != null 
                ? DateTime.tryParse(e['created_at']) ?? DateTime.now()
                : DateTime.now(),
            updatedAt: e['updated_at'] != null 
                ? DateTime.tryParse(e['updated_at']) ?? DateTime.now()
                : DateTime.now(),
          ));
        }
      } catch (e) {
        log('Error processing concept: $e', name: 'LessonProvider');
      }
    }

    // Map texts directly from response with defensive programming
    final texts = <TextContent>[];
    for (var e in textsResponse) {
      try {
        if (e != null && e is Map<String, dynamic>) {
          texts.add(TextContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: 0, // Default order
            text: e['text']?.toString() ?? '',
            createdAt: e['created_at'] != null 
                ? DateTime.tryParse(e['created_at']) ?? DateTime.now()
                : DateTime.now(),
            updatedAt: e['updated_at'] != null 
                ? DateTime.tryParse(e['updated_at']) ?? DateTime.now()
                : DateTime.now(),
          ));
        }
      } catch (e) {
        log('Error processing text: $e', name: 'LessonProvider');
      }
    }


// --- BEGIN: Preserve JSON order if available, else fallback to type order ---
List<LessonContent> lessonContent;
if (response['content'] is List) {
  // If the lesson JSON has a 'content' array, use its order
  final List<dynamic> contentJson = response['content'];
  lessonContent = [];
  for (final item in contentJson) {
    final type = item['type']?.toString();
    if (type == 'term') {
      final match = terms.where((t) => t.id == item['id']).toList();
      if (match.isNotEmpty) lessonContent.add(match.first);
    } else if (type == 'question' || type == 'mcq') {
      final match = questions.where((q) => q.id == item['id']).toList();
      if (match.isNotEmpty) lessonContent.add(match.first);
    } else if (type == 'concept') {
      final match = concepts.where((c) => c.id == item['id']).toList();
      if (match.isNotEmpty) lessonContent.add(match.first);
    } else if (type == 'text') {
      final match = texts.where((t) => t.id == item['id']).toList();
      if (match.isNotEmpty) lessonContent.add(match.first);
    }
    // Add support for other types as needed
  }
  // Add any content not in the JSON order at the end (defensive)
  for (final t in terms) {
    if (!lessonContent.contains(t)) lessonContent.add(t);
  }
  for (final q in questions) {
    if (!lessonContent.contains(q)) lessonContent.add(q);
  }
  for (final c in concepts) {
    if (!lessonContent.contains(c)) lessonContent.add(c);
  }
  for (final t in texts) {
    if (!lessonContent.contains(t)) lessonContent.add(t);
  }
} else {
  // Fallback: current logic (concepts, terms, questions, texts)
  lessonContent = [...concepts, ...terms, ...questions, ...texts];
  lessonContent.sort((a, b) => a.order.compareTo(b.order));
}

log('Lesson content loaded: ${lessonContent.length} items', name: 'LessonProvider');

return FullLesson(
  lesson: lesson,
  lessonContent: lessonContent,
);
    
  } catch (e, stackTrace) {
    log('Error loading lesson: $e', name: 'LessonProvider', error: e, stackTrace: stackTrace);
    rethrow;
  }
});

class FullLesson {
  final Lesson lesson;
  final List<LessonContent> lessonContent;

  FullLesson({required this.lesson, required this.lessonContent});
}
