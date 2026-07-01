import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/streak_provider.dart';
import 'package:learning_pwa/providers/lesson_progress_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/daily_goal_ring.dart';
import 'package:learning_pwa/widgets/level_badge.dart';
import 'package:learning_pwa/widgets/review_widgets.dart';

/// Right sidebar for desktop/tablet screens (>= 1024px width).
/// Shows daily goal, streak, recently mastered lessons, and quick actions.
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          left: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DesignTokens.space4,
          DesignTokens.space4,
          DesignTokens.space4,
          80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // XP Progress Section
            _buildSectionHeader(context, 'Your Progress'),
            const SizedBox(height: DesignTokens.space3),
            const XpProgressCard(),
            const SizedBox(height: DesignTokens.space5),

            // Daily Goal Section
            _buildSectionHeader(context, 'Daily Goal'),
            const SizedBox(height: DesignTokens.space3),
            const Center(child: DailyGoalRingLarge(size: 140)),
            const SizedBox(height: DesignTokens.space5),

            // Review Section
            _buildSectionHeader(context, 'Spaced Repetition'),
            const SizedBox(height: DesignTokens.space3),
            const ReviewSummaryCard(),
            const SizedBox(height: DesignTokens.space5),

            // Streak Section
            _buildSectionHeader(context, 'Current Streak'),
            const SizedBox(height: DesignTokens.space3),
            _buildStreakCard(context, ref, colorScheme, textTheme),
            const SizedBox(height: DesignTokens.space5),

            // Quick Actions
            _buildSectionHeader(context, 'Quick Actions'),
            const SizedBox(height: DesignTokens.space3),
            _buildQuickActions(context, ref, colorScheme),
            const SizedBox(height: DesignTokens.space5),

            // Recently Mastered
            _buildSectionHeader(context, 'Recently Completed'),
            const SizedBox(height: DesignTokens.space3),
            _buildRecentlyMastered(context, ref, colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildStreakCard(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final streakAsync = ref.watch(streakProvider);

    return streakAsync.when(
      data: (streak) {
        if (streak.currentStreak == 0) {
          return _buildEmptyStreakCard(colorScheme, textTheme);
        }
        return Container(
          padding: const EdgeInsets.all(DesignTokens.space4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade400,
                Colors.orange.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(width: DesignTokens.space3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.currentStreak} days',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Keep it going!',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => _buildEmptyStreakCard(colorScheme, textTheme),
    );
  }

  Widget _buildEmptyStreakCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
            size: 40,
          ),
          const SizedBox(width: DesignTokens.space3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No streak yet',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                'Study today to start!',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
    return Column(
      children: [
        _QuickActionButton(
          icon: Icons.add,
          label: 'Create Lesson',
          onTap: () => context.push('/create-lesson'),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: DesignTokens.space2),
        _QuickActionButton(
          icon: Icons.quiz,
          label: 'Random Quiz',
          onTap: () => _startRandomQuiz(context, ref),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: DesignTokens.space2),
        _QuickActionButton(
          icon: Icons.library_books,
          label: 'Browse Library',
          onTap: () => context.push('/browse'),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Future<void> _startRandomQuiz(BuildContext context, WidgetRef ref) async {
    final lessonsAsync = ref.read(allLessonsProvider);
    
    lessonsAsync.when(
      data: (lessons) {
        if (lessons.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No lessons available. Create one first!')),
          );
          return;
        }
        
        // Pick a random lesson
        final random = Random();
        final randomLesson = lessons[random.nextInt(lessons.length)];
        
        // Navigate to study mode
        context.push('/study/${randomLesson.id}');
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading lessons...')),
        );
      },
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading lessons: $e')),
        );
      },
    );
  }

  Widget _buildRecentlyMastered(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // Use the continueLearningSuggestion provider to show recent activity
    final recentAsync = ref.watch(continueLearningSuggestionProvider);

    return recentAsync.when(
      data: (suggestion) {
        if (suggestion == null) {
          return Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: DesignTokens.space3),
                Expanded(
                  child: Text(
                    'Complete lessons to see them here',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Show the most recent lesson being studied
        return _RecentLessonCard(
          title: suggestion.lessonTitle,
          timeAgo: suggestion.timeAgo,
          questionsAnswered: suggestion.questionsAnswered,
          onTap: () => context.push('/study/${suggestion.lessonId}'),
          colorScheme: colorScheme,
          textTheme: textTheme,
        );
      },
      loading: () => Container(
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: DesignTokens.space3),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentLessonCard extends StatelessWidget {
  final String title;
  final String timeAgo;
  final int questionsAnswered;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RecentLessonCard({
    required this.title,
    required this.timeAgo,
    required this.questionsAnswered,
    required this.onTap,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space3),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: Icon(
                  Icons.menu_book,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: DesignTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$timeAgo • $questionsAnswered questions',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow,
                color: colorScheme.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
