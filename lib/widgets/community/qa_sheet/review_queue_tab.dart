part of '../in_context_qa_sheet.dart';

// Moderator review queue (questions, answers, audit log).
// Moved unchanged from in_context_qa_sheet.dart (code-efficiency plan
// §14, Phase 2); setState calls go through the sheet's _update helper
// because extensions may not call the protected setState directly.
extension _QaReviewQueueTab on InContextQaSheetState {
  Widget _buildReviewQueueTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment<int>(
                value: 0,
                label: Text('Questions (${_reviewQuestions.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.help_outline, size: 14),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Answers (${_reviewAnswers.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.question_answer_outlined, size: 14),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text('Audit Log (${_auditLogs.length})', style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.history, size: 14),
              ),
            ],
            selected: {_reviewSubTab},
            onSelectionChanged: (set) {
              _update(() => _reviewSubTab = set.first);
            },
          ),
        ),
        Expanded(
          child: switch (_reviewSubTab) {
            0 => _buildReviewQuestionsList(theme),
            1 => _buildReviewAnswersList(theme),
            _ => QaAuditLogList(
                auditLogs: _auditLogs,
                questionTitles: _questionTitles,
                answerParentQuestionIds: _answerParentQuestionIds,
              ),
          },
        ),
      ],
    );
  }

  Widget _buildReviewQuestionsList(ThemeData theme) {
    if (_reviewQuestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'No Questions Awaiting Review',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All learner submitted questions have been reviewed.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviewQuestions.length,
      itemBuilder: (context, index) {
        final q = _reviewQuestions[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Under Review',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (q.conceptId != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            q.conceptId!,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Submitted: ${_formatDate(q.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 13, color: Colors.blueGrey[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Author: ${_formatAuthorId(q.authorId)}',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  q.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  q.bodyMarkdown,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      onPressed: () => _showRejectionDialog(
                        targetType: 'question',
                        targetId: q.id,
                        title: q.title,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Publish', style: TextStyle(fontSize: 12)),
                      onPressed: () => _handleReviewQuestion(q.id, 'publish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewAnswersList(ThemeData theme) {
    if (_reviewAnswers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 36, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'No Answers Awaiting Review',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'All submitted answers have been reviewed.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _reviewAnswers.length,
      itemBuilder: (context, index) {
        final a = _reviewAnswers[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Under Review',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (a.isAiGenerated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              a.aiModelName != null ? 'AI: ${a.aiModelName}' : 'AI Assisted',
                              style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Submitted: ${_formatDate(a.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 13, color: Colors.blueGrey[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Author: ${_formatAuthorId(a.authorId)}',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline, size: 14, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Question: "${_questionTitles[a.questionId] ?? a.questionId}"',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blueGrey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  a.bodyMarkdown,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_answerRevisions[a.id]?.isNotEmpty ?? false)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AnswerRevisionsButton(
                      answerId: a.id,
                      revisions: _answerRevisions[a.id]!,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 14, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                      onPressed: () => _showRejectionDialog(
                        targetType: 'answer',
                        targetId: a.id,
                        title: 'Answer',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Publish', style: TextStyle(fontSize: 12)),
                      onPressed: () => _handleReviewAnswer(a.id, 'publish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
