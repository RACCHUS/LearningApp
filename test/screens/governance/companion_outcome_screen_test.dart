import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/companion_outcome_screen.dart';

void main() {
  final calls = <String, Map<String, dynamic>>{};

  Map<String, dynamic> report({bool small = false}) => {
    'target_version_id': 'v1',
    'goal_learners': small ? null : 40,
    'goal_learners_status': small ? 'small_cohort_suppressed' : 'ok',
    'with_outside_resource': small ? null : 12,
    'outside_resource_share': small ? null : 0.3,
    'outside_resource_status': small ? 'small_cohort_suppressed' : 'ok',
    'mapping': small
        ? {'status': 'small_cohort_suppressed'}
        : {
            'status': 'ok',
            'listed_only': 0,
            'ticked_objectives': 5,
            'outline_word_match': 7,
            'outline_own_ai': 0,
          },
    'studied_then_checked': small
        ? {'status': 'small_cohort_suppressed'}
        : {
            'status': 'ok',
            'studied_pairs': 30,
            'checked_within_7_days': 18,
            'checked_share': 0.6,
            'mean_check_score': 0.725,
          },
    'not_measured': [
      {
        'measure': 'return after a break',
        'reason':
            'needs a session definition and events that are not collected',
      },
    ],
  };

  Future<void> pump(
    WidgetTester tester, {
    bool small = false,
    bool fails = false,
  }) async {
    calls.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: CompanionOutcomeScreen(
          loadVersions: () async => [
            {'id': 'v1', 'label': 'CLEP College Algebra · 2026'},
          ],
          rpc: (fn, params) async {
            calls[fn] = params;
            if (fails) throw StateError('forbidden');
            return report(small: small);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the grouped counts for the chosen goal', (tester) async {
    await pump(tester);
    expect(calls['get_companion_outcome_report'], {
      'p_target_version_id': 'v1',
    });
    expect(find.text('Learners on this goal: 40'), findsOneWidget);
    expect(find.text('With an outside resource: 12 (30%)'), findsOneWidget);
    expect(find.text('Pasted an outline: 7'), findsOneWidget);
    expect(
      find.text('Followed by a LearningApp check within 7 days: 18 (60%)'),
      findsOneWidget,
    );
    expect(find.text('Mean check score: 73%'), findsOneWidget);
    expect(find.textContaining('return after a break'), findsOneWidget);
    expect(find.textContaining('It proves no effect'), findsOneWidget);
  });

  testWidgets('says plainly when a group is too small to show', (tester) async {
    await pump(tester, small: true);
    expect(
      find.textContaining('Learners on this goal: fewer than 5'),
      findsOneWidget,
    );
    expect(find.textContaining('Breakdown fewer than 5'), findsOneWidget);
    expect(find.textContaining('Counts fewer than 5'), findsOneWidget);
    expect(find.textContaining('40'), findsNothing);
  });

  testWidgets('a refusal from the server says who may read it', (tester) async {
    await pump(tester, fails: true);
    expect(find.textContaining('Admins and moderators only'), findsOneWidget);
  });
}
