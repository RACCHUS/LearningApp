import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Card allowing educators and reviewers to inspect and resolve autonomous proposals (ECO-10).
class ContentProposalReviewCard extends StatelessWidget {
  final ContentProposalCore proposal;
  final void Function(ContentProposalCore proposal, String? notes)? onApprove;
  final void Function(ContentProposalCore proposal, String? notes)? onReject;

  const ContentProposalReviewCard({
    super.key,
    required this.proposal,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = proposal.status == ProposalReviewStatus.pendingReview;

    return Card(
      key: Key('proposal_card_${proposal.id}'),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                _buildTypeBadge(context),
                const SizedBox(width: 8),
                Text(
                  proposal.targetConceptSlug,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                _buildStatusChip(context),
              ],
            ),
            const SizedBox(height: 10),

            // Summary
            Text(
              proposal.summary,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            // Proposed Diff
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  proposal.proposedDiff,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.lightGreenAccent,
                  ),
                ),
              ),
            ),

            if (proposal.reviewerNotes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reviewer Note: ${proposal.reviewerNotes}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],

            if (isPending) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: Key('reject_proposal_button_${proposal.id}'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    onPressed: () => onReject?.call(proposal, 'Rejected by reviewer.'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: Key('approve_proposal_button_${proposal.id}'),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve Diff'),
                    onPressed: () => onApprove?.call(proposal, 'Approved diff into curriculum.'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (proposal.proposalType) {
      case ContentProposalType.misconceptionRemediation:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        label = 'MISCONCEPTION';
        break;
      case ContentProposalType.contentGap:
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        label = 'CONTENT GAP';
        break;
      case ContentProposalType.citationFreshness:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        label = 'CITATION';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (proposal.status) {
      case ProposalReviewStatus.pendingReview:
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'PENDING';
        break;
      case ProposalReviewStatus.approved:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'APPROVED';
        break;
      case ProposalReviewStatus.rejected:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'REJECTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
