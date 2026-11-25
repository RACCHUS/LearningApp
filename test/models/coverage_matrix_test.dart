import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/screens/governance/coverage_matrix_screen.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';

Map<String, dynamic> row(
  String code,
  List<String> tags, {
  int teach = 5,
  int example = 2,
  int practice = 3,
  int check = 4,
  bool unreviewed = true,
}) => {
  'objective_id': 'o-$code',
  'code': code,
  'title': 'Objective $code',
  'tags': tags,
  'unreviewed': unreviewed,
  'teach_blocks': teach,
  'example_blocks': example,
  'practice_items': practice,
  'check_items': check,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary bridges;
  setUpAll(() async => bridges = await BridgeLibrary.load(rootBundle));

  test('imported content, a Bridge and unverified access', () {
    final r = CoverageRow.fromServer(
      row('1.2', ['algebra', 'exponents']),
      bridges,
    );
    expect(r.cells[CoverageRole.teach], CoverageState.imported);
    expect(r.cells[CoverageRole.check], CoverageState.imported);
    expect(r.cells[CoverageRole.bridge], CoverageState.imported);
    expect(r.cells[CoverageRole.access], CoverageState.notVerified);
    expect(r.gaps, isEmpty);
  });

  test('missing roles are gaps; reviewed content is marked reviewed', () {
    final r = CoverageRow.fromServer(
      row('9.9', ['history'], example: 0, check: 0, unreviewed: false),
      bridges,
    );
    expect(r.cells[CoverageRole.teach], CoverageState.reviewed);
    expect(r.gaps, [
      CoverageRole.example,
      CoverageRole.check,
      CoverageRole.bridge,
    ]);
  });

  test('Check counts independent checks once the server reports them', () {
    Map<String, dynamic> v2(int heldOut, {int practice = 0, int graded = 0}) =>
        {
          ...row('2.1', ['history'], practice: practice, unreviewed: false),
          'graded_practice_items': graded,
          'held_out_items': heldOut,
        };
    // Graded lesson questions are practice, not checks.
    final none = CoverageRow.fromServer(v2(0, graded: 10), bridges);
    expect(none.cells[CoverageRole.check], CoverageState.gap);
    expect(none.cells[CoverageRole.practice], CoverageState.reviewed);
    expect(none.gaps, contains(CoverageRole.check));
    expect(
      CoverageRow.fromServer(v2(3), bridges).cells[CoverageRole.check],
      CoverageState.partial,
    );
    final full = CoverageRow.fromServer(v2(6), bridges);
    expect(full.cells[CoverageRole.check], CoverageState.verified);
    expect(full.cells[CoverageRole.practice], CoverageState.gap);
    expect(full.gaps, isNot(contains(CoverageRole.check)));
    // A draft fills a gap only; partial and verified checks stay as they are.
    expect(
      CoverageRow.fromServer(
        v2(3),
        bridges,
      ).withDraft().cells[CoverageRole.check],
      CoverageState.partial,
    );
  });

  test('every state has its required text label', () {
    for (final s in CoverageState.values) {
      expect(s.label, isNotEmpty);
      expect(s.icon, isNotEmpty);
    }
  });

  testWidgets('the screen shows a row per objective with labelled cells', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bridgeLibraryProvider.overrideWith((ref) async => bridges)],
        child: MaterialApp(
          home: CoverageMatrixScreen(
            loadTargets: () async => ['open-openstax-college-algebra-1e'],
            loadMatrix: (slug) async => {
              'objectives': [
                row('1.2', ['exponents']),
                row('1.4', ['algebra'], check: 0),
              ],
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coverage_table')), findsOneWidget);
    expect(find.text('◐ Imported'), findsWidgets);
    expect(find.byKey(const Key('cell_1.4_check')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cell_1.4_check'))).data,
      '○ Not available yet',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('cell_1.2_access'))).data,
      '? Not yet verified',
    );
  });

  testWidgets('the fill list opens from the matrix and shows every score term', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bridgeLibraryProvider.overrideWith((ref) async => bridges)],
        child: MaterialApp(
          home: CoverageMatrixScreen(
            loadTargets: () async => ['open-openstax-prealgebra-1e'],
            loadMatrix: (slug) async => {'objectives': []},
            loadFillList: () async => [
              {
                'target_slug': 'open-openstax-prealgebra-1e',
                'objective_id': 'o1',
                'code': '6.1',
                'title': 'Understand Percent',
                'missing': ['check'],
                'priority': 0.5,
                'fan_in': 2,
                'frequency_boost': 1.0,
                'coverage_deficit': 0.25,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coverage_fill_list')));
    await tester.pumpAndSettle();
    expect(
      find.text('open-openstax-prealgebra-1e · 6.1 Understand Percent'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Missing: check · priority 0.5 (books 2 × requests 1.0 × missing 0.25)',
      ),
      findsOneWidget,
    );
  });
}
