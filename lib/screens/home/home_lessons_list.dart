import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/empty_state.dart';
import 'package:learning_pwa/widgets/lesson_card.dart';
import 'package:learning_pwa/widgets/shimmer_loading.dart';

/// Sort options for the lessons list
enum LessonSortOption {
  recent,
  alphabetical,
  alphabeticalDesc,
}

class HomeLessonsList extends ConsumerWidget {
  final AsyncValue<List<Lesson>> lessonsStream;
  final String searchQuery;
  final String? selectedTag;
  final LessonSortOption sortOption;
  final VoidCallback? onClearSearch;

  const HomeLessonsList({
    super.key,
    required this.lessonsStream,
    required this.searchQuery,
    this.selectedTag,
    this.sortOption = LessonSortOption.recent,
    this.onClearSearch,
  });

  List<Lesson> _filterAndSortLessons(List<Lesson> lessons) {
    // Filter
    var filtered = lessons.where((lesson) {
      final query = searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          lesson.title.toLowerCase().contains(query) ||
          (lesson.description?.toLowerCase() ?? '').contains(query) ||
          lesson.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchesTag =
          selectedTag == null || lesson.tags.contains(selectedTag);
      return matchesSearch && matchesTag;
    }).toList();

    // Sort
    switch (sortOption) {
      case LessonSortOption.recent:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case LessonSortOption.alphabetical:
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case LessonSortOption.alphabeticalDesc:
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return lessonsStream.when(
      data: (lessons) {
        // Empty state - no lessons at all
        if (lessons.isEmpty) {
          return SliverFillRemaining(
            child: EmptyStateWidget(
              icon: Icons.auto_stories_outlined,
              title: 'Start Your Learning Journey',
              subtitle: 'Create your first lesson or explore the community library',
              buttonLabel: 'Create Lesson',
              onButtonPressed: () => context.push('/create-lesson'),
              illustration: const EmptyStateIllustrationWidget(
                type: EmptyStateIllustration.noLessons,
              ),
            ),
          );
        }

        final filteredLessons = _filterAndSortLessons(lessons);

        // No results state - has lessons but none match filters
        if (filteredLessons.isEmpty) {
          return SliverFillRemaining(
            child: NoResultsWidget(
              searchQuery: searchQuery.isNotEmpty ? searchQuery : (selectedTag ?? 'filters'),
              onClearSearch: onClearSearch,
            ),
          );
        }

        // Responsive grid/list layout
        return SliverLayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.crossAxisExtent;
            final columns = DesignTokens.getGridColumns(width);

            if (columns == 1) {
              // Single column list
              return SliverPadding(
                padding: const EdgeInsets.only(
                  top: DesignTokens.space2,
                  bottom: DesignTokens.space4,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildLessonCard(context, ref, filteredLessons[index]),
                    childCount: filteredLessons.length,
                  ),
                ),
              );
            }

            // Multi-column grid
            return SliverPadding(
              padding: const EdgeInsets.symmetric(
                vertical: DesignTokens.space4,
                horizontal: DesignTokens.space4,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: DesignTokens.space3,
                  crossAxisSpacing: DesignTokens.space3,
                  mainAxisExtent: 180, // Increased card height for grid to prevent overflow
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLessonCard(
                    context, 
                    ref, 
                    filteredLessons[index],
                    isGridItem: true,
                  ),
                  childCount: filteredLessons.length,
                ),
              ),
            );
          },
        );
      },
      
      // Loading state with skeleton cards
      loading: () => const LessonListSkeleton(itemCount: 4),
      
      // Error state
      error: (error, stackTrace) => SliverFillRemaining(
        child: _buildErrorState(context, error),
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context, 
    WidgetRef ref, 
    Lesson lesson, {
    bool isGridItem = false,
  }) {
    return LessonCard(
      lesson: lesson,
      onDelete: () => _handleDelete(context, ref, lesson),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, Lesson lesson) async {
    try {
      final lessonService = LessonService();
      await lessonService.deleteLessonFromSupabase(lesson.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${lesson.title}"'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting lesson: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            Text(
              'Error loading lessons',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            Text(
              error.toString(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
