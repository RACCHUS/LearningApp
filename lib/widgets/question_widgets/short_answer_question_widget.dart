import 'package:flutter/material.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/widgets/primary_button.dart';
import 'package:learning_pwa/widgets/short_answer_field.dart';
import 'package:learning_pwa/widgets/audio/audio_question_header.dart';

class ShortAnswerQuestionWidget extends StatefulWidget {
  final QuestionContent content;
  final TextEditingController controller;
  final String? feedback;
  final bool showCorrect;
  final Function(String) onAnswerChanged;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final Function(String) onVoiceInput;
  final Widget Function(String) customTextBuilder;

  const ShortAnswerQuestionWidget({
    super.key,
    required this.content,
    required this.controller,
    required this.feedback,
    required this.showCorrect,
    required this.onAnswerChanged,
    required this.onSubmit,
    required this.onNext,
    required this.onVoiceInput,
    required this.customTextBuilder,
  });

  @override
  State<ShortAnswerQuestionWidget> createState() => _ShortAnswerQuestionWidgetState();
}

class _ShortAnswerQuestionWidgetState extends State<ShortAnswerQuestionWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AudioQuestionHeader(
          questionText: widget.content.questionText,
          textStyle: Theme.of(context).textTheme.titleLarge,
          customTextBuilder: widget.customTextBuilder,
          onVoiceInput: widget.onVoiceInput,
          voiceInputHint: 'Speak your answer',
        ),
        const SizedBox(height: 16),
        ShortAnswerField(
          controller: widget.controller,
          enabled: !widget.showCorrect,
          feedback: widget.feedback,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: widget.showCorrect ? 'Next' : 'Submit',
          onPressed: widget.showCorrect ? widget.onNext : widget.onSubmit,
          loading: false,
          icon: null,
        ),
        if (widget.showCorrect && widget.content.explanation != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Explanation',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 20),
                          onPressed: () {
                            AudioService().speak(
                              'Explanation: ${widget.content.explanation!}',
                              interrupt: true,
                            );
                          },
                          tooltip: 'Read explanation aloud',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.content.explanation!),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
