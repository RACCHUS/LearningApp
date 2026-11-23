// Accessibility review for P3.3 (master plan v2.6): the learning-support
// surfaces must meet Flutter's tap-target, labelling and contrast
// guidelines in light and dark themes, and must not overflow at 200% text.
// Findings and fixes: docs/accessibility/LEARNING_SUPPORT_ACCESSIBILITY_REVIEW.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/providers/companion_plan_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/companion_plan_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';
import 'package:learning_pwa/services/learning_support/support_session_store.dart';
import 'package:learning_pwa/theme/app_theme.dart';
import 'package:learning_pwa/widgets/learning_support/companion_plan_screen.dart';
import 'package:learning_pwa/widgets/learning_support/learning_help_action.dart';
import 'package:learning_pwa/widgets/targets/target_coverage_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // No web fonts in tests; colours (what contrast depends on) are real.
  AppTheme.useWebFonts = false;
  late BridgeLibrary library;
  late ExternalCompanionLibrary companions;
  late CompanionPlanLibrary plans;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    library = await BridgeLibrary.load(rootBundle);
    companions = await ExternalCompanionLibrary.load(rootBundle, library);
    plans = await CompanionPlanLibrary.load(rootBundle, library, companions);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  List<Override> overrides() => [
        quickRescueEnabledProvider.overrideWith((ref) => true),
        bridgeLibraryProvider.overrideWith((ref) async => library),
        supportSessionStoreProvider.overrideWithValue(SupportSessionStore()),
        supportOwnerScopeProvider.overrideWithValue('user-a'),
        supportContextIdProvider.overrideWith((ref, id) => 'ctx-1'),
        supportStrategyProvider.overrideWithValue(PersistedLearningStrategy.fast),
        coverageMatrixLoaderProvider.overrideWithValue((slug) async => {
              'objectives': [
                {
                  'objective_id': 'o-6.1', 'code': '6.1', 'title': 'Understand Percent',
                  'tags': ['percent'], 'unreviewed': true, 'teach_blocks': 5,
                  'example_blocks': 2, 'practice_items': 3, 'check_items': 0,
                },
              ],
            }),
      ];

  Future<void> pump(
    WidgetTester tester, {
    required ThemeData theme,
    double textScale = 1,
    Widget? body,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(),
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Percent'),
            actions: const [
              LearningHelpAction(
                lessonId: 'pct-1',
                lessonTitle: 'Percent',
                tags: ['percent'],
              ),
            ],
          ),
          body: body ?? const Text('Lesson body'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> meetsAll(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  for (final (name, makeTheme) in [
    ('light', () => AppTheme.lightTheme()),
    ('dark', () => AppTheme.darkTheme()),
  ]) {
    testWidgets('help action and choice sheet meet guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, theme: makeTheme());
      await meetsAll(tester);
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('support_choice_sheet')), findsOneWidget);
      await meetsAll(tester);
      handle.dispose();
    });

    testWidgets('an open Bridge meets guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, theme: makeTheme());
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('support_choice_bridge-percent-of-number')));
      await tester.pumpAndSettle();
      expect(find.text(library['bridge-percent-of-number']!.title), findsOneWidget);
      // Check every screenful: teaching, checks, the outside resource with
      // its depth control, and the Back button.
      final scroll = find.byType(Scrollable).first;
      for (var page = 0; page < 30; page++) {
        await meetsAll(tester);
        if (find.byKey(const Key('bridge-return-button')).hitTestable().evaluate().isNotEmpty) break;
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('bridge-return-button')).hitTestable(), findsOneWidget);
      handle.dispose();
    });

    testWidgets('coverage card meets guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester,
          theme: makeTheme(),
          body: const SingleChildScrollView(
            child: TargetCoverageCard(targetSlug: 'pct', targetVersionId: 'v1'),
          ));
      expect(find.byKey(const Key('target-coverage-card')), findsOneWidget);
      await meetsAll(tester);
      handle.dispose();
    });

    testWidgets('companion plan meets guidelines ($name)', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...overrides(),
          externalCompanionEnabledProvider.overrideWithValue(true),
          externalCompanionLibraryProvider.overrideWith((ref) async => companions),
          companionPlanLibraryProvider.overrideWith((ref) async => plans),
        ],
        child: MaterialApp(
          theme: makeTheme(),
          home: CompanionPlanScreen(plan: plans.forBridge('bridge-percent-change')!),
        ),
      ));
      await tester.pumpAndSettle();
      await meetsAll(tester);
      await tester.tap(find.byKey(const Key('companion-plan-part-pa-1')));
      await tester.pumpAndSettle();
      await meetsAll(tester);
      handle.dispose();
    });
  }

  testWidgets('every Bridge renders at 200% text on a phone without overflow', (tester) async {
    for (final b in library.bridges) {
      await pump(tester, theme: AppTheme.lightTheme(), textScale: 2);
      await tester.tap(find.byKey(const Key('learning_help_action')));
      await tester.pumpAndSettle();
      final choice = find.byKey(Key('support_choice_${b.bridgeId}'));
      if (choice.evaluate().isEmpty) {
        // Only Bridges for this lesson's tags are offered; reach the
        // rest through their own tags.
        await tester.pumpWidget(const SizedBox());
        await pumpFor(tester, b.appliesToTags.first, textScale: 2, overrides: overrides());
        await tester.tap(find.byKey(const Key('learning_help_action')));
        await tester.pumpAndSettle();
      }
      final target = find.byKey(Key('support_choice_${b.bridgeId}'));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: b.bridgeId);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Future<void> pumpFor(
  WidgetTester tester,
  String tag, {
  required double textScale,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Lesson'),
          actions: [
            LearningHelpAction(lessonId: 'l-$tag', lessonTitle: 'Lesson', tags: [tag]),
          ],
        ),
        body: const Text('Lesson body'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
