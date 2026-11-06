import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

class ShortAnswerField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? feedback;

  const ShortAnswerField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          textField: true,
          label: 'Your answer',
          child: TextField(
            controller: controller,
            enabled: enabled,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Your Answer',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (feedback != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              feedback!,
              style: TextStyle(
                color: feedback!.startsWith('Correct')
                    ? Theme.of(context).extension<SemanticColors>()?.success ??
                        Colors.green.shade800
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]
      ],
    );
  }
}
