import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/learner_signals_screen.dart';

void main() {
  final calls = <String>[];

  Map<String, dynamic> report({bool failing = true}) => {
    'learners_status': 'ok',
    'consenting_learners': 14,
    'objectives': [
      {
        'objective_id': 'o1',
        'code': '1.1',
        'title': 'Busy objective',
        'status': 'ok',
        'held_out_items': 6,
        'estimate_low': 5,
        'estimate_high': 9,
        'completed_learners': 12,
        'checked_after_teaching': 11,
        'fail_rate': 0.545,
        'timed_learners': 12,
        'median_active_minutes': 20.0,
        'signals': [
          if (failing) 'repeated_failure_after_teaching',
          'time_off_estimate',
        ],
      },
      {
        'objective_id': 'o2',
        'code': '1.2',
        'title': 'Quiet objective',
        'status': 'small_cohort_suppressed',
        'held_out_items': 0,
        'estimate_low': null,
        'estimate_high': null,
        'signals': [],
      },
    ],
  };

  Future<dynamic> Function(String, Map<String, dynamic>) fakeRpc({
    bool failing = true,
  }) => (fn, params) async {
    calls.add(fn);
    if (fn == 'get_learner_signal_report') return report(failing: failing);
    if (fn == 'open_learner_signal_reviews') {
      return {'opened': 1, 'already_open': 0};
    }
    return null;
  };

  Future<void> pump(WidgetTester tester, {bool failing = true}) async {
    calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerSignalsScreen(
          loadVersions: () async => [
            {'id': 'v1', 'label': 'College Algebra · R6'},
          ],
          rpc: fakeRpc(failing: failing),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows counts, suppression and signals per objective', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Learners with progress: 14'), findsOneWidget);
    expect(find.text('12 finished the teaching'), findsOneWidget);
    expect(
      find.text('11 took the checks afterwards; 55% scored below 60%'),
      findsOneWidget,
    );
    expect(
      find.text('Median study time 20.0 min (12 learners)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('6 independent checks · estimate 5–9 min'),
      findsOneWidget,
    );
    expect(
      find.text('Fewer than 5 learners finished the teaching, not shown'),
      findsOneWidget,
    );
    expect(
      find.textContaining('review the teaching and Bridges first'),
      findsOneWidget,
    );
    expect(find.textContaining('update the estimate'), findsOneWidget);
    expect(find.textContaining('not a comparison'), findsOneWidget);
  });

  testWidgets('opens review items only on request', (tester) async {
    await pump(tester);
    expect(calls, isNot(contains('open_learner_signal_reviews')));
    await tester.tap(find.byKey(const Key('signals-open-reviews')));
    await tester.pumpAndSettle();
    expect(calls, contains('open_learner_signal_reviews'));
    expect(find.textContaining('Opened 1 review item(s)'), findsOneWidget);
  });

  testWidgets('no review button without a repeated-failure signal', (
    tester,
  ) async {
    await pump(tester, failing: false);
    expect(find.byKey(const Key('signals-open-reviews')), findsNothing);
  });

  testWidgets('a refused report says who can read it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearnerSignalsScreen(
          loadVersions: () async => [
            {'id': 'v1', 'label': 'Target · V1'},
          ],
          rpc: (fn, params) async => throw Exception('42501'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load the signals. Admins and moderators only.'),
      findsOneWidget,
    );
  });
}
