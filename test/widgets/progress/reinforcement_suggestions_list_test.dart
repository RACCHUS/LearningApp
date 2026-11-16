import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/reinforcement_suggestions_provider.dart';
import 'package:learning_pwa/services/progress/reinforcement_suggestion_service.dart';
import 'package:learning_pwa/widgets/progress/reinforcement_suggestions_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI spec §5.5 "needs reinforcement" list behind
/// learning.reinforcement_suggestions; §6.1 copy; §8 silent hiding.
void main() {
  final suggestions = [
    ReinforcementSuggestion(
      conceptId: 'c1',
      name: 'Beta blockers',
      confidence: ConceptConfidence.low,
      dueContentIds: const ['fc-1', 'fc-2'],
      lastEvidenceAt: DateTime.utc(2026, 9, 1),
    ),
    const ReinforcementSuggestion(
      conceptId: 'c2',
      name: 'ACE inhibitors',
      confidence: ConceptConfidence.medium,
      dueContentIds: ['q-1'],
    ),
    const ReinforcementSuggestion(
      conceptId: 'c3',
      name: 'Diuretics',
      confidence: ConceptConfidence.low,
      dueContentIds: [],
    ),
  ];

  Future<List<String>> pump(
    WidgetTester tester, {
    required bool enabled,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final opened = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: SingleChildScrollView(child: ReinforcementSuggestionsList()),
        ),
      ),
      GoRoute(
        path: '/review',
        builder: (_, state) {
          opened.add(state.uri.toString());
          return const Scaffold(body: Text('Review screen'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        reinforcementSuggestionsFeatureEnabledProvider.overrideWithValue(enabled),
        reinforcementSuggestionsProvider.overrideWith((ref) async => suggestions),
        learnerIdProvider.overrideWithValue('u1'),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('gate OFF: nothing renders', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byKey(const Key('reinforcement-suggestions')), findsNothing);
    expect(find.text('Beta blockers'), findsNothing);
  });

  testWidgets('gate ON: names, band and confidence; never a percentage',
      (tester) async {
    await pump(tester, enabled: true);
    expect(find.text('Needs reinforcement'), findsOneWidget);
    expect(find.text('Beta blockers'), findsOneWidget);
    expect(find.text('Needs reinforcement · low confidence · 2 items due'), findsOneWidget);
    expect(find.text('Needs reinforcement · medium confidence · 1 item due'), findsOneWidget);
    expect(find.text('Needs reinforcement · low confidence · nothing due yet'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('!'), findsNothing);
    expect(find.textContaining(RegExp('master', caseSensitive: false)), findsNothing);
  });

  testWidgets('Review opens a targeted review of that concept\'s due items',
      (tester) async {
    final opened = await pump(tester, enabled: true);
    expect(find.byKey(const Key('reinforce-review-c3')), findsNothing,
        reason: 'no Review button when nothing is due');
    await tester.tap(find.byKey(const Key('reinforce-review-c1')));
    await tester.pumpAndSettle();
    expect(opened.single, '/review?concepts=fc-1,fc-2');
  });

  testWidgets('Review all covers every concept with due items', (tester) async {
    final opened = await pump(tester, enabled: true);
    await tester.tap(find.byKey(const Key('reinforce-review-all')));
    await tester.pumpAndSettle();
    expect(opened.single, '/review?concepts=fc-1,fc-2,q-1');
  });

  testWidgets('hiding is silent and remembered on this device', (tester) async {
    await pump(tester, enabled: true);
    await tester.tap(find.byKey(const Key('reinforce-hide-c2')));
    await tester.pumpAndSettle();
    expect(find.text('ACE inhibitors'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('progress.reinforcement_hidden.u1'), ['c2|']);
  });

  testWidgets('a hidden concept stays hidden until new evidence arrives',
      (tester) async {
    await pump(tester, enabled: true, prefs: {
      'progress.reinforcement_hidden.u1': [
        'c1|${DateTime.utc(2026, 9, 1).toIso8601String()}',
        'c3|2026-01-01T00:00:00.000Z',
      ],
    });
    expect(find.text('Beta blockers'), findsNothing, reason: 'same evidence: still hidden');
    expect(find.text('Diuretics'), findsOneWidget, reason: 'hidden for older evidence');
  });

  testWidgets('everything hidden: the section disappears', (tester) async {
    await pump(tester, enabled: true, prefs: {
      'progress.reinforcement_hidden.u1': [
        'c1|${DateTime.utc(2026, 9, 1).toIso8601String()}',
        'c2|',
        'c3|',
      ],
    });
    expect(find.byKey(const Key('reinforcement-suggestions')), findsNothing);
  });
}
