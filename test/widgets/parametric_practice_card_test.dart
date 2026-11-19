import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/parametric_practice_service.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:learning_pwa/widgets/learning_support/parametric_practice_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeParametric extends ParametricPracticeService {
  int served = 0;
  final submitted = <String>[];

  @override
  Future<List<ParametricFamily>> familiesFor(String conceptId) async => [
    if (conceptId == 'spreadsheet-percent-format')
      const ParametricFamily('pc-whole-percent', 'Percent change practice'),
  ];

  @override
  Future<ParametricItem> nextItem(String familyId) async {
    served++;
    return ParametricItem(
      instanceId: 'i$served',
      prompt: 'Question $served: from \$80 to \$60?',
      acceptsPercentSign: true,
    );
  }

  @override
  Future<ParametricResult> submit(String instanceId, String answer) async {
    submitted.add('$instanceId=$answer');
    if (answer == 'abc') return const ParametricResult(readable: false);
    return ParametricResult(
      readable: true,
      correct: answer.replaceAll('%', '').trim() == '-25',
      answer: '-25',
      firstAttempt: true,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpCard(WidgetTester tester, FakeParametric s) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [parametricPracticeServiceProvider.overrideWithValue(s)],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ParametricPracticeCard(
                family: ParametricFamily('pc', 'Percent change practice'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('start, answer wrong, see the answer, then next question', (
    tester,
  ) async {
    final s = FakeParametric();
    await pumpCard(tester, s);
    await tester.tap(find.byKey(const Key('parametric-start-pc')));
    await tester.pumpAndSettle();
    expect(find.text(r'Question 1: from $80 to $60?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('parametric-input-pc')), 'abc');
    await tester.tap(find.byKey(const Key('parametric-check-pc')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Type a number'), findsOneWidget);
    expect(find.byKey(const Key('parametric-next-pc')), findsNothing);

    await tester.enterText(find.byKey(const Key('parametric-input-pc')), '-20');
    await tester.tap(find.byKey(const Key('parametric-check-pc')));
    await tester.pumpAndSettle();
    expect(find.text('Not quite. The answer is -25.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('parametric-next-pc')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 2'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('parametric-input-pc')),
      '-25%',
    );
    await tester.tap(find.byKey(const Key('parametric-check-pc')));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    expect(s.submitted, ['i1=abc', 'i1=-20', 'i2=-25%']);
  });

  test('server refusals map to plain messages', () {
    expect(
      ParametricPracticeException.from(
        const PostgrestException(message: 'rate_limited'),
      ).message,
      contains('Try again tomorrow'),
    );
    expect(ParametricPracticeException.from(StateError('x')).code, 'unknown');
  });

  group('in a Bridge', () {
    late BridgeLibrary library;
    setUpAll(() async => library = await BridgeLibrary.load(rootBundle));

    Future<void> openBridge(WidgetTester tester, {required bool on}) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickRescueEnabledProvider.overrideWithValue(true),
            parametricPracticeEnabledProvider.overrideWithValue(on),
            parametricPracticeServiceProvider.overrideWithValue(
              FakeParametric(),
            ),
            bridgeLibraryProvider.overrideWith((ref) async => library),
            supportSessionStoreProvider.overrideWithValue(
              SupportSessionStore(),
            ),
            supportOwnerScopeProvider.overrideWithValue('user-a'),
            supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
            supportStrategyProvider.overrideWithValue(
              PersistedLearningStrategy.standard,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                actions: const [
                  LearningHelpAction(
                    lessonId: 'excel-101',
                    lessonTitle: 'Budget Totals in Excel',
                    tags: ['excel'],
                  ),
                ],
              ),
              body: const Text('lesson body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('support_choice_bridge-spreadsheet-percent-format'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('switch ON: the family card appears', (tester) async {
      await openBridge(tester, on: true);
      await tester.scrollUntilVisible(
        find.byKey(const Key('parametric-pc-whole-percent')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Percent change practice'), findsOneWidget);
    });

    testWidgets('switch OFF: no extra practice', (tester) async {
      await openBridge(tester, on: false);
      await tester.scrollUntilVisible(
        find.byKey(const Key('bridge-not-reviewed')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('parametric-pc-whole-percent')),
        findsNothing,
      );
    });
  });
}
