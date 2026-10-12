import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Renders as plain text when there is only one context: a one-item dropdown
/// is noise, and implies the learner has failed to add more (spec §1.2b).
/// Allows managing, pausing, resuming, or removing goals.
class ContextSwitcher extends ConsumerWidget {
  final LearningContextsState state;

  /// Rows shown before folding into "Browse all learning".
  static const int maxRows = 5;

  const ContextSwitcher({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = state.active;

    if (!state.showSwitcherControl) {
      if (active == null) {
        return Text(
          'Learn',
          style: theme.textTheme.titleLarge,
          overflow: TextOverflow.ellipsis,
        );
      }
      return InkWell(
        key: const Key('active-goal-header'),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        onTap: () => _openGoalOptions(context, ref, active),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space2,
            vertical: DesignTokens.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  active.label,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: DesignTokens.space1),
              Icon(
                Icons.more_horiz,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      key: const Key('context-switcher'),
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      onTap: () => _open(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space2,
          vertical: DesignTokens.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                active?.label ?? 'Learn',
                style: theme.textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: DesignTokens.space1),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _openGoalOptions(
    BuildContext context,
    WidgetRef ref,
    LearningContext target,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.space4,
                    0,
                    DesignTokens.space4,
                    DesignTokens.space2,
                  ),
                  child: Row(
                    children: [
                      Text(
                        target.emoji ?? _fallbackEmoji(target.rootType),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: DesignTokens.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Progress is saved where you left off',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('Pause & Archive Goal'),
                  subtitle: const Text('Save your place and pick up anytime'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(learningContextsProvider.notifier)
                        .archive(target.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.clear_all),
                  title: const Text('Clear active goal'),
                  subtitle: const Text('Return to general learn view'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(learningContextsProvider.notifier)
                        .clearActive();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    'Remove Goal',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  subtitle: const Text('Remove from your learning list'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await ref
                        .read(learningContextsProvider.notifier)
                        .delete(target.id);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('browse-all-learning'),
                  leading: const Icon(Icons.library_books_outlined),
                  title: const Text('Browse all learning'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/library');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final rows = state.contexts.take(maxRows).toList();
    final archived = state.archivedContexts;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DesignTokens.space4,
                    0,
                    DesignTokens.space4,
                    DesignTokens.space2,
                  ),
                  child: Text(
                    'Your learning',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                for (final c in rows)
                  ListTile(
                    key: Key('context-row-${c.id}'),
                    leading: Text(
                      c.emoji ?? _fallbackEmoji(c.rootType),
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(c.label),
                    subtitle: Text(_relative(c.lastActiveAt)),
                    selected: c.id == state.activeId,
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      tooltip: 'Goal options',
                      onSelected: (val) async {
                        if (val == 'archive') {
                          Navigator.of(sheetContext).pop();
                          await ref
                              .read(learningContextsProvider.notifier)
                              .archive(c.id);
                        } else if (val == 'delete') {
                          Navigator.of(sheetContext).pop();
                          await ref
                              .read(learningContextsProvider.notifier)
                              .delete(c.id);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              Icon(Icons.pause_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Pause / Archive Goal'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: theme.colorScheme.error),
                              const SizedBox(width: 8),
                              Text('Remove Goal',
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref
                          .read(learningContextsProvider.notifier)
                          .setActive(c.id);
                    },
                  ),
                if (state.activeId != null && state.activeId!.isNotEmpty) ...[
                  ListTile(
                    leading: const Icon(Icons.clear_all, size: 20),
                    title: const Text('Clear active goal'),
                    subtitle: const Text('Return to general dashboard'),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref
                          .read(learningContextsProvider.notifier)
                          .clearActive();
                    },
                  ),
                ],
                if (archived.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DesignTokens.space4,
                      DesignTokens.space3,
                      DesignTokens.space4,
                      DesignTokens.space1,
                    ),
                    child: Text(
                      'Paused & Completed Goals (${archived.length})',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  for (final c in archived)
                    ListTile(
                      key: Key('archived-row-${c.id}'),
                      leading: Text(
                        c.emoji ?? _fallbackEmoji(c.rootType),
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(c.label),
                      subtitle: const Text('Progress saved where you left off'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            child: const Text('Resume'),
                            onPressed: () async {
                              Navigator.of(sheetContext).pop();
                              await ref
                                  .read(learningContextsProvider.notifier)
                                  .unarchive(c.id);
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: 'Options',
                            onSelected: (val) async {
                              if (val == 'delete') {
                                Navigator.of(sheetContext).pop();
                                await ref
                                    .read(learningContextsProvider.notifier)
                                    .delete(c.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete saved goal',
                                    style: TextStyle(
                                        color: theme.colorScheme.error)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
                const Divider(height: 1),
                ListTile(
                  key: const Key('browse-all-learning'),
                  title: const Text('Browse all learning'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/library');
                  },
                ),
                ListTile(
                  key: const Key('add-something'),
                  leading: const Icon(Icons.add),
                  title: const Text('Add something'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.go('/library');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fallbackEmoji(ContextRootType type) => switch (type) {
        ContextRootType.target => '🎯',
        ContextRootType.concept => '💡',
        ContextRootType.path => '🧭',
        ContextRootType.course => '📘',
        ContextRootType.module => '📗',
        ContextRootType.lesson => '📄',
        ContextRootType.studySet => '🃏',
      };

  static String _relative(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 14) return 'last week';
    if (days < 60) return '${(days / 7).floor()} weeks ago';
    return '${(days / 30).floor()} months ago';
  }
}
