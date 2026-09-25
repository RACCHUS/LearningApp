import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/account_actions.dart';

/// Where choice expands. Higher information density is correct here: the user
/// came to browse and manage.
///
/// Informational counts are allowed on this screen — the badge ban applies to
/// top-level navigation controls only (spec B3).
class LibraryScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const LibraryScreen({super.key, this.initialQuery});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery ?? '');
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contexts = ref.watch(learningContextsProvider);
    final catalogAsync = ref.watch(availableLessonsCatalogProvider);
    final catalog = catalogAsync.valueOrNull;
    final lessons = (catalog?.lessons ?? const [])
        .where((l) =>
            _query.isEmpty ||
            l.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: const [AccountActions()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          TextField(
            key: const Key('library-search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search lessons, courses, study sets',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: DesignTokens.space5),
          _SectionHeader('Your learning'),
          if (contexts.error != null)
            _InlineError(
              message: contexts.error!,
              onRetry: () =>
                  ref.read(learningContextsProvider.notifier).load(),
            )
          else if (contexts.contexts.isEmpty)
            const _EmptyHint('Nothing yet. Start something below.')
          else
            ...contexts.contexts.map(
              (c) => ListTile(
                key: Key('library-context-${c.id}'),
                leading: Text(c.emoji ?? '📘',
                    style: const TextStyle(fontSize: 20)),
                title: Text(c.label),
                subtitle: Text(c.rootType.name),
                trailing: c.isPinned ? const Icon(Icons.push_pin, size: 18) : null,
                onTap: () async {
                  await ref
                      .read(learningContextsProvider.notifier)
                      .setActive(c.id);
                  if (context.mounted) context.go('/learn');
                },
              ),
            ),
          const SizedBox(height: DesignTokens.space5),
          _SectionHeader('Discover', trailing: '${lessons.length}'),
          if (catalogAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(DesignTokens.space5),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (catalogAsync.hasError)
            _InlineError(
              message: 'Could not load lessons.',
              onRetry: () => ref.invalidate(availableLessonsCatalogProvider),
            )
          else ...[
            if (catalog?.hasRemoteError ?? false)
              _InlineWarning(
                message:
                    'Online lessons could not be loaded. Showing saved and built-in lessons.',
                onRetry: () {
                  ref.invalidate(remoteCatalogLessonsProvider);
                  ref.invalidate(availableLessonsCatalogProvider);
                },
              ),
            if (lessons.isEmpty)
              const _EmptyHint(
                'No lessons match. Try a different search, or create one below.',
              )
            else
              ...lessons.take(50).map(
                    (l) => ListTile(
                      key: Key('library-lesson-${l.id}'),
                      title: Text(l.title),
                      subtitle: Text(
                        l.description ?? 'No description',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        child: const Text('Start learning'),
                        onPressed: () async {
                          final created = await ref
                              .read(learningContextsProvider.notifier)
                              .add(
                                label: l.title,
                                rootType: ContextRootType.lesson,
                                rootId: l.id,
                                emoji: l.emoji,
                              );
                          if (created != null && context.mounted) {
                            context.go('/learn');
                          }
                        },
                      ),
                      onTap: () => context.push('/lesson/${l.id}'),
                    ),
                  ),
          ],
          const SizedBox(height: DesignTokens.space5),
          _SectionHeader('Create'),
          Wrap(
            spacing: DesignTokens.space3,
            runSpacing: DesignTokens.space2,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.style_outlined),
                label: const Text('Study set'),
                onPressed: () => context.push('/content-picker'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Lesson'),
                onPressed: () => context.push('/create-lesson'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Import'),
                onPressed: () => context.push('/create-lesson?tab=json'),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space5),
          _SectionHeader('More'),
          ListTile(
            title: const Text('Courses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/course-management'),
          ),
          ListTile(
            title: const Text('Study sets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/study-sets'),
          ),
          ListTile(
            title: const Text('Paths'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/careers'),
          ),
          Text(
            'Library',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space2),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (trailing != null) ...[
            const SizedBox(width: DesignTokens.space2),
            Text(
              trailing!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space3),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space3),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineWarning({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: DesignTokens.space2),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
