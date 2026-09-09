import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Renders as plain text when there is only one context: a one-item dropdown
/// is noise, and implies the learner has failed to add more (spec §1.2b).
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
      return Text(
        active?.label ?? 'Learn',
        style: theme.textTheme.titleLarge,
        overflow: TextOverflow.ellipsis,
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final rows = state.contexts.take(maxRows).toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          // Up to 5 rows plus the two footer actions can exceed a short
          // viewport, so the sheet scrolls rather than overflowing.
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
                    style: Theme.of(sheetContext).textTheme.titleSmall,
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
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await ref
                          .read(learningContextsProvider.notifier)
                          .setActive(c.id);
                    },
                  ),
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
