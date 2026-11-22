import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/community/wanted_board_service.dart';

/// The Wanted Board (master plan v2.6 §6.8 M-14): moderated, concept-level
/// lesson requests that anyone can fulfil by sharing a lesson through the
/// normal contribution review. It never shows who asked or voted.
class WantedBoardScreen extends ConsumerStatefulWidget {
  const WantedBoardScreen({super.key});

  @override
  ConsumerState<WantedBoardScreen> createState() => _WantedBoardScreenState();
}

class _WantedBoardScreenState extends ConsumerState<WantedBoardScreen> {
  List<WantedNeed>? _needs;
  Object? _error;
  bool _busy = false;

  WantedBoardService get _service => ref.read(wantedBoardServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!ref.read(wantedBoardEnabledProvider)) return;
    setState(() {
      _needs = null;
      _error = null;
    });
    try {
      final needs = await _service.board();
      if (mounted) setState(() => _needs = needs);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _say(done);
      await _load();
    } on WantedBoardException catch (e) {
      _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _propose() async {
    final title = TextEditingController();
    final details = TextEditingController();
    final tag = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ask for a lesson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Describe a topic, not yourself. A moderator checks it '
                'before it appears on the board.',
              ),
              TextField(
                key: const Key('wanted_title'),
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
              TextField(
                key: const Key('wanted_details'),
                controller: details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'What should it cover? (optional)',
                ),
              ),
              TextField(
                key: const Key('wanted_tag'),
                controller: tag,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Subject tag, e.g. excel (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('wanted_send'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send for review'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _service.propose(
        title.text.trim(),
        details: details.text.trim().isEmpty ? null : details.text.trim(),
        tag: tag.text.trim().isEmpty ? null : tag.text.trim().toLowerCase(),
      ),
      'Thanks. A moderator will check it before it appears.',
    );
  }

  Future<void> _fulfil(WantedNeed need) async {
    List<LinkableContribution> mine;
    try {
      mine = await _service.myContributions();
    } on WantedBoardException catch (e) {
      return _say(e.message);
    }
    if (!mounted) return;
    final chosen = await showDialog<LinkableContribution>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make "${need.title}"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create the lesson as usual, then use "Share with the '
                'community" on it. After that, link it here so moderators '
                'can see it answers this request.',
              ),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                const Text(
                  'You have not shared a lesson yet.',
                  key: Key('wanted_no_contributions'),
                ),
              for (final c in mine)
                ListTile(
                  key: Key('wanted_link_${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.title),
                  subtitle: Text(c.isPublished ? 'Published' : 'In review'),
                  onTap: () => Navigator.of(context).pop(c),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await _run(
      () => _service.link(need.id, chosen.id),
      'Linked. Moderators will see it with this request.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(wantedBoardEnabledProvider);
    final isModerator =
        ref.watch(contributionRolesProvider).valueOrNull?.moderator == true;
    if (!enabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wanted lessons')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The Wanted Board is not available right now.',
              key: Key('wanted_off'),
            ),
          ),
        ),
      );
    }
    final board = _boardBody(context);
    return DefaultTabController(
      length: isModerator ? 3 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wanted lessons'),
          bottom: isModerator
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Board'),
                    Tab(key: Key('wanted_review_tab'), text: 'To review'),
                    Tab(key: Key('wanted_priority_tab'), text: 'Priority'),
                  ],
                )
              : null,
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('wanted_propose'),
          onPressed: _busy ? null : _propose,
          icon: const Icon(Icons.add),
          label: const Text('Ask for a lesson'),
        ),
        body: isModerator
            ? TabBarView(
                children: [board, const _WantedReviewTab(), const _WantedPriorityTab()],
              )
            : board,
      ),
    );
  }

  Widget _boardBody(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: TextButton(
          key: const Key('wanted_retry'),
          onPressed: _load,
          child: Text(
            _error is WantedBoardException
                ? '${(_error as WantedBoardException).message} Retry'
                : 'Could not load. Retry',
          ),
        ),
      );
    }
    final needs = _needs;
    if (needs == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Text(
            'Lessons learners would like. Anyone can make one and share it '
            'for review. Requests show topics only, never who asked.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (needs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text('No requests yet.', key: Key('wanted_empty')),
              ),
            ),
          for (final n in needs)
            Card(
              key: Key('wanted_need_${n.id}'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: theme.textTheme.titleSmall),
                    if (n.details != null) Text(n.details!),
                    const SizedBox(height: 4),
                    Text(
                      '${n.demand}'
                      '${n.subjectTag == null ? '' : ' · ${n.subjectTag}'}'
                      '${n.linked == 0 ? '' : ' · ${n.linked} lesson(s) in progress'}',
                      key: Key('wanted_demand_${n.id}'),
                      style: theme.textTheme.bodySmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          key: Key('wanted_vote_${n.id}'),
                          label: const Text('I need this too'),
                          selected: n.hasVoted,
                          onSelected: _busy
                              ? null
                              : (v) => _run(
                                  () => _service.vote(n.id, v),
                                  v ? 'Added your vote.' : 'Vote removed.',
                                ),
                        ),
                        TextButton(
                          key: Key('wanted_fulfil_${n.id}'),
                          onPressed: _busy ? null : () => _fulfil(n),
                          child: const Text("I'll make it"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Moderator review: approve or reject proposals; fulfil or close open
/// needs. The server re-checks the role and every rule.
class _WantedReviewTab extends ConsumerStatefulWidget {
  const _WantedReviewTab();

  @override
  ConsumerState<_WantedReviewTab> createState() => _WantedReviewTabState();
}

class _WantedReviewTabState extends ConsumerState<_WantedReviewTab> {
  List<WantedNeed>? _proposed;
  List<WantedNeed>? _open;
  Map<String, List<LinkableContribution>> _links = const {};
  Object? _error;

  WantedBoardService get _service => ref.read(wantedBoardServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final proposed = await _service.needsWithStatus('proposed');
      final open = await _service.needsWithStatus('open');
      final links = await _service.linksFor([for (final n in open) n.id]);
      final byNeed = <String, List<LinkableContribution>>{};
      for (final l in links) {
        byNeed.putIfAbsent(l.needId, () => []).add(l.contribution);
      }
      if (!mounted) return;
      setState(() {
        _proposed = proposed;
        _open = open;
        _links = byNeed;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<String?> _note(String title, {required bool required}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('wanted_note'),
          controller: c,
          maxLength: 1000,
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
            key: const Key('wanted_note_confirm'),
            onPressed: () => Navigator.of(context).pop(c.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _act(Future<void> Function() f, String done) async {
    try {
      await f();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on WantedBoardException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    final proposed = _proposed;
    final open = _open;
    if (proposed == null || open == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Waiting for review', style: theme.textTheme.titleMedium),
        if (proposed.isEmpty) const Text('Nothing to review.'),
        for (final n in proposed)
          Card(
            key: Key('wanted_proposed_${n.id}'),
            child: ListTile(
              title: Text(n.title),
              subtitle: Text(
                [n.details, n.subjectTag].whereType<String>().join(' · '),
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    key: Key('wanted_approve_${n.id}'),
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check),
                    onPressed: () => _act(
                      () => _service.review(n.id, approve: true),
                      'Approved. It is on the board now.',
                    ),
                  ),
                  IconButton(
                    key: Key('wanted_reject_${n.id}'),
                    tooltip: 'Reject',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      final note = await _note('Reject', required: true);
                      if (note == null) return;
                      await _act(
                        () => _service.review(n.id, approve: false, note: note),
                        'Rejected.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text('Open requests', style: theme.textTheme.titleMedium),
        if (open.isEmpty) const Text('No open requests.'),
        for (final n in open)
          Card(
            key: Key('wanted_open_${n.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title, style: theme.textTheme.titleSmall),
                  for (final c
                      in _links[n.id] ?? const <LinkableContribution>[])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.title),
                      subtitle: Text(c.isPublished ? 'Published' : c.status),
                      trailing: c.isPublished
                          ? TextButton(
                              key: Key('wanted_fulfilled_${n.id}_${c.id}'),
                              onPressed: () => _act(
                                () => _service.setStatus(
                                  n.id,
                                  'fulfilled',
                                  contributionId: c.id,
                                ),
                                'Marked as fulfilled.',
                              ),
                              child: const Text('Fulfilled by this'),
                            )
                          : null,
                    ),
                  TextButton(
                    key: Key('wanted_close_${n.id}'),
                    onPressed: () async {
                      final note = await _note(
                        'Close request',
                        required: false,
                      );
                      if (note == null) return;
                      await _act(
                        () => _service.setStatus(n.id, 'closed', note: note),
                        'Closed.',
                      );
                    },
                    child: const Text('Close request'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Maintainer seeding list (plan v2.6 §6.5): open needs by reuse-value
/// priority, with the terms behind each score. Moderators only; learners
/// never see a score, only the board's order.
class _WantedPriorityTab extends ConsumerWidget {
  const _WantedPriorityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return FutureBuilder<List<WantedPriority>>(
      future: ref.read(wantedBoardServiceProvider).priorityList(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return const Center(child: Text('Could not load the priority list.'));
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return const Center(child: Text('No open needs.'));
        }
        return ListView(
          key: const Key('wanted_priority_list'),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Ordered by reuse value: places it would serve × request boost × '
              'how uncovered it is. A work order for seeding, not a quality '
              'judgement.',
              style: theme.textTheme.bodySmall,
            ),
            for (final r in rows)
              ListTile(
                key: Key('wanted_priority_${r.id}'),
                title: Text(r.title),
                subtitle: Text(r.explanation),
                trailing: Text(r.priority.toStringAsFixed(2)),
              ),
          ],
        );
      },
    );
  }
}
