import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final lessonProvider = FutureProvider.family<FullLesson, String>((ref, lessonId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('lessons')
      .select('*, lesson_terms(terms(*)), lesson_questions(questions(*)), lesson_concepts(concepts(*))')
      .eq('id', lessonId)
      .single();

  final lesson = Lesson.fromJson(response);
  final terms = (response['lesson_terms'] as List).map((e) => Term.fromJson(e['terms'])).toList();
  final questions = (response['lesson_questions'] as List).map((e) => Question.fromJson(e['questions'])).toList();
  final concepts = (response['lesson_concepts'] as List).map((e) => Concept.fromJson(e['concepts'])).toList();

  final lessonContent = [...terms, ...questions, ...concepts];
  lessonContent.sort((a, b) {
    if (a is Question && b is Question) {
      // A real implementation would use the order_index from the join table
      return 0;
    }
    return 0;
  });

  return FullLesson(
    lesson: lesson,
    lessonContent: lessonContent,
  );
});

class FullLesson {
  final Lesson lesson;
  final List<dynamic> lessonContent;

  FullLesson({required this.lesson, required this.lessonContent});
}
