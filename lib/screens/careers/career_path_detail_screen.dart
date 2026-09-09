import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/career_path.dart';
import '../../providers/career_path_provider.dart';
import '../../services/career_path_service.dart';

/// Detail screen for a single career path
class CareerPathDetailScreen extends ConsumerWidget {
  final String pathId;

  const CareerPathDetailScreen({super.key, required this.pathId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(careerPathProvider(pathId));
    final progressAsync = ref.watch(careerPathProgressProvider(pathId));
    final userPaths = ref.watch(userCareerPathsProvider);

    return pathAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (path) {
        final isEnrolled = userPaths.maybeWhen(
          data: (paths) => paths.any((p) => p.careerPathId == pathId),
          orElse: () => false,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(path.title),
                  background: path.imageUrl != null
                      ? Image.network(
                          path.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderBackground(path),
                        )
                      : _buildPlaceholderBackground(path),
                ),
                actions: [
                  if (path.createdBy != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.push('/careers/${path.id}/edit'),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Row(
                        children: [
                          if (path.isOfficial)
                            _Badge(
                              icon: Icons.verified,
                              label: 'Official',
                              color: Colors.blue,
                            ),
                          if (path.isFeatured)
                            _Badge(
                              icon: Icons.star,
                              label: 'Featured',
                              color: Colors.amber,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      if (path.description != null) ...[
                        Text(
                          path.description!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Stats
                      Row(
                        children: [
                          _StatCard(
                            icon: Icons.schedule,
                            value: '${path.estimatedMonths}',
                            label: 'Months',
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.school,
                            value: '${path.courses?.length ?? 0}',
                            label: 'Courses',
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.psychology,
                            value: '${path.skills?.length ?? 0}',
                            label: 'Skills',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Progress (if enrolled)
                      if (isEnrolled)
                        progressAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox(),
                          data: (progress) => _ProgressCard(progress: progress),
                        ),

                      const SizedBox(height: 24),

                      // Skills section
                      if (path.skills?.isNotEmpty ?? false) ...[
                        const Text(
                          'Skills You\'ll Learn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: path.skills!.map((skillLink) {
                            return ActionChip(
                              avatar: Icon(
                                _getImportanceIcon(skillLink.importance),
                                size: 16,
                              ),
                              label: Text(skillLink.skill?.name ?? 'Skill'),
                              onPressed: () => context.push(
                                  '/skills/${skillLink.skill?.slug ?? skillLink.skillId}'),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Courses section
                      const Text(
                        'Course Curriculum',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Course list
              if (path.courses?.isNotEmpty ?? false)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final courseLink = path.courses![index];
                      return _CourseListItem(
                        courseLink: courseLink,
                        index: index + 1,
                      );
                    },
                    childCount: path.courses!.length,
                  ),
                )
              else
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No courses added yet'),
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isEnrolled
                  ? OutlinedButton.icon(
                      onPressed: () => _showLeaveDialog(context, ref, path),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Leave Path'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _enroll(context, ref, pathId),
                      icon: const Icon(Icons.add),
                      label: const Text('Start This Career Path'),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderBackground(CareerPath path) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.purple.shade700,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.route, size: 64, color: Colors.white24),
      ),
    );
  }

  IconData _getImportanceIcon(SkillImportance importance) {
    switch (importance) {
      case SkillImportance.core:
        return Icons.star;
      case SkillImportance.recommended:
        return Icons.thumb_up;
      case SkillImportance.optional:
        return Icons.add_circle_outline;
    }
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref, String pathId) async {
    try {
      await ref.read(userCareerPathsProvider.notifier).enroll(pathId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enrolled successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showLeaveDialog(
      BuildContext context, WidgetRef ref, CareerPath path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Career Path?'),
        content: Text(
            'Are you sure you want to leave "${path.title}"? Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(userCareerPathsProvider.notifier).leave(path.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left career path')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 4),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final CareerPathProgress progress;

  const _ProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${progress.progressPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.progressPercent / 100,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${progress.completedCourses}/${progress.totalCourses} courses completed',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseListItem extends StatelessWidget {
  final CareerPathCourse courseLink;
  final int index;

  const _CourseListItem({
    required this.courseLink,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final course = courseLink.course;

    return ListTile(
      leading: CircleAvatar(
        child: Text('$index'),
      ),
      title: Text(course?.title ?? 'Course'),
      subtitle: courseLink.sectionTitle != null
          ? Text(courseLink.sectionTitle!)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!courseLink.isRequired)
            const Chip(
              label: Text('Optional'),
              visualDensity: VisualDensity.compact,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () =>
          context.push('/courses/${courseLink.courseId}'),
    );
  }
}
