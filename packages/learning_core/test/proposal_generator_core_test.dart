import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProposalGeneratorCore & ContentProposalCore (ECO-10)', () {
    const itemWithMisconception = AssessmentItemCore(
      id: 'item-circuit-1',
      conceptSlug: 'ohms-law-series',
      stem: 'In a series circuit, what happens to current as total resistance increases?',
      options: [
        AssessmentOptionCore(
          text: 'Current decreases proportionally throughout the circuit',
          isCorrect: true,
        ),
        AssessmentOptionCore(
          text: 'Current increases because electrons push harder',
          isCorrect: false,
          misconception: 'Believing voltage/push increases with resistance instead of current dropping.',
        ),
        AssessmentOptionCore(
          text: 'Current stays constant at all resistances',
          isCorrect: false,
        ),
      ],
    );

    test('detects high-frequency misconception and generates reviewable proposal with diff', () {
      // 10 attempts: 4 correct (idx 0), 5 misconception (idx 1), 1 distractor (idx 2)
      // Misconception frequency: 5/10 = 50% >= 25% threshold
      final proposals = ProposalGeneratorCore.detectMisconceptionProposals(
        item: itemWithMisconception,
        resourceId: 'res-electronics-101',
        optionSelectionCounts: {0: 4, 1: 5, 2: 1},
        minSelectionsThreshold: 3,
        frequencyThreshold: 0.25,
      );

      expect(proposals.length, equals(1));
      final proposal = proposals.first;
      expect(proposal.proposalType, equals(ContentProposalType.misconceptionRemediation));
      expect(proposal.targetConceptSlug, equals('ohms-law-series'));
      expect(proposal.targetResourceId, equals('res-electronics-101'));
      expect(proposal.summary, contains('5 selections, 50% of attempts'));
      expect(proposal.proposedDiff, contains('> [!IMPORTANT] Common Misconception:'));
      expect(proposal.status, equals(ProposalReviewStatus.pendingReview));
    });

    test('suppresses proposals when attempts are below minimum threshold', () {
      // Only 2 total attempts
      final proposals = ProposalGeneratorCore.detectMisconceptionProposals(
        item: itemWithMisconception,
        resourceId: 'res-electronics-101',
        optionSelectionCounts: {1: 2},
        minSelectionsThreshold: 3,
      );

      expect(proposals, isEmpty);
    });

    test('generates content gap proposal with structured diff and metadata', () {
      final proposal = ProposalGeneratorCore.generateContentGapProposal(
        conceptSlug: 'transformer-attention',
        targetResourceId: 'res-deep-learning',
        currentItemCount: 1,
        recommendedItemCount: 5,
      );

      expect(proposal.proposalType, equals(ContentProposalType.contentGap));
      expect(proposal.targetConceptSlug, equals('transformer-attention'));
      expect(proposal.summary, contains('only 1 items (minimum recommended: 5)'));
      expect(proposal.proposedDiff, contains('PROPOSED: Add 4 retrieval practice items'));
      expect(proposal.evidenceData['gap'], equals(4));
    });
  });
}
