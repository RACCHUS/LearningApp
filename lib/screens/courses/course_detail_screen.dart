import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Provider for course details with content
final courseDetailProvider =
    FutureProvider.family<CourseWithContent?, String>((ref, courseId) async {
  final courseService = CourseService();
  return courseService.getCourseWithContent(courseId);
});

/// Screen showing course details and lessons
class CourseDetailScreen extends ConsumerWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load course'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(courseDetailProvider(courseId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (courseData) {
          if (courseData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('Course not found'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return _CourseDetailContent(
            course: courseData.course,
            lessons: courseData.orderedLessons,
          );
        },
      ),
    );
  }
}

class _CourseDetailContent extends StatelessWidget {
  final Course course;
  final List<Lesson> lessons;

  const _CourseDetailContent({
    required this.course,
    required this.lessons,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        // App Bar with course image/header
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              course.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black54),
                ],
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  _getCategoryIcon(course.category),
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push('/course-management');
              },
              tooltip: 'Edit Course',
            ),
          ],
        ),

        // Course info section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and difficulty row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (course.category.isNotEmpty)
                      Chip(
                        avatar: Icon(
                          _getCategoryIcon(course.category),
                          size: 16,
                        ),
                        label: Text(course.category),
                      ),
                    _DifficultyChip(difficulty: course.difficulty),
                    Chip(
                      avatar: const Icon(Icons.menu_book, size: 16),
                      label: Text('${lessons.length} lessons'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Description
                if (course.description.isNotEmpty)
                  Text(
                    course.description,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: lessons.isEmpty
                            ? null
                            : () {
                                final idsParam =
                                    lessons.map((l) => l.id).join(',');
                                context.push('/study-set?ids=$idsParam');
                              },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Study All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          context.push('/course-management');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Lessons'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Divider
        const SliverToBoxAdapter(
          child: Divider(height: 1),
        ),

        // Lessons header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.space4,
              DesignTokens.space4,
              DesignTokens.space4,
              DesignTokens.space2,
            ),
            child: Text(
              'Lessons',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Lessons list
        if (lessons.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No lessons in this course yet',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () {
                        context.push('/course-management');
                      },
                      child: const Text('Add Lessons'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.space4,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final lesson = lessons[index];
                  return _LessonTile(
                    lesson: lesson,
                    index: index + 1,
                    onTap: () {
                      context.push('/lesson/${lesson.id}');
                    },
                  );
                },
                childCount: lessons.length,
              ),
            ),
          ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
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

class _DifficultyChip extends StatelessWidget {
  final String difficulty;

  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (difficulty.toLowerCase()) {
      'beginner' => (Colors.green, Icons.star_border),
      'intermediate' => (Colors.orange, Icons.star_half),
      'advanced' => (Colors.red, Icons.star),
      _ => (Colors.grey, Icons.help_outline),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(difficulty),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Count content
    final termCount = lesson.terms.length;
    final questionCount = lesson.questions.length;
    final conceptCount = lesson.concepts.length;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Row(
            children: [
              // Lesson number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (termCount > 0)
                          _ContentBadge(
                            icon: Icons.style,
                            count: termCount,
                            label: 'terms',
                          ),
                        if (questionCount > 0)
                          _ContentBadge(
                            icon: Icons.quiz,
                            count: questionCount,
                            label: 'questions',
                          ),
                        if (conceptCount > 0)
                          _ContentBadge(
                            icon: Icons.lightbulb,
                            count: conceptCount,
                            label: 'concepts',
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;

  const _ContentBadge({
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
