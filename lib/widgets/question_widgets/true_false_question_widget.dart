import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/answer_feedback.dart';
import 'package:learning_pwa/widgets/question_widgets/unscorable_answer_notice.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/true_false_selector.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';
import 'package:learning_pwa/widgets/audio/audio_text_widget.dart';

class TrueFalseQuestionWidget extends StatefulWidget {
  final QuestionContent content;
  final bool? selectedValue;
  final bool showCorrect;
  final Function(bool?) onSelectionChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final Function(String) onVoiceInput;
  final Widget Function(String) customTextBuilder;

  const TrueFalseQuestionWidget({
    super.key,
    required this.content,
    required this.selectedValue,
    required this.showCorrect,
    required this.onSelectionChanged,
    required this.onSubmit,
    required this.onNext,
    required this.onVoiceInput,
    required this.customTextBuilder,
  });

  @override
  State<TrueFalseQuestionWidget> createState() => _TrueFalseQuestionWidgetState();
}

class _TrueFalseQuestionWidgetState extends State<TrueFalseQuestionWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AudioQuestionHeader(
          questionText: widget.content.questionText,
          textStyle: Theme.of(context).textTheme.titleLarge,
          customTextBuilder: widget.customTextBuilder,
          onVoiceInput: widget.onVoiceInput,
          voiceInputHint: 'Say true or false',
        ),
        const SizedBox(height: 16),
        TrueFalseSelector(
          value: widget.selectedValue,
          onChanged: widget.onSelectionChanged,
          showCorrect: widget.showCorrect,
          // Derived from option labels, never from index position.
          correctValue: widget.content.trueFalseCorrectValue,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.showCorrect ? 'Next' : 'Submit',
          onPressed: widget.showCorrect ? widget.onNext : widget.onSubmit,
          loading: false,
          icon: null,
        ),
        if (widget.showCorrect &&
            widget.selectedValue != null &&
            widget.content.trueFalseCorrectValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: AnswerFeedbackText(
              correct: widget.selectedValue ==
                  widget.content.trueFalseCorrectValue,
            ),
          ),
        if (widget.showCorrect && widget.content.trueFalseCorrectValue == null)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: UnscorableAnswerNotice(),
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
