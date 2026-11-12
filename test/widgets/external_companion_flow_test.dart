import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late BridgeLibrary library;
  late ExternalCompanionLibrary companionLibrary;
  late List<Uri> opened;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
    companionLibrary = await ExternalCompanionLibrary.load(rootBundle, library);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    opened = [];
  });

  Future<void> openBridge(
    WidgetTester tester, {
    required bool companions,
    bool launchOk = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickRescueEnabledProvider.overrideWithValue(true),
          externalCompanionEnabledProvider.overrideWithValue(companions),
          bridgeLibraryProvider.overrideWith((ref) async => library),
          externalCompanionLibraryProvider.overrideWith(
            (ref) async => companionLibrary,
          ),
          externalLinkLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return launchOk;
          }),
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
      find.byKey(const Key('support_choice_bridge-percent-change')),
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

  const section = Key('external-companion-bridge-percent-change');
  const openKey = Key('external-companion-open-bridge-percent-change');

  testWidgets('flag OFF: no companion, Bridge sources still shown', (
    tester,
  ) async {
    await openBridge(tester, companions: false);
    await reveal(tester, find.text('Sources (links only)'));
    expect(find.byKey(section), findsNothing);
  });

  testWidgets('flag ON: pointer, focus note, outside link and own checks', (
    tester,
  ) async {
    await openBridge(tester, companions: true);
    await reveal(tester, find.byKey(openKey));
    expect(find.textContaining('6.2 Solve General Applications'), findsWidgets);
    expect(find.textContaining('Free · no sign-in'), findsOneWidget);
    expect(find.textContaining('What to look for:'), findsOneWidget);

    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'openstax.org');
    // Still on the Bridge: nothing navigated away inside the app.
    expect(
      find.text('Percent change: how much did it grow or shrink?'),
      findsOneWidget,
    );

    final input = find.byKey(const Key('bridge-check-input-pcx-check-1'));
    await reveal(tester, input);
    await tester.enterText(input, '-25%');
    await tester.tap(find.byKey(const Key('bridge-check-submit-pcx-check-1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('bridge-check-result-pcx-check-1')),
          )
          .data,
      'Correct!',
    );
  });

  testWidgets('a failed launch explains itself and keeps the learner here', (
    tester,
  ) async {
    await openBridge(tester, companions: true, launchOk: false);
    await reveal(tester, find.byKey(openKey));
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't open the link"), findsOneWidget);
  });
}
