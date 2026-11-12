// PR-A2: seeded option permutation with correct-answer remapping
// (master plan v2.6 §5.6, Appendix D.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/content_generation/option_permutation.dart';

void main() {
  const options = ['A0', 'B1', 'C2', 'D3'];

  test('every seed gives a complete permutation', () {
    for (var seed = 0; seed < 500; seed++) {
      final p = OptionPermutation.seeded(4, seed);
      expect(OptionPermutation.isValidOrder(p.order, 4), isTrue);
    }
  });

  test('same seed, same order (deterministic)', () {
    expect(
      OptionPermutation.seeded(6, 42).order,
      OptionPermutation.seeded(6, 42).order,
    );
  });

  test('pinned orders guard cross-platform stability', () {
    // If these change, previously shown attempts would re-shuffle
    // differently on reload. Update only deliberately.
    expect(OptionPermutation.seeded(4, 1).order, [0, 2, 3, 1]);
    expect(OptionPermutation.seeded(4, 12345).order, [1, 3, 0, 2]);
    expect(OptionPermutation.seeded(6, 0x7FFFFFFF).order, [4, 0, 2, 5, 1, 3]);
  });

  test('displayed correct option is the canonical one for every seed', () {
    for (var seed = 0; seed < 200; seed++) {
      final p = OptionPermutation.seeded(4, seed);
      final shown = p.apply(options);
      for (var c = 0; c < 4; c++) {
        expect(shown[p.displayedCorrectIndex(c)], options[c]);
        expect(p.originalIndexAt(p.displayedCorrectIndex(c)), c);
      }
    }
  });

  test('the correct option lands in every display position across seeds', () {
    final positions = <int>{};
    for (var seed = 0; seed < 200; seed++) {
      positions.add(OptionPermutation.seeded(4, seed).displayedCorrectIndex(0));
    }
    expect(positions, {0, 1, 2, 3});
  });

  test('shuffling without remapping would be wrong for some seed', () {
    // Guard against the bug the plan forbids: using c unchanged.
    final differs = Iterable<int>.generate(50).any((seed) {
      final p = OptionPermutation.seeded(4, seed);
      return p.displayedCorrectIndex(2) != 2;
    });
    expect(differs, isTrue);
  });

  test('incomplete or duplicate orders are rejected', () {
    expect(
      () => OptionPermutation.fromOrder([0, 0, 1, 2]),
      throwsArgumentError,
    );
    expect(
      () => OptionPermutation.fromOrder([0, 1, 4, 2]),
      throwsArgumentError,
    );
    expect(OptionPermutation.fromOrder([2, 0, 1]).displayedCorrectIndex(0), 1);
  });

  test('applying to the wrong number of options throws', () {
    expect(
      () => OptionPermutation.seeded(3, 1).apply(options),
      throwsArgumentError,
    );
  });
}
