import 'package:flutter/material.dart';

/// Shown instead of right/wrong feedback when a question's stored answer key
/// is missing, out of range or ambiguous. The app never guesses an answer,
/// and the attempt is not counted as correct or incorrect.
class UnscorableAnswerNotice extends StatelessWidget {
  const UnscorableAnswerNotice({super.key});

  static const message =
      'This question has no clear correct answer saved, '
      'so it was not scored. Edit the lesson to choose the right answer.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
