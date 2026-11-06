import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';

class McqQuestionWidget extends StatefulWidget {
  final QuestionContent content;
  final int? selectedIndex;
  final bool showCorrect;
  final Function(int?) onSelectionChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final Function(String) onVoiceInput;
  final Widget Function(String) customTextBuilder;
  final bool shuffleOptions;
  final int? presentationSeed;
  final VoidCallback? onRetry;

  const McqQuestionWidget({
    super.key,
    required this.content,
    required this.selectedIndex,
    required this.showCorrect,
    required this.onSelectionChanged,
    required this.onSubmit,
    required this.onNext,
    required this.onVoiceInput,
    required this.customTextBuilder,
    this.shuffleOptions = true,
    this.presentationSeed,
    this.onRetry,
  });

  @override
  State<McqQuestionWidget> createState() => _McqQuestionWidgetState();
}

class _McqQuestionWidgetState extends State<McqQuestionWidget> {
  static int _globalAttemptSeed = 0x13579BDF;
  late int _fallbackPresentationSeed;
  List<int>? _avoidOrder;

  int get effectivePresentationSeed =>
      widget.presentationSeed ?? _fallbackPresentationSeed;

  List<int> get presentationOrder => McqOptions.computePresentationOrder(
    widget.content.options,
    presentationSeed: effectivePresentationSeed,
    shuffle: widget.shuffleOptions,
    avoidOrder: _avoidOrder,
  );

  @override
  void initState() {
    super.initState();
    _globalAttemptSeed = McqOptions.nextPresentationNonce(
      currentNonce: _globalAttemptSeed ^ DateTime.now().microsecondsSinceEpoch,
      options: widget.content.options,
      itemHash: widget.content.id.hashCode,
    );
    _fallbackPresentationSeed = _globalAttemptSeed ^ widget.content.id.hashCode;
  }

  @override
  void didUpdateWidget(covariant McqQuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.presentationSeed != widget.presentationSeed) {
      final prevOrder = McqOptions.computePresentationOrder(
        oldWidget.content.options,
        presentationSeed:
            oldWidget.presentationSeed ?? _fallbackPresentationSeed,
        shuffle: oldWidget.shuffleOptions,
        avoidOrder: _avoidOrder,
      );
      _avoidOrder = oldWidget.content.id == widget.content.id
          ? prevOrder
          : null;
      _globalAttemptSeed = McqOptions.nextPresentationNonce(
        currentNonce: _globalAttemptSeed,
        options: widget.content.options,
        itemHash: widget.content.id.hashCode,
        previousOrder: _avoidOrder,
      );
      _fallbackPresentationSeed =
          _globalAttemptSeed ^ widget.content.id.hashCode;
    }
  }

  void retry() {
    if (widget.onRetry != null) {
      widget.onRetry!();
      return;
    }
    final prevOrder = presentationOrder;
    setState(() {
      _avoidOrder = prevOrder;
      _globalAttemptSeed = McqOptions.nextPresentationNonce(
        currentNonce: _globalAttemptSeed,
        options: widget.content.options,
        itemHash: widget.content.id.hashCode,
        previousOrder: prevOrder,
      );
      _fallbackPresentationSeed =
          _globalAttemptSeed ^ widget.content.id.hashCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AudioQuestionHeader(
          questionText: widget.content.questionText,
          textStyle: Theme.of(context).textTheme.titleLarge,
          customTextBuilder: widget.customTextBuilder,
          onVoiceInput: widget.onVoiceInput,
          voiceInputHint: 'Say A, B, C, or D',
        ),
        const SizedBox(height: 16),
        McqOptions(
          options: widget.content.options,
          selectedIndex: widget.selectedIndex,
          onChanged: widget.onSelectionChanged,
          showCorrect: widget.showCorrect,
          correctIndex: widget.content.correctAnswer,
          shuffleOptions: widget.shuffleOptions,
          presentationSeed: effectivePresentationSeed,
          avoidOrder: _avoidOrder,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.showCorrect ? 'Next' : 'Submit',
          onPressed: widget.showCorrect ? widget.onNext : widget.onSubmit,
          loading: false,
          icon: null,
        ),
        if (widget.showCorrect && widget.onRetry != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
        if (widget.showCorrect && widget.selectedIndex != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              widget.selectedIndex == widget.content.correctAnswer
                  ? 'Correct!'
                  : 'Incorrect',
              style: TextStyle(
                color: widget.selectedIndex == widget.content.correctAnswer
                    ? Colors.green
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (widget.showCorrect && widget.content.explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Explanation: ${widget.content.explanation!}'),
          ),
      ],
    );
  }
}
