import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_support/learning_support_kinds.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/gap_signal_service.dart';

CheckAttempt miss(String id, {bool disputed = false}) =>
    CheckAttempt(itemId: id, firstAttemptCorrect: false, disputed: disputed);
CheckAttempt hit(String id) =>
    CheckAttempt(itemId: id, firstAttemptCorrect: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary library;

  setUpAll(() async => library = await BridgeLibrary.load(rootBundle));

  GapSuggestion? propose(
    List<CheckAttempt> attempts, {
    String bridge = 'bridge-spreadsheet-percent-format',
    Set<String> dismissed = const {},
    bool Function(dynamic)? canOpen,
  }) => GapSignalService.propose(
    bridge: library[bridge]!,
    attempts: attempts,
    library: library,
    dismissed: dismissed,
    canOpen: canOpen ?? (_) => true,
  );

  test('tiers: one miss is only suspected, two distinct misses supported', () {
    expect(GapSignalService.tierFor([]), GapEvidenceTier.none);
    expect(GapSignalService.tierFor([hit('a')]), GapEvidenceTier.none);
    expect(GapSignalService.tierFor([miss('a')]), GapEvidenceTier.suspected);
    expect(
      GapSignalService.tierFor([miss('a'), miss('a')]),
      GapEvidenceTier.suspected,
      reason: 'the same item twice is not independent evidence',
    );
    expect(
      GapSignalService.tierFor([miss('a'), miss('b')]),
      GapEvidenceTier.supported,
    );
  });

  test('a single miss never produces a suggestion (A21)', () {
    expect(propose([miss('sp-check-1'), hit('sp-check-2')]), isNull);
  });

  test('two misses suggest the first prerequisite, with a reason', () {
    final s = propose([miss('sp-check-1'), miss('sp-check-2'), hit('x')])!;
    expect(s.prerequisite.bridgeId, 'bridge-fraction-decimal');
    expect(s.tier, GapEvidenceTier.supported);
    expect(s.hypothesis, GapKind.missingPrerequisite);
    expect(s.missed, 2);
    expect(s.counted, 3);
    expect(s.reason, contains('missed 2 of 3'));
  });

  test('disputed questions never count against the learner (A22)', () {
    expect(
      propose([miss('sp-check-1'), miss('sp-check-2', disputed: true)]),
      isNull,
    );
  });

  test('"Not the issue" moves to the next prerequisite, then to none', () {
    final attempts = [miss('a'), miss('b')];
    expect(
      propose(
        attempts,
        dismissed: {'bridge-fraction-decimal'},
      )!.prerequisite.bridgeId,
      'bridge-percent-change',
    );
    expect(
      propose(
        attempts,
        dismissed: {'bridge-fraction-decimal', 'bridge-percent-change'},
      ),
      isNull,
    );
  });

  test('respects depth and cycle limits via canOpen', () {
    expect(propose([miss('a'), miss('b')], canOpen: (_) => false), isNull);
  });

  test('a Bridge with no prerequisites never suggests anything', () {
    expect(
      propose([
        miss('a'),
        miss('b'),
        miss('c'),
      ], bridge: 'bridge-fraction-decimal'),
      isNull,
    );
  });
}
