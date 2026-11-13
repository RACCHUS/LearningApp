import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';

/// Moderator/admin review of community lesson contributions (master plan
/// v2.6 §5.2, P5.1; PR-H slice 2).
///
/// Shows the frozen snapshot that would be shared, never the live lesson.
/// The server decides every action (role, own-contribution ban, switch,
/// state); this screen only offers the actions that fit the status.
class ContributionReviewScreen extends ConsumerStatefulWidget {
  const ContributionReviewScreen({super.key});

  @override
  ConsumerState<ContributionReviewScreen> createState() =>
      _ContributionReviewScreenState();
}

enum _Tab {
  waiting('Waiting', ['submitted']),
  approved('Approved', ['ready_for_publication']),
  published('Published', ['published']),
  closed('Closed', ['checks_failed', 'rejected', 'withdrawn', 'superseded']);

  const _Tab(this.label, this.statuses);
  final String label;
  final List<String> statuses;
}

class _ContributionReviewScreenState
    extends ConsumerState<ContributionReviewScreen> {
  _Tab _tab = _Tab.waiting;
  List<ContributionQueueItem>? _items;
  Object? _loadError;
  bool _busy = false;

  LessonContributionService get _service =>
      ref.read(lessonContributionServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _loadError = null;
    });
    try {
      final items = await _service.fetchQueue(_tab.statuses);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<String?> _askReason(String title, {required bool required}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('review_reason_field'),
          controller: controller,
          maxLength: 1000,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: required ? 'Reason (required)' : 'Note (optional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('review_reason_confirm'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on ContributionException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(ContributionQueueItem item) async {
    final note = await _askReason('Approve for publishing', required: false);
    if (note == null) return;
    await _run(
      () => _service.review(item.id, approve: true, note: note),
      'Approved. An admin can now publish it.',
    );
  }

  Future<void> _reject(ContributionQueueItem item) async {
    final note = await _askReason('Reject contribution', required: true);
    if (note == null) return;
    await _run(
      () => _service.review(item.id, approve: false, note: note),
      'Rejected.',
    );
  }

  Future<void> _publish(ContributionQueueItem item) => _run(
    () => _service.publish(item.id),
    'Published as "Community · unreviewed".',
  );

  Future<void> _takedown(ContributionQueueItem item) async {
    final reason = await _askReason('Take down', required: true);
    if (reason == null) return;
    await _run(() => _service.takedown(item.id, reason), 'Taken down.');
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(contributionRolesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson contributions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: roles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not check access.')),
        data: (r) => r.moderator
            ? _body(r)
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Only moderators and admins can review contributions.',
                    key: Key('contribution_review_denied'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _body(ContributionRoles roles) {
    final theme = Theme.of(context);
    final enabled = ref.watch(publicContributionEnabledProvider);
    final items = _items;
    return Column(
      children: [
        if (!enabled)
          Container(
            key: const Key('contribution_review_paused'),
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Text(
              'Contributions are switched off: reviewing and publishing are '
              'paused. Takedowns still work.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<_Tab>(
            segments: [
              for (final t in _Tab.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_tab},
            onSelectionChanged: (v) {
              setState(() => _tab = v.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: _loadError != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Could not load the queue. Retry'),
                  ),
                )
              : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
              ? const Center(child: Text('Nothing here.'))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final item in items) _card(item, roles, enabled),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _card(
    ContributionQueueItem item,
    ContributionRoles roles,
    bool enabled,
  ) {
    final theme = Theme.of(context);
    final actions = <Widget>[
      if (item.status == 'submitted' || item.status == 'ready_for_publication')
        TextButton(
          key: Key('reject_${item.id}'),
          onPressed: _busy || !enabled ? null : () => _reject(item),
          child: const Text('Reject'),
        ),
      if (item.status == 'submitted')
        FilledButton(
          key: Key('approve_${item.id}'),
          onPressed: _busy || !enabled ? null : () => _approve(item),
          child: const Text('Approve'),
        ),
      if (item.status == 'ready_for_publication' && roles.admin)
        FilledButton(
          key: Key('publish_${item.id}'),
          onPressed: _busy || !enabled ? null : () => _publish(item),
          child: const Text('Publish'),
        ),
      if (item.status == 'published')
        OutlinedButton(
          key: Key('takedown_${item.id}'),
          onPressed: _busy ? null : () => _takedown(item),
          child: const Text('Take down'),
        ),
    ];

    return Card(
      key: Key('contribution_${item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(item.title),
        subtitle: Text(
          'Version ${item.version} · ${item.license}'
          '${item.aiAssisted ? ' · AI-assisted' : ''} · '
          '${item.terms.length} terms, ${item.concepts.length} ideas, '
          '${item.questions.length} questions',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final code in item.issues) Text('• Check failed: $code'),
          if (item.reviewNote != null) Text('Note: ${item.reviewNote}'),
          for (final t in item.terms)
            Text(
              '${t['term']}: ${t['definition']}',
              style: theme.textTheme.bodyMedium,
            ),
          for (final c in item.concepts)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${c['concept_text']}'
                '${c['example_text'] == null ? '' : '\n${c['example_text']}'}',
              ),
            ),
          for (final q in item.questions) _question(q, theme),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
        ],
      ),
    );
  }

  Widget _question(Map<String, dynamic> q, ThemeData theme) {
    final options = (q['options'] as List?) ?? const [];
    final key = q['correct_answer'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q: ${q['question_text']}', style: theme.textTheme.titleSmall),
          for (final (i, o) in options.indexed)
            Text(
              '${i == key ? '✓' : '·'} $o',
              style: i == key
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          if (q['explanation'] != null)
            Text('Why: ${q['explanation']}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
