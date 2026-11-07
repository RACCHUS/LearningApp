import 'package:flutter/material.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';

/// Correct/incorrect markers that never rely on color alone: each pairs a
/// distinct icon shape with a text or semantic label.
Color answerColor(BuildContext context, {required bool correct}) {
  final semantic = Theme.of(context).extension<SemanticColors>();
  return correct
      ? semantic?.success ?? Colors.green.shade800
      : semantic?.danger ?? Theme.of(context).colorScheme.error;
}

/// Check / cross icon for an answer option.
class AnswerMarkIcon extends StatelessWidget {
  const AnswerMarkIcon({super.key, required this.correct, this.size = 20});

  final bool correct;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      correct ? Icons.check_circle : Icons.cancel,
      key: Key(correct ? 'answer-mark-correct' : 'answer-mark-incorrect'),
      color: answerColor(context, correct: correct),
      size: size,
      semanticLabel: correct ? 'Correct answer' : 'Incorrect answer',
    );
  }
}

/// "Correct!" / "Incorrect" result line with an icon.
class AnswerFeedbackText extends StatelessWidget {
  const AnswerFeedbackText({super.key, required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: AnswerMarkIcon(correct: correct)),
        const SizedBox(width: 6),
        Text(
          correct ? 'Correct!' : 'Incorrect',
          style: TextStyle(
            color: answerColor(context, correct: correct),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
