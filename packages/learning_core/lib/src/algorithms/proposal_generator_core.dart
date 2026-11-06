import '../models/assessment_item.dart';
import '../models/content_proposal.dart';

/// Aggregates learning telemetry and automatically generates content improvement proposals (ECO-10).
class ProposalGeneratorCore {
  const ProposalGeneratorCore._();

  /// Scans learner answer selections for high-frequency misconceptions.
  ///
  /// When a distractor with an annotated misconception is selected by $\ge 25\%$ of
  /// incorrect attempts (with a minimum of [minSelectionsThreshold] selections),
  /// an autonomous remediation proposal is generated for educator review.
  static List<ContentProposalCore> detectMisconceptionProposals({
    required AssessmentItemCore item,
    required String resourceId,
    required Map<int, int> optionSelectionCounts,
    int minSelectionsThreshold = 3,
    double frequencyThreshold = 0.25,
  }) {
    final proposals = <ContentProposalCore>[];

    final totalSelections = optionSelectionCounts.values.fold<int>(0, (sum, count) => sum + count);
    if (totalSelections < minSelectionsThreshold) {
      return proposals;
    }

    for (int i = 0; i < item.options.length; i++) {
      final option = item.options[i];
      if (option.isCorrect) continue;

      final count = optionSelectionCounts[i] ?? 0;
      final frequency = count / totalSelections;

      if (count >= minSelectionsThreshold && frequency >= frequencyThreshold) {
        final misconceptionText = option.misconception ??
            'Learners frequently confuse "${option.text}" with the correct principle.';

        final proposalId = 'proposal-misconception-${item.id}-$i';
        final diffPatch = '''
--- a/lessons/${item.conceptSlug ?? "concept"}.md
+++ b/lessons/${item.conceptSlug ?? "concept"}.md
@@ -10,3 +10,6 @@
+> [!IMPORTANT] Common Misconception:
+> $misconceptionText
+> Ensure distinction is clearly emphasized before proceeding.
''';

        proposals.add(
          ContentProposalCore(
            id: proposalId,
            targetResourceId: resourceId,
            targetConceptSlug: item.conceptSlug ?? 'general-concept',
            proposalType: ContentProposalType.misconceptionRemediation,
            summary: 'High-frequency misconception detected ($count selections, ${(frequency * 100).toInt()}% of attempts): "$misconceptionText"',
            proposedDiff: diffPatch,
            evidenceData: {
              'item_id': item.id,
              'option_index': i,
              'selection_count': count,
              'total_attempts': totalSelections,
              'selection_frequency': double.parse(frequency.toStringAsFixed(4)),
              'misconception': misconceptionText,
            },
            status: ProposalReviewStatus.pendingReview,
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    }

    return proposals;
  }

  /// Generates a content gap proposal when a curriculum concept lacks sufficient items.
  static ContentProposalCore generateContentGapProposal({
    required String conceptSlug,
    required String targetResourceId,
    required int currentItemCount,
    required int recommendedItemCount,
  }) {
    final diff = '''
--- a/manifests/$conceptSlug.yaml
+++ b/manifests/$conceptSlug.yaml
@@ -15,0 +15,5 @@
+# PROPOSED: Add ${recommendedItemCount - currentItemCount} retrieval practice items for concept: $conceptSlug
''';

    return ContentProposalCore(
      id: 'proposal-gap-$conceptSlug',
      targetResourceId: targetResourceId,
      targetConceptSlug: conceptSlug,
      proposalType: ContentProposalType.contentGap,
      summary: 'Concept "$conceptSlug" has only $currentItemCount items (minimum recommended: $recommendedItemCount).',
      proposedDiff: diff,
      evidenceData: {
        'current_item_count': currentItemCount,
        'recommended_item_count': recommendedItemCount,
        'gap': recommendedItemCount - currentItemCount,
      },
      status: ProposalReviewStatus.pendingReview,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
