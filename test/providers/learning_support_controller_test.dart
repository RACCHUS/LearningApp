import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/models/learning_support/return_anchor.dart';
import 'package:learning_pwa/models/learning_support/return_anchor_stack.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReturnAnchor anchor(String session, {String context = 'ctx-1'}) => ReturnAnchor(
  learningContextId: context,
  rootType: ReturnAnchorRootType.lesson,
  rootId: 'excel-101',
  originRoute: '/lesson/excel-101',
  lessonId: 'excel-101',
  activeLearningStrategy: PersistedLearningStrategy.fast,
  originActivityStateRevision: 0,
  rescueSessionId: session,
  createdAt: DateTime.utc(2026, 11, 12),
);

class FailingStore extends SupportSessionStore {
  @override
  Future<bool> save(ReturnAnchorStack stack) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BridgeLibrary library;
  late SupportSessionStore store;
  var gate = true;
  const key = SupportContextKey(
    ownerScope: 'user-a',
    learningContextId: 'ctx-1',
  );

  LearningSupportController make({
    SupportSessionStore? s,
    String owner = 'user-a',
  }) => LearningSupportController(
    key: SupportContextKey(ownerScope: owner, learningContextId: 'ctx-1'),
    store: s ?? store,
    isGateOn: () => gate,
  );

  setUpAll(() async {
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SupportSessionStore();
    gate = true;
  });

  test('bundled library loads every bundled Bridge offline', () {
    expect(library.bridges.map((b) => b.bridgeId).toSet(), {
      'bridge-fraction-decimal',
      'bridge-percent-change',
      'bridge-percent-of-number',
      'bridge-spreadsheet-percent-format',
      'bridge-exponents',
      'bridge-scientific-notation',
      'bridge-square-roots',
      'bridge-order-of-operations',
      'bridge-fraction-arithmetic',
      'bridge-integer-division',
      'bridge-loop-count',
    });
    expect(
      library.offerOrder.first.bridgeId,
      'bridge-spreadsheet-percent-format',
    );
  });

  test('gate OFF opens nothing and writes nothing (A24)', () async {
    gate = false;
    final c = make();
    final out = await c.openBridge(
      library['bridge-percent-change']!,
      anchor('r1'),
    );
    expect(out, BridgeOpenOutcome.gateOff);
    expect(c.state.stack.isEmpty, isTrue);
    expect(await store.load('user-a'), isNull);
  });

  test('anchor is saved before open returns', () async {
    final c = make();
    final out = await c.openBridge(
      library['bridge-percent-change']!,
      anchor('r1'),
    );
    expect(out, BridgeOpenOutcome.opened);
    final saved = await store.load('user-a');
    expect(saved!.top!.rescueSessionId, 'r1');
    expect(saved.top!.activeLearningStrategy, PersistedLearningStrategy.fast);
    expect(c.state.persisted, isTrue);
  });

  test(
    'Excel → percent → fractions nests, then a repeat is a cycle (A23)',
    () async {
      final c = make();
      expect(
        await c.openBridge(
          library['bridge-spreadsheet-percent-format']!,
          anchor('r1'),
        ),
        BridgeOpenOutcome.opened,
      );
      expect(
        await c.openBridge(library['bridge-percent-change']!, anchor('r2')),
        BridgeOpenOutcome.opened,
      );
      expect(
        await c.openBridge(library['bridge-fraction-decimal']!, anchor('r3')),
        BridgeOpenOutcome.opened,
      );
      expect(c.canOpen(library['bridge-percent-change']!), isFalse);
      expect(
        await c.openBridge(library['bridge-percent-change']!, anchor('r4')),
        BridgeOpenOutcome.cycle,
      );
      await c.returnFromTop();
      expect(
        await c.openBridge(library['bridge-percent-change']!, anchor('r5')),
        BridgeOpenOutcome.cycle,
      );
    },
  );

  test('return works after the gate turns OFF mid-rescue (A61)', () async {
    final c = make();
    await c.openBridge(
      library['bridge-spreadsheet-percent-format']!,
      anchor('r1'),
    );
    await c.openBridge(library['bridge-percent-change']!, anchor('r2'));
    gate = false;
    expect(c.canOpen(library['bridge-fraction-decimal']!), isFalse);
    final back = await c.returnFromTop();
    expect(back!.rescueSessionId, 'r2');
    final root = await c.returnToRoot();
    expect(root!.rescueSessionId, 'r1');
    expect(c.state.stack.isEmpty, isTrue);
    expect(await store.load('user-a'), isNull);
  });

  test(
    'a refresh restores the trail, and settling at the origin clears it',
    () async {
      final first = make();
      await first.openBridge(library['bridge-percent-change']!, anchor('r1'));

      final afterRefresh = make();
      await afterRefresh.restore();
      expect(afterRefresh.state.stack.depth, 1);

      await afterRefresh.settleAt('/lesson/other');
      expect(afterRefresh.state.stack.depth, 1, reason: 'not at the origin');
      await afterRefresh.settleAt('/lesson/excel-101');
      expect(afterRefresh.state.stack.isEmpty, isTrue);
    },
  );

  test("another account never sees this account's trail", () async {
    await make().openBridge(library['bridge-percent-change']!, anchor('r1'));
    final other = make(owner: 'user-b');
    await other.restore();
    expect(other.state.stack.isEmpty, isTrue);
  });

  test('rejects anchors from another context', () async {
    final c = make();
    expect(
      await c.openBridge(
        library['bridge-percent-change']!,
        anchor('r1', context: 'ctx-2'),
      ),
      BridgeOpenOutcome.rejected,
    );
  });

  test('a storage failure is reported but Back still works', () async {
    final c = make(s: FailingStore());
    await c.openBridge(library['bridge-percent-change']!, anchor('r1'));
    expect(c.state.persisted, isFalse);
    expect((await c.returnFromTop())!.rescueSessionId, 'r1');
  });

  test('help is scoped to the lesson topic, with foundations kept', () {
    Set<String> ids(List<String> tags) =>
        library.forLesson(tags).bridges.map((b) => b.bridgeId).toSet();
    expect(library.hasHelpFor(['Excel', 'budget']), isTrue);
    expect(ids(['percent', 'math']), {
      'bridge-fraction-decimal',
      'bridge-percent-change',
      'bridge-percent-of-number',
    });
    // Scientific notation builds on exponents, so both are offered.
    expect(ids(['algebra', 'scientific-notation']), {
      'bridge-exponents',
      'bridge-scientific-notation',
    });
    expect(ids(['radicals']), {'bridge-exponents', 'bridge-square-roots'});
    expect(ids(['order-of-operations']), {'bridge-order-of-operations'});
    // Fraction arithmetic builds on fractions/decimals, which is kept.
    expect(ids(['rational-expressions']), {
      'bridge-fraction-arithmetic',
      'bridge-fraction-decimal',
    });
    // A lesson no Bridge covers gets no help button.
    expect(library.hasHelpFor(['algebra', 'math']), isFalse);
    expect(library.forLesson(['history']).isEmpty, isTrue);
  });

  test('owner scope', () {
    expect(supportOwnerScope('8f0c-uuid'), '8f0c-uuid');
    expect(supportOwnerScope('bad owner'), 'guest');
    expect(key.ownerScope, 'user-a');
  });

  test('corrupt stored data is ignored, not trusted', () async {
    SharedPreferences.setMockInitialValues({
      SupportSessionStore.keyFor('user-a'): '{not json',
    });
    expect(await SupportSessionStore().load('user-a'), isNull);
  });
}
