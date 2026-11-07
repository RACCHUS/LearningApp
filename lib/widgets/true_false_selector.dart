import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/answer_feedback.dart';

class TrueFalseSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool showCorrect;
  final bool? correctValue;

  const TrueFalseSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.showCorrect = false,
    this.correctValue,
  });

  @override
  Widget build(BuildContext context) {
    bool? markFor(bool option) {
      if (!showCorrect || correctValue == null) return null;
      if (correctValue == option) return true;
      return value == option ? false : null;
    }

    final trueMark = markFor(true);
    final falseMark = markFor(false);
    Color? tint(bool? mark) => mark == null
        ? null
        : answerColor(context, correct: mark).withValues(alpha: 0.2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('True'),
          avatar: trueMark == null ? null : AnswerMarkIcon(correct: trueMark),
          showCheckmark: trueMark == null,
          selected: value == true,
          onSelected: (_) => onChanged(true),
          selectedColor: tint(trueMark),
        ),
        const SizedBox(width: 16),
        ChoiceChip(
          label: const Text('False'),
          avatar: falseMark == null ? null : AnswerMarkIcon(correct: falseMark),
          showCheckmark: falseMark == null,
          selected: value == false,
          onSelected: (_) => onChanged(false),
          selectedColor: tint(falseMark),
        ),
      ],
    );
  }
}
