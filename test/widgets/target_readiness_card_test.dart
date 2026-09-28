import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
