import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_practice_erasure_service.dart';

/// Destructive action is deliberately separate from account export.
/// Users can preview, export their data, then explicitly confirm deletion.
class ReferencePracticeErasureCard extends ConsumerWidget {
  final ExamReferencePracticeErasureService? service;

  const ReferencePracticeErasureCard({super.key, this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth is! AuthSuccess || auth.user.isAnonymous) {
      return const SizedBox.shrink();
    }
    return _OwnedErasure(
      key: ValueKey('exm-erasure:${auth.user.id}'),
      ownerId: auth.user.id,
      service: service,
    );
  }
}

class _OwnedErasure extends StatefulWidget {
  final String ownerId;
  final ExamReferencePracticeErasureService? service;

  const _OwnedErasure({
    super.key, required this.ownerId, this.service,
  });

  @override
  State<_OwnedErasure> createState() => _OwnedErasureState();
}

class _OwnedErasureState extends State<_OwnedErasure> {
  late final ExamReferencePracticeErasureService _defaultService =
      ExamReferencePracticeErasureService();
  ExamReferencePracticeErasureService get _api =>
      widget.service ?? _defaultService;
  final TextEditingController _confirmation = TextEditingController();
  ReferencePracticeErasurePreview? _preview;
  ReferencePracticeErasureReceipt? _receipt;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _refreshPreview() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _preview = null;
      _receipt = null;
      _confirmation.clear();
    });
    try {
      final preview = await _api.preview(expectedOwnerId: widget.ownerId);
      if (!mounted) return;
      if (preview.ownerId != widget.ownerId) {
        throw StateError('Wrong reference-practice owner');
      }
      setState(() => _preview = preview);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not preview all saved practice. No records were deleted.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _erase() async {
    final preview = _preview;
    if (_busy || preview == null || preview.events == 0 ||
        _confirmation.text !=
            ExamReferencePracticeErasureService.confirmationPhrase) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Permanently delete saved reference practice?'),
        content: Text(
          'Delete ${preview.events} EXM R1–R4 step records across '
          '${preview.editions} reference edition(s), including '
          '${preview.grades} server grades? This cannot be undone. '
          'Previously copied exports or clipboard data will not be erased. '
          'This action does not delete your whole LearningApp account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Permanently delete EXM practice'),
          ),
        ],
      ),
    );
    // Owner-keyed widget disposal cancels a cross-account confirmation.
    if (!mounted || accepted != true || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await _api.deletePreviewed(
        expectedOwnerId: widget.ownerId,
        preview: preview,
        exactConfirmation: _confirmation.text,
      );
      if (!mounted) return;
      setState(() {
        _preview = null;
        _confirmation.clear();
        _receipt = receipt;
      });
    } catch (_) {
      if (!mounted) return;
      // The network response could have been lost after a successful commit:
      // do NOT claim deletion or retry blindly. Require a new server preview.
      setState(() {
        _preview = null;
        _confirmation.clear();
        _error = 'Deletion was not confirmed. Refresh the preview to '
            'check remaining records before trying again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Card(
      key: const Key('exm-erasure-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete saved reference-practice history',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'You control removal of your saved EXM R1–R4 activity and '
              'its derived grades, including retired editions. '
              'Export your practice data first if you want a copy. '
              'No automatic retention schedule is enabled here.',
            ),
            TextButton.icon(
              key: const Key('exm-erasure-preview'),
              onPressed: _busy ? null : _refreshPreview,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Preview my saved EXM practice'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('exm-erasure-error')),
            if (_receipt != null) ...[
              Text(
                '${_receipt!.deleted} step(s) deleted.',
                key: const Key('exm-erasure-result'),
              ),
              if (_receipt!.remaining > 0)
                Text(
                  '${_receipt!.remaining} new or concurrent step(s) remain. '
                  'Refresh the preview to inspect them.',
                ),
              const Text(
                'Server grades linked to deleted steps are removed by '
                'database cascade. Saved copies and clipboard data remain '
                'under your control.',
              ),
            ],
            if (preview != null) ...[
              Text(
                '${preview.events} step(s) across ${preview.editions} '
                'edition(s), including ${preview.grades} grade(s).',
                key: const Key('exm-erasure-count'),
              ),
              if (preview.events == 0)
                const Text('No saved EXM reference-practice steps to delete.'),
              if (preview.events > 0) ...[
                const Text('To enable deletion, type exactly: '
                    'DELETE REFERENCE PRACTICE'),
                TextField(
                  key: const Key('exm-erasure-phrase'),
                  controller: _confirmation,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Exact deletion confirmation',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('exm-erasure-delete'),
                  onPressed: !_busy &&
                      _confirmation.text ==
                          ExamReferencePracticeErasureService.confirmationPhrase
                      ? _erase : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Review permanent deletion'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
