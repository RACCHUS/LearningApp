/// Attempt-scoped, seeded option shuffle with correct-answer remapping
/// (master plan v2.6 §5.6, Appendix D.2).
///
/// `permutation[displayPosition] = originalIndex`, so the displayed correct
/// position is `permutation.indexOf(canonicalCorrectIndex)`. Never shuffle
/// without remapping.
///
/// Uses a 32-bit xorshift generator so the same seed yields the same order
/// on the Dart VM and on the web. For protected assessments the permutation
/// and key stay on the authorized server; this is for formative use.
class OptionPermutation {
  OptionPermutation._(this.order);

  /// `order[displayPosition] = originalIndex`.
  final List<int> order;

  int get length => order.length;

  /// Deterministic Fisher-Yates shuffle of [count] options for [seed].
  factory OptionPermutation.seeded(int count, int seed) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    final order = List<int>.generate(count, (i) => i);
    var state = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : seed & 0xFFFFFFFF;
    int next() {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= state >> 17;
      state ^= (state << 5) & 0xFFFFFFFF;
      state &= 0xFFFFFFFF;
      return state;
    }

    for (var i = count - 1; i > 0; i--) {
      final j = next() % (i + 1);
      final tmp = order[i];
      order[i] = order[j];
      order[j] = tmp;
    }
    return OptionPermutation._(List.unmodifiable(order));
  }

  /// Wraps an explicit order after checking it is a complete permutation.
  factory OptionPermutation.fromOrder(List<int> order) {
    if (!isValidOrder(order, order.length)) {
      throw ArgumentError('Not a complete permutation: $order');
    }
    return OptionPermutation._(List.unmodifiable(order));
  }

  /// True when [order] contains each of `0..count-1` exactly once.
  static bool isValidOrder(List<int> order, int count) {
    if (order.length != count) return false;
    final seen = List<bool>.filled(count, false);
    for (final i in order) {
      if (i < 0 || i >= count || seen[i]) return false;
      seen[i] = true;
    }
    return true;
  }

  /// Options in display order.
  List<T> apply<T>(List<T> options) {
    if (options.length != order.length) {
      throw ArgumentError('Expected ${order.length} options');
    }
    return [for (final i in order) options[i]];
  }

  /// Display position of the canonical correct option.
  int displayedCorrectIndex(int canonicalCorrectIndex) {
    final position = order.indexOf(canonicalCorrectIndex);
    if (position < 0) {
      throw RangeError.index(canonicalCorrectIndex, order, 'correct index');
    }
    return position;
  }

  /// Original index of the option shown at [displayPosition].
  int originalIndexAt(int displayPosition) => order[displayPosition];
}
