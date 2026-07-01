import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'package:learning_pwa/models/term_content.dart';
import 'package:learning_pwa/models/question_content.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/study/flashcard_screen.dart';
import 'package:learning_pwa/screens/study/mcq_screen.dart';
import 'package:learning_pwa/screens/study/concept_screen.dart';

/// Study mode identifiers for persistence
enum StudyModePreference { lesson, flashcards, mcq, concepts, mixed }

/// Get the saved study mode preference for a lesson
Future<StudyModePreference?> getSavedStudyMode(String lessonId) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('study_mode_$lessonId');
  if (value == null) return null;
  return StudyModePreference.values.where((m) => m.name == value).firstOrNull;
}

/// Save the study mode preference for a lesson
Future<void> saveStudyMode(String lessonId, StudyModePreference mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('study_mode_$lessonId', mode.name);
}

/// Clear the study mode preference for a lesson
Future<void> clearStudyMode(String lessonId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('study_mode_$lessonId');
}

class LessonModeDialog extends ConsumerStatefulWidget {
  final String lessonId;
  final VoidCallback? onLessonModeSelected;
  
  const LessonModeDialog({
    super.key, 
    required this.lessonId,
    this.onLessonModeSelected,
  });

  @override
  ConsumerState<LessonModeDialog> createState() => _LessonModeDialogState();
}

class _LessonModeDialogState extends ConsumerState<LessonModeDialog> {
  bool _rememberChoice = false;

  void _selectMode(StudyModePreference mode, VoidCallback action) {
    if (_rememberChoice) {
      saveStudyMode(widget.lessonId, mode);
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    final lessonContent = ref.watch(lessonProvider(widget.lessonId)).asData?.value.lessonContent ?? [];
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
              _selectMode(StudyModePreference.lesson, () {
                Navigator.pop(context);
                widget.onLessonModeSelected?.call();
              });
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
              _selectMode(StudyModePreference.flashcards, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FlashcardScreen(
                      terms: lessonContent.whereType<TermContent>().map((c) => Term.fromTermContent(c)).toList(),
                    ),
                  ),
                );
              });
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
              _selectMode(StudyModePreference.mcq, () {
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
              });
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
              _selectMode(StudyModePreference.concepts, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConceptScreen(
                      concepts: lessonContent.whereType<ConceptContent>().toList(),
                    ),
                  ),
                );
              });
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
              _selectMode(StudyModePreference.mixed, () {
                Navigator.pop(context);
                context.go('/study-set?ids=${widget.lessonId}');
              });
            },
          ),
          const Text(
            'Mix all content types in random order',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _rememberChoice,
                onChanged: (v) => setState(() => _rememberChoice = v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rememberChoice = !_rememberChoice),
                  child: const Text(
                    'Remember my choice for this lesson',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
