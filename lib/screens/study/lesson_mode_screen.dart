import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/utils/math_utils.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/short_answer_field.dart';
import 'package:learning_pwa/widgets/true_false_selector.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';

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

  void _handleVoiceAnswer(String voiceInput, QuestionContent content) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);
    
    if (command?.type == VoiceCommandType.answer) {
      // Convert voice command answer (A, B, C, D) to index
      final answerLetter = command!.value as String;
      int? answerIndex;
      
      switch (answerLetter) {
        case 'A':
          answerIndex = 0;
          break;
        case 'B':
          answerIndex = 1;
          break;
        case 'C':
          answerIndex = 2;
          break;
        case 'D':
          answerIndex = 3;
          break;
      }
      
      if (answerIndex != null && answerIndex < content.options.length) {
        setState(() {
          selectedMcq = answerIndex;
        });
      }
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();
      int? answerIndex;
      
      if (input.contains('a') || input.contains('first')) {
        answerIndex = 0;
      } else if (input.contains('b') || input.contains('second')) {
        answerIndex = 1;
      } else if (input.contains('c') || input.contains('third')) {
        answerIndex = 2;
      } else if (input.contains('d') || input.contains('fourth')) {
        answerIndex = 3;
      }
      
      if (answerIndex != null && answerIndex < content.options.length) {
        setState(() {
          selectedMcq = answerIndex;
        });
      }
    }
  }

  void _handleVoiceTrueFalse(String voiceInput) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);
    
    if (command?.type == VoiceCommandType.answer && command!.value is bool) {
      setState(() {
        selectedTf = command.value as bool;
      });
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();
      
      if (input.contains('true') || input.contains('yes') || input.contains('correct')) {
        setState(() {
          selectedTf = true;
        });
      } else if (input.contains('false') || input.contains('no') || input.contains('incorrect')) {
        setState(() {
          selectedTf = false;
        });
      }
    }
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
                    AudioTextWidget(
                      text: content.term,
                      style: Theme.of(context).textTheme.titleLarge,
                      contentType: 'content',
                      autoPlay: true,
                      customTextBuilder: (text) => renderText(text),
                    ),
                    const SizedBox(height: 16),
                    if (content.example != null) ...[
                      AudioTextWidget(
                        text: 'Example: ${content.example!}',
                        style: Theme.of(context).textTheme.bodyLarge,
                        contentType: 'content',
                      ),
                      const SizedBox(height: 8),
                    ],
                    AudioTextWidget(
                      text: content.definition,
                      style: Theme.of(context).textTheme.titleLarge,
                      contentType: 'answer',
                      customTextBuilder: (text) => renderText(text),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (content is QuestionContent) {
          if (content.type == 'mcq') {
            child = Column(
              children: [
                AudioQuestionHeader(
                  questionText: content.questionText,
                  textStyle: Theme.of(context).textTheme.titleLarge,
                  customTextBuilder: (text) => renderText(text),
                  onVoiceInput: (result) {
                    _handleVoiceAnswer(result, content);
                  },
                  voiceInputHint: 'Say A, B, C, or D',
                ),
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
                AudioQuestionHeader(
                  questionText: content.questionText,
                  textStyle: Theme.of(context).textTheme.titleLarge,
                  customTextBuilder: (text) => renderText(text),
                  onVoiceInput: (result) {
                    _handleVoiceTrueFalse(result);
                  },
                  voiceInputHint: 'Say true or false',
                ),
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
                AudioQuestionHeader(
                  questionText: content.questionText,
                  textStyle: Theme.of(context).textTheme.titleLarge,
                  customTextBuilder: (text) => renderText(text),
                  onVoiceInput: (result) {
                    shortAnswerController.text = result;
                  },
                  voiceInputHint: 'Speak your answer',
                ),
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
          child = AudioConceptWidget(
            conceptText: content.conceptText,
            exampleText: content.exampleText,
            customTextBuilder: (text) => renderText(text),
          );
        } else {
          // For any text content that's not a specific type
          String textContent = '';
          if (content is ConceptContent) {
            textContent = content.conceptText;
          } else if (content.toString().isNotEmpty) {
            textContent = content.toString();
          }
          
          if (textContent.isNotEmpty) {
            child = AudioTextWidget(
              text: textContent,
              customTextBuilder: (text) => renderText(text),
              style: Theme.of(context).textTheme.bodyLarge,
            );
          } else {
            child = const SizedBox.shrink();
          }
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
