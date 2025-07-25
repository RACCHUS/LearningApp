import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';

class LessonScreen extends ConsumerWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider(lessonId));

    return lesson.when(
      data: (lesson) {
        return Scaffold(
          appBar: AppBar(
            title: Text(lesson.title),
          ),
          body: PageView.builder(
            itemCount: lesson.lessonContent.length,
            itemBuilder: (context, index) {
              final content = lesson.lessonContent[index];
              if (content is Term) {
                return FlashcardScreen(term: content);
              } else if (content is Question) {
                return McqScreen(question: content);
              } else if (content is Concept) {
                return ConceptScreen(concept: content);
              }
              return Container();
            },
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
