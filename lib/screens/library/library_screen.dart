import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/catalog_cluster.dart';
import 'package:learning_pwa/providers/canonical_taxonomy_provider.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/screens/home/home_courses_list.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/account_actions.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:learning_pwa/widgets/taxonomy/taxonomy_banner_card.dart';
import 'package:learning_pwa/widgets/targets/create_target_dialog.dart';

/// Where choice expands. Higher information density is correct here: the user
/// came to browse and manage.
///
/// Informational counts are allowed on this screen — the badge ban applies to
/// top-level navigation controls only (spec B3).
class LibraryScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialType;

  const LibraryScreen({super.key, this.initialQuery, this.initialType});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late final TextEditingController _search =
      TextEditingController(text: widget.initialQuery ?? '');
  String _query = '';
  String? _selectedCategory;
  bool _isScoped = true;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    if (widget.initialType == 'standardized_exam' || widget.initialType == 'licensure_exam') {
      _selectedCategory = 'exam';
    } else {
      _selectedCategory = widget.initialType;
    }
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

    TargetType? targetTypeFilter;
    if (_selectedCategory == 'career') targetTypeFilter = TargetType.career;
    if (_selectedCategory == 'certification') targetTypeFilter = TargetType.certification;
    if (_selectedCategory == 'academic_program') targetTypeFilter = TargetType.academicProgram;
    if (_selectedCategory == 'curriculum_standard') targetTypeFilter = TargetType.curriculumStandard;

    // Query targets
    final targetsAsync = ref.watch(targetsListProvider((
      type: targetTypeFilter,
      types: _selectedCategory == 'exam'
          ? const [TargetType.standardizedExam, TargetType.licensureExam]
          : null,
      search: _query.isNotEmpty ? _query : null,
    )));
    var targets = targetsAsync.valueOrNull ?? const <LearningTarget>[];

    if (_selectedCategory == 'exam' || _selectedCategory == 'standardized_exam') {
      targets = targets
          .where((t) =>
              t.targetType == TargetType.standardizedExam ||
              t.targetType == TargetType.licensureExam)
          .toList();
    } else if (_selectedCategory == 'course') {
      targets = const [];
    }

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

    // When a target destination is explicitly selected, hide lessons and courses
    if (_selectedCategory != null && _selectedCategory != 'course') {
      lessons = const [];
      courses = const [];
    }

    // Apply Contextual Scope filter if active and enabled (§11.2)
    final bool canScope = activeContext != null;
    final bool effectiveScoped = canScope && _isScoped;

    if (effectiveScoped && activeScope != null) {
      // 1. Lessons in scope: universal across all root types
      lessons = lessons.where((l) {
        if (activeContext.rootType == ContextRootType.lesson && l.id == activeContext.rootId) {
          return true;
        }
        return activeScope.includesItem(contentId: l.id, lessonId: l.id) ||
            activeScope.orderedActivities.any((a) => a.activityId == l.id);
      }).toList();

      // 2. Targets in scope
      if (activeContext.rootType == ContextRootType.target) {
        targets = targets
            .where((t) => t.id == activeContext.rootId || t.slug == activeContext.rootId)
            .toList();
      } else {
        targets = const [];
      }

      // 3. Courses in scope (including target-context course search)
      if (activeContext.rootType == ContextRootType.course) {
        courses = courses.where((c) => c.id == activeContext.rootId).toList();
      } else {
        final courseIdsInScope = activeScope.orderedActivities
            .map((a) => a.courseId)
            .whereType<String>()
            .toSet();
        courses = courses.where((c) => courseIdsInScope.contains(c.id)).toList();
      }

      // 4. Concepts in scope
      concepts = concepts.where((c) {
        if (activeContext.rootType == ContextRootType.concept && c.id == activeContext.rootId) {
          return true;
        }
        return activeScope.coreConceptIds.contains(c.id) ||
            activeScope.supportingConceptIds.contains(c.id);
      }).toList();
    }

    final bool isSearching = _query.trim().isNotEmpty;
    final int totalSearchResults =
        targets.length + courses.length + lessons.length + concepts.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: const [HelpAction(), AccountActions()],
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
          const SizedBox(height: DesignTokens.space3),

          // Destination Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  key: const Key('library-filter-all'),
                  label: const Text('All Destinations'),
                  selected: _selectedCategory == null,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-careers'),
                  avatar: const Text('💼'),
                  label: const Text('Careers'),
                  selected: _selectedCategory == 'career',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'career' : null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-certs'),
                  avatar: const Text('📜'),
                  label: const Text('Certifications'),
                  selected: _selectedCategory == 'certification',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'certification' : null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-exams'),
                  avatar: const Text('📝'),
                  label: const Text('Exams'),
                  selected: _selectedCategory == 'exam' || _selectedCategory == 'standardized_exam',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'exam' : null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-academics'),
                  avatar: const Text('🎓'),
                  label: const Text('Academic Programs'),
                  selected: _selectedCategory == 'academic_program',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'academic_program' : null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-standards'),
                  avatar: const Text('📋'),
                  label: const Text('Curriculum Standards'),
                  selected: _selectedCategory == 'curriculum_standard',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'curriculum_standard' : null);
                  },
                ),
                const SizedBox(width: DesignTokens.space2),
                FilterChip(
                  key: const Key('library-filter-courses'),
                  avatar: const Text('📚'),
                  label: const Text('Courses & Lessons'),
                  selected: _selectedCategory == 'course',
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? 'course' : null);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          if (!isSearching) ...[
            const TaxonomyBannerCard(),
            const SizedBox(height: DesignTokens.space4),
          ],

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
            _SectionHeader(
              'Your learning',
              action: TextButton.icon(
                onPressed: () => CreateTargetDialog.show(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Goal'),
              ),
            ),
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
                              'Set up a learning destination or pick a lesson below.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => CreateTargetDialog.show(context),
                        child: const Text('Create Goal'),
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
                    if (context.mounted) context.go('/learn');
                  },
                ),
              ),
            const SizedBox(height: DesignTokens.space5),

            if (_selectedCategory != 'course') ...[
              // Knowledge Clusters Section (CIP / Canonical Field Domains)
              _SectionHeader('Explore Domains & Fields', trailing: '12 Domains'),
              const SizedBox(height: DesignTokens.space2),
              Consumer(
                builder: (context, ref, _) {
                  final clustersAsync = ref.watch(catalogClustersProvider);
                  return clustersAsync.when(
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
                  );
                },
              ),
              const SizedBox(height: DesignTokens.space4),
            ],

            // Learning Targets Section
            _SectionHeader(
              'Learning Goals & Targets',
              trailing: targets.isNotEmpty ? '${targets.length}' : null,
              action: TextButton.icon(
                onPressed: () => CreateTargetDialog.show(context, initialType: targetTypeFilter),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Goal'),
              ),
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
                              'Set up a career, cert, or exam target to track your mastery.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => CreateTargetDialog.show(context, initialType: targetTypeFilter),
                        child: const Text('Create Goal'),
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
                  subtitle: Text(t.disambiguationTag),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/target/${t.id}'),
                ),
              ),
            const SizedBox(height: DesignTokens.space5),

            if (_selectedCategory == null || _selectedCategory == 'course') ...[
              _SectionHeader(
                'Discover Lessons',
                trailing: '${lessons.length}',
                action: TextButton.icon(
                  onPressed: () => context.push('/create-lesson'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Lesson'),
                ),
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
                                  'Create a lesson or generate curriculum with AI.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => context.push('/create-lesson'),
                            child: const Text('Create Lesson'),
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
            ],
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

  void _showClusterDetailsModal(BuildContext context, CatalogCluster cluster) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
      ),
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final fieldsAsync = ref.watch(clusterFieldsProvider(cluster.id));
                final targetsAsync = ref.watch(clusterTargetsProvider(cluster.id));
                final theme = Theme.of(context);

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(DesignTokens.space4),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space3),
                    Row(
                      children: [
                        Text(cluster.emoji ?? '🌐', style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: DesignTokens.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cluster.title,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (cluster.description != null)
                                Text(
                                  cluster.description!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: DesignTokens.space5),
                    Text(
                      'Learning Targets in this Domain',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: DesignTokens.space2),
                    targetsAsync.when(
                      data: (targets) {
                        if (targets.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
                            child: Text(
                              'No learning targets linked to this cluster yet.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: targets.map((t) => ListTile(
                            leading: Text(t.emoji ?? '🎯', style: const TextStyle(fontSize: 20)),
                            title: Text(t.title),
                            subtitle: Text(t.disambiguationTag),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(modalContext);
                              context.push('/target/${t.id}');
                            },
                          )).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(DesignTokens.space3),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Text('Error loading targets: $err'),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    Text(
                      'Canonical Fields (CIP Series & Programs)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: DesignTokens.space2),
                    fieldsAsync.when(
                      data: (fields) {
                        if (fields.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
                            child: Text(
                              'No canonical fields found.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: fields.map((f) => ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                f.slug.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(f.name),
                            subtitle: f.description != null ? Text(f.description!, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                            trailing: Text(
                              f.fieldKind.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(modalContext);
                              setState(() {
                                _search.text = f.name;
                                _query = f.name;
                              });
                            },
                          )).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(DesignTokens.space3),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Text('Error loading fields: $err'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? action;
  const _SectionHeader(this.title, {this.trailing, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space2),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (trailing != null) ...[
            const SizedBox(width: DesignTokens.space2),
            Text(
              trailing!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const Spacer(),
          if (action != null) action!,
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
