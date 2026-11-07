import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';
import 'package:learning_pwa/services/assessment/short_answer_grader.dart';
import 'package:learning_pwa/utils/voice_command_router.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/question_widgets/mcq_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/true_false_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/short_answer_question_widget.dart';

class QuestionContentRenderer extends ConsumerStatefulWidget {
  final QuestionContent content;
  final VoidCallback onNext;
  final bool? autoPlayOverride;
  final bool isOrchestratorMode;
  final int? presentationSeed;

  const QuestionContentRenderer({
    super.key,
    required this.content,
    required this.onNext,
    this.autoPlayOverride,
    this.isOrchestratorMode = false,
    this.presentationSeed,
  });

  @override
  ConsumerState<QuestionContentRenderer> createState() =>
      _QuestionContentRendererState();
}

class _QuestionContentRendererState
    extends ConsumerState<QuestionContentRenderer> {
  static int _globalAttemptNonce = 0x369CF258;

  late int _attemptNonce;
  late int _presentationSeed;
  List<int> _presentationOrder = const [];

  int get attemptNonce => _attemptNonce;
  int get presentationSeed => _presentationSeed;
  List<int> get presentationOrder => List.unmodifiable(_presentationOrder);

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
  void initState() {
    super.initState();
    _initPresentationState();
  }

  @override
  void dispose() {
    shortAnswerController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuestionContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when content or presentationSeed changes
    if (oldWidget.content != widget.content ||
        oldWidget.presentationSeed != widget.presentationSeed) {
      final previousOrder =
          (oldWidget.content.id == widget.content.id &&
              _presentationOrder.isNotEmpty)
          ? List<int>.from(_presentationOrder)
          : null;
      _resetState(previousOrder: previousOrder);
    }
  }

  void _initPresentationState({List<int>? previousOrder}) {
    final options = widget.content.options;

    if (widget.presentationSeed != null) {
      _attemptNonce = widget.presentationSeed!;
      int candidateSeed = _attemptNonce ^ widget.content.id.hashCode;
      if (previousOrder != null &&
          McqOptions.countNonAnchorOptions(options) > 1) {
        final candidateOrder = McqOptions.computePresentationOrder(
          options,
          presentationSeed: candidateSeed,
          shuffle: true,
        );
        if (McqOptions.listsEqual(candidateOrder, previousOrder)) {
          _attemptNonce = McqOptions.nextPresentationNonce(
            currentNonce: _attemptNonce,
            options: options,
            itemHash: widget.content.id.hashCode,
            previousOrder: previousOrder,
          );
          candidateSeed = _attemptNonce ^ widget.content.id.hashCode;
        }
      }
      _presentationSeed = candidateSeed;
    } else {
      _globalAttemptNonce = McqOptions.nextPresentationNonce(
        currentNonce:
            _globalAttemptNonce ^ DateTime.now().microsecondsSinceEpoch,
        options: options,
        itemHash: widget.content.id.hashCode,
        previousOrder: previousOrder,
      );
      _attemptNonce = _globalAttemptNonce;
      _presentationSeed = _attemptNonce ^ widget.content.id.hashCode;
    }

    _presentationOrder = McqOptions.computePresentationOrder(
      options,
      presentationSeed: _presentationSeed,
      shuffle: true,
      avoidOrder: previousOrder,
    );
  }

  void _resetState({List<int>? previousOrder}) {
    setState(() {
      _initPresentationState(previousOrder: previousOrder);
      selectedMcq = null;
      showMcqCorrect = false;
      selectedTf = null;
      showTfCorrect = false;
      shortAnswerController.clear();
      shortAnswerFeedback = null;
      showSaCorrect = false;
    });
  }

  /// Retries the current question with a fresh per-attempt nonce and option permutation.
  void retryQuestion() {
    final previousOrder = _presentationOrder.isNotEmpty
        ? List<int>.from(_presentationOrder)
        : null;
    setState(() {
      _globalAttemptNonce = McqOptions.nextPresentationNonce(
        currentNonce: _attemptNonce,
        options: widget.content.options,
        itemHash: widget.content.id.hashCode,
        previousOrder: previousOrder,
      );
      _attemptNonce = _globalAttemptNonce;
      _presentationSeed = _attemptNonce ^ widget.content.id.hashCode;
      _presentationOrder = McqOptions.computePresentationOrder(
        widget.content.options,
        presentationSeed: _presentationSeed,
        shuffle: true,
        avoidOrder: previousOrder,
      );
      selectedMcq = null;
      showMcqCorrect = false;
      selectedTf = null;
      showTfCorrect = false;
      shortAnswerController.clear();
      shortAnswerFeedback = null;
      showSaCorrect = false;
    });
  }

  String _effectiveQuestionType(QuestionContent content) {
    if (content.type == 'mcq' ||
        content.type == 'true_false' ||
        content.type == 'short_answer') {
      return content.type;
    }
    if (content.options.length == 2) {
      final normalized = content.options
          .map((o) => o.toLowerCase().trim())
          .toSet();
      if (normalized.contains('true') && normalized.contains('false')) {
        return 'true_false';
      }
    }
    if (content.options.length <= 1) {
      return 'short_answer';
    }
    return 'mcq';
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

    switch (widget.content.effectiveQuestionType) {
      case 'mcq':
        return McqQuestionWidget(
          content: widget.content,
          selectedIndex: selectedMcq,
          showCorrect: showMcqCorrect,
          shuffleOptions: true,
          presentationSeed: _presentationSeed,
          onSelectionChanged: (index) => setState(() => selectedMcq = index),
          onSubmit: () {
            final isCorrect = selectedMcq == widget.content.correctAnswer;
            if (isCorrect) {
              HapticUtils.success();
            } else {
              HapticUtils.error();
            }
            setState(() => showMcqCorrect = true);
          },
          onNext: widget.onNext,
          onRetry: retryQuestion,
          onVoiceInput: handleVoiceInput,
          customTextBuilder: _renderText,
        );

      case 'true_false':
        return TrueFalseQuestionWidget(
          content: widget.content,
          selectedValue: selectedTf,
          showCorrect: showTfCorrect,
          onSelectionChanged: (value) => setState(() => selectedTf = value),
          onSubmit: () {
            final correctValue =
                widget.content.correctAnswer == 0; // 0=true, 1=false
            final isCorrect = selectedTf == correctValue;
            if (isCorrect) {
              HapticUtils.success();
            } else {
              HapticUtils.error();
            }
            setState(() => showTfCorrect = true);
          },
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
            final grade = ShortAnswerGrader.grade(
              widget.content,
              shortAnswerController.text,
            );
            final isCorrect = grade.isCorrect;
            if (isCorrect) {
              HapticUtils.success();
            } else {
              HapticUtils.error();
            }
            setState(() {
              showSaCorrect = true;
              shortAnswerFeedback = grade.feedback;
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

  void handleVoiceInput(String voiceInput) {
    if (_effectiveQuestionType(widget.content) == 'mcq') {
      final result = VoiceInputHandler.handleMcqVoiceInput(
        voiceInput,
        widget.content,
        presentationOrder: _presentationOrder,
      );
      if (result != null) {
        setState(() => selectedMcq = result);
        return;
      }
    }
    _handleVoiceInput(voiceInput);
  }

  void _handleVoiceInput(String voiceInput) {
    if (widget.isOrchestratorMode) {
      // In orchestrator mode, voice input is handled by the orchestrator
      return;
    }

    // Legacy voice input handling for non-orchestrator mode
    final rawContext = VoiceCommandRouter.getContextFromContent(widget.content);
    final effectiveContext = (rawContext == null || rawContext == 'question')
        ? _effectiveQuestionType(widget.content)
        : rawContext;
    final command = VoiceCommandRouter.parseContextAwareCommand(
      voiceInput,
      context: effectiveContext,
    );

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
    switch (widget.content.effectiveQuestionType) {
      case 'mcq':
        if (command.value is String) {
          final slotIndex =
              (command.value as String).toUpperCase().codeUnitAt(0) -
              65; // A=0, B=1, etc.
          if (slotIndex >= 0 && slotIndex < _presentationOrder.length) {
            final canonicalIndex = _presentationOrder[slotIndex];
            setState(() => selectedMcq = canonicalIndex);
          }
        }
        break;
      case 'true_false':
        if (command.value is bool) {
          setState(() => selectedTf = command.value as bool);
        }
        break;
      case 'short_answer':
        if (command.value is String) {
          shortAnswerController.text = command.value as String;
        }
        break;
    }
  }

  Widget _renderText(String text) {
    if (text.contains(r'\(') ||
        text.contains(r'\[') ||
        text.contains(r'\frac') ||
        text.contains(r'\sqrt')) {
      return Math.tex(text, textStyle: Theme.of(context).textTheme.titleLarge);
    }
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}
