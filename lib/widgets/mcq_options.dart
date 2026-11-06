import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/answer_feedback.dart';

class McqOptions extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onChanged;
  final bool showCorrect;
  final int? correctIndex;
  final bool shuffleOptions;
  final int? presentationSeed;

  const McqOptions({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.showCorrect = false,
    this.correctIndex,
    this.shuffleOptions = false,
    this.presentationSeed,
  });

  /// Computes the presentation order for a list of options with anchor preservation.
  /// Returns a list of original indices mapped to each presented position.
  static List<int> computePresentationOrder(
    List<String> options, {
    int? presentationSeed,
    bool shuffle = true,
  }) {
    final count = options.length;
    if (!shuffle || count <= 1) {
      return List.generate(count, (i) => i);
    }

    final anchorIndices = <int>[];
    final nonAnchorIndices = <int>[];

    for (int i = 0; i < count; i++) {
      final text = options[i].toLowerCase();
      final isAnchor = text.contains('all of the above') ||
          text.contains('none of the above') ||
          text.contains('both a and') ||
          text.contains('both b and') ||
          text.contains('neither a nor') ||
          text.contains('neither of the above');
      if (isAnchor) {
        anchorIndices.add(i);
      } else {
        nonAnchorIndices.add(i);
      }
    }

    final seed = presentationSeed ?? 0x5bf03635;
    final rand = math.Random(seed);
    nonAnchorIndices.shuffle(rand);

    return [...nonAnchorIndices, ...anchorIndices];
  }

  @override
  Widget build(BuildContext context) {
    final presentationOrder = (shuffleOptions || presentationSeed != null)
        ? computePresentationOrder(
            options,
            presentationSeed: presentationSeed,
            shuffle: true,
          )
        : List.generate(options.length, (i) => i);

    return Column(
      children: presentationOrder.map((originalIdx) {
        final text = options[originalIdx];
        bool? mark;
        if (showCorrect && correctIndex != null) {
          if (originalIdx == correctIndex) {
            mark = true;
          } else if (selectedIndex == originalIdx) {
            mark = false;
          }
        }
        final color =
            mark == null ? null : answerColor(context, correct: mark);
        return ListTile(
          title: Text(text),
          onTap: () => onChanged(originalIdx),
          leading: Radio<int>(
            value: originalIdx,
            groupValue: selectedIndex,
            onChanged: (v) => onChanged(originalIdx),
          ),
          trailing: mark == null ? null : AnswerMarkIcon(correct: mark),
          tileColor: color?.withValues(alpha: 0.1),
        );
      }).toList(),
    );
  }
}
