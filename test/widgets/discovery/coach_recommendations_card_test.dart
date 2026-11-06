import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/widgets/discovery/coach_recommendations_card.dart';

void main() {
  group('CoachRecommendationsCard Widget Tests (ECO-11)', () {
    const sampleRec = CoachRecommendation(
      id: 'rec-1',
      targetConceptSlug: 'pharmacology-beta-blockers',
      urgency: RecommendationUrgency.immediateReview,
      headline: 'Memory Refresh: pharmacology-beta-blockers',
      rationale: 'Retrievability has decayed to 72% based on FSRS spacing. A 2-minute review will restore retention to 90%+.',
      recommendedAction: 'review_flashcards',
    );

    testWidgets('renders coach recommendation with evidence rationale and Coach Principle subtitle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoachRecommendationsCard(
              recommendations: [sampleRec],
            ),
          ),
        ),
      );

      // Verify header and Coach Principle
      expect(find.text('Coach Recommendations'), findsOneWidget);
      expect(
        find.text('Evidence-based suggestions (Coach Principle: always optional)'),
        findsOneWidget,
      );

      // Verify recommendation details
      expect(find.text('Review Due (FSRS)'), findsOneWidget);
      expect(find.text('Memory Refresh: pharmacology-beta-blockers'), findsOneWidget);
      expect(
        find.textContaining('Retrievability has decayed to 72% based on FSRS spacing'),
        findsOneWidget,
      );
      expect(find.text('Review Memory Flashcards'), findsOneWidget);
    });

    testWidgets('triggers onAction callback when action button is tapped', (tester) async {
      CoachRecommendation? tappedRec;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachRecommendationsCard(
              recommendations: const [sampleRec],
              onAction: (rec) {
                tappedRec = rec;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('rec_action_button_rec-1')));
      await tester.pump();

      expect(tappedRec?.id, equals('rec-1'));
    });

    testWidgets('dismisses recommendation cleanly when close icon is tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CoachRecommendationsCard(
              recommendations: [sampleRec],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('rec_tile_rec-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rec_dismiss_button_rec-1')));
      await tester.pump();

      expect(find.byKey(const Key('rec_tile_rec-1')), findsNothing);
    });
  });
}
