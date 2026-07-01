import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/services/supabase_service.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';

class StudySet {
  final List<String> lessonIds;
  final List<Term> terms;
  final List<Concept> concepts;
  final List<Question> questions;

  StudySet({
    required this.lessonIds,
    required this.terms,
    required this.concepts,
    required this.questions,
  });
}

class StudySetService {
  final SupabaseService _supabase = SupabaseService();
  final AppLogger _logger = AppLogger('StudySetService');

  Future<StudySet> fetchStudySet(List<String> lessonIds) async {
    if (lessonIds.isEmpty) {
      return StudySet(
        lessonIds: const [],
        terms: const [],
        concepts: const [],
        questions: const [],
      );
    }

    final termsResponse =
        await _supabase.from('terms').select().inFilter('lesson_id', lessonIds);
    final conceptsResponse = await _supabase
        .from('concepts')
        .select()
        .inFilter('lesson_id', lessonIds);
    final questionsResponse = await _supabase
        .from('questions')
        .select()
        .inFilter('lesson_id', lessonIds);

    try {
      final terms = (termsResponse as List).map((t) => Term.fromJson(t)).toList();
      final concepts = (conceptsResponse as List).map((c) => Concept.fromJson(c)).toList();
      final questions = (questionsResponse as List).map((q) => Question.fromJson(q)).toList();

      return StudySet(
        lessonIds: lessonIds,
        terms: terms,
        concepts: concepts,
        questions: questions,
      );
    } catch (e, stack) {
      _logger.error('Failed to parse study set', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
