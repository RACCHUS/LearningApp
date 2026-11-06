import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/answer_feedback.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/mcq_options.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';

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
    this.shuffleOptions = false,
    this.presentationSeed,
  });

  @override
  State<McqQuestionWidget> createState() => _McqQuestionWidgetState();
}

class _McqQuestionWidgetState extends State<McqQuestionWidget> {
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
          presentationSeed: widget.presentationSeed,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.showCorrect ? 'Next' : 'Submit',
          onPressed: widget.showCorrect ? widget.onNext : widget.onSubmit,
          loading: false,
          icon: null,
        ),
        if (widget.showCorrect && widget.selectedIndex != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: AnswerFeedbackText(
              correct: widget.selectedIndex == widget.content.correctAnswer,
            ),
          ),
        if (widget.showCorrect && widget.content.explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: AudioTextWidget(
              text: 'Explanation: ${widget.content.explanation!}',
            ),
          ),
      ],
    );
  }
}
