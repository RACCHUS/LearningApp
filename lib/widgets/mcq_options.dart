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
  final List<int>? avoidOrder;

  const McqOptions({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.showCorrect = false,
    this.correctIndex,
    this.shuffleOptions = true,
    this.presentationSeed,
    this.avoidOrder,
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

  /// Ensures [order] differs from [previousOrder] whenever [options] has at
  /// least two non-anchor choices by deterministically transposing the first
  /// two non-anchor slots if a collision occurred.
  static List<int> ensureDistinctOrder(
    List<String> options,
    List<int> order,
    List<int>? previousOrder,
  ) {
    if (previousOrder == null ||
        order.length != previousOrder.length ||
        countNonAnchorOptions(options) < 2 ||
        !listsEqual(order, previousOrder)) {
      return order;
    }

    final adjusted = List<int>.from(order);
    int? firstNonAnchorPos;
    int? secondNonAnchorPos;
    for (int pos = 0; pos < adjusted.length; pos++) {
      final originalIdx = adjusted[pos];
      if (originalIdx >= 0 &&
          originalIdx < options.length &&
          !isAnchorOption(options[originalIdx])) {
        if (firstNonAnchorPos == null) {
          firstNonAnchorPos = pos;
        } else {
          secondNonAnchorPos = pos;
          break;
        }
      }
    }

    if (firstNonAnchorPos != null && secondNonAnchorPos != null) {
      final tmp = adjusted[firstNonAnchorPos];
      adjusted[firstNonAnchorPos] = adjusted[secondNonAnchorPos];
      adjusted[secondNonAnchorPos] = tmp;
    }
    return adjusted;
  }

  /// Computes the presentation order for a list of options with anchor preservation.
  /// Returns a list of original indices mapped to each presented position.
  ///
  /// When [avoidOrder] is provided and [options] has at least two non-anchor
  /// choices, the returned permutation is guaranteed to differ from [avoidOrder].
  static List<int> computePresentationOrder(
    List<String> options, {
    int? presentationSeed,
    bool shuffle = true,
    List<int>? avoidOrder,
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

    final order = <int>[...nonAnchorIndices, ...anchorIndices];
    if (avoidOrder != null && nonAnchorIndices.length >= 2) {
      return ensureDistinctOrder(options, order, avoidOrder);
    }
    return order;
  }

  /// Advances [currentNonce] to a fresh raw per-presentation/per-attempt nonce.
  ///
  /// The returned nonce is never pre-XORed with [itemHash]. When [options] has
  /// at least 2 non-anchor choices and [previousOrder] is provided, candidate
  /// nonces are stepped across a bounded window as a best-effort statistical
  /// diversifier. The strict guarantee that consecutive presentations differ is
  /// enforced deterministically by [ensureDistinctOrder] (and by
  /// [computePresentationOrder] when `avoidOrder` is supplied).
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
        countNonAnchorOptions(options) < 2) {
      return candidate;
    }

    // Bounded search across 64 candidate nonces to reduce RNG collisions before
    // deterministic transposition in ensureDistinctOrder.
    for (int attempt = 0; attempt < 64; attempt++) {
      final effectiveSeed = itemHash != null
          ? (candidate ^ itemHash)
          : candidate;
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
            avoidOrder: avoidOrder,
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
