import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/objective_readiness.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/widgets/targets/objective_readiness_card.dart';

// Readiness by objective (ingestion plan v1.2 §8.7).
class _FakeApi implements ObjectiveReadinessApi {
  final Map<String, dynamic>? json;
  final bool fail;
  int calls = 0;
  _FakeApi(this.json, {this.fail = false});

  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async {
    calls++;
    if (fail) throw Exception('offline');
    return json;
  }
}

Map<String, dynamic> _view({bool signedIn = true, bool editorial = false}) => {
      'enabled': true,
      'signed_in': signedIn,
      'weights_editorial': editorial,
      'min_held_out_items': 6,
      'domains': [
        {
          'code': 'D1',
          'title': 'Equations',
          'weight_share': 0.75,
          'status': 'building',
          'objectives': [
            {'code': '1.1', 'title': 'Linear equations', 'status': 'strong', 'checked': true},
            {'code': '1.2', 'title': 'Inequalities', 'status': 'building', 'checked': false},
            {'code': '1.3', 'title': 'Systems', 'status': 'not_available', 'checked': false},
          ],
        },
        {'code': 'D2', 'title': 'Functions', 'weight_share': 0.25, 'status': 'not_available', 'objectives': []},
      ],
    };

void main() {
  group('model', () {
    test('parses statuses and fails closed on unknown ones', () {
      expect(ObjectiveReadinessStatus.parse('strong'), ObjectiveReadinessStatus.strong);
      expect(ObjectiveReadinessStatus.parse('not_started'), ObjectiveReadinessStatus.notStarted);
      expect(ObjectiveReadinessStatus.parse('mastered'), ObjectiveReadinessStatus.notAvailable);
      expect(ObjectiveReadinessStatus.parse(null), ObjectiveReadinessStatus.notAvailable);
    });

    test('switch off is null; a view parses domains, weights and checks', () {
      expect(TargetObjectiveReadiness.fromJson({'enabled': false}), isNull);
      final v = TargetObjectiveReadiness.fromJson(_view())!;
      expect(v.domains.map((d) => d.weightPercent), [75, 25]);
      expect(v.domains.first.objectives.first.checked, isTrue);
      expect(v.hasUncheckedObjectives, isTrue);
    });

    test('an out-of-range weight is clamped', () {
      final d = DomainReadiness.fromJson({'weight_share': 1.7, 'status': 'building'});
      expect(d.weightShare, 1.0);
    });
  });

  Future<void> pump(WidgetTester tester, {required bool on, required _FakeApi api}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        objectiveReadinessViewEnabledProvider.overrideWithValue(on),
        objectiveReadinessApiProvider.overrideWithValue(api),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ObjectiveReadinessCard(targetVersionId: 'v1'))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('switched off: nothing is fetched or shown', (tester) async {
    final api = _FakeApi(_view());
    await pump(tester, on: false, api: api);
    expect(api.calls, 0);
    expect(find.byKey(const Key('objective_readiness_card')), findsNothing);
  });

  testWidgets('shows domains with weights and each objective status', (tester) async {
    await pump(tester, on: true, api: _FakeApi(_view()));
    expect(find.text('Readiness by objective'), findsOneWidget);
    expect(find.text('Equations · 75%'), findsOneWidget);
    expect(find.text('Functions · 25%'), findsOneWidget);
    expect(find.text('1.1 Linear equations'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('objective_status_1.1')), matching: find.text('Strong')),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('objective_status_1.2')), matching: find.text('Building')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('objective_status_1.3')), matching: find.text('Not yet available')),
        findsOneWidget);
    expect(find.byKey(const Key('objective_readiness_unchecked_note')), findsOneWidget);
    expect(find.byKey(const Key('objective_readiness_missing_note')), findsOneWidget);
    expect(find.byKey(const Key('objective_readiness_guest_note')), findsNothing);
  });

  testWidgets('guests see a sign-in note; editorial weights hide percentages', (tester) async {
    await pump(tester, on: true, api: _FakeApi(_view(signedIn: false, editorial: true)));
    expect(find.byKey(const Key('objective_readiness_guest_note')), findsOneWidget);
    expect(find.text('Equations'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Each area counts equally here (no official weights).'), findsOneWidget);
  });

  testWidgets('a failed read shows nothing rather than a guess', (tester) async {
    await pump(tester, on: true, api: _FakeApi(null, fail: true));
    expect(find.byKey(const Key('objective_readiness_card')), findsNothing);
  });
}
