import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_support/companion_plan.dart';
import 'package:learning_pwa/providers/companion_plan_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/services/learning_support/companion_plan_library.dart';
import 'package:learning_pwa/services/learning_support/external_companion_library.dart';
import 'package:learning_pwa/widgets/learning_support/companion_plan_screen.dart';
import 'package:learning_pwa/widgets/learning_support/external_companion_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary bridges;
  late ExternalCompanionLibrary companions;
  late CompanionPlanLibrary plans;

  setUpAll(() async {
    bridges = await BridgeLibrary.load(rootBundle);
    companions = await ExternalCompanionLibrary.load(rootBundle, bridges);
    plans = await CompanionPlanLibrary.load(rootBundle, bridges, companions);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> plan(List<Map<String, dynamic>> parts, {Object? usesAi = false}) => {
        'plan_version': 1, 'plan_id': 'plan-test', 'title': 'Test plan', 'uses_ai': usesAi,
        'intro': 'Follow along.', 'parts': parts,
      };
  Map<String, dynamic> part(String id, String bridge, String kind) =>
      {'part_id': id, 'bridge_id': bridge, 'kind': kind};

  group('bundled plans', () {
    for (final path in CompanionPlanLibrary.assetPaths) {
      test('$path is valid against the Bridges and companions', () async {
        final json = jsonDecode(await rootBundle.loadString(path));
        expect(CompanionPlanLibrary.issuesFor(json, bridges, companions), isEmpty);
      });
    }

    test('every bundled plan loads', () {
      expect(plans.plans, hasLength(CompanionPlanLibrary.assetPaths.length));
      expect(plans.forBridge('bridge-percent-change')!.planId, 'plan-openstax-prealgebra-percent');
    });
  });

  group('validation', () {
    test('must work without AI and have at least two steps', () {
      expect(CompanionPlan.decode(plan([
        part('a', 'bridge-exponents', 'outside_section'),
        part('b', 'bridge-square-roots', 'outside_section'),
      ], usesAi: true)).plan, isNull);
      expect(CompanionPlan.decode(plan([part('a', 'bridge-exponents', 'outside_section')])).plan, isNull);
    });

    test('a Bridge appears once and an outside section is required', () {
      expect(CompanionPlan.decode(plan([
        part('a', 'bridge-exponents', 'outside_section'),
        part('b', 'bridge-exponents', 'fill_in'),
      ])).plan, isNull);
      expect(CompanionPlan.decode(plan([
        part('a', 'bridge-exponents', 'fill_in'),
        part('b', 'bridge-square-roots', 'fill_in'),
      ])).plan, isNull);
    });

    test('unknown Bridges are rejected', () {
      final unknown = plan([
        part('a', 'bridge-exponents', 'outside_section'),
        part('b', 'bridge-nope', 'fill_in'),
      ]);
      expect(CompanionPlanLibrary.issuesFor(unknown, bridges, companions), isNotEmpty);
    });
  });

  List<Override> overrides(List<Uri> opened) => [
        externalCompanionEnabledProvider.overrideWithValue(true),
        bridgeLibraryProvider.overrideWith((ref) async => bridges),
        externalCompanionLibraryProvider.overrideWith((ref) async => companions),
        companionPlanLibraryProvider.overrideWith((ref) async => plans),
        externalLinkLauncherProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ];

  testWidgets('the plan lists steps in order, opens links and keeps ticks', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <Uri>[];
    final p = plans.forBridge('bridge-percent-change')!;
    await tester.pumpWidget(ProviderScope(
      overrides: overrides(opened),
      child: MaterialApp(home: CompanionPlanScreen(plan: p)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1: 5.3 Decimals and Fractions'), findsOneWidget);
    expect(find.textContaining('Step 4: '), findsOneWidget);
    expect(find.textContaining('(short LearningApp lesson)'), findsOneWidget);
    expect(find.text('0 of 4 steps ticked. Your ticks stay on this device; reading outside '
        'is never tracked or counted as progress.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('companion-plan-part-pa-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion-plan-open-pa-2')));
    await tester.pumpAndSettle();
    expect(opened.single.path, contains('6-1'));

    await tester.tap(find.byKey(const Key('companion-plan-done-pa-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 4 steps ticked'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('companion_plan_done_v1_plan-openstax-prealgebra-percent'), ['pa-1']);
  });

  testWidgets('a fill-in step shows the short lesson and its checks', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final p = plans.forBridge('bridge-percent-change')!;
    await tester.pumpWidget(ProviderScope(
      overrides: overrides([]),
      child: MaterialApp(home: CompanionPlanScreen(plan: p)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion-plan-part-pa-4')));
    await tester.pumpAndSettle();
    final bridge = bridges['bridge-spreadsheet-percent-format']!;
    expect(find.text(bridge.objectiveStatement), findsOneWidget);
    expect(find.text('Check yourself (practice only):'), findsOneWidget);
  });

  testWidgets('a companion that belongs to a plan links to it', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides([]),
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ExternalCompanionSection(bridgeId: 'bridge-loop-count')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final link = find.byKey(const Key('external-companion-plan-bridge-loop-count'));
    expect(find.textContaining('Step 2 of 2 in "Python basics'), findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(CompanionPlanScreen), findsOneWidget);
  });
}
