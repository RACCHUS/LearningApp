import 'package:flutter/material.dart';

class ShortAnswerField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? feedback;

  const ShortAnswerField({
    Key? key,
    required this.controller,
    this.enabled = true,
    this.feedback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Your Answer',
            border: OutlineInputBorder(),
          ),
        ),
        if (feedback != null) ...[
          const SizedBox(height: 8),
          Text(
            feedback!,
            style: TextStyle(
              color: feedback == 'Correct!' ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ]
      ],
    );
  }
}
