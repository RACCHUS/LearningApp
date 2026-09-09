import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/providers/lessons_provider.dart';
import 'package:learning_pwa/providers/study_set_provider.dart';
import 'package:learning_pwa/services/course_service.dart';
import 'package:learning_pwa/services/progress_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Aggregated progress data
class DashboardProgress {
  final int totalLessons;
  final int completedLessons;
  final int totalCourses;
  final int completedCourses;
  final int totalStudySets;
  final int studySetSessionsCompleted;
  final int totalTimeMinutes;
  final int currentStreak;
  final int longestStreak;
  final List<RecentActivity> recentActivities;

  const DashboardProgress({
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.totalCourses = 0,
    this.completedCourses = 0,
    this.totalStudySets = 0,
    this.studySetSessionsCompleted = 0,
    this.totalTimeMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.recentActivities = const [],
  });

  double get lessonProgress =>
      totalLessons > 0 ? completedLessons / totalLessons : 0.0;
  double get courseProgress =>
      totalCourses > 0 ? completedCourses / totalCourses : 0.0;

  String get formattedTime {
    if (totalTimeMinutes < 60) {
      return '${totalTimeMinutes}m';
    } else {
      final hours = totalTimeMinutes ~/ 60;
      final mins = totalTimeMinutes % 60;
      return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
  }
}

/// Recent activity entry
class RecentActivity {
  final String title;
  final String type; // 'lesson', 'course', 'study_set'
  final DateTime timestamp;
  final double? progress;
  final String? id;

  const RecentActivity({
    required this.title,
    required this.type,
    required this.timestamp,
    this.progress,
    this.id,
  });
}

/// Provider for dashboard progress data
final dashboardProgressProvider =
    FutureProvider<DashboardProgress>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    return const DashboardProgress();
  }

  // Get lessons count
  final lessonsState = ref.watch(lessonsProvider);
  final totalLessons = lessonsState.lessons.length;

  // Get courses
  final courseService = CourseService();
  final courses = await courseService.getUserCourses();
  final totalCourses = courses.length;

  // Get study sets
  final studySetState = ref.watch(studySetProvider);
  final totalStudySets = studySetState.studySets.length;

  // Calculate total study set sessions from progress data
  int studySetSessionsTotal = 0;
  for (final progress in studySetState.progressBySetId.values) {
    studySetSessionsTotal += progress.sessionsCount;
  }

  // Get progress data
  final courseProgressList =
      await ProgressService.getUserCourseProgress(userId);

  int completedLessons = 0;
  int completedCourses = 0;
  int totalTimeMinutes = 0;

  for (final cp in courseProgressList) {
    if (cp.status == CourseProgressStatus.completed) {
      completedCourses++;
    }
    totalTimeMinutes += cp.totalTimeSpentMinutes;

    for (final lp in cp.lessonProgress.values) {
      if (lp.status == LessonProgressStatus.completed) {
        completedLessons++;
      }
    }
  }

  // Get streak
  final streak = await ProgressService.getLearningStreak(userId);

  // Build recent activities
  final activities = <RecentActivity>[];

  // Add recent lesson activities from progress
  for (final cp in courseProgressList) {
    for (final entry in cp.lessonProgress.entries) {
      final lp = entry.value;
      activities.add(RecentActivity(
        title: 'Lesson ${entry.key.substring(0, 8)}...', // Truncated ID
        type: 'lesson',
        timestamp: lp.lastAccessedAt,
        progress: lp.progress / 100,
        id: entry.key,
      ));
    }
  }

  // Add study set activities (using updatedAt as proxy for last study time)
  for (final ss in studySetState.studySets) {
    activities.add(RecentActivity(
      title: ss.title,
      type: 'study_set',
      timestamp: ss.updatedAt,
      id: ss.id,
    ));
  }

  // Sort by most recent
  activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return DashboardProgress(
    totalLessons: totalLessons,
    completedLessons: completedLessons,
    totalCourses: totalCourses,
    completedCourses: completedCourses,
    totalStudySets: totalStudySets,
    studySetSessionsCompleted: studySetSessionsTotal,
    totalTimeMinutes: totalTimeMinutes,
    currentStreak: streak.currentStreak,
    longestStreak: streak.longestStreak,
    recentActivities: activities.take(10).toList(),
  );
});

/// Progress Dashboard Screen
class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(dashboardProgressProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProgressProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: progressAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load progress'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(dashboardProgressProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (progress) => _DashboardContent(progress: progress),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardProgress progress;

  const _DashboardContent({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Streak card
          _StreakCard(
            currentStreak: progress.currentStreak,
            longestStreak: progress.longestStreak,
          ),

          const SizedBox(height: 24),

          // Stats grid
          Text(
            'Overview',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                icon: Icons.menu_book,
                iconColor: Colors.blue,
                label: 'Lessons',
                value: '${progress.completedLessons}/${progress.totalLessons}',
                progress: progress.lessonProgress,
              ),
              _StatCard(
                icon: Icons.school,
                iconColor: Colors.purple,
                label: 'Courses',
                value: '${progress.completedCourses}/${progress.totalCourses}',
                progress: progress.courseProgress,
              ),
              _StatCard(
                icon: Icons.library_books,
                iconColor: Colors.orange,
                label: 'Study Sets',
                value: '${progress.totalStudySets}',
                sublabel: 'created',
              ),
              _StatCard(
                icon: Icons.timer,
                iconColor: Colors.green,
                label: 'Time Spent',
                value: progress.formattedTime,
                sublabel: 'total',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent activity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Could navigate to full history
                },
                child: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (progress.recentActivities.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent activity',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start studying to see your progress here',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: progress.recentActivities.length,
              itemBuilder: (context, index) {
                final activity = progress.recentActivities[index];
                return _ActivityTile(activity: activity);
              },
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const _StreakCard({
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: colorScheme.onPrimary,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$currentStreak day streak!',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    currentStreak > 0
                        ? 'Keep it up!'
                        : 'Start learning to build your streak',
                    style: textTheme.bodyMedium?.copyWith(
                      color:
                          colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Best',
                  style: textTheme.labelSmall?.copyWith(
                    color:
                        colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '$longestStreak days',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? sublabel;
  final double? progress;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.sublabel,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final RecentActivity activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (icon, iconColor) = switch (activity.type) {
      'lesson' => (Icons.menu_book, Colors.blue),
      'course' => (Icons.school, Colors.purple),
      'study_set' => (Icons.library_books, Colors.orange),
      _ => (Icons.article, Colors.grey),
    };

    final timeAgo = _formatTimeAgo(activity.timestamp);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          // Navigate to the item
          if (activity.id != null) {
            if (activity.type == 'lesson') {
              context.push('/lesson/${activity.id}');
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      timeAgo,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (activity.progress != null) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: activity.progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        strokeWidth: 4,
                      ),
                      Text(
                        '${(activity.progress! * 100).toInt()}%',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.month}/${timestamp.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
