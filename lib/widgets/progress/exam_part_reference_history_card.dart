import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/learning_context_provider.dart';
import '../../services/assessment/exam_part_reference_attempt_history_service.dart';

final examPartReferenceHistoryServiceProvider =
    Provider<ExamPartReferenceAttemptHistoryService>((ref) {
  return ExamPartReferenceAttemptHistoryService();
});

/// Opt-in read of durable EXM-02B reference drills, never diagnostic/mock
/// attempts. Deliberately separate from concept readiness and NextAction.
class ExamPartReferenceHistoryCard extends ConsumerStatefulWidget {
  final String ownerId;
  final String targetVersionId;
  final String examPartKey;

  const ExamPartReferenceHistoryCard({
    super.key,
    required this.ownerId,
    required this.targetVersionId,
    required this.examPartKey,
  });

  @override
  ConsumerState<ExamPartReferenceHistoryCard> createState() =>
      _ExamPartReferenceHistoryCardState();
}

class _ExamPartReferenceHistoryCardState
    extends ConsumerState<ExamPartReferenceHistoryCard> {
  static const _pageLimit = 20;
  static const _uiMax = 500;
  bool _busy = false;
  bool _loaded = false;
  bool _mightHaveMore = false;
  String? _error;
  List<SavedPartReferenceAttempt> _attempts = const [];

  @override
  void didUpdateWidget(covariant ExamPartReferenceHistoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ownerId != oldWidget.ownerId ||
        widget.examPartKey != oldWidget.examPartKey ||
        widget.targetVersionId != oldWidget.targetVersionId) {
      _busy = false;
      _loaded = false;
      _mightHaveMore = false;
      _error = null;
      _attempts = const [];
    }
  }

  Future<void> _load({bool older = false}) async {
    if (_busy || (older && (_attempts.isEmpty || !_mightHaveMore)) ||
        ref.read(learnerIdProvider) != widget.ownerId) {
      return;
    }
    final requestOwner = widget.ownerId;
    final requestVersion = widget.targetVersionId;
    final requestPart = widget.examPartKey;
    final previous = _attempts;
    final last = older ? previous.last : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await ref.read(examPartReferenceHistoryServiceProvider).load(
        expectedOwnerId: requestOwner,
        targetVersionId: requestVersion,
        examPartKey: requestPart,
        limit: _pageLimit,
        beforeAt: last?.lastRecordedAt,
        beforeAttemptId: last?.id,
      );
      if (!mounted || ref.read(learnerIdProvider) != requestOwner ||
          widget.ownerId != requestOwner ||
          widget.targetVersionId != requestVersion ||
          widget.examPartKey != requestPart) return;
      if (page.ownerId != requestOwner ||
          page.partKey != requestPart ||
          page.targetVersionId != requestVersion) {
        throw const FormatException('Mismatched owner-scoped history page');
      }
      final all = older ? [...previous, ...page.attempts] : page.attempts;
      if (all.map((a) => a.id).toSet().length != all.length) {
        throw const FormatException('Repeated practice attempt across pages');
      }
      setState(() {
        _attempts = List.unmodifiable(all);
        _loaded = true;
        _mightHaveMore = page.mightHaveMore && all.length < _uiMax;
      });
    } catch (_) {
      if (!mounted || ref.read(learnerIdProvider) != requestOwner ||
          widget.ownerId != requestOwner ||
          widget.targetVersionId != requestVersion ||
          widget.examPartKey != requestPart) return;
      setState(() {
        _error = 'Could not load private saved reference drills. '
            'A permanent owner sign-in is required. Retry.';
      });
    } finally {
      if (mounted && ref.read(learnerIdProvider) == requestOwner &&
          widget.ownerId == requestOwner &&
          widget.targetVersionId == requestVersion &&
          widget.examPartKey == requestPart) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(learnerIdProvider) != widget.ownerId) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final completed = _attempts.where((a) => a.completedFourSteps).length;
    return Column(
      key: const Key('exam-part-saved-reference-history'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text('Saved reference practice · selected part',
            style: theme.textTheme.titleSmall),
        const Text(
          'These are recorded R1–R4 reference drills for reviewed editions. '
          'They are not diagnostic or mock exams. Book use and times are '
          'self-reported; saved steps and server-graded choices are distinct.',
        ),
        TextButton.icon(
          key: const Key('exam-part-history-load'),
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.history),
          label: Text(_loaded ? 'Refresh saved reference drills'
                              : 'Load saved reference drills'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Text(_error!, key: const Key('exam-part-history-error')),
        if (_loaded) ...[
          Text(
            '${_attempts.length} recent saved drill(s) shown: '
            '$completed recorded all four stages; '
            '${_attempts.length - completed} incomplete.',
            key: const Key('exam-part-history-summary'),
          ),
          if (_attempts.isEmpty)
            const Text('No saved reference drills for this selected part.'),
          for (final attempt in _attempts)
            Padding(
              key: Key('exam-part-attempt:${attempt.id}'),
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                'Reference revision ${attempt.manifestRevision} · '
                '${attempt.recordedSteps}/4 stages recorded · '
                '${attempt.correct} graded correct · '
                '${attempt.incorrect} graded incorrect · '
                '${attempt.awaiting} awaiting · '
                '${attempt.skipped} skipped · '
                '${attempt.lastRecordedAt.toLocal().toString().split('.').first}',
              ),
            ),
          if (_mightHaveMore)
            TextButton(
              key: const Key('exam-part-history-more'),
              onPressed: _busy ? null : () => _load(older: true),
              child: const Text('Load older saved drills'),
            ),
          if (_attempts.length >= _uiMax)
            const Text(
              'Only the latest 500 drills can be displayed here. '
              'Use your reference-practice account export for the '
              'bounded complete event history.',
            ),
          const Text(
            'Saved R1–R4 events are included in the existing owner-only '
            'reference-practice export and explicit erasure tools. '
            'Four recorded steps do not establish an official exam result.',
          ),
        ],
      ],
    );
  }
}
