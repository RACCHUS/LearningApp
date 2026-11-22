import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/governance/contribution_review_screen.dart';
import 'package:learning_pwa/screens/governance/prompt_pack_signals_screen.dart';

void main() {
  final calls = <String, Map<String, dynamic>>{};

  Future<dynamic> fakeRpc(String fn, Map<String, dynamic> params) async {
    calls[fn] = params;
    switch (fn) {
      case 'get_prompt_quality_overview':
        return {'groups': [
          {'pack_version': 'la-gen-1.1', 'ai_label': 'gemini', 'tier': 'compact',
           'status': 'measured', 'accounts': 6, 'replies': 40,
           'clean_first_pass_rate': 0.8, 'slots_complete_rate': 0.9},
          {'pack_version': 'la-gen-1.1', 'ai_label': 'claude', 'tier': 'compact',
           'status': 'small_cohort_suppressed'},
        ]};
      case 'get_generated_lesson_feedback_overview':
        return {'packs': []};
      case 'get_prompt_pack_signals':
        return {
          'golden_runs': [
            {'pack_version': 'la-gen-1.1', 'ai_label': 'gemini', 'run_on': '2026-11-22',
             'cases_total': 10, 'cases_passed': 9, 'pass_rate': 0.9, 'note': 'Free tier'},
          ],
          'review_evidence': [
            {'pack_version': 'la-gen-1.1', 'aspect': 'accuracy', 'lessons': 2, 'ok': 1, 'concern': 1},
          ],
          'downstream': [
            {'pack_version': 'la-gen-1.1', 'status': 'measured', 'accounts': 5,
             'answered': 20, 'later_check_accuracy': 0.75},
          ],
        };
      default:
        return null;
    }
  }

  testWidgets('shows all five signals with suppression', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PromptPackSignalsScreen(rpc: fakeRpc)));
    await tester.pumpAndSettle();
    expect(find.textContaining('clean first pass 80%'), findsOneWidget);
    expect(find.text('la-gen-1.1 · claude · compact: fewer than 5 accounts, not shown'), findsOneWidget);
    expect(find.textContaining('1 ok, 1 concerns'), findsOneWidget);
    expect(find.textContaining('75% correct'), findsOneWidget);
    expect(find.textContaining('9/10 (90%) — Free tier'), findsOneWidget);
    expect(find.text('Nothing yet.'), findsOneWidget); // no chips yet
  });

  testWidgets('records a golden run and rejects impossible counts', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PromptPackSignalsScreen(rpc: fakeRpc)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signals-record-golden-run')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('golden-total')), '10');
    await tester.enterText(find.byKey(const Key('golden-passed')), '11');
    await tester.tap(find.byKey(const Key('golden-save')));
    await tester.pumpAndSettle();
    expect(find.text('Passed must be between 0 and the total.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('golden-passed')), '7');
    await tester.tap(find.byKey(const Key('golden-save')));
    await tester.pumpAndSettle();
    expect(calls['record_prompt_golden_run'],
        containsPair('p_cases_passed', 7));
    expect(calls['record_prompt_golden_run'], containsPair('p_ai_label', 'gemini'));
  });

  testWidgets('a failed load says admins only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PromptPackSignalsScreen(rpc: (fn, p) async => throw Exception('42501')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Admins only'), findsOneWidget);
  });

  testWidgets('review evidence dialog saves the chosen finding', (tester) async {
    List<Object?>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewEvidenceDialog(
          save: (a, o, k, n) async => saved = [a, o, k, n],
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('evidence-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concern').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('evidence-note')), 'Step 2 is wrong');
    await tester.tap(find.byKey(const Key('evidence-save')));
    await tester.pumpAndSettle();
    expect(saved, ['accuracy', 'concern', 'volunteer', 'Step 2 is wrong']);
  });
}
