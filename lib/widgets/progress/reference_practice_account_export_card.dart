import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_drill_account_export_service.dart';
import '../../services/assessment/exam_reference_verified_large_export_service.dart';
import '../../services/assessment/reference_practice_json_download.dart';

/// EXM reference-practice subsystem portability, NOT a full account archive.
/// Kept separate from ordinary knowledge/mastery dashboards.
class ReferencePracticeAccountExportCard extends ConsumerWidget {
  final ExamReferenceDrillAccountExportService? exportService;
  final ExamReferenceVerifiedLargeExportService? largeExportService;
  final ReferencePracticeJsonDownload? fileDownload;

  const ReferencePracticeAccountExportCard({
    super.key,
    this.exportService,
    this.largeExportService,
    this.fileDownload,
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
      largeService: largeExportService,
      fileDownload: fileDownload,
      ownerStillCurrent: () {
        final current = ref.read(authProvider);
        return current is AuthSuccess && !current.user.isAnonymous &&
            current.user.id == auth.user.id;
      },
    );
  }
}

class _OwnerExport extends StatefulWidget {
  final String ownerId;
  final ExamReferenceDrillAccountExportService? service;
  final ExamReferenceVerifiedLargeExportService? largeService;
  final ReferencePracticeJsonDownload? fileDownload;
  final bool Function() ownerStillCurrent;

  const _OwnerExport({
    super.key,
    required this.ownerId,
    this.service,
    this.largeService,
    this.fileDownload,
    required this.ownerStillCurrent,
  });

  @override
  State<_OwnerExport> createState() => _OwnerExportState();
}

class _OwnerExportState extends State<_OwnerExport> {
  late final ExamReferenceDrillAccountExportService _defaultService =
      ExamReferenceDrillAccountExportService();
  ExamReferenceDrillAccountExportService get _service =>
      widget.service ?? _defaultService;

  late final ExamReferenceVerifiedLargeExportService _defaultLargeService =
      ExamReferenceVerifiedLargeExportService();
  ExamReferenceVerifiedLargeExportService get _largeService =>
      widget.largeService ?? _defaultLargeService;

  late final ReferencePracticeJsonDownload _defaultDownload =
      ReferencePracticeJsonDownload();
  ReferencePracticeJsonDownload get _fileDownload =>
      widget.fileDownload ?? _defaultDownload;

  ReferencePracticeAccountExport? _export;
  bool _largeMode = false;
  bool _busy = false;
  String? _error;

  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _export = null;
      _largeMode = false;
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

  Future<void> _prepareLarge() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _export = null;
      _largeMode = false;
    });
    try {
      final export = await _largeService.loadComplete(
        expectedOwnerId: widget.ownerId,
      );
      if (!mounted) return;
      if (export.ownerId != widget.ownerId) {
        throw StateError('Untrusted large export owner');
      }
      setState(() {
        _export = export;
        _largeMode = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not verify a complete large-history export. '
          'Records may have changed; retry. No JSON was copied.');
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
    if (!mounted || confirmed != true || _busy ||
        !widget.ownerStillCurrent() || !identical(data, _export)) return;
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

  /// Confirmation button itself initiates the browser request synchronously,
  /// preserving user activation. Returning from a dialog Future first can
  /// cause browsers to block programmatic file downloads.
  void _confirmFileDownload() {
    final data = _export;
    if (_busy || data == null || !_fileDownload.isSupported) return;
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Download your reference-practice JSON?'),
        content: const Text(
          'Requests a local JSON file containing your saved R1–R4 steps, '
          'including older reference editions and owner identifiers. '
          'This is not a full LearningApp account archive. Keep the file '
          'private and check your browser Downloads; the app cannot '
          'confirm that the file was saved. Browser file exports are '
          'limited to 64 MiB to avoid excessive memory usage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('exm-json-download-confirm'),
            onPressed: () {
              Navigator.of(dialog).pop();
              _requestFileDownload(data);
            },
            child: const Text('Request JSON file download'),
          ),
        ],
      ),
    );
  }

  void _requestFileDownload(ReferencePracticeAccountExport data) {
    if (!mounted || _busy || !widget.ownerStillCurrent() ||
        !identical(data, _export)) return;
    setState(() => _busy = true);
    try {
      // No giant intermediate JSON string; the browser collects bounded
      // UTF-8 byte segments before attempting the user-activated download.
      _fileDownload.requestChunkedDownload(
        filename: ReferencePracticeJsonDownload.filenameAt(DateTime.now()),
        chunks: data.toJsonExportChunks(),
      );
      if (!mounted || !widget.ownerStillCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'JSON download requested. Check your browser Downloads.',
        )),
      );
    } catch (_) {
      if (!mounted || !widget.ownerStillCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not request JSON download.')),
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
            TextButton.icon(
              key: const Key('exm-large-export-load'),
              onPressed: _busy ? null : _prepareLarge,
              icon: const Icon(Icons.storage_outlined),
              label: const Text('Prepare verified large history (up to 50,000 steps)'),
            ),
            const Text(
              'Large-history export checks that event and grade inventories '
              'match before and after paging. This is not an atomic '
              'database snapshot; changes during collection cause a failure. '
              'All-edition exports remain EXM-only, not full account archives.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('exm-account-export-error')),
            if (data != null) ...[
              if (_largeMode)
                const Text('Large export verified against the final account '
                    'inventory; not a single database transaction.'),
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
              if (_fileDownload.isSupported)
                OutlinedButton.icon(
                  key: const Key('exm-account-export-download'),
                  onPressed: _busy ? null : _confirmFileDownload,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download reference-practice JSON file'),
                )
              else
                const Text('File download is available in a supported web '
                    'browser. You can still copy JSON on this device.'),
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
