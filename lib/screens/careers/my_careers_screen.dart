import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/career_path.dart';
import '../../providers/career_path_provider.dart';

/// Screen showing user's enrolled career paths with progress
class MyCareersScreen extends ConsumerWidget {
  const MyCareersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userPathsAsync = ref.watch(userCareerPathsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Career Paths'),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore),
            tooltip: 'Browse All',
            onPressed: () => context.push('/careers'),
          ),
        ],
      ),
      body: userPathsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (enrollments) {
          if (enrollments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.school_outlined,
                        size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    const Text(
                      'No career paths yet',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enroll in a career path to start your learning journey',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push('/careers'),
                      icon: const Icon(Icons.explore),
                      label: const Text('Browse Career Paths'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Group by status
          final active = enrollments
              .where((e) => e.status == CareerPathStatus.active)
              .toList();
          final paused = enrollments
              .where((e) => e.status == CareerPathStatus.paused)
              .toList();
          final completed = enrollments
              .where((e) => e.status == CareerPathStatus.completed)
              .toList();

          return RefreshIndicator(
            onRefresh: () => ref.read(userCareerPathsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Active paths
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'In Progress',
                    count: active.length,
                    icon: Icons.play_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  ...active.map((e) => _EnrolledPathCard(enrollment: e)),
                  const SizedBox(height: 24),
                ],

                // Paused paths
                if (paused.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Paused',
                    count: paused.length,
                    icon: Icons.pause_circle,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  ...paused.map((e) => _EnrolledPathCard(enrollment: e)),
                  const SizedBox(height: 24),
                ],

                // Completed paths
                if (completed.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Completed',
                    count: completed.length,
                    icon: Icons.check_circle,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  ...completed.map((e) => _EnrolledPathCard(enrollment: e)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/careers'),
        icon: const Icon(Icons.add),
        label: const Text('Add Path'),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _EnrolledPathCard extends ConsumerWidget {
  final UserCareerPath enrollment;

  const _EnrolledPathCard({required this.enrollment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathAsync = ref.watch(careerPathProvider(enrollment.careerPathId));
    final progressAsync =
        ref.watch(careerPathProgressProvider(enrollment.careerPathId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/careers/${enrollment.careerPathId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: pathAsync.when(
                      data: (path) => Text(
                        path.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      loading: () => Container(
                        height: 20,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      error: (_, __) =>
                          const Text('Error loading path'),
                    ),
                  ),
                  _StatusChip(status: enrollment.status),
                ],
              ),
              const SizedBox(height: 12),

              // Progress
              progressAsync.when(
                data: (progress) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress.completedCourses}/${progress.totalCourses} courses',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        Text(
                          '${progress.progressPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.progressPercent / 100,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ],
                ),
                loading: () => LinearProgressIndicator(
                  backgroundColor: Colors.grey.shade200,
                ),
                error: (_, __) => const Text('Error loading progress'),
              ),

              // Started date
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Started ${_formatDate(enrollment.startedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (enrollment.completedAt != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.check_circle,
                        size: 14, color: Colors.green.shade400),
                    const SizedBox(width: 4),
                    Text(
                      'Completed ${_formatDate(enrollment.completedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final CareerPathStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      CareerPathStatus.active => ('Active', Colors.green, Icons.play_arrow),
      CareerPathStatus.paused => ('Paused', Colors.orange, Icons.pause),
      CareerPathStatus.completed => ('Completed', Colors.blue, Icons.check),
      CareerPathStatus.abandoned => ('Abandoned', Colors.grey, Icons.close),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
