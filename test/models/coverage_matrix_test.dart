import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/screens/governance/coverage_matrix_screen.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';

Map<String, dynamic> row(String code, List<String> tags, {
  int teach = 5, int example = 2, int practice = 3, int check = 4, bool unreviewed = true,
}) => {
  'objective_id': 'o-$code', 'code': code, 'title': 'Objective $code', 'tags': tags,
  'unreviewed': unreviewed, 'teach_blocks': teach, 'example_blocks': example,
  'practice_items': practice, 'check_items': check,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BridgeLibrary bridges;
  setUpAll(() async => bridges = await BridgeLibrary.load(rootBundle));

  test('imported content, a Bridge and unverified access', () {
    final r = CoverageRow.fromServer(row('1.2', ['algebra', 'exponents']), bridges);
    expect(r.cells[CoverageRole.teach], CoverageState.imported);
    expect(r.cells[CoverageRole.check], CoverageState.imported);
    expect(r.cells[CoverageRole.bridge], CoverageState.imported);
    expect(r.cells[CoverageRole.access], CoverageState.notVerified);
    expect(r.gaps, isEmpty);
  });

  test('missing roles are gaps; reviewed content is marked reviewed', () {
    final r = CoverageRow.fromServer(
      row('9.9', ['history'], example: 0, check: 0, unreviewed: false), bridges);
    expect(r.cells[CoverageRole.teach], CoverageState.reviewed);
    expect(r.gaps, [CoverageRole.example, CoverageRole.check, CoverageRole.bridge]);
  });

  test('every state has its required text label', () {
    for (final s in CoverageState.values) {
      expect(s.label, isNotEmpty);
      expect(s.icon, isNotEmpty);
    }
  });

  testWidgets('the screen shows a row per objective with labelled cells', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ProviderScope(
      overrides: [bridgeLibraryProvider.overrideWith((ref) async => bridges)],
      child: MaterialApp(
        home: CoverageMatrixScreen(
          loadTargets: () async => ['open-openstax-college-algebra-1e'],
          loadMatrix: (slug) async => {
            'objectives': [row('1.2', ['exponents']), row('1.4', ['algebra'], check: 0)],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coverage_table')), findsOneWidget);
    expect(find.text('◐ Imported'), findsWidgets);
    expect(find.byKey(const Key('cell_1.4_check')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cell_1.4_check'))).data, '○ Not available yet');
    expect(tester.widget<Text>(find.byKey(const Key('cell_1.2_access'))).data, '? Not yet verified');
  });
}
