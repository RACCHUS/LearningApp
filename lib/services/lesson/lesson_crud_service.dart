import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service for lesson CRUD operations
/// 
/// Handles basic create, read, update, delete operations
/// for lessons in Supabase database.
class LessonCrudService {
  final SupabaseClient _supabase;

  LessonCrudService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get all lessons for a user
  Future<List<Lesson>> getLessonsForUser(String userId) async {
    try {
      debugPrint('🔍 DEBUG: Getting lessons for user: $userId');
      debugPrint('🔍 DEBUG: Supabase client: ${_supabase.toString()}');
      
      // Validate userId format
      if (userId.trim().isEmpty) {
        debugPrint('🔍 DEBUG: Empty userId, using guest UUID');
        userId = '00000000-0000-0000-0000-000000000000';
      }
      
      // Get user's own lessons + public lessons (where user_id is null)
      final response = await _supabase
          .from('lessons')
          .select('*')
          .or('user_id.eq.$userId,user_id.is.null')
          .order('updated_at', ascending: false);

      debugPrint('🔍 DEBUG: Query response type: ${response.runtimeType}');
      debugPrint('🔍 DEBUG: Response data: $response');

      // Handle empty response
      if (response.isEmpty) {
        debugPrint('🔍 DEBUG: Empty response received');
        return [];
      }

      debugPrint('🔍 DEBUG: Processing ${response.length} lessons');
      return (response as List).map<Lesson>((data) => Lesson(
        id: data['id']?.toString() ?? '',
        title: data['title']?.toString() ?? 'Untitled',
        description: data['description']?.toString(),
        tags: data['tags'] is List ? List<String>.from(data['tags']) : <String>[],
        createdAt: data['created_at'] != null 
            ? DateTime.parse(data['created_at']) 
            : DateTime.now(),
        updatedAt: data['updated_at'] != null 
            ? DateTime.parse(data['updated_at']) 
            : DateTime.now(),
        userId: data['user_id']?.toString() ?? userId,
        terms: <Term>[], // Load separately if needed
        questions: <Question>[], // Load separately if needed
        concepts: <Concept>[], // Load separately if needed
      )).toList();
    } catch (e) {
      debugPrint('❌ ERROR: Error getting lessons for user: $e');
      debugPrint('❌ ERROR: Error type: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('❌ ERROR: Postgrest details - Message: ${e.message}, Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint}');
      }
      return []; // Return empty list instead of rethrowing
    }
  }

  /// Get a lesson with all its content
  Future<Lesson> getLesson(String lessonId) async {
    try {
      debugPrint('🔍 DEBUG: Getting lesson with content for lessonId: $lessonId');
      
      // Get the lesson with all related content
      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            terms(*),
            questions(*),
            concepts(*)
          ''')
          .eq('id', lessonId)
          .single();

      debugPrint('🔍 DEBUG: Lesson response: $response');

      // Transform the response into our Lesson model
      return Lesson(
        id: response['id'],
        title: response['title'],
        description: response['description'],
        tags: List<String>.from(response['tags'] ?? []),
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'],
        terms: _parseTerms(response['terms'] as List<dynamic>?),
        questions: _parseQuestions(response['questions'] as List<dynamic>?),
        concepts: _parseConcepts(response['concepts'] as List<dynamic>?),
      );
    } catch (e) {
      debugPrint('❌ ERROR: Error getting lesson: $e');
      if (e is PostgrestException) {
        debugPrint('❌ ERROR: Postgrest details - Message: ${e.message}, Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint}');
      }
      rethrow;
    }
  }

  /// Parse terms from database response
  List<Term> _parseTerms(List<dynamic>? termsData) {
    if (termsData == null || termsData.isEmpty) {
      return [];
    }
    return termsData
        .map((t) => Term(
              id: t['id'],
              term: t['term'],
              definition: t['definition'],
              example: t['example'],
              createdBy: t['user_id'] ?? '',
            ))
        .toList();
  }

  /// Parse questions from database response
  List<Question> _parseQuestions(List<dynamic>? questionsData) {
    if (questionsData == null || questionsData.isEmpty) {
      return [];
    }
    return questionsData
        .map((q) => Question(
              id: q['id'],
              questionText: q['question_text'],
              correctAnswer: q['correct_answer'],
              options: List<String>.from(q['options']),
              type: q['type'],
              explanation: q['explanation'],
              createdBy: q['user_id'] ?? '',
            ))
        .toList();
  }

  /// Parse concepts from database response
  List<Concept> _parseConcepts(List<dynamic>? conceptsData) {
    if (conceptsData == null || conceptsData.isEmpty) {
      return [];
    }
    return conceptsData
        .map((c) => Concept(
              id: c['id'],
              lessonId: c['lesson_id'],
              conceptText: c['concept_text'],
              exampleText: c['example_text'],
              createdBy: c['user_id'] ?? '',
              createdAt: DateTime.parse(c['created_at']),
            ))
        .toList();
  }

  /// Add a new lesson
  Future<Lesson> addLesson(String title, String? description, String userId, {List<String>? tags}) async {
    try {
      debugPrint('🔍 DEBUG: Adding lesson for user: $userId');
      debugPrint('🔍 DEBUG: Title: $title, Description: $description');
      
      // Validate inputs
      if (title.trim().isEmpty) {
        throw ArgumentError('Lesson title cannot be empty');
      }
      
      if (userId.trim().isEmpty) {
        debugPrint('🔍 DEBUG: Empty userId, using guest UUID');
        userId = '00000000-0000-0000-0000-000000000000';
      }

      // Generate a UUID for the lesson
      final lessonId = const Uuid().v4();
      
      final lessonData = {
        'id': lessonId,
        'title': title.trim(),
        'description': description?.trim(),
        'tags': tags ?? [],
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('🔍 DEBUG: Inserting lesson with data: $lessonData');

      final response = await _supabase
          .from('lessons')
          .insert(lessonData)
          .select()
          .single();

      debugPrint('✅ Lesson added successfully: ${response['id']}');

      return Lesson(
        id: response['id'].toString(),
        title: response['title'].toString(),
        description: response['description']?.toString(),
        tags: response['tags'] is List ? List<String>.from(response['tags']) : <String>[],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'].toString(),
        terms: <Term>[],
        questions: <Question>[],
        concepts: <Concept>[],
      );
    } catch (e) {
      debugPrint('❌ ERROR: Failed to add lesson: $e');
      if (e is PostgrestException) {
        debugPrint('❌ ERROR: Postgrest details - Message: ${e.message}, Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint}');
      }
      rethrow;
    }
  }

  /// Delete a lesson and all its content from Supabase
  Future<void> deleteLessonFromSupabase(String lessonId) async {
    try {
      debugPrint('🔍 DEBUG: Deleting lesson and all related content for lessonId: $lessonId');
      // Delete from child tables first if ON DELETE CASCADE is not set in Supabase
      // If ON DELETE CASCADE is set, deleting from lessons will remove all related content
      await _supabase.from('lessons').delete().eq('id', lessonId);
      debugPrint('✅ Lesson and related content deleted from Supabase');
    } catch (e) {
      debugPrint('❌ ERROR: Failed to delete lesson from Supabase: $e');
      if (e is PostgrestException) {
        debugPrint('❌ ERROR: Postgrest details - Message: [33m${e.message}[0m, Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint}');
      }
      rethrow;
    }
  }

  /// Update lesson metadata
  Future<Lesson> updateLesson(String lessonId, {
    String? title,
    String? description, 
    List<String>? tags,
  }) async {
    try {
      debugPrint('🔍 DEBUG: Updating lesson: $lessonId');
      
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (title != null) updateData['title'] = title.trim();
      if (description != null) updateData['description'] = description.trim();
      if (tags != null) updateData['tags'] = tags;

      final response = await _supabase
          .from('lessons')
          .update(updateData)
          .eq('id', lessonId)
          .select()
          .single();

      debugPrint('✅ Lesson updated successfully');

      return Lesson(
        id: response['id'].toString(),
        title: response['title'].toString(),
        description: response['description']?.toString(),
        tags: response['tags'] is List ? List<String>.from(response['tags']) : <String>[],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'].toString(),
        terms: <Term>[],
        questions: <Question>[],
        concepts: <Concept>[],
      );
    } catch (e) {
      debugPrint('❌ ERROR: Failed to update lesson: $e');
      rethrow;
    }
  }
}
