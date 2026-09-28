import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/screens/home/home_courses_list.dart';
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
  bool _isScoped = true;

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
    final activeContext = contexts.active;
    final activeScopeAsync = ref.watch(activeResolvedScopeProvider);
    final activeScope = activeScopeAsync.valueOrNull;

    final catalogAsync = ref.watch(availableLessonsCatalogProvider);
    final catalog = catalogAsync.valueOrNull;

    // Filter lessons by search query
    var lessons = (catalog?.lessons ?? const [])
        .where((l) =>
            _query.isEmpty ||
            l.title.toLowerCase().contains(_query.toLowerCase()) ||
            (l.description?.toLowerCase().contains(_query.toLowerCase()) ?? false))
        .toList();

    // Query targets
    final targetsAsync = ref.watch(targetsListProvider((
      type: null,
      search: _query.isNotEmpty ? _query : null,
    )));
    var targets = targetsAsync.valueOrNull ?? const <LearningTarget>[];

    // Query courses (when searching)
    List<Course> courses = const [];
    if (_query.isNotEmpty) {
      courses = ref.watch(searchCoursesProvider(_query)).valueOrNull ?? const [];
    }

    // Query concepts (when searching)
    List<KnowledgeConcept> concepts = const [];
    if (_query.isNotEmpty) {
      concepts = ref.watch(searchConceptsProvider(_query)).valueOrNull ?? const [];
    }

    // Apply Contextual Scope filter if active and enabled (§11.2)
    final bool canScope = activeContext != null;
    final bool effectiveScoped = canScope && _isScoped;

    if (effectiveScoped && activeScope != null) {
      // 1. Lessons in scope
      if (activeContext.rootType == ContextRootType.target) {
        lessons = lessons
            .where((l) => activeScope.orderedActivities.any((a) => a.activityId == l.id))
            .toList();
      } else if (activeContext.rootType == ContextRootType.course) {
        lessons = lessons
            .where((l) =>
                activeScope.orderedActivities.any((a) => a.activityId == l.id))
            .toList();
      } else if (activeContext.rootType == ContextRootType.lesson) {
        lessons = lessons.where((l) => l.id == activeContext.rootId).toList();
      }

      // 2. Targets in scope
      if (activeContext.rootType == ContextRootType.target) {
        targets = targets
            .where((t) => t.id == activeContext.rootId || t.slug == activeContext.rootId)
            .toList();
      } else {
        targets = const [];
      }

      // 3. Courses in scope
      if (activeContext.rootType == ContextRootType.course) {
        courses = courses.where((c) => c.id == activeContext.rootId).toList();
      }

      // 4. Concepts in scope
      concepts = concepts
          .where((c) =>
              activeScope.coreConceptIds.contains(c.id) ||
              activeScope.supportingConceptIds.contains(c.id))
          .toList();
    }

    final bool isSearching = _query.trim().isNotEmpty;
    final int totalSearchResults =
        targets.length + courses.length + lessons.length + concepts.length;

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
              hintText: 'Search targets, courses, lessons, concepts...',
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
          if (canScope) ...[
            const SizedBox(height: DesignTokens.space2),
            Wrap(
              spacing: DesignTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (effectiveScoped) ...[
                  InputChip(
                    key: const Key('library-scope-chip'),
                    avatar: Text(activeContext.emoji ?? '🎯',
                        style: const TextStyle(fontSize: 14)),
                    label: Text('In: ${activeContext.label}'),
                    selected: true,
                    onDeleted: () => setState(() => _isScoped = false),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    tooltip: 'Filtered to ${activeContext.label}',
                  ),
                  ActionChip(
                    key: const Key('library-search-all-chip'),
                    label: const Text('Search entire library'),
                    avatar: const Icon(Icons.public, size: 16),
                    onPressed: () => setState(() => _isScoped = false),
                  ),
                ] else ...[
                  ActionChip(
                    key: const Key('library-scope-chip'),
                    avatar: const Icon(Icons.filter_list, size: 16),
                    label: Text('Scope to: ${activeContext.label}'),
                    onPressed: () => setState(() => _isScoped = true),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: DesignTokens.space5),

          if (isSearching) ...[
            // MULTI-ENTITY SEARCH RESULTS WITH DISAMBIGUATION TAGS (§11.1 & §11.2)
            _SectionHeader('Search Results', trailing: '$totalSearchResults'),
            if (totalSearchResults == 0) ...[
              _EmptyHint(
                effectiveScoped
                    ? 'No results found within "${activeContext.label}".'
                    : 'No results match "$_query". Try a different search.',
              ),
              if (effectiveScoped)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.public),
                    label: const Text('Search entire library'),
                    onPressed: () => setState(() => _isScoped = false),
                  ),
                ),
            ] else ...[
              // Targets
              ...targets.map(
                (t) => ListTile(
                  key: Key('library-target-${t.id}'),
                  leading: Text(t.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
                  title: Text(t.title),
                  subtitle: Text(
                    t.disambiguationTag,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/target/${t.id}'),
                ),
              ),
              // Courses
              ...courses.map(
                (c) => ListTile(
                  key: Key('library-course-${c.id}'),
                  leading: const Text('📚', style: TextStyle(fontSize: 20)),
                  title: Text(c.title),
                  subtitle: const Text(
                    'Course',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/courses/${c.id}'),
                ),
              ),
              // Lessons
              ...lessons.take(50).map(
                (l) => ListTile(
                  key: Key('library-lesson-${l.id}'),
                  leading: Text(l.emoji ?? '📄', style: const TextStyle(fontSize: 20)),
                  title: Text(l.title),
                  subtitle: Text(
                    'Lesson${l.description != null ? ' · ${l.description}' : ''}',
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
              // Concepts
              ...concepts.map(
                (c) => ListTile(
                  key: Key('library-concept-${c.id}'),
                  leading: const Text('💡', style: TextStyle(fontSize: 20)),
                  title: Text(c.name),
                  subtitle: Text(
                    'Concept${c.description != null ? ' · ${c.description}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/concept/${c.id}'),
                ),
              ),
            ],
          ] else ...[
            // NORMAL BROWSING MODE
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

            // Learning Targets Section
            if (targets.isNotEmpty) ...[
              _SectionHeader('Learning Targets', trailing: '${targets.length}'),
              ...targets.take(6).map(
                (t) => ListTile(
                  key: Key('library-target-${t.id}'),
                  leading: Text(t.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
                  title: Text(t.title),
                  subtitle: Text(t.disambiguationTag),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/target/${t.id}'),
                ),
              ),
              const SizedBox(height: DesignTokens.space5),
            ],

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
              title: const Text('Learning Targets (Certifications & Careers)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/careers'),
            ),
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
          ],
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
