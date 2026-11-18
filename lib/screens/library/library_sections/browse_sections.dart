part of '../library_screen.dart';

// Normal browsing mode: your learning, knowledge clusters, targets, more.
// Moved unchanged from LibraryScreen.build (code-efficiency plan §14,
// Phase 2): the 804-line build now computes the results once and hands
// each section exactly the values it reads.
extension _LibraryBrowseSections on _LibraryScreenState {
  List<Widget> _browseSections({
    required ThemeData theme,
    required LearningContextsState contexts,
    required AsyncValue<AvailableLessonsCatalog> catalogAsync,
    required AvailableLessonsCatalog? catalog,
    required List<BaseLesson> lessons,
    required List<LearningTarget> targets,
  }) {
    return [
      // NORMAL BROWSING MODE
      _SectionHeader('Your learning'),
      if (contexts.error != null)
        _InlineError(
          message: contexts.error!,
          onRetry: () =>
              ref.read(learningContextsProvider.notifier).load(),
        )
      else if (contexts.contexts.isEmpty)
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No active learning tracks',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Pick a goal or lesson below, or use Create to make your own.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
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
              if (mounted) context.go('/learn');
            },
          ),
        ),
      const SizedBox(height: DesignTokens.space5),

      if (_selectedCategory != 'course') ...[
        // Knowledge Clusters Section (CIP / Canonical Field Domains)
        Consumer(
          builder: (context, ref, _) {
            final clustersAsync = ref.watch(catalogClustersProvider);
            final clusterCount = clustersAsync.valueOrNull?.length ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            _SectionHeader(
              'Explore Domains & Fields',
              trailing: clusterCount == 0
                  ? null
                  : '$clusterCount ${clusterCount == 1 ? 'Domain' : 'Domains'}',
            ),
            const SizedBox(height: DesignTokens.space2),
            clustersAsync.when(
              data: (clusters) => SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: clusters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: DesignTokens.space2),
                  itemBuilder: (context, idx) {
                    final c = clusters[idx];
                    return InkWell(
                      onTap: () => _showClusterDetailsModal(context, c),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(DesignTokens.space3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c.emoji ?? '🌐', style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 6),
                            Text(
                              c.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
              ],
            );
          },
        ),
        const SizedBox(height: DesignTokens.space4),
      ],

      // Learning Targets Section
      _SectionHeader(
        'Learning Goals & Targets',
        trailing: targets.isNotEmpty ? '${targets.length}' : null,
      ),
      if (targets.isEmpty)
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.track_changes, color: theme.colorScheme.secondary),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCategory != null
                            ? 'No ${_selectedCategory!.replaceAll('_', ' ')} goals yet'
                            : 'No learning goals yet',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _source == CatalogSource.trusted
                            ? 'Try another source or category, or use Create to set up your own.'
                            : 'Try the Trusted catalog source, or use Create to set up your own.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
      else
        ...targets.take(6).map(
          (t) => ListTile(
            key: Key('library-target-${t.id}'),
            leading: Text(t.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
            title: Text(t.title),
            subtitle: Text('${t.disambiguationTag} · ${t.sourceLabel}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuickOverviewEntry(
                  targetId: t.id,
                  targetSlug: t.slug,
                  compact: true,
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.push('/target/${t.id}'),
          ),
        ),
      const SizedBox(height: DesignTokens.space5),

      if (_selectedCategory == null || _selectedCategory == 'course') ...[
        _SectionHeader(
          'Discover Lessons',
          trailing: '${lessons.length}',
        ),
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
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.space2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.auto_stories_outlined, color: theme.colorScheme.tertiary),
                    ),
                    const SizedBox(width: DesignTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No lessons available',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Use Create to write your own lesson or import one.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                        if (created != null && mounted) {
                          context.go('/learn');
                        }
                      },
                    ),
                    onTap: () => context.push('/lesson/${l.id}'),
                  ),
                ),
        ],
        const SizedBox(height: DesignTokens.space5),
      ],
      _SectionHeader('More'),
      ListTile(
        title: const Text('Career pathways & official classifications'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/taxonomy'),
      ),
      if (_selectedCategory != 'milestones')
        ListTile(
          title: const Text('Life milestones & literacy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/milestones'),
        ),
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
    ];
  }
}
