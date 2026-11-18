import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/catalog_cluster.dart';
import 'package:learning_pwa/providers/canonical_taxonomy_provider.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/providers/scope_resolver_provider.dart';
import 'package:learning_pwa/screens/community/community_lessons_screen.dart';
import 'package:learning_pwa/screens/home/home_courses_list.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/account_actions.dart';
import 'package:learning_pwa/widgets/help/help_action.dart';
import 'package:learning_pwa/widgets/literacy/life_milestones_banner_card.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_picture_grid_widget.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/widgets/library/create_chooser_sheet.dart';
import 'package:learning_pwa/widgets/library/quick_overview_entry.dart';
import 'package:learning_pwa/screens/library/catalog_source.dart';

part 'library_sections/category_chips.dart';
part 'library_sections/search_results.dart';
part 'library_sections/browse_sections.dart';

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
  Timer? _searchDebounce;
  String? _selectedCategory;
  bool _isScoped = true;
  CatalogSource _source = CatalogSource.trusted;

  /// For the section extensions in library_sections/ (they may not
  /// call the protected setState directly).
  void _update(VoidCallback fn) => setState(fn);

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
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Searches launched from the desktop sidebar update this existing page.
    if (widget.initialQuery != oldWidget.initialQuery) {
      _searchDebounce?.cancel();
      _search.text = widget.initialQuery ?? '';
      _query = widget.initialQuery ?? '';
      _isScoped = false;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || _query == value) return;
      setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contexts = ref.watch(learningContextsProvider);
    final activeContext = contexts.active;
    final activeScopeAsync = ref.watch(activeResolvedScopeProvider);
    final activeScope = activeScopeAsync.valueOrNull;
    final isPreReader = ref.watch(preReaderProvider).enabled;

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
    } else if (_selectedCategory == 'course' || _selectedCategory == 'milestones') {
      targets = const [];
    }

    // Trusted catalog is the default: private or unreviewed personal targets
    // remain visible only through the explicit "My goals" choice.
    final authState = ref.watch(authProvider);
    final userId = authState is AuthSuccess ? authState.user.id : null;
    targets = targets
        .where((target) => _source.shows(target, userId: userId))
        .toList();

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
    final bool showWordsResult = isSearching && _matchesWordPractice(_query);
    final int totalSearchResults = targets.length +
        courses.length +
        lessons.length +
        concepts.length +
        (showWordsResult ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: const [AccountActions(), HelpAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Row(
            children: [
              Tooltip(
                message: 'Your spelling word lists',
                child: OutlinedButton.icon(
                  key: const Key('library-words'),
                  onPressed: () => context.go('/words'),
                  icon: const Icon(Icons.spellcheck),
                  label: const Text('Words'),
                ),
              ),
              const CommunityLessonsEntry(),
              const Spacer(),
              OutlinedButton.icon(
                key: const Key('library-create'),
                onPressed: () => CreateChooserSheet.show(
                  context,
                  query: _query,
                  initialType: targetTypeFilter,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('library-search'),
            controller: _search,
            onChanged: _onSearchChanged,
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
                        _searchDebounce?.cancel();
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

          _categoryChips(theme),
          const SizedBox(height: DesignTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<CatalogSource>(
              key: const Key('library-source-picker'),
              tooltip: 'Choose where goals come from',
              initialValue: _source,
              onSelected: (value) => setState(() => _source = value),
              itemBuilder: (context) => [
                for (final value in CatalogSource.values)
                  PopupMenuItem(
                    key: Key('library-source-${value.name}'),
                    value: value,
                    child: Text(value.label),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DesignTokens.space1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: DesignTokens.space2),
                    Text('Source: ${_source.label}', style: theme.textTheme.labelLarge),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space4),

          if (!isSearching && (isPreReader || _selectedCategory == 'milestones')) ...[
            const PreReaderPictureGridWidget(),
            const SizedBox(height: DesignTokens.space4),
          ],

          if (!isSearching && _selectedCategory == 'milestones') ...[
            const LifeMilestonesBannerCard(),
            const SizedBox(height: DesignTokens.space4),
          ],

          if (isSearching)
            ..._searchResults(
              theme: theme,
              activeContext: activeContext,
              lessons: lessons,
              targetTypeFilter: targetTypeFilter,
              targets: targets,
              courses: courses,
              concepts: concepts,
              effectiveScoped: effectiveScoped,
              showWordsResult: showWordsResult,
              totalSearchResults: totalSearchResults,
            )
          else
            ..._browseSections(
              theme: theme,
              contexts: contexts,
              catalogAsync: catalogAsync,
              catalog: catalog,
              lessons: lessons,
              targets: targets,
            ),
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
                                _searchDebounce?.cancel();
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

const _wordPracticeTerms = ['word', 'spell', 'vocab'];

bool _matchesWordPractice(String query) {
  final q = query.trim().toLowerCase();
  if (q.length < 3) return false;
  return _wordPracticeTerms.any((term) => q.contains(term) || term.startsWith(q));
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
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
