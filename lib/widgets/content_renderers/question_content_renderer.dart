import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';
import 'package:learning_pwa/utils/math_utils.dart';
import 'package:learning_pwa/utils/voice_command_router.dart';
import 'package:learning_pwa/widgets/question_widgets/mcq_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/true_false_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/short_answer_question_widget.dart';

class QuestionContentRenderer extends ConsumerStatefulWidget {
  final QuestionContent content;
  final VoidCallback onNext;
  final bool? autoPlayOverride;
  final bool isOrchestratorMode;

  const QuestionContentRenderer({
    super.key,
    required this.content,
    required this.onNext,
    this.autoPlayOverride,
    this.isOrchestratorMode = false,
  });

  @override
  ConsumerState<QuestionContentRenderer> createState() => _QuestionContentRendererState();
}

class _QuestionContentRendererState extends ConsumerState<QuestionContentRenderer> {
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
  void didUpdateWidget(QuestionContentRenderer oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    // In orchestrator mode, listen for voice command processing
    if (widget.isOrchestratorMode) {
      ref.listen<AudioLessonState>(audioLessonStateProvider, (previous, next) {
        if (next == AudioLessonState.processing) {
          _handleOrchestratorVoiceInput();
        }
      });
    }

    switch (widget.content.type) {
      case 'mcq':
        return McqQuestionWidget(
          content: widget.content,
          selectedIndex: selectedMcq,
          showCorrect: showMcqCorrect,
          onSelectionChanged: (index) => setState(() => selectedMcq = index),
          onSubmit: () => setState(() => showMcqCorrect = true),
          onNext: widget.onNext,
          onVoiceInput: _handleVoiceInput,
          customTextBuilder: _renderText,
        );

      case 'true_false':
        return TrueFalseQuestionWidget(
          content: widget.content,
          selectedValue: selectedTf,
          showCorrect: showTfCorrect,
          onSelectionChanged: (value) => setState(() => selectedTf = value),
          onSubmit: () => setState(() => showTfCorrect = true),
          onNext: widget.onNext,
          onVoiceInput: _handleVoiceInput,
          customTextBuilder: _renderText,
        );

      case 'short_answer':
        return ShortAnswerQuestionWidget(
          content: widget.content,
          controller: shortAnswerController,
          feedback: shortAnswerFeedback,
          showCorrect: showSaCorrect,
          onAnswerChanged: (answer) {
            // Handle answer changed if needed
          },
          onSubmit: () {
            final isCorrect = MathUtils.isAnswerCorrect(
              shortAnswerController.text,
              widget.content.options[widget.content.correctAnswer],
            );
            setState(() {
              showSaCorrect = true;
              shortAnswerFeedback = isCorrect ? 'Correct!' : 'Incorrect';
            });
          },
          onNext: widget.onNext,
          onVoiceInput: _handleVoiceInput,
          customTextBuilder: _renderText,
        );

      default:
        return const Text('Unsupported question type');
    }
  }

  void _handleVoiceInput(String voiceInput) {
    if (widget.isOrchestratorMode) {
      // In orchestrator mode, voice input is handled by the orchestrator
      return;
    }

    // Legacy voice input handling for non-orchestrator mode
    final context = VoiceCommandRouter.getContextFromContent(widget.content);
    final command = VoiceCommandRouter.parseContextAwareCommand(voiceInput, context: context);
    
    if (command?.type == VoiceCommandType.answer) {
      _processAnswerCommand(command!);
    }
  }

  void _handleOrchestratorVoiceInput() {
    // This is called when the orchestrator is processing voice input
    // We can update UI to show that voice input is being processed
    // The actual answer handling is done by the orchestrator
  }

  void _processAnswerCommand(VoiceCommand command) {
    switch (widget.content.type) {
      case 'mcq':
        if (command.value is String) {
          final answerIndex = command.value.codeUnitAt(0) - 65; // A=0, B=1, etc.
          if (answerIndex >= 0 && answerIndex < widget.content.options.length) {
            setState(() => selectedMcq = answerIndex);
          }
        }
        break;
      case 'true_false':
        if (command.value is bool) {
          setState(() => selectedTf = command.value);
        }
        break;
      case 'short_answer':
        if (command.value is String) {
          shortAnswerController.text = command.value;
        }
        break;
    }
  }

  Widget _renderText(String text) {
    if (text.contains(r'\(') || text.contains(r'\[') || text.contains(r'\frac') || text.contains(r'\sqrt')) {
      return Math.tex(text, textStyle: Theme.of(context).textTheme.titleLarge);
    }
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}
