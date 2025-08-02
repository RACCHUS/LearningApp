import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/services/supabase_service.dart';

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

  Future<StudySet> fetchStudySet(List<String> lessonIds) async {
    print('DEBUG: fetchStudySet called with lessonIds: $lessonIds');
    final termsResponse = await _supabase.from('terms').select().filter('lesson_id', 'in', '(${lessonIds.map((id) => '"$id"').join(',')})');
    print('DEBUG: termsResponse: $termsResponse');
    final conceptsResponse = await _supabase.from('concepts').select().filter('lesson_id', 'in', '(${lessonIds.map((id) => '"$id"').join(',')})');
    print('DEBUG: conceptsResponse: $conceptsResponse');
    final questionsResponse = await _supabase.from('questions').select().filter('lesson_id', 'in', '(${lessonIds.map((id) => '"$id"').join(',')})');
    print('DEBUG: questionsResponse: $questionsResponse');

    try {
      final terms = (termsResponse as List).map((t) => Term.fromJson(t)).toList();
      final concepts = (conceptsResponse as List).map((c) => Concept.fromJson(c)).toList();
      final questions = (questionsResponse as List).map((q) => Question.fromJson(q)).toList();

      print('DEBUG: terms.length=${terms.length}, concepts.length=${concepts.length}, questions.length=${questions.length}');

      return StudySet(
        lessonIds: lessonIds,
        terms: terms,
        concepts: concepts,
        questions: questions,
      );
    } catch (e, stack) {
      print('ERROR in StudySetService parsing: $e\n$stack');
      rethrow;
    }
  }
}
