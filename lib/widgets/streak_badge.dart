import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/streak_provider.dart';

/// Compact streak badge for display in app headers.
/// 
/// Shows a flame icon with the current streak count.
/// Taps navigate to the progress dashboard.
class StreakBadge extends ConsumerWidget {
  final bool showLabel;

  const StreakBadge({
    super.key,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return streakAsync.when(
      data: (streak) => _buildBadge(context, streak.currentStreak, colorScheme),
      loading: () => _buildBadge(context, 0, colorScheme, isLoading: true),
      error: (_, __) => _buildBadge(context, 0, colorScheme),
    );
  }

  Widget _buildBadge(
    BuildContext context,
    int streak,
    ColorScheme colorScheme, {
    bool isLoading = false,
  }) {
    final hasStreak = streak > 0;
    final color = hasStreak ? Colors.orange : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: hasStreak 
          ? '$streak day streak! Keep it up!' 
          : 'Start learning to build your streak',
      child: InkWell(
        onTap: () => context.push('/progress'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: hasStreak 
                ? Colors.orange.withValues(alpha: 0.15) 
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 18,
                color: isLoading 
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : color,
              ),
              const SizedBox(width: 4),
              Text(
                isLoading ? '-' : '$streak',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isLoading 
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      : color,
                ),
              ),
              if (showLabel && hasStreak) ...[
                const SizedBox(width: 4),
                Text(
                  streak == 1 ? 'day' : 'days',
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
