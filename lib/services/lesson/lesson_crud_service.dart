import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';

/// Maximum number of characters accepted for a lesson title.
const int kMaxLessonTitleLength = 200;

/// Maximum number of characters accepted for a lesson description.
const int kMaxLessonDescriptionLength = 2000;

/// Default page size for list queries to avoid unbounded reads.
const int kLessonsPageSize = 100;

/// Service for lesson CRUD operations
///
/// Handles basic create, read, update, delete operations
/// for lessons in Supabase database.
class LessonCrudService {
  final SupabaseClient _supabase;

  LessonCrudService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Get all lessons for a user
  Future<List<Lesson>> getLessonsForUser(
    String userId, {
    int limit = kLessonsPageSize,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔍 DEBUG: Getting lessons for user: $userId');
      debugPrint('🔍 DEBUG: Supabase client: ${_supabase.toString()}');

      // Fall back to the current auth session if the caller passed nothing.
      if (userId.trim().isEmpty) {
        userId = _supabase.auth.currentUser?.id ?? '';
      }
      if (userId.trim().isEmpty) {
        // No session at all — only legacy/public lessons are visible.
        final response = await _supabase
            .from('lessons')
            .select('*')
            .filter('user_id', 'is', null)
            .order('updated_at', ascending: false)
            .range(offset, offset + limit - 1);
        return (response as List)
            .map<Lesson>((data) => Lesson(
                  id: data['id']?.toString() ?? '',
                  title: data['title']?.toString() ?? 'Untitled',
                  description: data['description']?.toString(),
                  tags: data['tags'] is List
                      ? List<String>.from(data['tags'])
                      : <String>[],
                  createdAt: data['created_at'] != null
                      ? DateTime.parse(data['created_at'])
                      : DateTime.now(),
                  updatedAt: data['updated_at'] != null
                      ? DateTime.parse(data['updated_at'])
                      : DateTime.now(),
                  userId: data['user_id']?.toString() ?? '',
                  terms: <Term>[],
                  questions: <Question>[],
                  concepts: <Concept>[],
                ))
            .toList();
      }

      // Get user's own lessons + public lessons (where user_id is null)
      final response = await _supabase
          .from('lessons')
          .select('*')
          .or('user_id.eq.$userId,user_id.is.null')
          .order('updated_at', ascending: false)
          .range(offset, offset + limit - 1);

      debugPrint('🔍 DEBUG: Query response type: ${response.runtimeType}');
      debugPrint('🔍 DEBUG: Response data: $response');

      // Handle empty response
      if (response.isEmpty) {
        debugPrint('🔍 DEBUG: Empty response received');
        return [];
      }

      debugPrint('🔍 DEBUG: Processing ${response.length} lessons');
      return (response as List)
          .map<Lesson>((data) => Lesson(
                id: data['id']?.toString() ?? '',
                title: data['title']?.toString() ?? 'Untitled',
                description: data['description']?.toString(),
                tags: data['tags'] is List
                    ? List<String>.from(data['tags'])
                    : <String>[],
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
              ))
          .toList();
    } on PostgrestException catch (e, stackTrace) {
      // Log full error details securely, never expose to user
      if (kDebugMode) {
        debugPrint('❌ Database error getting lessons: ${e.message}');
      }
      
      // Throw instead of returning empty list - let caller handle
      throw DatabaseException(
        'Failed to load lessons',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error getting lessons: $e');
      }
      throw DatabaseException(
        'Failed to load lessons',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Get a lesson with all its content
  Future<Lesson> getLesson(String lessonId) async {
    try {
      debugPrint(
          '🔍 DEBUG: Getting lesson with content for lessonId: $lessonId');

      // Get the lesson with all related content
      final response = await _supabase.from('lessons').select('''
            *,
            terms(*),
            questions(*),
            concepts(*)
          ''').eq('id', lessonId).single();

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
    } on PostgrestException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error getting lesson: ${e.message}');
      }
      throw DatabaseException(
        'Failed to load lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error getting lesson: $e');
      }
      throw DatabaseException(
        'Failed to load lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
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
  Future<Lesson> addLesson(String title, String? description, String userId,
      {List<String>? tags}) async {
    try {
      debugPrint('🔍 DEBUG: Adding lesson for user: $userId');
      debugPrint('🔍 DEBUG: Title: $title, Description: $description');

      // Validate inputs
      if (title.trim().isEmpty) {
        throw ArgumentError('Lesson title cannot be empty');
      }
      if (title.trim().length > kMaxLessonTitleLength) {
        throw ArgumentError(
          'Lesson title must be $kMaxLessonTitleLength characters or fewer.',
        );
      }
      if (description != null &&
          description.trim().length > kMaxLessonDescriptionLength) {
        throw ArgumentError(
          'Lesson description must be $kMaxLessonDescriptionLength characters or fewer.',
        );
      }

      if (userId.trim().isEmpty) {
        userId = _supabase.auth.currentUser?.id ?? '';
      }
      if (userId.trim().isEmpty) {
        throw AuthenticationException(
          'You must be signed in (or continue as guest) to create a lesson.',
        );
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

      final response =
          await _supabase.from('lessons').insert(lessonData).select().single();

      debugPrint('✅ Lesson added successfully: ${response['id']}');

      return Lesson(
        id: response['id'].toString(),
        title: response['title'].toString(),
        description: response['description']?.toString(),
        tags: response['tags'] is List
            ? List<String>.from(response['tags'])
            : <String>[],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'].toString(),
        terms: <Term>[],
        questions: <Question>[],
        concepts: <Concept>[],
      );
    } on PostgrestException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error adding lesson: ${e.message}');
      }
      if (e.message.contains('guest_lesson_limit_reached')) {
        throw InvalidInputException(
          'You\'ve reached the guest limit of 5 lessons. Sign up with Google to create more.',
          code: 'GUEST_LESSON_LIMIT',
        );
      }
      throw DatabaseException(
        'Failed to create lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error adding lesson: $e');
      }
      throw DatabaseException(
        'Failed to create lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a lesson and all its content from Supabase
  Future<void> deleteLessonFromSupabase(String lessonId) async {
    try {
      debugPrint(
          '🔍 DEBUG: Deleting lesson and all related content for lessonId: $lessonId');
      // Delete from child tables first if ON DELETE CASCADE is not set in Supabase
      // If ON DELETE CASCADE is set, deleting from lessons will remove all related content
      await _supabase.from('lessons').delete().eq('id', lessonId);
      debugPrint('✅ Lesson and related content deleted from Supabase');
    } on PostgrestException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error deleting lesson: ${e.message}');
      }
      throw DatabaseException(
        'Failed to delete lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error deleting lesson: $e');
      }
      throw DatabaseException(
        'Failed to delete lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update lesson metadata
  Future<Lesson> updateLesson(
    String lessonId, {
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
        tags: response['tags'] is List
            ? List<String>.from(response['tags'])
            : <String>[],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
        userId: response['user_id'].toString(),
        terms: <Term>[],
        questions: <Question>[],
        concepts: <Concept>[],
      );
    } on PostgrestException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error updating lesson: ${e.message}');
      }
      throw DatabaseException(
        'Failed to update lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error updating lesson: $e');
      }
      throw DatabaseException(
        'Failed to update lesson',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
