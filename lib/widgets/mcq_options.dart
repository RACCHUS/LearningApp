import 'dart:math' as math;
import 'package:flutter/material.dart';

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
    this.shuffleOptions = true,
    this.presentationSeed,
  });

  /// Returns true if [optionText] is a positional anchor choice that must
  /// remain at the end of the option list.
  static bool isAnchorOption(String optionText) {
    final text = optionText.toLowerCase();
    return text.contains('all of the above') ||
        text.contains('none of the above') ||
        text.contains('both a and') ||
        text.contains('both b and') ||
        text.contains('neither a nor') ||
        text.contains('neither of the above');
  }

  /// Counts how many choices in [options] are non-anchor options.
  static int countNonAnchorOptions(List<String> options) {
    int count = 0;
    for (final option in options) {
      if (!isAnchorOption(option)) {
        count++;
      }
    }
    return count;
  }

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
      if (isAnchorOption(options[i])) {
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

  /// Advances [currentNonce] to a fresh raw per-presentation/per-attempt nonce.
  ///
  /// The returned nonce is never pre-XORed with [itemHash]. When [options] has
  /// at least 2 non-anchor choices and [previousOrder] is provided, candidate
  /// nonces are stepped until the resulting permutation (computed with
  /// `candidate ^ itemHash` when [itemHash] is supplied, or `candidate`
  /// directly otherwise) differs from [previousOrder].
  static int nextPresentationNonce({
    required int currentNonce,
    List<String>? options,
    int? itemHash,
    List<int>? previousOrder,
  }) {
    int candidate = (currentNonce + 0x9E3779B9) & 0x7FFFFFFF;
    if (candidate == 0 || candidate == currentNonce) {
      candidate = (currentNonce ^ 0x5bf03635) & 0x7FFFFFFF;
      if (candidate == 0) candidate = 0x5bf03635;
    }

    if (options == null ||
        previousOrder == null ||
        countNonAnchorOptions(options) <= 1) {
      return candidate;
    }

    for (int attempt = 0; attempt < 32; attempt++) {
      final effectiveSeed =
          itemHash != null ? (candidate ^ itemHash) : candidate;
      final order = computePresentationOrder(
        options,
        presentationSeed: effectiveSeed,
        shuffle: true,
      );
      if (!listsEqual(order, previousOrder)) {
        return candidate;
      }
      candidate = (candidate + 0x9E3779B9 + attempt + 1) & 0x7FFFFFFF;
      if (candidate == 0 || candidate == currentNonce) {
        candidate = (0x5bf03635 + attempt + 1) & 0x7FFFFFFF;
      }
    }
    return candidate;
  }

  static bool listsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
        Color? color;
        if (showCorrect && correctIndex != null) {
          if (originalIdx == correctIndex) {
            color = Colors.green;
          } else if (selectedIndex == originalIdx && originalIdx != correctIndex) {
            color = Colors.red;
          }
        }
        return ListTile(
          title: Text(text),
          onTap: () => onChanged(originalIdx),
          leading: Radio<int>(
            value: originalIdx,
            groupValue: selectedIndex,
            onChanged: (v) => onChanged(originalIdx),
          ),
          tileColor: color?.withValues(alpha: 0.1),
        );
      }).toList(),
    );
  }
}
