import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';

class LessonModeDialog extends ConsumerWidget {
  final String lessonId;
  final VoidCallback? onLessonModeSelected;
  
  const LessonModeDialog({
    super.key, 
    required this.lessonId,
    this.onLessonModeSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonContent = ref.watch(lessonProvider(lessonId)).asData?.value.lessonContent ?? [];
    return AlertDialog(
      title: const Text('Choose Study Mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'How would you like to study this lesson?',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.school),
            label: const Text('Lesson Mode'),
            onPressed: () {
              Navigator.pop(context);
              onLessonModeSelected?.call();
            },
          ),
          const Text(
            'Study the lesson as designed with all content types',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.style),
            label: const Text('Flashcards'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FlashcardScreen(
                    terms: lessonContent.whereType<TermContent>().map((c) => Term.fromTermContent(c)).toList(),
                  ),
                ),
              );
            },
          ),
          const Text(
            'Practice with flashcard-style terms and definitions',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.quiz),
            label: const Text('MCQ'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => McqScreen(
                    questions: lessonContent.whereType<QuestionContent>().map((c) => Question(
                      id: c.id,
                      questionText: c.questionText,
                      options: c.options,
                      correctAnswer: c.correctAnswer,
                      type: 'multiple_choice',
                      explanation: c.explanation,
                      createdBy: 'system',
                    )).toList(),
                  ),
                ),
              );
            },
          ),
          const Text(
            'Answer multiple choice questions only',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.lightbulb),
            label: const Text('Concepts'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConceptScreen(
                    concepts: lessonContent.whereType<ConceptContent>().toList(),
                  ),
                ),
              );
            },
          ),
          const Text(
            'Review concepts and key ideas only',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.shuffle),
            label: const Text('Mixed (All)'),
            onPressed: () {
              Navigator.pop(context);
              context.go('/study-set?ids=$lessonId');
            },
          ),
          const Text(
            'Mix all content types in random order',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
