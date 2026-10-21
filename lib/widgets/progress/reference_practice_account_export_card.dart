import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_drill_account_export_service.dart';

/// EXM reference-practice subsystem portability, NOT a full account archive.
/// Kept separate from ordinary knowledge/mastery dashboards.
class ReferencePracticeAccountExportCard extends ConsumerWidget {
  final ExamReferenceDrillAccountExportService? exportService;

  const ReferencePracticeAccountExportCard({
    super.key,
    this.exportService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth is! AuthSuccess || auth.user.isAnonymous) {
      return const SizedBox.shrink();
    }
    return _OwnerExport(
      key: ValueKey('exm-account-export:${auth.user.id}'),
      ownerId: auth.user.id,
      service: exportService,
    );
  }
}

class _OwnerExport extends StatefulWidget {
  final String ownerId;
  final ExamReferenceDrillAccountExportService? service;

  const _OwnerExport({
    super.key,
    required this.ownerId,
    this.service,
  });

  @override
  State<_OwnerExport> createState() => _OwnerExportState();
}

class _OwnerExportState extends State<_OwnerExport> {
  late final ExamReferenceDrillAccountExportService _defaultService =
      ExamReferenceDrillAccountExportService();
  ExamReferenceDrillAccountExportService get _service =>
      widget.service ?? _defaultService;

  ReferencePracticeAccountExport? _export;
  bool _busy = false;
  String? _error;

  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _export = null;
      _error = null;
    });
    try {
      final export = await _service.load(expectedOwnerId: widget.ownerId);
      if (!mounted) return;
      if (export.ownerId != widget.ownerId) {
        throw StateError('Unexpected private export account');
      }
      setState(() => _export = export);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not prepare a complete private reference-practice export. '
          'Retry; no partial file was copied.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final data = _export;
    if (_busy || data == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Copy all saved reference-practice evidence?'),
        content: const Text(
          'Copies all available R1–R4 practice records from this account, '
          'including historical reference editions. This does not export '
          'your full LearningApp account. Other apps may read clipboard '
          'data. Do not share it publicly. No private answer keys are included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Copy reference-practice JSON'),
          ),
        ],
      ),
    );
    // If the owning account changes while the dialog is open, Flutter
    // disposes this keyed widget. Never copy an old account's payload.
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await Clipboard.setData(ClipboardData(text: data.toJsonExport()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reference-practice JSON copied.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy reference-practice JSON.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _export;
    return Card(
      key: const Key('exm-account-export-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export reference-practice history',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'This exports saved exam reference drills across your '
              'reference editions, including retired historical lists. '
              'It is not a whole-account archive or current-book checklist. '
              'Only server-checked choices count as graded responses.',
            ),
            TextButton.icon(
              key: const Key('exm-account-export-load'),
              onPressed: _busy ? null : _prepare,
              icon: const Icon(Icons.history_outlined),
              label: Text(data == null
                  ? 'Prepare all reference-practice data'
                  : 'Refresh reference-practice export'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('exm-account-export-error')),
            if (data != null) ...[
              Text(
                '${data.events.length} saved steps across '
                '${data.manifestCount} reference edition(s)',
                key: const Key('exm-account-export-count'),
              ),
              Text(
                '${data.gradedCorrect} correct, '
                '${data.gradedIncorrect} incorrect, '
                '${data.awaiting} awaiting grading, '
                '${data.skipped} skipped.',
              ),
              const Text(
                'Older editions are historical learning records and '
                'may not be approved for your next exam. Practice times '
                'and physical book use are unverified.',
              ),
              OutlinedButton.icon(
                key: const Key('exm-account-export-copy'),
                onPressed: _busy ? null : _copy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy all reference-practice JSON'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
