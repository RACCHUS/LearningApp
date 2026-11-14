import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_review_audit.dart';

/// Short learner label used across Community Q&A moderation views.
String formatQaAuthorId(String id) {
  if (id == 'offline-demo') return 'Offline Demo';
  return 'Learner (${id.length > 8 ? id.substring(0, 8) : id})';
}

/// Short moderator label; a null reviewer is a system action.
String formatQaReviewerId(String? id) {
  if (id == null) return 'System';
  return 'Moderator (${id.length > 8 ? id.substring(0, 8) : id})';
}

/// Read-only audit trail of Community Q&A moderation decisions.
///
/// Shows moderators' internal notes, so it must only be built inside the
/// moderator review queue; [InContextQaSheet] decides who sees that tab.
class QaAuditLogList extends StatelessWidget {
  final List<CommunityReviewAudit> auditLogs;

  /// Question id -> title, used to label audit targets.
  final Map<String, String> questionTitles;

  /// Answer id -> parent question id, so answer audits show their question.
  final Map<String, String> answerParentQuestionIds;

  const QaAuditLogList({
    super.key,
    required this.auditLogs,
    required this.questionTitles,
    required this.answerParentQuestionIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (auditLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_toggle_off, size: 36, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'No Audit Records Yet',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Moderation decisions and review actions will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: auditLogs.length,
      itemBuilder: (context, index) {
        final audit = auditLogs[index];
        final actionColor = switch (audit.action) {
          'publish' => Colors.green,
          'reject' => Colors.red,
          'flag' => Colors.orange,
          _ => Colors.blueGrey,
        };

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            audit.action.toUpperCase(),
                            style: TextStyle(
                              color: actionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          audit.targetType == 'question' ? 'Question Review' : 'Answer Review',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      '${audit.createdAt.month}/${audit.createdAt.day}/${audit.createdAt.year} ${audit.createdAt.hour}:${audit.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    String targetTitle;
                    if (audit.isQuestion) {
                      final qTitle = questionTitles[audit.targetId];
                      targetTitle = qTitle ?? 'Question #${formatQaAuthorId(audit.targetId)}';
                    } else {
                      final parentQuestionId = answerParentQuestionIds[audit.targetId];
                      final parentTitle = parentQuestionId != null ? questionTitles[parentQuestionId] : null;
                      targetTitle = parentTitle != null
                          ? 'Answer to: "$parentTitle"'
                          : 'Answer #${formatQaAuthorId(audit.targetId)}';
                    }
                    return Text(
                      'Target: $targetTitle',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Reviewer: ${formatQaReviewerId(audit.reviewerId)}',
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                    Text(
                      'Status change: ${audit.previousStatus} -> ${audit.newStatus}',
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
                if (audit.notes != null && audit.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.comment_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Author Feedback: ${audit.notes!}',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (audit.internalNotes != null && audit.internalNotes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 12, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Internal Notes: ${audit.internalNotes!}',
                            style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
