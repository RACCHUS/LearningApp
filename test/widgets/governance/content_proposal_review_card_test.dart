import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/widgets/governance/content_proposal_review_card.dart';

void main() {
  group('ContentProposalReviewCard Widget Tests (ECO-10)', () {
    final sampleProposal = ContentProposalCore(
      id: 'prop-101',
      targetResourceId: 'res-circuit-theory',
      targetConceptSlug: 'ohms-law-series',
      proposalType: ContentProposalType.misconceptionRemediation,
      summary: 'High-frequency misconception detected: "Believing voltage increases with resistance."',
      proposedDiff: '+> [!IMPORTANT] Voltage across resistor scales with current, not resistance alone.',
      status: ProposalReviewStatus.pendingReview,
      createdAt: DateTime.utc(2026, 11, 6, 10, 0),
    );

    testWidgets('renders proposal metadata, diff block, and pending review status',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentProposalReviewCard(
              proposal: sampleProposal,
            ),
          ),
        ),
      );

      expect(find.text('MISCONCEPTION'), findsOneWidget);
      expect(find.text('ohms-law-series'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
      expect(find.textContaining('High-frequency misconception detected'), findsOneWidget);
      expect(find.textContaining('+> [!IMPORTANT] Voltage across resistor scales'), findsOneWidget);

      expect(find.byKey(const Key('approve_proposal_button_prop-101')), findsOneWidget);
      expect(find.byKey(const Key('reject_proposal_button_prop-101')), findsOneWidget);
    });

    testWidgets('triggers onApprove callback when Approve Diff button is pressed',
        (tester) async {
      ContentProposalCore? approvedProposal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentProposalReviewCard(
              proposal: sampleProposal,
              onApprove: (prop, notes) {
                approvedProposal = prop;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('approve_proposal_button_prop-101')));
      await tester.pump();

      expect(approvedProposal?.id, equals('prop-101'));
    });

    testWidgets('triggers onReject callback when Reject button is pressed', (tester) async {
      ContentProposalCore? rejectedProposal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContentProposalReviewCard(
              proposal: sampleProposal,
              onReject: (prop, notes) {
                rejectedProposal = prop;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reject_proposal_button_prop-101')));
      await tester.pump();

      expect(rejectedProposal?.id, equals('prop-101'));
    });
  });
}
