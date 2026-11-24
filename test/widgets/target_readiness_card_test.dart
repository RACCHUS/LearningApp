import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/readiness_coverage.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/target_readiness_provider.dart';
import 'package:learning_pwa/widgets/targets/target_readiness_card.dart';

void main() {
  testWidgets('TargetReadinessCard renders qualitative readiness and Invariant 5 disclaimer', (tester) async {
    const mockReadiness = TargetReadiness(
      targetVersionId: 'v1',
      band: TargetReadinessBand.strongCoverage,
      score: 0.9,
      totalCoreConcepts: 10,
      assessedConceptsCount: 8,
      bandDistribution: {
        RetrievalBand.wellEstablished: 4,
        RetrievalBand.wellRetained: 4,
        RetrievalBand.developing: 0,
        RetrievalBand.needsReinforcement: 0,
        RetrievalBand.unassessed: 2,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          targetReadinessProvider('v1').overrideWith((ref) => Future.value(mockReadiness)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TargetReadinessCard(targetVersionId: 'v1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Knowledge Readiness'), findsOneWidget);
    expect(find.text('Strong Coverage'), findsOneWidget);
    expect(find.text('8 of 10 core concepts assessed'), findsOneWidget);
    expect(find.textContaining('independent of structural course completion'), findsOneWidget);
    expect(find.text('4 Well Established'), findsOneWidget);
    expect(find.text('4 Well Retained'), findsOneWidget);
    expect(find.text('2 Not Assessed'), findsOneWidget);
  });

  group('Readiness coverage gate (ingestion plan D-14)', () {
    const readiness = TargetReadiness(
      targetVersionId: 'v1',
      band: TargetReadinessBand.strongCoverage,
      score: 0.9,
      totalCoreConcepts: 2,
      assessedConceptsCount: 2,
      bandDistribution: {
        RetrievalBand.wellEstablished: 2,
        RetrievalBand.wellRetained: 0,
        RetrievalBand.developing: 0,
        RetrievalBand.needsReinforcement: 0,
        RetrievalBand.unassessed: 0,
      },
    );

    Future<_FakeCoverageApi> pump(
      WidgetTester tester, {
      required bool gate,
      Map<String, dynamic>? response,
      bool fail = false,
    }) async {
      final api = _FakeCoverageApi(response, fail: fail);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetReadinessProvider('v1').overrideWith((ref) => Future.value(readiness)),
            readinessCoverageGateEnabledProvider.overrideWithValue(gate),
            readinessCoverageApiProvider.overrideWithValue(api),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TargetReadinessCard(targetVersionId: 'v1')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    Map<String, dynamic> coverage(String state, double covered) => {
          'enabled': true,
          'state': state,
          'covered_weight': covered,
          'objectives_total': 4,
          'objectives_covered': 1,
          'min_held_out_items': 6,
          'provisional_threshold': 0.6,
          'full_threshold': 0.9,
          'weights_editorial': false,
        };

    testWidgets('gate off: readiness unchanged and nothing fetched', (tester) async {
      final api = await pump(tester, gate: false, response: coverage('hidden', 0));
      expect(api.calls, 0);
      expect(find.text('Strong Coverage'), findsOneWidget);
      expect(find.byKey(const Key('readiness_coverage_message')), findsNothing);
    });

    testWidgets('below 60%: band hidden, study progress shown with the reason', (tester) async {
      await pump(tester, gate: true, response: coverage('hidden', 0.25));
      expect(find.text('Strong Coverage'), findsNothing);
      expect(find.text('Study progress'), findsOneWidget);
      expect(find.byKey(const Key('readiness_not_enough_checks_badge')), findsOneWidget);
      expect(find.textContaining('cover 25% of this target'), findsOneWidget);
      expect(find.text('2 Well Established'), findsOneWidget);
    });

    testWidgets('60% to 90%: band labelled provisional', (tester) async {
      await pump(tester, gate: true, response: coverage('provisional', 0.7));
      expect(find.text('Strong Coverage (provisional)'), findsOneWidget);
      expect(find.textContaining('Provisional: independent checks cover 70%'), findsOneWidget);
    });

    testWidgets('90% or more: shown as before', (tester) async {
      await pump(tester, gate: true, response: coverage('full', 0.95));
      expect(find.text('Strong Coverage'), findsOneWidget);
      expect(find.byKey(const Key('readiness_coverage_message')), findsNothing);
    });

    testWidgets('read failure fails closed: band hidden', (tester) async {
      await pump(tester, gate: true, fail: true);
      expect(find.text('Strong Coverage'), findsNothing);
      expect(find.textContaining("couldn't confirm"), findsOneWidget);
    });

    testWidgets('server reports the gate off: readiness unchanged', (tester) async {
      await pump(tester, gate: true, response: {'enabled': false});
      expect(find.text('Strong Coverage'), findsOneWidget);
      expect(find.byKey(const Key('readiness_coverage_message')), findsNothing);
    });

    test('unknown state or missing ratio fails closed', () {
      expect(ReadinessCoverage.fromJson({'enabled': true, 'state': 'weird', 'covered_weight': 0.99})!.state,
          ReadinessCoverageState.hidden);
      expect(ReadinessCoverage.fromJson({'enabled': true, 'state': 'full'})!.state,
          ReadinessCoverageState.hidden);
    });
  });
}

class _FakeCoverageApi implements ReadinessCoverageApi {
  final Map<String, dynamic>? response;
  final bool fail;
  int calls = 0;

  _FakeCoverageApi(this.response, {this.fail = false});

  @override
  Future<Map<String, dynamic>?> fetch(String targetVersionId) async {
    calls++;
    if (fail) throw Exception('network');
    return response;
  }
}
