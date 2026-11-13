import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';

/// Owner-only "Share with the community" entry (master plan v2.6 §8.6,
/// PR-H). Separate from the lesson's own Private/Public toggle: sharing
/// submits a reviewed, licensed copy and never changes the lesson itself.
class ShareWithCommunityAction extends ConsumerWidget {
  const ShareWithCommunityAction({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.isOwner,
    this.tags = const [],
  });

  final String lessonId;
  final String lessonTitle;
  final bool isOwner;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isOwner || !ref.watch(publicContributionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const Key('share_with_community_action'),
      icon: const Icon(Icons.volunteer_activism_outlined),
      tooltip: 'Share with the community',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => ShareWithCommunityDialog(
          lessonId: lessonId,
          lessonTitle: lessonTitle,
          aiAssistedHint: tags.contains('ai-generated'),
        ),
      ),
    );
  }
}

class ShareWithCommunityDialog extends ConsumerStatefulWidget {
  const ShareWithCommunityDialog({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    this.aiAssistedHint = false,
  });

  final String lessonId;
  final String lessonTitle;
  final bool aiAssistedHint;

  @override
  ConsumerState<ShareWithCommunityDialog> createState() =>
      _ShareWithCommunityDialogState();
}

class _ShareWithCommunityDialogState
    extends ConsumerState<ShareWithCommunityDialog> {
  ContributionLicense _license = ContributionLicense.ccBy;
  bool _rights = false;
  late bool _ai = widget.aiAssistedHint;
  bool _busy = false;
  bool _loaded = false;
  ContributionStatus? _latest;
  List<RefreshProposal> _accepted = const [];
  String? _message;

  static const _issueText = {
    'missing_title': 'The lesson needs a title.',
    'empty_lesson': 'The lesson has no terms, ideas or questions yet.',
    'too_large': 'The lesson is too large to share.',
    'option_count': 'A question needs 2 to 8 answer options.',
    'answer_key_out_of_range': 'A question has no valid correct answer.',
    'duplicate_options': 'A question has two options with the same text.',
    'missing_accepted_answers':
        'A short-answer question has no accepted answer.',
  };

  static const _statusText = {
    'submitted': 'Waiting for review.',
    'checks_failed': 'Needs fixes before review.',
    'ready_for_publication': 'Approved. Waiting to be published.',
    'published': 'Shared with the community (labelled unreviewed).',
    'rejected': 'Not accepted.',
    'withdrawn': 'Withdrawn.',
    'superseded': 'Replaced by a newer version.',
  };

  LessonContributionService get _service =>
      ref.read(lessonContributionServiceProvider);

  @override
  void initState() {
    super.initState();
    _service.latestFor(widget.lessonId).then((s) {
      if (mounted) {
        setState(() {
          _latest = s;
          _loaded = true;
        });
      }
    });
    _service.acceptedProposalsFor(widget.lessonId).then((p) {
      if (mounted) setState(() => _accepted = p);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final s = await _service.submit(
        lessonId: widget.lessonId,
        license: _license,
        rightsAttested: _rights,
        aiAssisted: _ai,
      );
      setState(() {
        _latest = s;
        _message = s.status == 'submitted'
            ? 'Sent for review. Your lesson stays private.'
            : 'Some things need fixing first. Your lesson stays private.';
      });
    } on ContributionException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(ContributionStatus s) async {
    setState(() => _busy = true);
    try {
      await _service.withdraw(s.id);
      final latest = await _service.latestFor(widget.lessonId);
      setState(() {
        _latest = latest;
        _message = 'Withdrawn.';
      });
    } on ContributionException catch (e) {
      setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = _latest;
    final canSubmit =
        _loaded &&
        !_busy &&
        _rights &&
        (latest == null || !latest.isOpen || latest.status == 'checks_failed');

    return AlertDialog(
      title: const Text('Share with the community'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A copy of "${widget.lessonTitle}" is checked automatically and '
              'reviewed before anyone else sees it. Your lesson itself stays '
              'private. Shared copies are labelled "Community · unreviewed" '
              'and never count as verified mastery.',
              style: theme.textTheme.bodyMedium,
            ),
            if (latest != null) ...[
              const SizedBox(height: 12),
              Text(
                'Version ${latest.version}: '
                '${_statusText[latest.status] ?? latest.status}',
                key: const Key('contribution_status'),
                style: theme.textTheme.titleSmall,
              ),
              for (final code in latest.issues)
                Text('• ${_issueText[code] ?? code}'),
              if (latest.reviewNote != null)
                Text('Reviewer note: ${latest.reviewNote}'),
              if (latest.canWithdraw)
                TextButton(
                  key: const Key('contribution_withdraw'),
                  onPressed: _busy ? null : () => _withdraw(latest),
                  child: const Text('Withdraw'),
                ),
            ],
            if (_accepted.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Update suggestions accepted by moderators',
                key: const Key('accepted_suggestions'),
                style: theme.textTheme.titleSmall,
              ),
              for (final p in _accepted)
                Text(
                  '• ${p.kind.label}'
                  '${p.itemRef == null ? '' : ' (${p.itemRef})'}: '
                  '${p.description}',
                ),
              Text(
                'Edit your lesson, then submit again to share the update.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Text('Licence', style: theme.textTheme.titleSmall),
            DropdownButton<ContributionLicense>(
              key: const Key('contribution_license'),
              value: _license,
              isExpanded: true,
              items: [
                for (final l in ContributionLicense.values)
                  DropdownMenuItem(
                    value: l,
                    child: Text('${l.label}: ${l.summary}'),
                  ),
              ],
              onChanged: (v) => setState(() => _license = v ?? _license),
            ),
            CheckboxListTile(
              key: const Key('contribution_rights'),
              contentPadding: EdgeInsets.zero,
              value: _rights,
              onChanged: (v) => setState(() => _rights = v ?? false),
              title: const Text(
                'I created this lesson or have the right to share it under '
                'this licence.',
              ),
            ),
            CheckboxListTile(
              key: const Key('contribution_ai'),
              contentPadding: EdgeInsets.zero,
              value: _ai,
              onChanged: (v) => setState(() => _ai = v ?? false),
              title: const Text('AI helped write it'),
            ),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(_message!, key: const Key('contribution_message')),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          key: const Key('contribution_submit'),
          onPressed: canSubmit ? _submit : null,
          child: Text(
            latest?.status == 'checks_failed'
                ? 'Submit again'
                : 'Submit for review',
          ),
        ),
      ],
    );
  }
}
