import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/widgets/library/create_chooser_sheet.dart';
import 'package:learning_pwa/widgets/targets/target_coverage_card.dart';

Map<String, dynamic> row(String code, List<String> tags,
        {int example = 2, int check = 4}) =>
    {
      'objective_id': 'o-$code', 'code': code, 'title': 'Objective $code',
      'tags': tags, 'unreviewed': true, 'teach_blocks': 5,
      'example_blocks': example, 'practice_items': 3, 'check_items': check,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary bridges;
  setUpAll(() async => bridges = await BridgeLibrary.load(rootBundle));

  Future<void> pumpCard(WidgetTester tester, List<Map<String, dynamic>> rows) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(
            child: TargetCoverageCard(targetSlug: 'algebra', targetVersionId: 'v1'),
          ),
        ),
      ),
      GoRoute(path: '/create-lesson', builder: (_, __) => const Text('create')),
      GoRoute(path: '/community/wanted', builder: (_, __) => const Text('wanted')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bridgeLibraryProvider.overrideWith((ref) async => bridges),
        coverageMatrixLoaderProvider.overrideWithValue((slug) async => {'objectives': rows}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  test('summary counts per role and lists needs without Access', () {
    final s = CoverageSummary([
      CoverageRow.fromServer(row('1.2', ['exponents']), bridges),
      CoverageRow.fromServer(row('1.4', ['history'], check: 0), bridges),
    ]);
    expect(s.countsFor(CoverageRole.teach), {CoverageState.imported: 2});
    expect(s.countsFor(CoverageRole.check),
        {CoverageState.imported: 1, CoverageState.gap: 1});
    expect(s.needs.single.row.code, '1.4');
    expect(s.needs.single.missing, [CoverageRole.check, CoverageRole.bridge]);
  });

  testWidgets('chips are text-labelled and need cards open a private draft',
      (tester) async {
    await pumpCard(tester, [row('1.2', ['exponents']), row('1.4', ['history'], check: 0)]);
    expect(find.byKey(const Key('target-coverage-card')), findsOneWidget);
    expect(find.text('Check: ◐ 1 imported · ○ 1 not available yet'), findsOneWidget);
    expect(find.text('Access: ? 2 not yet verified'), findsOneWidget);
    expect(find.text('○ Not available yet: Check, Bridge'), findsOneWidget);
    expect(find.byKey(const Key('need-card-o-1.2')), findsNothing);

    await tester.tap(find.byKey(const Key('need-make-own-o-1.4')));
    await tester.pumpAndSettle();
    expect(find.text('create'), findsOneWidget);
  });

  testWidgets('long need lists collapse to three', (tester) async {
    await pumpCard(tester, [
      for (var i = 1; i <= 5; i++) row('2.$i', ['history'], check: 0),
    ]);
    expect(find.text('Missing pieces (5)'), findsOneWidget);
    expect(find.byType(NeedCard), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('target-coverage-show-all')));
    await tester.pumpAndSettle();
    expect(find.byType(NeedCard), findsNWidgets(5));
  });

  testWidgets('no published objectives shows nothing', (tester) async {
    await pumpCard(tester, const []);
    expect(find.byKey(const Key('target-coverage-card')), findsNothing);
  });

  testWidgets('chooser lists the goal needs above the general choices',
      (tester) async {
    final need = CoverageSummary([
      CoverageRow.fromServer(row('1.4', ['history'], check: 0), bridges),
    ]).needs.single;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CreateChooserSheet(needs: [need], needsGoalTitle: 'Algebra'),
      ),
    ));
    expect(find.text('Missing from Algebra'), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-need-o-1.4')), findsOneWidget);
    expect(find.byKey(const Key('create-chooser-lesson')), findsOneWidget);
  });

  testWidgets('chooser without needs shows only the general choices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CreateChooserSheet()),
    ));
    expect(find.textContaining('Missing from'), findsNothing);
    expect(find.byKey(const Key('create-chooser-goal')), findsOneWidget);
  });
}
