import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/learning_context.dart';
import '../../providers/auth_provider.dart';
import '../../services/assessment/exam_reference_context_progress_service.dart';

/// EXM-02B: Current Context only. This does not update ordinary concept mastery.
class ReferenceContextProgressCard extends ConsumerWidget {
  final LearningContext activeContext;
  final ExamReferenceContextProgressService? service;

  const ReferenceContextProgressCard({
    super.key,
    required this.activeContext,
    this.service,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final version = activeContext.targetVersionId;
    if (auth is! AuthSuccess ||
        auth.user.isAnonymous ||
        activeContext.rootType != ContextRootType.target ||
        activeContext.userId != auth.user.id ||
        version == null || version.isEmpty) {
      return const SizedBox.shrink();
    }
    return _OwnerContextProgress(
      key: ValueKey('exam-context-progress:${auth.user.id}:'
          '${activeContext.id}:$version'),
      ownerId: auth.user.id,
      targetVersionId: version,
      service: service,
    );
  }
}

class _OwnerContextProgress extends StatefulWidget {
  final String ownerId;
  final String targetVersionId;
  final ExamReferenceContextProgressService? service;

  const _OwnerContextProgress({
    super.key,
    required this.ownerId,
    required this.targetVersionId,
    this.service,
  });

  @override
  State<_OwnerContextProgress> createState() => _OwnerContextProgressState();
}

class _OwnerContextProgressState extends State<_OwnerContextProgress> {
  late final ExamReferenceContextProgressService _defaultService =
      ExamReferenceContextProgressService();
  ExamReferenceContextProgressService get _api =>
      widget.service ?? _defaultService;

  bool _loading = false;
  ReferenceContextProgress? _data;
  String? _error;

  Future<void> _fetch() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.load(
        expectedOwnerId: widget.ownerId,
        targetVersionId: widget.targetVersionId,
      );
      if (!mounted) return;
      if (result.ownerId != widget.ownerId ||
          result.targetVersionId != widget.targetVersionId) {
        throw const FormatException('Wrong reference Progress context');
      }
      setState(() => _data = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _data = null;
        _error = 'Could not load private reference evidence. Retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static const _skills = [
    ('resource_choice', 'R1 · Select reference'),
    ('section_location', 'R2 · Find section'),
    ('interpretation', 'R3 · Interpret rule'),
    ('application', 'R4 · Apply rule'),
  ];

  @override
  Widget build(BuildContext context) {
    final summary = _data;
    return Card(
      key: const Key('exam-context-progress'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exam reference practice evidence',
                style: Theme.of(context).textTheme.titleMedium),
            const Text(
              'Separate from concept mastery and readiness. '
              'Only your saved responses for currently published reviewed '
              'reference editions are shown. Physical book use and '
              'practice timing are not independently verified.',
            ),
            TextButton.icon(
              onPressed: _loading ? null : _fetch,
              icon: const Icon(Icons.refresh),
              label: Text(summary == null
                  ? 'Load exam practice evidence'
                  : 'Refresh exam practice evidence'),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, key: const Key('exam-context-progress-error')),
            if (summary != null) ...[
              if (summary.editions.isEmpty)
                const Text('No saved reference practice for this target version.'),
              for (final edition in summary.editions) ...[
                const Divider(),
                Text(
                  '${edition.partKey.replaceAll('_', ' ')} · '
                  'reference revision ${edition.revision}',
                  key: Key('exam-context-edition:${edition.manifestId}'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${edition.total} saved step(s): '
                  '${edition.correct} correct, '
                  '${edition.incorrect} incorrect, '
                  '${edition.awaiting} awaiting score, '
                  '${edition.skipped} skipped.',
                ),
                for (final skill in _skills)
                  if (edition.steps[skill.$1] case final count?)
                    Text(
                      '${skill.$2}: ${count.correct} correct, '
                      '${count.incorrect} incorrect, '
                      '${count.awaiting} awaiting, '
                      '${count.skipped} skipped '
                      '(${count.recorded} recorded)',
                      key: Key('exam-context-skill:'
                          '${edition.manifestId}:${skill.$1}'),
                    ),
              ],
              const Text(
                'These are counts of server-checked choices, not '
                'licensing-exam scores or passing predictions. '
                'Open the exam target and confirm your actual exam '
                'date for the complete edition-specific history and export.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
