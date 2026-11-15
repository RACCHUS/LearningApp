import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/community_answer_revision.dart';

/// "Earlier versions (n)" button for a Q&A answer that revises rejected
/// answers (`learning.answer_revisions`). Renders nothing when there is no
/// history, so answers without earlier versions look exactly as before.
class AnswerRevisionsButton extends StatelessWidget {
  const AnswerRevisionsButton({
    super.key,
    required this.answerId,
    required this.revisions,
  });

  final String answerId;
  final List<CommunityAnswerRevision> revisions;

  @override
  Widget build(BuildContext context) {
    if (revisions.isEmpty) return const SizedBox.shrink();
    final count = revisions.length;
    return TextButton.icon(
      key: Key('answer-revisions-$answerId'),
      icon: const Icon(Icons.history, size: 16),
      label: Text(
        'Earlier versions ($count)',
        style: const TextStyle(fontSize: 12),
      ),
      onPressed: () => showAnswerRevisionsDialog(context, revisions),
    );
  }
}

/// Lists earlier versions newest first, each with the review note it was
/// rejected with. Only the author and moderators ever receive this data.
Future<void> showAnswerRevisionsDialog(
  BuildContext context,
  List<CommunityAnswerRevision> revisions,
) {
  final ordered = [...revisions]
    ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber));
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('Earlier versions'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: ordered.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (_, i) {
              final r = ordered[i];
              final reason = r.editReason?.trim();
              return Column(
                key: Key('answer-revision-${r.revisionNumber}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Version ${r.revisionNumber} · ${_date(r.createdAt)}',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(r.bodyMarkdown, style: theme.textTheme.bodyMedium),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Review feedback: $reason',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

String _date(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
