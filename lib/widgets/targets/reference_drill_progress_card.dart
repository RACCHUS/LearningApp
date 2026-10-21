import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_drill_progress_service.dart';

/// Progress from real durable events. Correctness is only a checked response
/// token; it is NOT official readiness or proof of physical book navigation.
class ReferenceDrillProgressCard extends ConsumerWidget {
  final String manifestRevisionId;
  final ExamReferenceDrillProgressService? progressService;

  const ReferenceDrillProgressCard({
    super.key,
    required this.manifestRevisionId,
    this.progressService,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authProvider);
    if (session is! AuthSuccess || session.user.isAnonymous) {
      return const SizedBox.shrink();
    }
    return _OwnerProgress(
      key: ValueKey('reference-progress:${session.user.id}:$manifestRevisionId'),
      ownerId: session.user.id,
      manifestId: manifestRevisionId,
      service: progressService,
    );
  }
}

class _OwnerProgress extends StatefulWidget {
  final String ownerId;
  final String manifestId;
  final ExamReferenceDrillProgressService? service;

  const _OwnerProgress({
    super.key,
    required this.ownerId,
    required this.manifestId,
    this.service,
  });

  @override
  State<_OwnerProgress> createState() => _OwnerProgressState();
}

class _OwnerProgressState extends State<_OwnerProgress> {
  late final ExamReferenceDrillProgressService _defaultService =
      ExamReferenceDrillProgressService();
  ExamReferenceDrillProgressService get _service =>
      widget.service ?? _defaultService;

  bool _loading = false;
  bool _loaded = false;
  String? _error;
  ReferenceDrillProgressSnapshot? _snapshot;

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _service.loadComplete(
        expectedOwnerId: widget.ownerId,
        manifestRevisionId: widget.manifestId,
      );
      if (!mounted) return;
      // Defense against a faulty transport returning the wrong edition/owner.
      if (snapshot.ownerId != widget.ownerId ||
          snapshot.manifestId != widget.manifestId) {
        throw StateError('Incorrect progress account or reference edition');
      }
      setState(() {
        _snapshot = snapshot;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _loaded = false;
        _error = 'Could not load complete private progress. Retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyExport() async {
    final snapshot = _snapshot;
    if (snapshot == null || _loading) return;
    // Build the export BEFORE opening the confirmation, but never copy
    // until the owner explicitly authorizes the transfer to clipboard.
    final json = snapshot.toJsonExport();
    final copy = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Copy private practice data?'),
        content: const Text(
          'Copies this reference edition\'s complete saved observations '
          'and server-checked results as JSON. Clipboard content can '
          'be read by other applications. No protected answers are included.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Copy JSON'),
          ),
        ],
      ),
    );
    if (!mounted || copy != true) return;
    try {
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private reference practice JSON copied.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy JSON. Try again.')),
      );
    }
  }

  String _name(String step) => switch (step) {
    'resource_choice' => 'R1 · Reference choice',
    'section_location' => 'R2 · Section location',
    'interpretation' => 'R3 · Interpretation',
    'application' => 'R4 · Application',
    _ => 'Unknown',
  };

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Card(
      key: const Key('reference-drill-progress'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reference skill progress',
                style: Theme.of(context).textTheme.titleSmall),
            const Text(
              'Only saved practice for this reference edition. '
              'Server-checked choices are separated from ungraded activity. '
              'Not an official score or passing prediction.',
            ),
            TextButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(_loaded ? 'Refresh progress' : 'Load private progress'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('reference-progress-error')),
            if (snapshot != null) ...[
              Text(
                '${snapshot.events.length} saved step observation(s)',
                key: const Key('reference-progress-count'),
              ),
              if (snapshot.events.isEmpty)
                const Text('No saved reference practice for this edition.'),
              for (final skill in snapshot.skills)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${_name(skill.step)}: ${skill.graded} server-graded '
                    '(${skill.correct} correct, ${skill.incorrect} incorrect); '
                    '${skill.awaitingScore} awaiting score; '
                    '${skill.skipped} skipped.',
                    key: Key('reference-progress-skill:${skill.step}'),
                  ),
                ),
              const Text(
                'Timing and physical-book use are self-reported/client '
                'observations and are not independently verified.',
              ),
              OutlinedButton.icon(
                key: const Key('reference-progress-export-json'),
                onPressed: _loading ? null : _copyExport,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy this edition JSON export'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
