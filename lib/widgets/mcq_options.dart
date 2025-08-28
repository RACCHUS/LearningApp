import 'package:flutter/material.dart';

class McqOptions extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onChanged;
  final bool showCorrect;
  final int? correctIndex;

  const McqOptions({
    Key? key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.showCorrect = false,
    this.correctIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final idx = entry.key;
        final text = entry.value;
        Color? color;
        if (showCorrect && correctIndex != null) {
          if (idx == correctIndex) color = Colors.green;
          else if (selectedIndex == idx && idx != correctIndex) color = Colors.red;
        }
        return ListTile(
          title: Text(text),
          leading: Radio<int>(
            value: idx,
            groupValue: selectedIndex,
            onChanged: (v) => onChanged(idx),
          ),
          tileColor: color?.withValues(alpha: 0.1),
        );
      }).toList(),
    );
  }
}
