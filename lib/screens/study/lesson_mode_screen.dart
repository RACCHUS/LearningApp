import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';

class LessonModeScreen extends ConsumerWidget {
  final String lessonId;

  const LessonModeScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonProvider(lessonId));

    return lessonAsync.when(
      data: (lessonData) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lessonData.lesson.title),
          ),
          body: PageView.builder(
            itemCount: lessonData.lessonContent.length,
            itemBuilder: (context, index) {
              final content = lessonData.lessonContent[index];
              if (content is TermContent) {
                return FlashcardScreen(term: content);
              } else if (content is QuestionContent) {
                return McqScreen(question: content);
              } else if (content is ConceptContent) {
                return ConceptScreen(concept: content);
              }
              return Container();
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
