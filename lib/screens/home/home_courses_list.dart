import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Provider for user's courses
final userCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final courseService = CourseService();
  return courseService.getUserCourses();
});

/// Provider for individual course progress
final courseProgressProvider = FutureProvider.family<CourseProgress?, String>((ref, courseId) async {
  final courseService = CourseService();
  try {
    return await courseService.getCourseProgress(courseId);
  } catch (e) {
    // Return null if progress can't be loaded (e.g., not authenticated)
    return null;
  }
});

/// Shows the user's courses with progress indicators
class HomeCoursesList extends ConsumerWidget {
  const HomeCoursesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(userCoursesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return coursesAsync.when(
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load courses',
                  style: TextStyle(color: colorScheme.error)),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(userCoursesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (courses) {
        if (courses.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState(context),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: DesignTokens.space4,
              crossAxisSpacing: DesignTokens.space4,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CourseCard(course: courses[index]),
              childCount: courses.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No courses yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a course to organize your lessons',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.push('/course-management');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Course'),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  final Course course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Load actual course progress from provider
    final courseProgressAsync = ref.watch(courseProgressProvider(course.id));
    final progress = courseProgressAsync.when(
      data: (cp) => cp?.overallProgress ?? 0.0,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/courses/${course.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use LayoutBuilder to handle overflow gracefully
              final showDescription = constraints.maxHeight > 180;
              final showProgressDetails = constraints.maxHeight > 140;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Category icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(course.category)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getCategoryIcon(course.category),
                          size: 24,
                          color: _getCategoryColor(course.category),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title and category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (course.category.isNotEmpty)
                              Text(
                                course.category,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Difficulty badge
                      _DifficultyBadge(difficulty: course.difficulty),
                    ],
                  ),

                  if (showDescription) ...[
                    const SizedBox(height: 12),

                    // Description
                    if (course.description.isNotEmpty)
                      Expanded(
                        child: Text(
                          course.description,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      const Spacer(),
                  ] else
                    const Spacer(),

                  // Progress section
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showProgressDetails)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (course.estimatedHours > 0)
                              Text(
                                '${course.estimatedHours}h estimated',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (progress > 0)
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      if (showProgressDetails) const SizedBox(height: 6),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        context.push('/courses/${course.id}');
                      },
                      child: Text(progress > 0 ? 'Continue' : 'View'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'language':
        return Colors.blue;
      case 'math':
      case 'mathematics':
        return Colors.orange;
      case 'science':
        return Colors.green;
      case 'history':
        return Colors.brown;
      case 'art':
        return Colors.purple;
      case 'music':
        return Colors.pink;
      case 'programming':
      case 'technology':
        return Colors.teal;
      default:
        return Colors.indigo;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'language':
        return Icons.translate;
      case 'math':
      case 'mathematics':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'history':
        return Icons.history_edu;
      case 'art':
        return Icons.palette;
      case 'music':
        return Icons.music_note;
      case 'programming':
      case 'technology':
        return Icons.code;
      default:
        return Icons.school;
    }
  }
}

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (difficulty.toLowerCase()) {
      'beginner' => (Colors.green, 'Beginner'),
      'intermediate' => (Colors.orange, 'Intermediate'),
      'advanced' => (Colors.red, 'Advanced'),
      _ => (Colors.grey, difficulty),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
