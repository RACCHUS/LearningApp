import 'package:flutter/material.dart';
import 'package:learning_pwa/services/learning_support/check_dispute_service.dart';

/// What the learner chose to send about a disputed check.
class CheckDisputeChoice {
  const CheckDisputeChoice(this.reason, this.note);

  final CheckDisputeReason reason;
  final String? note;
}

/// Asks what seems wrong, so a moderator can review it. Cancelling sends
/// nothing; the question is already left out of suggestions either way.
Future<CheckDisputeChoice?> showCheckDisputeDialog(BuildContext context) {
  return showDialog<CheckDisputeChoice>(
    context: context,
    builder: (_) => const _CheckDisputeDialog(),
  );
}

class _CheckDisputeDialog extends StatefulWidget {
  const _CheckDisputeDialog();

  @override
  State<_CheckDisputeDialog> createState() => _CheckDisputeDialogState();
}

class _CheckDisputeDialogState extends State<_CheckDisputeDialog> {
  CheckDisputeReason? _reason;
  final _note = TextEditingController();

  static const maxNote = 500;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send this question for review?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A moderator will check it. Your answer is not sent.'),
            const SizedBox(height: 8),
            RadioGroup<CheckDisputeReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in CheckDisputeReason.values)
                    RadioListTile<CheckDisputeReason>(
                      key: Key('check-dispute-reason-${r.wire}'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: r,
                      title: Text(r.label),
                    ),
                ],
              ),
            ),
            TextField(
              key: const Key('check-dispute-note'),
              controller: _note,
              maxLength: maxNote,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What seems wrong? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const Key('check-dispute-send'),
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop(
                  CheckDisputeChoice(
                    _reason!,
                    _note.text.trim().isEmpty ? null : _note.text.trim(),
                  ),
                ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
