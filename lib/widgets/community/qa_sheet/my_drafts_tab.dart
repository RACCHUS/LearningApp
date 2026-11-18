part of '../in_context_qa_sheet.dart';

// "My Drafts" tab: the learner's own questions and answers.
// Moved unchanged from in_context_qa_sheet.dart (code-efficiency plan
// §14, Phase 2); setState calls go through the sheet's _update helper
// because extensions may not call the protected setState directly.
extension _QaMyDraftsTab on InContextQaSheetState {
  Widget _buildMyDraftsTab(ThemeData theme) {
    final totalDrafts = _myDrafts.length + _myDraftAnswers.length;
    if (totalDrafts == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'You have not authored any private questions or answers yet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_myDrafts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(
              'My Questions (${_myDrafts.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          ..._myDrafts.map((d) {
            final isArchived = d.status == 'archived';
            final isUnderReview = d.status == 'under_review';
            final feedback = _submissionFeedback[d.id];

            final statusLabel = isArchived
                ? 'Rejected — Create a Revised Submission'
                : (isUnderReview ? 'Under Review' : 'Draft');
            final statusColor = isArchived
                ? Colors.red
                : (isUnderReview ? Colors.orange : Colors.grey);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: statusColor.withValues(alpha: isArchived ? 0.35 : 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: isArchived ? Colors.red[800] : (isUnderReview ? Colors.orange[800] : Colors.grey[700]),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.bodyMarkdown,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (feedback != null && feedback.feedback.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.rate_review_outlined, size: 14, color: Colors.amber[900]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Educator Review Feedback:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber[900]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    feedback.feedback,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isArchived) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Revise and Resubmit as New Question', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            _titleController.text = d.title;
                            _bodyController.text = d.bodyMarkdown;
                            _update(() {
                              _statusMessage = 'Revise your question based on educator feedback and save as a new draft.';
                            });
                            _tabController?.animateTo(1);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
        if (_myDraftAnswers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 12),
            child: Text(
              'My Answers (${_myDraftAnswers.length})',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          ..._myDraftAnswers.map((a) {
            final isArchived = a.status == 'archived';
            final isUnderReview = a.status == 'under_review';
            final feedback = _submissionFeedback[a.id];

            final statusLabel = isArchived
                ? 'Rejected — Create a Revised Submission'
                : (isUnderReview ? 'Under Review' : 'Draft');
            final statusColor = isArchived
                ? Colors.red
                : (isUnderReview ? Colors.orange : Colors.grey);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: statusColor.withValues(alpha: isArchived ? 0.35 : 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Answer to: "${_questionTitles[a.questionId] ?? a.questionId}"',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.blueGrey),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: isArchived ? Colors.red[800] : (isUnderReview ? Colors.orange[800] : Colors.grey[700]),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.bodyMarkdown,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (feedback != null && feedback.feedback.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.rate_review_outlined, size: 14, color: Colors.amber[900]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Educator Review Feedback:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber[900]),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    feedback.feedback,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_answerRevisions[a.id]?.isNotEmpty ?? false)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AnswerRevisionsButton(
                          answerId: a.id,
                          revisions: _answerRevisions[a.id]!,
                        ),
                      ),
                    if (isArchived) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('Revise and Resubmit Answer', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showAnswerRevisionDialog(a),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
