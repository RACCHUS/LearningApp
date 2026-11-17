import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/author_review_feedback.dart';
import 'package:learning_pwa/models/community/community_answer.dart';
import 'package:learning_pwa/models/community/community_question.dart';

// Moderator rejection, learner "revise and resubmit" and "teach this topic"
// dialogs for the in-context Q&A sheet. Moved unchanged from in_context_qa_sheet.dart
// (code-efficiency plan §14, Pilot A). The sheet owns when they open and
// what happens with the result; these widgets own only the form.

class QaRejectionDialog extends StatefulWidget {
  final String targetType;
  final String title;

  const QaRejectionDialog({
    super.key,
    required this.targetType,
    required this.title,
  });

  @override
  State<QaRejectionDialog> createState() => _QaRejectionDialogState();
}

class _QaRejectionDialogState extends State<QaRejectionDialog> {
  late final TextEditingController _notesController;
  late final TextEditingController _internalNotesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _internalNotesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject ${widget.targetType}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provide feedback for rejecting "${widget.title}". Learner-facing feedback will be delivered directly to the author in their private drafts.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Author Feedback (Shared with Author)',
                hintText: 'e.g., Needs revision: clarify distinction between blends and digraphs.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _internalNotesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Internal Moderation Notes (Confidential)',
                hintText: 'e.g., Escalated to curriculum lead; check state benchmark alignment.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
          onPressed: () {
            final notes = _notesController.text.trim();
            final internalNotes = _internalNotesController.text.trim();
            Navigator.of(context).pop(
              (notes.isEmpty ? null : notes, internalNotes.isEmpty ? null : internalNotes),
            );
          },
          child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class QaAnswerRevisionDialog extends StatefulWidget {
  final CommunityAnswer rejectedAnswer;
  final String parentTitle;
  final AuthorReviewFeedback? feedback;
  final String? dialogAuthorId;
  final int sessionGen;
  final bool Function(int sessionGen, String? sessionUserId) isSessionValid;
  final Future<CommunityAnswer?> Function(String bodyMarkdown) onSubmitAnswer;
  final void Function(CommunityAnswer newAnswer) onSuccess;

  const QaAnswerRevisionDialog({
    super.key,
    required this.rejectedAnswer,
    required this.parentTitle,
    required this.feedback,
    required this.dialogAuthorId,
    required this.sessionGen,
    required this.isSessionValid,
    required this.onSubmitAnswer,
    required this.onSuccess,
  });

  @override
  State<QaAnswerRevisionDialog> createState() => _QaAnswerRevisionDialogState();
}

class _QaAnswerRevisionDialogState extends State<QaAnswerRevisionDialog> {
  late final TextEditingController _answerController;
  final _formKey = GlobalKey<FormState>();
  bool _isDialogSubmitting = false;

  @override
  void initState() {
    super.initState();
    _answerController = TextEditingController(text: widget.rejectedAnswer.bodyMarkdown);
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final text = _answerController.text.trim();
    if (text.length < 20 || text.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer must be between 20 and 1,000 characters.')),
      );
      return;
    }

    if (!widget.isSessionValid(widget.sessionGen, widget.dialogAuthorId)) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submission cancelled: account changed during revision.'),
        ),
      );
      return;
    }

    setState(() => _isDialogSubmitting = true);

    try {
      final newAnswer = await widget.onSubmitAnswer(_answerController.text.trim());

      if (!widget.isSessionValid(widget.sessionGen, widget.dialogAuthorId)) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (newAnswer != null) {
        widget.onSuccess(newAnswer);
      }
    } catch (e) {
      if (!widget.isSessionValid(widget.sessionGen, widget.dialogAuthorId)) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      if (mounted) {
        setState(() => _isDialogSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Failed to submit revised answer: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Colors.blueAccent),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Revise and Resubmit Answer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Parent Question:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.parentTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (widget.feedback != null && widget.feedback!.feedback.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.feedback_outlined, size: 16, color: Colors.amber[900]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Educator Feedback:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.feedback!.feedback,
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _answerController,
                  maxLines: 6,
                  minLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Your Revised Answer (Markdown supported)',
                    hintText: 'Address feedback and provide a clear, accurate explanation...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 10) {
                      return 'Answer must be at least 10 characters long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Submitting creates a new private draft answer queued for educator review. Your previous submission remains archived.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDialogSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          icon: _isDialogSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send, size: 14),
          label: const Text('Submit Revised Answer'),
          onPressed: _isDialogSubmitting ? null : _submit,
        ),
      ],
    );
  }
}


/// "Teach this topic" answer form. The sheet checks adult confirmation and
/// sign-in before opening it, and refreshes answers when it returns `true`.
class QaTeachTopicDialog extends StatefulWidget {
  const QaTeachTopicDialog({
    super.key,
    required this.question,
    required this.onSubmit,
  });

  final CommunityQuestion question;

  /// Saves the answer. Throwing keeps the dialog open with the error shown.
  final Future<Object?> Function(String bodyMarkdown) onSubmit;

  @override
  State<QaTeachTopicDialog> createState() => _QaTeachTopicDialogState();
}

class _QaTeachTopicDialogState extends State<QaTeachTopicDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school, color: Colors.teal),
            SizedBox(width: 8),
            Expanded(
              child: Text('Teach This Topic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal[800])),
                      const SizedBox(height: 2),
                      Text(widget.question.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (widget.question.bodyMarkdown.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(widget.question.bodyMarkdown, style: const TextStyle(fontSize: 12, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                TextField(
                  key: const Key('teach_topic_answer_field'),
                  controller: _controller,
                  maxLines: 5,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Your Explanation / Answer (Markdown supported) *',
                    hintText: 'Explain the core concept clearly with examples or practical steps...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Answers from verified contributors display credential badges and earn evidence-weighted reputation.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('submit_teach_answer_button'),
            icon: _submitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 14),
            label: const Text('Contribute Answer'),
            onPressed: _submitting
                ? null
                : () async {
                    final text = _controller.text.trim();
                    if (text.length < 10) {
                      setState(() => _error = 'Answer must be at least 10 characters long.');
                      return;
                    }
                    setState(() {
                      _submitting = true;
                      _error = null;
                    });
                    try {
                      await widget.onSubmit(text);
                      if (mounted) {
                        Navigator.of(this.context).pop(true);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _error = 'Failed to submit answer: $e';
                          _submitting = false;
                        });
                      }
                    }
                  },
          ),
        ],
      );
  }
}
