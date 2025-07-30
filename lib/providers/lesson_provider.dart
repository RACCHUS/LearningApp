import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final lessonProvider =
    FutureProvider.family<FullLesson, String>((ref, lessonId) async {
  final supabase = Supabase.instance.client;
  final response = await supabase
      .from('lessons')
      .select(
          '*, lesson_terms(terms(*)), lesson_questions(order_index, questions(*)), lesson_concepts(concepts(*))')
      .eq('id', lessonId)
      .single();

  final lesson = Lesson.fromJson(response);
  final terms = (response['lesson_terms'] as List)
      .map((e) => TermContent(
            id: e['terms']['id'],
            term: e['terms']['term'],
            definition: e['terms']['definition'],
            example: e['terms']['example'],
            createdBy: e['terms']['created_by'],
          ))
      .toList();
  final questions = (response['lesson_questions'] as List)
      .map((e) => QuestionContent(
            id: e['questions']['id'],
            questionText: e['questions']['question_text'],
            options: List<String>.from(e['questions']['options']),
            correctAnswer: e['questions']['correct_answer'],
            explanation: e['questions']['explanation'],
            createdBy: e['questions']['created_by'],
            orderIndex: e['order_index'],
          ))
      .toList();
  final concepts = (response['lesson_concepts'] as List)
      .map((e) => ConceptContent(
            id: e['concepts']['id'],
            conceptText: e['concepts']['concept_text'],
            exampleText: e['concepts']['example_text'],
            createdBy: e['concepts']['created_by'],
          ))
      .toList();

  final List<LessonContent> lessonContent = [...terms, ...questions, ...concepts];
  lessonContent.sort((a, b) {
    if (a is QuestionContent && b is QuestionContent) {
      return a.orderIndex.compareTo(b.orderIndex);
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
  final List<LessonContent> lessonContent;

  FullLesson({required this.lesson, required this.lessonContent});
}
