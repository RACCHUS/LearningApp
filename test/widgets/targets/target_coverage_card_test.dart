import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
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

  Future<void> pumpCard(WidgetTester tester, List<Map<String, dynamic>> rows,
      {Set<String> drafts = const {}, String? targetId, List<LearnerResource> mine = const []}) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: TargetCoverageCard(targetSlug: 'algebra', targetVersionId: 'v1', targetId: targetId),
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
        coverageDraftsLoaderProvider.overrideWithValue((ids) async => drafts.intersection(ids)),
        learnerResourcesProvider.overrideWith((ref, id) async => mine),
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

  testWidgets("the learner's own outside resources are marked, as their own notes", (tester) async {
    const book = LearnerResource(
      id: 'r1',
      targetId: 't1',
      title: 'My textbook',
      kind: LearnerResourceKind.book,
      objectives: {'1.2': null},
    );
    final rows = [row('1.2', ['exponents'], example: 0), row('1.4', ['history'], example: 0)];
    await pumpCard(tester, rows, targetId: 't1', mine: const [book]);
    expect(find.byKey(const Key('target-coverage-outside')), findsOneWidget);
    expect(find.textContaining('1 of 2 topics'), findsOneWidget);
    expect(find.textContaining('only LearningApp checks count toward readiness'), findsOneWidget);
    expect(find.text('Covered in what you use: My textbook'), findsOneWidget);
    expect(find.byKey(const Key('need-outside-o-1.4')), findsNothing);
    // Without a goal id, or with no resources, nothing outside is shown.
    await pumpCard(tester, rows);
    expect(find.byKey(const Key('target-coverage-outside')), findsNothing);
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

  test('a draft fills content gaps but never outranks imported content', () {
    final r = CoverageRow.fromServer(row('1.4', ['history'], check: 0), bridges).withDraft();
    expect(r.cells[CoverageRole.check], CoverageState.draft);
    expect(r.cells[CoverageRole.teach], CoverageState.imported);
    // Bridge and Access are not something a private lesson stands in for.
    expect(r.cells[CoverageRole.bridge], CoverageState.gap);
    expect(r.cells[CoverageRole.access], CoverageState.notVerified);
  });

  testWidgets('a learner-attached lesson shows as "Your draft"', (tester) async {
    await pumpCard(tester, [row('1.4', ['exponents'], check: 0)], drafts: {'o-1.4'});
    expect(find.text('Check: ✎ 1 your draft'), findsOneWidget);
    // Nothing is missing any more, so no Need card.
    expect(find.byType(NeedCard), findsNothing);
  });

  testWidgets('a drafts lookup failure still shows coverage', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bridgeLibraryProvider.overrideWith((ref) async => bridges),
        coverageMatrixLoaderProvider.overrideWithValue(
            (slug) async => {'objectives': [row('1.4', ['history'], check: 0)]}),
        coverageDraftsLoaderProvider.overrideWithValue((ids) async => throw Exception('offline')),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TargetCoverageCard(targetSlug: 'x', targetVersionId: 'v1'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Check: ○ 1 not available yet'), findsOneWidget);
  });
}
