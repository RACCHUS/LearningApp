import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/version_decision_screen.dart';

void main() {
  late Map<String, Map<String, dynamic>> calls;

  Future<dynamic> rpc(String fn, Map<String, dynamic> params) async {
    calls[fn] = params;
    switch (fn) {
      case 'get_version_decision_candidates':
        return [
          {
            'target_slug': 'open-openstax-prealgebra-1e', 'target_title': 'Prealgebra',
            'champion_id': 'v3', 'champion_code': 'R3',
            'challengers': [{'id': 'v4', 'code': 'R4'}],
          },
        ];
      case 'get_version_comparison':
        return {
          'champion': {
            'version_code': 'R3', 'lessons': 5, 'teach_blocks': 40, 'example_blocks': 10,
            'practice_items': 20, 'check_items': 49,
            'review': {'accuracy': {'ok': 1, 'concern': 2}},
            'learner_evidence': 'measured', 'learner_accounts': 7, 'check_accuracy': 0.8,
          },
          'challenger': {
            'version_code': 'R4', 'lessons': 5, 'teach_blocks': 42, 'example_blocks': 12,
            'practice_items': 20, 'check_items': 49, 'review': {},
            'learner_evidence': 'not_published',
          },
        };
      default:
        return null;
    }
  }

  setUp(() => calls = {});

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: VersionDecisionScreen(rpc: rpc)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decision-pick-v4')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows both versions side by side, honestly', (tester) async {
    await open(tester);
    expect(find.text('Prealgebra: R3 → R4'), findsOneWidget);
    expect(find.text('Published R3'), findsOneWidget);
    expect(find.text('1 ok, 2 concern'), findsOneWidget);
    expect(find.text('7 learners, 80% correct'), findsOneWidget);
    expect(find.text('not published yet'), findsOneWidget);
  });

  testWidgets('replacing for a defect needs the defect named', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('decision-blocker')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('decision-record'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('decision-defect')), 'Captions lost their numbers');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decision-record')));
    await tester.pumpAndSettle();
    final p = calls['record_content_version_decision']!;
    expect(p['p_decision'], 'replace');
    expect(p['p_basis'], 'fixes_defect');
    expect(p['p_defect_ref'], 'Captions lost their numbers');
    expect(p['p_rubric'], isNull);
  });

  testWidgets('a rubric replacement needs +2 and no lower accuracy', (tester) async {
    await open(tester);
    await tester.tap(find.text('Scores better'));
    await tester.pumpAndSettle();
    expect(find.text('Margin: +0'), findsOneWidget);
    expect(find.textContaining('at least 2 points'), findsOneWidget);

    Future<void> score(String side, String aspect, int value) async {
      await tester.tap(find.byKey(Key('decision-score-$side-$aspect')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$value').last);
      await tester.pumpAndSettle();
    }

    await score('challenger', 'clarity', 5);
    await score('challenger', 'accuracy', 2);
    expect(find.text('Margin: +1'), findsOneWidget);
    expect(find.textContaining('lower on accuracy'), findsOneWidget);

    await score('challenger', 'accuracy', 3);
    await score('challenger', 'accessibility', 4);
    expect(find.text('Margin: +3'), findsOneWidget);
    expect(find.byKey(const Key('decision-blocker')), findsNothing);
    await tester.tap(find.byKey(const Key('decision-record')));
    await tester.pumpAndSettle();
    final p = calls['record_content_version_decision']!;
    expect(p['p_basis'], 'rubric_margin');
    expect(p['p_rubric'], {
      'champion': {'clarity': 3, 'accuracy': 3, 'accessibility': 3},
      'challenger': {'clarity': 5, 'accuracy': 3, 'accessibility': 4},
    });
  });

  testWidgets('keeping as an alternate needs no basis', (tester) async {
    await open(tester);
    await tester.tap(find.text('Keep as alternate'));
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('decision-blocker')), findsNothing);
    await tester.tap(find.byKey(const Key('decision-record')));
    await tester.pumpAndSettle();
    expect(calls['record_content_version_decision']!['p_decision'], 'alternate');
    expect(calls['record_content_version_decision']!['p_basis'], 'none');
  });
}
