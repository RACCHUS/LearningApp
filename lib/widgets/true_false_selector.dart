import 'package:flutter/material.dart';

class TrueFalseSelector extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool showCorrect;
  final bool? correctValue;

  const TrueFalseSelector({
    Key? key,
    required this.value,
    required this.onChanged,
    this.showCorrect = false,
    this.correctValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color? trueColor;
    Color? falseColor;
    if (showCorrect && correctValue != null) {
      trueColor = correctValue == true ? Colors.green : (value == true ? Colors.red : null);
      falseColor = correctValue == false ? Colors.green : (value == false ? Colors.red : null);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('True'),
          selected: value == true,
          onSelected: (_) => onChanged(true),
          selectedColor: trueColor,
        ),
        const SizedBox(width: 16),
        ChoiceChip(
          label: const Text('False'),
          selected: value == false,
          onSelected: (_) => onChanged(false),
          selectedColor: falseColor,
        ),
      ],
    );
  }
}
