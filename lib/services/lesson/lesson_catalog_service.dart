import 'package:flutter/foundation.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only lesson catalog.
///
/// This deliberately does not apply an ownership filter. Supabase RLS is the
/// source of truth for which rows the current session may read. Ownership is a
/// write/edit concern, not a Discover visibility rule.
class LessonCatalogService {
  final SupabaseClient _supabase;

  LessonCatalogService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<List<Lesson>> getReadableLessons({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('*')
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
                    ? DateTime.parse(data['created_at'].toString())
                    : DateTime.now(),
                updatedAt: data['updated_at'] != null
                    ? DateTime.parse(data['updated_at'].toString())
                    : DateTime.now(),
                userId: data['user_id']?.toString() ?? '',
                terms: <Term>[],
                questions: <Question>[],
                concepts: <Concept>[],
              ))
          .toList();
    } on PostgrestException catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Database error loading lesson catalog: ${e.message}');
      }
      throw DatabaseException(
        'Failed to load lesson catalog',
        originalError: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      if (e is AppException) rethrow;
      if (kDebugMode) {
        debugPrint('❌ Unexpected error loading lesson catalog: $e');
      }
      throw DatabaseException(
        'Failed to load lesson catalog',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }
}
