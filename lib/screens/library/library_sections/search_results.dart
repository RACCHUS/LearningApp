part of '../library_screen.dart';

// Multi-entity search results with disambiguation tags (§11.1, §11.2).
// Moved unchanged from LibraryScreen.build (code-efficiency plan §14,
// Phase 2): the 804-line build now computes the results once and hands
// each section exactly the values it reads.
extension _LibrarySearchResults on _LibraryScreenState {
  List<Widget> _searchResults({
    required ThemeData theme,
    required LearningContext? activeContext,
    required List<BaseLesson> lessons,
    required TargetType? targetTypeFilter,
    required List<LearningTarget> targets,
    required List<Course> courses,
    required List<KnowledgeConcept> concepts,
    required bool effectiveScoped,
    required bool showWordsResult,
    required int totalSearchResults,
  }) {
    return [
      // MULTI-ENTITY SEARCH RESULTS WITH DISAMBIGUATION TAGS (§11.1 & §11.2)
      _SectionHeader('Search Results', trailing: '$totalSearchResults'),
      if (totalSearchResults == 0) ...[
        _EmptyHint(
          effectiveScoped
              ? 'Nothing found for "${_query.trim()}" within "${activeContext!.label}".'
              : 'Nothing found for "${_query.trim()}".',
        ),
        Wrap(
          spacing: DesignTokens.space2,
          runSpacing: DesignTokens.space2,
          children: [
            FilledButton.tonalIcon(
              key: const Key('library-empty-search-create'),
              icon: const Icon(Icons.add),
              label: Text('Create "${_query.trim()}"'),
              onPressed: () => CreateChooserSheet.show(
                context,
                query: _query,
                initialType: targetTypeFilter,
              ),
            ),
            if (effectiveScoped)
              TextButton.icon(
                icon: const Icon(Icons.public),
                label: const Text('Search entire library'),
                onPressed: () => _update(() => _isScoped = false),
              ),
          ],
        ),
      ] else ...[
        if (showWordsResult)
          ListTile(
            key: const Key('library-search-words'),
            leading: const Icon(Icons.spellcheck),
            title: const Text('Words'),
            subtitle: const Text('Spelling practice with your own word lists'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/words'),
          ),
        // Targets
        ...targets.map(
          (t) => ListTile(
            key: Key('library-target-${t.id}'),
            leading: Text(t.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
            title: Text(t.title),
            subtitle: Text(
              '${t.disambiguationTag} · ${t.sourceLabel}',
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
                if (created != null && mounted) {
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
    ];
  }
}
