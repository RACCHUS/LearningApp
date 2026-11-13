import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/lesson_contribution_provider.dart';
import 'package:learning_pwa/services/community/lesson_contribution_service.dart';

/// Library entry for community lessons. Shown only when
/// `content.public_contribution` is on.
class CommunityLessonsEntry extends ConsumerWidget {
  const CommunityLessonsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(publicContributionEnabledProvider)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Lessons shared by other learners (unreviewed)',
        child: OutlinedButton.icon(
          key: const Key('library-community'),
          onPressed: () => context.push('/community/lessons'),
          icon: const Icon(Icons.groups_outlined),
          label: const Text('Community'),
        ),
      ),
    );
  }
}

final _publishedProvider =
    FutureProvider.autoDispose<List<ContributionQueueItem>>(
      (ref) => ref.watch(lessonContributionServiceProvider).listPublished(),
    );

/// Browse published community lessons (master plan v2.6 §8.6: separate,
/// clearly labelled unverified community resources, with reporting).
class CommunityLessonsScreen extends ConsumerWidget {
  const CommunityLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(publicContributionEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Community lessons')),
      body: !enabled
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Community lessons are not available right now.',
                  key: Key('community_lessons_off'),
                ),
              ),
            )
          : ref
                .watch(_publishedProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(_publishedProvider),
                      child: const Text('Could not load. Retry'),
                    ),
                  ),
                  data: (items) => ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Text(
                        'Shared by learners and checked automatically, but '
                        'not reviewed for accuracy. Practice here does not '
                        'count as progress.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(
                            child: Text('No community lessons yet.'),
                          ),
                        ),
                      for (final item in items)
                        Card(
                          key: Key('community_lesson_${item.id}'),
                          child: ListTile(
                            title: Text(item.title),
                            subtitle: Text(
                              'Community · unreviewed · ${item.license}'
                              '${item.aiAssisted ? ' · AI-assisted' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CommunityLessonReaderScreen(item: item),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// Read-only view of one published snapshot. Contributor text is shown as
/// plain text only.
class CommunityLessonReaderScreen extends ConsumerStatefulWidget {
  const CommunityLessonReaderScreen({super.key, required this.item});

  final ContributionQueueItem item;

  @override
  ConsumerState<CommunityLessonReaderScreen> createState() =>
      _CommunityLessonReaderScreenState();
}

class _CommunityLessonReaderScreenState
    extends ConsumerState<CommunityLessonReaderScreen> {
  final Set<int> _revealed = {};

  static const _reasons = {
    'misinformation': 'Wrong or misleading',
    'copyright': 'Copied without permission',
    'inappropriate': 'Inappropriate',
    'spam': 'Spam',
    'minor_safety': 'Unsafe for children',
    'other': 'Something else',
  };

  Future<void> _report() async {
    var reason = 'misinformation';
    final details = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Report this lesson'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                key: const Key('report_reason'),
                value: reason,
                isExpanded: true,
                items: [
                  for (final e in _reasons.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setLocal(() => reason = v ?? reason),
              ),
              TextField(
                key: const Key('report_details'),
                controller: details,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What is wrong? (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('report_send'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    String message;
    try {
      await ref
          .read(lessonContributionServiceProvider)
          .report(
            widget.item.id,
            reason,
            description: details.text.trim().isEmpty
                ? null
                : details.text.trim(),
          );
      message = 'Thanks. A moderator will look at it.';
    } on ContributionException catch (e) {
      message = e.message;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('community_report'),
            tooltip: 'Report this lesson',
            icon: const Icon(Icons.flag_outlined),
            onPressed: _report,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Community · unreviewed · ${item.license}'
            '${item.aiAssisted ? ' · AI-assisted' : ''}. '
            'Not checked for accuracy, and not counted as progress.',
            key: const Key('community_label'),
            style: theme.textTheme.bodySmall,
          ),
          if (item.terms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Key terms', style: theme.textTheme.titleMedium),
            for (final t in item.terms)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${t['term']}: ${t['definition']}'),
              ),
          ],
          if (item.concepts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ideas', style: theme.textTheme.titleMedium),
            for (final c in item.concepts)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${c['concept_text']}'
                  '${c['example_text'] == null ? '' : '\n${c['example_text']}'}',
                ),
              ),
          ],
          if (item.questions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Questions', style: theme.textTheme.titleMedium),
            for (final (i, q) in item.questions.indexed)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${q['question_text']}'),
                      for (final (j, o)
                          in ((q['options'] as List?) ?? const []).indexed)
                        Text(
                          '${_revealed.contains(i) && j == q['correct_answer'] ? '✓' : '·'} $o',
                        ),
                      if (_revealed.contains(i) && q['explanation'] != null)
                        Text('Why: ${q['explanation']}'),
                      TextButton(
                        key: Key('community_reveal_$i'),
                        onPressed: () => setState(
                          () => _revealed.contains(i)
                              ? _revealed.remove(i)
                              : _revealed.add(i),
                        ),
                        child: Text(
                          _revealed.contains(i) ? 'Hide answer' : 'Show answer',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'Shared under ${item.license} by a LearningApp learner.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
