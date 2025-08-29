import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    List<dynamic> termsData;
    List<dynamic> questionsData;
    List<dynamic> conceptsData;
    
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
    final List<dynamic> termsResponse = termsData;
    final List<dynamic> questionsResponse = questionsData;
    final List<dynamic> conceptsResponse = conceptsData;
    final List<dynamic> textsResponse = textsData;
    
    log('📊 Processing ${termsResponse.length} terms', name: 'LessonProvider');
    log('📊 Processing ${questionsResponse.length} questions', name: 'LessonProvider');
    log('📊 Processing ${conceptsResponse.length} concepts', name: 'LessonProvider');
    log('📊 Processing ${textsResponse.length} texts', name: 'LessonProvider');
    
    // Map terms directly from response with defensive programming
    final terms = <TermContent>[];
    for (int i = 0; i < termsResponse.length; i++) {
      var e = termsResponse[i];
      try {
        if (e != null && e is Map<String, dynamic>) {
          // Safe fallback: if order_index is missing, use index + 1 (terms typically start at 1)
          int orderValue = e['order_index'] as int? ?? (i + 1);
          terms.add(TermContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: orderValue,
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
    for (int i = 0; i < questionsResponse.length; i++) {
      var e = questionsResponse[i];
      try {
        if (e != null && e is Map<String, dynamic>) {
          // Safe fallback: if order_index is missing, use 1000 + index (questions typically come last)
          int orderValue = e['order_index'] as int? ?? (1000 + i);
          questions.add(QuestionContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: orderValue,
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
    for (int i = 0; i < conceptsResponse.length; i++) {
      var e = conceptsResponse[i];
      try {
        if (e != null && e is Map<String, dynamic>) {
          // Safe fallback: if order_index is missing, use 500 + index (concepts typically in middle)
          int orderValue = e['order_index'] as int? ?? (500 + i);
          concepts.add(ConceptContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: orderValue,
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
    for (int i = 0; i < textsResponse.length; i++) {
      var e = textsResponse[i];
      try {
        if (e != null && e is Map<String, dynamic>) {
          // Safe fallback: if order_index is missing, use 100 + index (texts typically after terms)
          int orderValue = e['order_index'] as int? ?? (100 + i);
          texts.add(TextContent(
            id: e['id']?.toString() ?? '',
            lessonId: lesson.id,
            order: orderValue,
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

// Check if lesson has the full JSON structure stored in content field
if (response['content'] is Map && response['content']['content'] is List) {
  // If the lesson JSON has a 'content' array, use its order
  log('✅ Using JSON content order from stored lesson structure', name: 'LessonProvider');
  final List<dynamic> contentJson = response['content']['content'];
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
  // Fallback: Sort ALL content by order field only (ignore content type grouping)
  log('⚠️ Using fallback ordering (no JSON content array found)', name: 'LessonProvider');
  lessonContent = [...terms, ...questions, ...concepts, ...texts];
  
  // Debug: Log order values before sorting
  log('Before sorting - Terms orders: ${terms.map((t) => '${t.term}(${t.order})').join(', ')}', name: 'LessonProvider');
  log('Before sorting - Questions orders: ${questions.map((q) => 'Q${q.order}').join(', ')}', name: 'LessonProvider');
  log('Before sorting - Concepts orders: ${concepts.map((c) => 'C${c.order}').join(', ')}', name: 'LessonProvider');
  
  lessonContent.sort((a, b) => a.order.compareTo(b.order));
  
  // Debug: Log final order
  log('Final sorted order: ${lessonContent.map((item) => '${item.type}(${item.order})').join(', ')}', name: 'LessonProvider');
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
