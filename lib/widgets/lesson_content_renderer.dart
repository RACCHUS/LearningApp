import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/utils/math_utils.dart';
import 'package:learning_pwa/utils/voice_input_handler.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';
import 'package:learning_pwa/widgets/audio/audio_concept_widget.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/question_widgets/mcq_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/true_false_question_widget.dart';
import 'package:learning_pwa/widgets/question_widgets/short_answer_question_widget.dart';

class LessonContentRenderer extends StatefulWidget {
  final LessonContent content;
  final VoidCallback onNext;
  final int? presentationSeed;

  const LessonContentRenderer({
    super.key,
    required this.content,
    required this.onNext,
    this.presentationSeed,
  });

  @override
  State<LessonContentRenderer> createState() => _LessonContentRendererState();
}

class _LessonContentRendererState extends State<LessonContentRenderer> {
  static int _globalAttemptNonce = 0x2468ACE1;

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
  void didUpdateWidget(LessonContentRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when content or presentationSeed changes
    if (oldWidget.content != widget.content ||
        oldWidget.presentationSeed != widget.presentationSeed) {
      final previousOrder = (oldWidget.content.id == widget.content.id &&
              _presentationOrder.isNotEmpty)
          ? List<int>.from(_presentationOrder)
          : null;
      _resetState(previousOrder: previousOrder);
    }
  }

  void _initPresentationState({List<int>? previousOrder}) {
    final content = widget.content;
    final options = content is QuestionContent ? content.options : null;

    if (widget.presentationSeed != null) {
      _attemptNonce = widget.presentationSeed!;
      int candidateSeed = _attemptNonce ^ content.id.hashCode;
      if (options != null &&
          previousOrder != null &&
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
            itemHash: content.id.hashCode,
            previousOrder: previousOrder,
          );
          candidateSeed = _attemptNonce ^ content.id.hashCode;
        }
      }
      _presentationSeed = candidateSeed;
    } else {
      _globalAttemptNonce = McqOptions.nextPresentationNonce(
        currentNonce:
            _globalAttemptNonce ^ DateTime.now().microsecondsSinceEpoch,
        options: options,
        itemHash: content.id.hashCode,
        previousOrder: previousOrder,
      );
      _attemptNonce = _globalAttemptNonce;
      _presentationSeed = _attemptNonce ^ content.id.hashCode;
    }

    if (options != null) {
      _presentationOrder = McqOptions.computePresentationOrder(
        options,
        presentationSeed: _presentationSeed,
        shuffle: true,
      );
    } else {
      _presentationOrder = const [];
    }
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
    final previousOrder =
        _presentationOrder.isNotEmpty ? List<int>.from(_presentationOrder) : null;
    setState(() {
      final content = widget.content;
      final options = content is QuestionContent ? content.options : null;
      _globalAttemptNonce = McqOptions.nextPresentationNonce(
        currentNonce: _attemptNonce,
        options: options,
        itemHash: content.id.hashCode,
        previousOrder: previousOrder,
      );
      _attemptNonce = _globalAttemptNonce;
      _presentationSeed = _attemptNonce ^ content.id.hashCode;
      if (options != null) {
        _presentationOrder = McqOptions.computePresentationOrder(
          options,
          presentationSeed: _presentationSeed,
          shuffle: true,
        );
      }
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
      final normalized =
          content.options.map((o) => o.toLowerCase().trim()).toSet();
      if (normalized.contains('true') && normalized.contains('false')) {
        return 'true_false';
      }
    }
    if (content.options.length <= 1) {
      return 'short_answer';
    }
    return 'mcq';
  }

  void handleVoiceInput(String voiceInput) {
    final content = widget.content;
    if (content is! QuestionContent) return;

    switch (_effectiveQuestionType(content)) {
      case 'mcq':
        final result = VoiceInputHandler.handleMcqVoiceInput(
          voiceInput,
          content,
          presentationOrder: _presentationOrder,
        );
        if (result != null) {
          setState(() => selectedMcq = result);
        }
        break;
      case 'true_false':
        final result = VoiceInputHandler.handleTrueFalseVoiceInput(voiceInput);
        if (result != null) {
          setState(() => selectedTf = result);
        }
        break;
      case 'short_answer':
        final result = VoiceInputHandler.handleShortAnswerVoiceInput(voiceInput);
        setState(() {
          shortAnswerController.text = result;
        });
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
    switch (_effectiveQuestionType(content)) {
      case 'mcq':
        return McqQuestionWidget(
          content: content,
          selectedIndex: selectedMcq,
          showCorrect: showMcqCorrect,
          shuffleOptions: true,
          presentationSeed: _presentationSeed,
          onSelectionChanged: (index) => setState(() => selectedMcq = index),
          onSubmit: () => setState(() => showMcqCorrect = true),
          onNext: widget.onNext,
          onRetry: retryQuestion,
          onVoiceInput: handleVoiceInput,
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
          onVoiceInput: handleVoiceInput,
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
          onVoiceInput: handleVoiceInput,
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
