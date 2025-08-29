import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/true_false_selector.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';

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
          correctValue: widget.content.correctAnswer == 0 ? false : true,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.showCorrect ? 'Next' : 'Submit',
          onPressed: widget.showCorrect ? widget.onNext : widget.onSubmit,
          loading: false,
          icon: null,
        ),
        if (widget.showCorrect && widget.selectedValue != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              (widget.selectedValue == (widget.content.correctAnswer == 1)) ? 'Correct!' : 'Incorrect',
              style: TextStyle(
                color: (widget.selectedValue == (widget.content.correctAnswer == 1)) ? Colors.green : Colors.red,
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
