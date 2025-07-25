import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/utils/math_utils.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/short_answer_field.dart';
import 'package:learning_pwa/widgets/true_false_selector.dart';

class LessonModeScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonModeScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonModeScreen> createState() => _LessonModeScreenState();
}

class _LessonModeScreenState extends ConsumerState<LessonModeScreen> {
  int pageIndex = 0;
  int? selectedMcq;
  bool? selectedTf;
  final shortAnswerController = TextEditingController();
  String? shortAnswerFeedback;
  bool showCorrect = false;

  @override
  void dispose() {
    shortAnswerController.dispose();
    super.dispose();
  }

  void nextPage(int total) {
    setState(() {
      pageIndex = (pageIndex + 1).clamp(0, total - 1);
      selectedMcq = null;
      selectedTf = null;
      shortAnswerController.clear();
      shortAnswerFeedback = null;
      showCorrect = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    return lessonAsync.when(
      data: (lessonData) {
        final contentList = lessonData.lessonContent;
        final content = contentList[pageIndex];
        Widget renderText(String text) {
          if (text.contains(r'\(') || text.contains(r'\[') || text.contains(r'\frac') || text.contains(r'\sqrt')) {
            return Math.tex(text, textStyle: Theme.of(context).textTheme.titleLarge);
          }
          return Text(text, style: Theme.of(context).textTheme.titleLarge);
        }
        Widget child;
        if (content is TermContent) {
          child = Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    renderText(content.term),
                    const SizedBox(height: 16),
                    if (content.example != null) ...[
                      Text('Example: ${content.example!}', style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 8),
                    ],
                    renderText(content.definition),
                  ],
                ),
              ),
            ),
          );
        } else if (content is QuestionContent) {
          if (content.type == 'mcq') {
            child = Column(
              children: [
                renderText(content.questionText),
                const SizedBox(height: 16),
                McqOptions(
                  options: content.options,
                  selectedIndex: selectedMcq,
                  onChanged: (idx) => setState(() => selectedMcq = idx),
                  showCorrect: showCorrect,
                  correctIndex: content.correctAnswer,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: showCorrect ? 'Next' : 'Submit',
                  onPressed: () {
                    if (!showCorrect) {
                      setState(() => showCorrect = true);
                    } else {
                      nextPage(contentList.length);
                    }
                  },
                  loading: false,
                  icon: null,
                ),
                if (showCorrect && selectedMcq != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      selectedMcq == content.correctAnswer ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        color: selectedMcq == content.correctAnswer ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (showCorrect && content.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Explanation: ${content.explanation!}'),
                  ),
              ],
            );
          } else if (content.type == 'true_false') {
            child = Column(
              children: [
                renderText(content.questionText),
                const SizedBox(height: 16),
                TrueFalseSelector(
                  value: selectedTf,
                  onChanged: (v) => setState(() => selectedTf = v),
                  showCorrect: showCorrect,
                  correctValue: content.correctAnswer == 0 ? false : true,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: showCorrect ? 'Next' : 'Submit',
                  onPressed: () {
                    if (!showCorrect) {
                      setState(() => showCorrect = true);
                    } else {
                      nextPage(contentList.length);
                    }
                  },
                  loading: false,
                  icon: null,
                ),
                if (showCorrect && selectedTf != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      (selectedTf == (content.correctAnswer == 1)) ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        color: (selectedTf == (content.correctAnswer == 1)) ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (showCorrect && content.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Explanation: ${content.explanation!}'),
                  ),
              ],
            );
          } else if (content.type == 'short_answer') {
            child = Column(
              children: [
                renderText(content.questionText),
                const SizedBox(height: 16),
                ShortAnswerField(
                  controller: shortAnswerController,
                  enabled: !showCorrect,
                  feedback: shortAnswerFeedback,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: showCorrect ? 'Next' : 'Submit',
                  onPressed: () {
                    if (!showCorrect) {
                      final isCorrect = MathUtils.isAnswerCorrect(
                        shortAnswerController.text,
                        content.options[content.correctAnswer],
                      );
                      setState(() {
                        showCorrect = true;
                        shortAnswerFeedback = isCorrect ? 'Correct!' : 'Incorrect';
                      });
                    } else {
                      nextPage(contentList.length);
                    }
                  },
                  loading: false,
                  icon: null,
                ),
                if (showCorrect && content.explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Explanation: ${content.explanation!}'),
                  ),
              ],
            );
          } else {
            child = const Text('Unsupported question type');
          }
        } else if (content is ConceptContent) {
          child = Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                renderText(content.conceptText),
                const SizedBox(height: 24),
                if (content.exampleText != null)
                  renderText('Example: ${content.exampleText}'),
              ],
            ),
          );
        } else {
          child = const SizedBox.shrink();
        }
        // Add progress bar at top
        return Scaffold(
          appBar: AppBar(
            title: Text(lessonData.lesson.title),
            actions: [
              if (pageIndex < contentList.length - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => nextPage(contentList.length),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: LinearProgressIndicator(
                    value: (pageIndex + 1) / contentList.length,
                    minHeight: 8,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Progress: ${pageIndex + 1}/${contentList.length}'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
