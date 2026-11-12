import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openExcelBridge(
    WidgetTester tester, {
    required bool suggestions,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickRescueEnabledProvider.overrideWithValue(true),
          autoGapSuggestionsEnabledProvider.overrideWithValue(suggestions),
          bridgeLibraryProvider.overrideWith((ref) async => library),
          supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
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
      find.byKey(const Key('support_choice_bridge-spreadsheet-percent-format')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> answerChoice(
    WidgetTester tester,
    String item,
    String option,
  ) async {
    final o = find.byKey(Key('bridge-check-option-$item-$option'));
    await reveal(tester, o);
    await tester.tap(o);
    await tester.tap(find.byKey(Key('bridge-check-submit-$item')));
    await tester.pumpAndSettle();
  }

  const suggestion = Key('bridge-gap-suggestion');

  testWidgets('two first-try misses show one dismissible suggestion', (
    tester,
  ) async {
    await openExcelBridge(tester, suggestions: true);
    await answerChoice(tester, 'sp-check-1', 'c'); // wrong
    expect(
      find.byKey(suggestion),
      findsNothing,
      reason: 'one miss is not enough',
    );

    // A retry on the same item (wrong again) is not new evidence.
    await answerChoice(tester, 'sp-check-1', 'b');
    expect(find.byKey(suggestion), findsNothing);

    await answerChoice(tester, 'sp-check-2', 'a'); // wrong
    await reveal(tester, find.byKey(suggestion));
    expect(find.textContaining('missed 2 of 2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(suggestion),
        matching: find.textContaining('Fractions, decimals and percents'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('bridge-gap-not-the-issue')));
    await tester.pumpAndSettle();
    // The next prerequisite is offered instead; dismiss it too.
    expect(find.textContaining('Percent change'), findsWidgets);
    await tester.tap(find.byKey(const Key('bridge-gap-not-the-issue')));
    await tester.pumpAndSettle();
    expect(find.byKey(suggestion), findsNothing);
  });

  testWidgets('a disputed question does not count', (tester) async {
    await openExcelBridge(tester, suggestions: true);
    await answerChoice(tester, 'sp-check-1', 'c');
    final dispute = find.byKey(const Key('bridge-check-dispute-sp-check-2'));
    await reveal(tester, dispute);
    await tester.tap(dispute);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('bridge-check-disputed-sp-check-2')),
      findsOneWidget,
    );
    await answerChoice(tester, 'sp-check-2', 'a');
    expect(find.byKey(suggestion), findsNothing);
  });

  testWidgets('accepting opens the refresher inside the help trail', (
    tester,
  ) async {
    await openExcelBridge(tester, suggestions: true);
    await answerChoice(tester, 'sp-check-1', 'c');
    await answerChoice(tester, 'sp-check-2', 'a');
    final open = find.byKey(const Key('bridge-gap-open'));
    await reveal(tester, open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Fractions, decimals and percents'), findsOneWidget);
    expect(find.byKey(const Key('bridge-back-to-start')), findsOneWidget);
  });

  testWidgets('flag OFF: no suggestion even with many misses', (tester) async {
    await openExcelBridge(tester, suggestions: false);
    await answerChoice(tester, 'sp-check-1', 'c');
    await answerChoice(tester, 'sp-check-2', 'a');
    expect(find.byKey(suggestion), findsNothing);
    // Explicit help is unchanged.
    await reveal(
      tester,
      find.byKey(const Key('bridge-prereq-bridge-fraction-decimal')),
    );
  });
}
