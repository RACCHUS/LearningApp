import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/utils/math_utils.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/mcq_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/true_false_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/short_answer_question_widget.dart';

class LessonContentRenderer extends StatefulWidget {
  final LessonContent content;
  final VoidCallback onNext;

  const LessonContentRenderer({
    super.key,
    required this.content,
    required this.onNext,
  });

  @override
  State<LessonContentRenderer> createState() => _LessonContentRendererState();
}

class _LessonContentRendererState extends State<LessonContentRenderer> {
  // MCQ state
  int? selectedMcq;
  bool showMcqCorrect = false;

  // True/False state
  bool? selectedTf;
  bool showTfCorrect = false;

  // Short Answer state
  final shortAnswerController = TextEditingController();
  String? shortAnswerFeedback;
  bool showSaCorrect = false;

  @override
  void dispose() {
    shortAnswerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LessonContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when content changes
    if (oldWidget.content != widget.content) {
      _resetState();
    }
  }

  void _resetState() {
    setState(() {
      selectedMcq = null;
      showMcqCorrect = false;
      selectedTf = null;
      showTfCorrect = false;
      shortAnswerController.clear();
      shortAnswerFeedback = null;
      showSaCorrect = false;
    });
  }

  Widget _renderText(String text) {
    if (text.contains(r'\(') || text.contains(r'\[') || text.contains(r'\frac') || text.contains(r'\sqrt')) {
      return Math.tex(text, textStyle: Theme.of(context).textTheme.titleLarge);
    }
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;

    if (content is TermContent) {
      return _buildTermContent(content);
    } else if (content is QuestionContent) {
      return _buildQuestionContent(content);
    } else if (content is ConceptContent) {
      return _buildConceptContent(content);
    } else {
      return _buildGenericContent(content);
    }
  }

  Widget _buildTermContent(TermContent content) {
    return Center(
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
                customTextBuilder: _renderText,
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
                customTextBuilder: _renderText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionContent(QuestionContent content) {
    switch (content.type) {
      case 'mcq':
        return McqQuestionWidget(
          content: content,
          selectedIndex: selectedMcq,
          showCorrect: showMcqCorrect,
          onSelectionChanged: (index) => setState(() => selectedMcq = index),
          onSubmit: () => setState(() => showMcqCorrect = true),
          onNext: widget.onNext,
          onVoiceInput: (voiceInput) {
            final result = VoiceInputHandler.handleMcqVoiceInput(voiceInput, content);
            if (result != null) {
              setState(() => selectedMcq = result);
            }
          },
          customTextBuilder: _renderText,
        );

      case 'true_false':
        return TrueFalseQuestionWidget(
          content: content,
          selectedValue: selectedTf,
          showCorrect: showTfCorrect,
          onSelectionChanged: (value) => setState(() => selectedTf = value),
          onSubmit: () => setState(() => showTfCorrect = true),
          onNext: widget.onNext,
          onVoiceInput: (voiceInput) {
            final result = VoiceInputHandler.handleTrueFalseVoiceInput(voiceInput);
            if (result != null) {
              setState(() => selectedTf = result);
            }
          },
          customTextBuilder: _renderText,
        );

      case 'short_answer':
        return ShortAnswerQuestionWidget(
          content: content,
          controller: shortAnswerController,
          feedback: shortAnswerFeedback,
          showCorrect: showSaCorrect,
          onAnswerChanged: (answer) {
            // Handle answer changed if needed
          },
          onSubmit: () {
            final isCorrect = MathUtils.isAnswerCorrect(
              shortAnswerController.text,
              content.options[content.correctAnswer],
            );
            setState(() {
              showSaCorrect = true;
              shortAnswerFeedback = isCorrect ? 'Correct!' : 'Incorrect';
            });
          },
          onNext: widget.onNext,
          onVoiceInput: (voiceInput) {
            final result = VoiceInputHandler.handleShortAnswerVoiceInput(voiceInput);
            shortAnswerController.text = result;
          },
          customTextBuilder: _renderText,
        );

      default:
        return const Text('Unsupported question type');
    }
  }

  Widget _buildConceptContent(ConceptContent content) {
    return AudioConceptWidget(
      conceptText: content.conceptText,
      exampleText: content.exampleText,
      customTextBuilder: _renderText,
    );
  }

  Widget _buildGenericContent(LessonContent content) {
    // For any text content that's not a specific type
    String textContent = '';
    if (content is ConceptContent) {
      textContent = content.conceptText;
    } else if (content.toString().isNotEmpty) {
      textContent = content.toString();
    }
    
    if (textContent.isNotEmpty) {
      return AudioTextWidget(
        text: textContent,
        customTextBuilder: _renderText,
        style: Theme.of(context).textTheme.bodyLarge,
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
