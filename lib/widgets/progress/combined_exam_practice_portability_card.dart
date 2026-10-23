import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_combined_practice_portability_service.dart';
import '../../services/assessment/reference_practice_json_download.dart';

/// User-controlled portability of both EXM-02B and EXM-03 educational
/// practice, separate from general account data and official exam results.
/// Every action is gated on the current permanent account.
class CombinedExamPracticePortabilityCard extends ConsumerWidget {
  final ExamCombinedPracticePortabilityService? service;
  final ReferencePracticeJsonDownload? fileDownload;

  const CombinedExamPracticePortabilityCard({
    super.key,
    this.service,
    this.fileDownload,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth is! AuthSuccess || auth.user.isAnonymous) {
      return const SizedBox.shrink();
    }
    return _OwnedCombinedPractice(
      key: ValueKey('exm-combined-portability:${auth.user.id}'),
      ownerId: auth.user.id,
      service: service,
      fileDownload: fileDownload,
      ownerStillCurrent: () {
        final current = ref.read(authProvider);
        return current is AuthSuccess &&
            !current.user.isAnonymous &&
            current.user.id == auth.user.id;
      },
    );
  }
}

class _OwnedCombinedPractice extends StatefulWidget {
  final String ownerId;
  final bool Function() ownerStillCurrent;
  final ExamCombinedPracticePortabilityService? service;
  final ReferencePracticeJsonDownload? fileDownload;

  const _OwnedCombinedPractice({
    super.key,
    required this.ownerId,
    required this.ownerStillCurrent,
    this.service,
    this.fileDownload,
  });

  @override
  State<_OwnedCombinedPractice> createState() =>
      _OwnedCombinedPracticeState();
}

class _OwnedCombinedPracticeState extends State<_OwnedCombinedPractice> {
  late final ExamCombinedPracticePortabilityService _defaultService =
      ExamCombinedPracticePortabilityService();
  ExamCombinedPracticePortabilityService get _api =>
      widget.service ?? _defaultService;

  late final ReferencePracticeJsonDownload _defaultDownload =
      ReferencePracticeJsonDownload();
  ReferencePracticeJsonDownload get _download =>
      widget.fileDownload ?? _defaultDownload;

  final TextEditingController _confirmation = TextEditingController();
  ExamPracticeInventory? _inventory;
  ExamPracticeArchive? _archive;
  bool _busy = false;
  String? _error;
  String? _result;

  bool get _owned => mounted && widget.ownerStillCurrent();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_busy || !_owned) return;
    setState(() {
      _busy = true;
      _inventory = null;
      _archive = null;
      _error = null;
      _result = null;
      _confirmation.clear();
    });
    try {
      final inventory = await _api.inventory(
        expectedOwnerId: widget.ownerId,
      );
      if (!_owned) return;
      if (inventory.owner != widget.ownerId) {
        throw StateError('Wrong practice archive owner');
      }
      setState(() => _inventory = inventory);
    } catch (_) {
      if (!_owned) return;
      setState(() => _error = 'Unable to verify complete EXM practice '
          'history. No export or deletion is available; retry the preview.');
    } finally {
      if (_owned) setState(() => _busy = false);
    }
  }

  Future<void> _prepare() async {
    final preview = _inventory;
    if (_busy || !_owned || preview == null) return;
    setState(() {
      _busy = true;
      _archive = null;
      _error = null;
      _result = null;
    });
    try {
      final archive = await _api.export(expectedOwnerId: widget.ownerId);
      if (!_owned) return;
      final count = archive.inventory;
      if (count.owner != preview.owner ||
          count.fingerprint != preview.fingerprint ||
          count.referenceEvents != preview.referenceEvents ||
          count.referenceGrades != preview.referenceGrades ||
          count.assignments != preview.assignments ||
          count.attempts != preview.attempts) {
        throw StateError('Practice archive changed since the preview');
      }
      setState(() => _archive = archive);
    } catch (_) {
      if (!_owned) return;
      setState(() {
        _inventory = null;
        _archive = null;
        _confirmation.clear();
        _error = 'History changed or the complete archive could not be '
            'verified. Refresh the preview. No file was requested.';
      });
    } finally {
      if (_owned) setState(() => _busy = false);
    }
  }

  /// Called inside the confirmation button's gesture, not after awaiting
  /// a dialog Future; otherwise browsers may block the download request.
  void _requestDownload(ExamPracticeArchive archive) {
    if (_busy || !_owned || !identical(_archive, archive) ||
        !_download.isSupported) return;
    setState(() => _busy = true);
    try {
      _download.requestChunkedDownload(
        filename: ReferencePracticeJsonDownload.combinedFilenameAt(
          DateTime.now(),
        ),
        chunks: archive.toJsonChunks(),
      );
      if (!_owned) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Combined EXM JSON download requested. '
            'Check browser Downloads; saving is not confirmed.'),
      ));
    } catch (_) {
      if (!_owned) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not request combined EXM JSON download.'),
      ));
    } finally {
      if (_owned) setState(() => _busy = false);
    }
  }

  void _confirmDownload() {
    final archive = _archive;
    if (archive == null || !_owned || _busy || !_download.isSupported) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Download combined EXM practice history?'),
        content: const Text(
          'Includes R1–R4 reference steps, grades, issued EXM-03 '
          'assignments and completed educational practice summaries. '
          'This is not your full LearningApp account or an official exam '
          'record. Keep the file private. The 64 MiB browser limit applies; '
          'the app cannot verify that the browser saved the file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('exm-combined-download-confirm'),
            onPressed: () {
              Navigator.pop(dialog);
              _requestDownload(archive);
            },
            child: const Text('Request combined JSON download'),
          ),
        ],
      ),
    );
  }

  Future<void> _erase() async {
    final preview = _inventory;
    if (_busy || !_owned || preview == null || !preview.hasHistory ||
        _confirmation.text !=
            ExamCombinedPracticePortabilityService.confirmationPhrase) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Permanently delete all EXM practice history?'),
        content: Text(
          'Delete ${preview.referenceEvents} R1–R4 steps and '
          '${preview.referenceGrades} grades, plus '
          '${preview.assignments} EXM-03 issued assignments and '
          '${preview.attempts} scored summaries? This cannot be undone. '
          'Previously downloaded copies remain yours. This does not '
          'delete other LearningApp account information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('exm-combined-delete-confirm'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Permanently delete practice history'),
          ),
        ],
      ),
    );
    if (accepted != true || _busy || !_owned ||
        !identical(preview, _inventory) ||
        _confirmation.text !=
            ExamCombinedPracticePortabilityService.confirmationPhrase) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _archive = null;
    });
    try {
      await _api.erase(
        expectedOwnerId: widget.ownerId,
        preview: preview,
        exactConfirmation: _confirmation.text,
      );
      if (!_owned) return;
      setState(() {
        _inventory = null;
        _confirmation.clear();
        _result = 'Server confirmed EXM practice erasure. '
            'Refresh the inventory before any further action.';
      });
    } catch (_) {
      if (!_owned) return;
      // A network response can be lost after commit. Never claim erasure
      // or retry based on stale counts; force a fresh server preview.
      setState(() {
        _inventory = null;
        _archive = null;
        _confirmation.clear();
        _error = 'Deletion could not be confirmed. Refresh inventory '
            'to check which records remain before trying again.';
      });
    } finally {
      if (_owned) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _inventory;
    return Card(
      key: const Key('exm-combined-practice-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export or delete all EXM practice history',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'Includes saved R1–R4 reference drills and EXM-03 practice '
              'assignments/grades across parts and editions. It does not '
              'include unrelated account data or official exam results.',
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('exm-combined-preview'),
              onPressed: _busy ? null : _preview,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Verify my EXM practice inventory'),
            ),
            const Text(
              'This bounded archive supports up to 5,000 reference events '
              'and 5,000 EXM-03 assignments. Larger histories require a '
              'different verified export; no incomplete download is offered.',
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('exm-combined-error')),
            if (_result != null)
              Text(_result!, key: const Key('exm-combined-result')),
            if (count != null) ...[
              const Divider(),
              Text(
                '${count.referenceEvents} reference steps, '
                '${count.referenceGrades} grades; '
                '${count.assignments} issued part assignments, '
                '${count.attempts} scored part attempts.',
                key: const Key('exm-combined-counts'),
              ),
              OutlinedButton.icon(
                key: const Key('exm-combined-prepare'),
                onPressed: _busy ? null : _prepare,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Prepare verified combined JSON'),
              ),
              if (_archive != null) ...[
                const Text(
                  'Combined practice archive verified against this preview. '
                  'Download it before deletion if you want a copy.',
                  key: Key('exm-combined-verified'),
                ),
                if (_download.isSupported)
                  FilledButton.icon(
                    key: const Key('exm-combined-download'),
                    onPressed: _busy ? null : _confirmDownload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download combined JSON file'),
                  )
                else
                  const Text('Browser JSON download is unavailable here.'),
              ],
              if (count.hasHistory) ...[
                const Divider(),
                const Text(
                  'Permanently delete all EXM practice history only after '
                  'reviewing the inventory and saving any needed copy. '
                  'Type exactly: DELETE ALL EXAM PRACTICE',
                ),
                TextField(
                  key: const Key('exm-combined-phrase'),
                  controller: _confirmation,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Exact deletion confirmation',
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('exm-combined-delete'),
                  onPressed: !_busy &&
                          _confirmation.text ==
                              ExamCombinedPracticePortabilityService
                                  .confirmationPhrase
                      ? _erase
                      : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Review permanent EXM practice deletion'),
                ),
              ] else
                const Text('No saved EXM practice history to delete.'),
            ],
          ],
        ),
      ),
    );
  }
}
