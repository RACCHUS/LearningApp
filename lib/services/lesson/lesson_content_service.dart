import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service for managing lesson content
///
/// Handles adding terms, questions, and concepts to lessons
/// in the Supabase database.
class LessonContentService {
  final SupabaseClient _supabase;

  LessonContentService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  static int? _orderAt(List<int?> orders, int i) =>
      i < orders.length ? orders[i] : null;

  /// Add terms to a lesson
  ///
  /// [orders], when given, is parallel to [terms]; a non-null entry is
  /// stored as `order_index` so mixed content can follow a teaching order.
  Future<void> addTerms(
    String lessonId,
    List<Term> terms, {
    List<int?> orders = const [],
  }) async {
    try {
      debugPrint('🔍 DEBUG: Adding ${terms.length} terms to lesson: $lessonId');

      final termsData = terms.indexed
          .map(
            (e) => {
              if (_orderAt(orders, e.$1) case final o?) 'order_index': o,
              'id': e.$2.id.isNotEmpty ? e.$2.id : const Uuid().v4(),
              'lesson_id': lessonId,
              'term': e.$2.term,
              'definition': e.$2.definition,
              'example': e.$2.example,
              // Column is user_id (see lesson_crud_service read path).
              'user_id': e.$2.createdBy,
              'created_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();

      await _supabase.from('terms').insert(termsData);
      debugPrint('✅ Terms added successfully');
    } catch (e) {
      debugPrint('❌ ERROR: Failed to add terms: $e');
      rethrow;
    }
  }

  /// Add questions to a lesson
  Future<void> addQuestions(
    String lessonId,
    List<Question> questions, {
    List<int?> orders = const [],
  }) async {
    try {
      debugPrint(
        '🔍 DEBUG: Adding ${questions.length} questions to lesson: $lessonId',
      );

      final questionsData = questions.indexed.map((e) {
        final question = e.$2;
        return {
          if (_orderAt(orders, e.$1) case final o?) 'order_index': o,
          'id': question.id.isNotEmpty ? question.id : const Uuid().v4(),
          'lesson_id': lessonId,
          'question_text': question.questionText,
          'options': question.options,
          'correct_answer': question.correctAnswer,
          'type': question.type,
          'explanation': question.explanation,
          'accepted_answers': question.acceptedAnswers ?? <String>[],
          'grading_method': question.gradingMethod ?? 'normalized_text',
          'numeric_tolerance': question.numericTolerance,
          // Column is user_id (see lesson_crud_service read path).
          'user_id': question.createdBy,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('questions').insert(questionsData);
      debugPrint('✅ Questions added successfully');
    } catch (e) {
      debugPrint('❌ ERROR: Failed to add questions: $e');
      rethrow;
    }
  }

  /// Add concepts to a lesson
  Future<void> addConcepts(
    String lessonId,
    List<Concept> concepts, {
    List<int?> orders = const [],
  }) async {
    try {
      debugPrint(
        '🔍 DEBUG: Adding ${concepts.length} concepts to lesson: $lessonId',
      );

      final conceptsData = concepts.indexed.map((e) {
        final concept = e.$2;
        return {
          if (_orderAt(orders, e.$1) case final o?) 'order_index': o,
          'id': concept.id.isNotEmpty ? concept.id : const Uuid().v4(),
          'lesson_id': concept.lessonId,
          'concept_text': concept.conceptText,
          'example_text': concept.exampleText,
          // Column is user_id (see lesson_crud_service read path).
          'user_id': concept.createdBy,
          'created_at': concept.createdAt.toIso8601String(),
        };
      }).toList();

      await _supabase.from('concepts').insert(conceptsData);
      debugPrint('✅ Concepts added successfully');
    } catch (e) {
      debugPrint('❌ ERROR: Failed to add concepts: $e');
      rethrow;
    }
  }

  /// Remove content from a lesson
  Future<void> removeContent({
    String? lessonId,
    List<String>? termIds,
    List<String>? questionIds,
    List<String>? conceptIds,
  }) async {
    try {
      debugPrint('🔍 DEBUG: Removing content from lesson: $lessonId');

      // Remove by lesson ID (removes all content)
      if (lessonId != null) {
        await Future.wait([
          _supabase.from('terms').delete().eq('lesson_id', lessonId),
          _supabase.from('questions').delete().eq('lesson_id', lessonId),
          _supabase.from('concepts').delete().eq('lesson_id', lessonId),
        ]);
      }

      // Remove specific items by looping through IDs
      if (termIds != null && termIds.isNotEmpty) {
        for (final id in termIds) {
          await _supabase.from('terms').delete().eq('id', id);
        }
      }

      if (questionIds != null && questionIds.isNotEmpty) {
        for (final id in questionIds) {
          await _supabase.from('questions').delete().eq('id', id);
        }
      }

      if (conceptIds != null && conceptIds.isNotEmpty) {
        for (final id in conceptIds) {
          await _supabase.from('concepts').delete().eq('id', id);
        }
      }

      debugPrint('✅ Content removed successfully');
    } catch (e) {
      debugPrint('❌ ERROR: Failed to remove content: $e');
      rethrow;
    }
  }

  /// Get content counts for a lesson
  Future<Map<String, int>> getContentCounts(String lessonId) async {
    try {
      final futures = await Future.wait([
        _supabase.from('terms').select('id').eq('lesson_id', lessonId),
        _supabase.from('questions').select('id').eq('lesson_id', lessonId),
        _supabase.from('concepts').select('id').eq('lesson_id', lessonId),
      ]);

      return {
        'terms': (futures[0] as List).length,
        'questions': (futures[1] as List).length,
        'concepts': (futures[2] as List).length,
      };
    } catch (e) {
      debugPrint('❌ ERROR: Failed to get content counts: $e');
      return {'terms': 0, 'questions': 0, 'concepts': 0};
    }
  }
}
