import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/reading_position_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gate extends StateNotifier<bool> {
  _Gate(super.on);
  void set(bool on) => state = on;
}

final _gateProvider = StateNotifierProvider<_Gate, bool>((ref) => _Gate(true));

void main() {
  late BridgeLibrary library;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pumpLesson(
    WidgetTester tester, {
    bool gate = true,
    List<String> tags = const ['excel', 'spreadsheet'],
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        _gateProvider.overrideWith((ref) => _Gate(gate)),
        quickRescueEnabledProvider.overrideWith(
          (ref) => ref.watch(_gateProvider),
        ),
        bridgeLibraryProvider.overrideWith((ref) async => library),
        supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
        supportOwnerScopeProvider.overrideWithValue('user-a'),
        supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
        supportStrategyProvider.overrideWithValue(
          PersistedLearningStrategy.fast,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Budget Totals in Excel'),
              actions: [
                LearningHelpAction(
                  lessonId: 'excel-101',
                  lessonTitle: 'Budget Totals in Excel',
                  tags: tags,
                ),
              ],
            ),
            body: const Text('Original lesson body', key: Key('lesson-body')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  int depth(ProviderContainer c) => c
      .read(
        learningSupportControllerProvider(
          const SupportContextKey(
            ownerScope: 'user-a',
            learningContextId: 'ctx-1',
          ),
        ),
      )
      .stack
      .depth;

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFromSheet(WidgetTester tester, String bridgeId) async {
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('support_choice_$bridgeId')));
    await tester.pumpAndSettle();
  }

  testWidgets('no Learning help action when the gate is OFF', (tester) async {
    await pumpLesson(tester, gate: false);
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
    expect(find.byKey(const Key('lesson-body')), findsOneWidget);
  });

  testWidgets('no Learning help action outside the pilot lessons', (
    tester,
  ) async {
    await pumpLesson(tester, tags: const ['algebra']);
    expect(find.byKey(const Key('learning_help_action')), findsNothing);
  });

  testWidgets('exactly one help action; "Not now" opens nothing (A21, A59)', (
    tester,
  ) async {
    final c = await pumpLesson(tester);
    expect(find.byKey(const Key('learning_help_action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('learning_help_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support_choice_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('support_choice_not_now')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-body')), findsOneWidget);
    expect(depth(c), 0);
  });

  testWidgets('open a Bridge, practise, then go back to the lesson', (
    tester,
  ) async {
    final c = await pumpLesson(tester);
    await openFromSheet(tester, 'bridge-percent-change');

    expect(
      find.text('Percent change: how much did it grow or shrink?'),
      findsOneWidget,
    );
    await reveal(tester, find.byKey(const Key('bridge-practice-only')));
    expect(depth(c), 1);
    final saved = await SupportSessionStore().load('user-a');
    expect(saved!.top!.originRoute, '/lesson/excel-101');
    expect(saved.top!.activeLearningStrategy, PersistedLearningStrategy.fast);

    // Numeric check: unreadable, wrong, then right.
    final input = find.byKey(const Key('bridge-check-input-pc-check-1'));
    final submit = find.byKey(const Key('bridge-check-submit-pc-check-1'));
    final result = find.byKey(const Key('bridge-check-result-pc-check-1'));
    await reveal(tester, input);
    await tester.enterText(input, 'fifteen');
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<Text>(result).data, contains('Type a number'));
    await tester.enterText(input, '12');
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<Text>(result).data, contains('Not quite'));
    await tester.enterText(input, '15%');
    await tester.tap(submit);
    await tester.pump();
    expect(tester.widget<Text>(result).data, 'Correct!');

    // Choice check: picking the divide-by-new mistake is wrong.
    final wrong = find.byKey(const Key('bridge-check-option-pc-check-2-b'));
    await reveal(tester, wrong);
    await tester.tap(wrong);
    await tester.tap(find.byKey(const Key('bridge-check-submit-pc-check-2')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('bridge-check-result-pc-check-2')))
          .data,
      contains('Not quite'),
    );

    await reveal(tester, find.byKey(const Key('bridge-not-reviewed')));
    final back = find.byKey(const Key('bridge-return-button'));
    await reveal(tester, back);
    expect(find.text('Back to "Budget Totals in Excel"'), findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-body')), findsOneWidget);
    expect(depth(c), 0);
    expect(await SupportSessionStore().load('user-a'), isNull);
  });

  testWidgets('nested help, gate OFF mid-rescue, Back still works (A61)', (
    tester,
  ) async {
    final c = await pumpLesson(tester);
    await openFromSheet(tester, 'bridge-spreadsheet-percent-format');

    final prereq = find.byKey(const Key('bridge-prereq-bridge-percent-change'));
    await reveal(tester, prereq);
    await tester.tap(prereq);
    await tester.pumpAndSettle();
    expect(depth(c), 2);
    expect(find.byKey(const Key('bridge-back-to-start')), findsOneWidget);
    expect(
      find.byTooltip('Back to Showing percentages in Excel'),
      findsOneWidget,
    );

    c.read(_gateProvider.notifier).set(false);
    await tester.pumpAndSettle();
    final off = find.byKey(const Key('bridge-more-help-off'));
    await reveal(tester, off);
    expect(off, findsOneWidget);
    expect(
      find.byKey(const Key('bridge-prereq-bridge-fraction-decimal')),
      findsNothing,
    );

    // System/browser back goes through the same safe return.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(depth(c), 1);
    expect(find.text('Showing percentages in Excel'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bridge-back-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-body')), findsOneWidget);
    expect(depth(c), 0);
  });

  testWidgets('"Back to the lesson" from two levels deep', (tester) async {
    final c = await pumpLesson(tester);
    await openFromSheet(tester, 'bridge-spreadsheet-percent-format');
    final prereq = find.byKey(const Key('bridge-prereq-bridge-percent-change'));
    await reveal(tester, prereq);
    await tester.tap(prereq);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bridge-back-to-start')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lesson-body')), findsOneWidget);
    expect(depth(c), 0);
  });

  testWidgets('a stale trail is cleared when the origin lesson reopens', (
    tester,
  ) async {
    final first = await pumpLesson(tester);
    await openFromSheet(tester, 'bridge-percent-change');
    expect(depth(first), 1);
    expect(await SupportSessionStore().load('user-a'), isNotNull);

    // Simulated refresh: a new app instance lands on the lesson route.
    await tester.pumpWidget(const SizedBox());
    final second = await pumpLesson(tester);
    await tester.pumpAndSettle();
    expect(depth(second), 0);
    expect(await SupportSessionStore().load('user-a'), isNull);
  });

  testWidgets('the open block is saved and restored after a refresh', (
    tester,
  ) async {
    final first = await pumpLesson(tester);
    first.read(readingBlockProvider('excel-101').notifier).state = 'blk-7';
    await openFromSheet(tester, 'bridge-percent-change');
    final saved = await SupportSessionStore().load('user-a');
    expect(saved!.root!.blockId, 'blk-7');
    expect(saved.root!.assetVersionId, 'excel-101');

    // Simulated refresh: a new app instance lands on the lesson again.
    await tester.pumpWidget(const SizedBox());
    final second = await pumpLesson(tester);
    await tester.pumpAndSettle();
    expect(second.read(pendingReturnBlockProvider('excel-101')), 'blk-7');
    expect(await SupportSessionStore().load('user-a'), isNull);
  });

  testWidgets('without a reported block the anchor has no position', (
    tester,
  ) async {
    await pumpLesson(tester);
    await openFromSheet(tester, 'bridge-percent-change');
    final saved = await SupportSessionStore().load('user-a');
    expect(saved!.root!.blockId, isNull);
    expect(saved.root!.assetVersionId, isNull);
  });
}
