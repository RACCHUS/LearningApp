import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Compact circular progress ring showing daily study goal progress.
/// Displays in the app header, taps to navigate to progress dashboard.
class DailyGoalRing extends ConsumerWidget {
  /// Size of the ring widget
  final double size;

  const DailyGoalRing({
    super.key,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(dailyGoalProgressProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return goalAsync.when(
      data: (goal) => _buildRing(context, goal, colorScheme),
      loading: () => _buildLoadingRing(colorScheme),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildRing(
    BuildContext context,
    DailyGoalProgress goal,
    ColorScheme colorScheme,
  ) {
    // Determine color based on progress
    Color progressColor;
    if (goal.goalMet) {
      progressColor = Colors.green;
    } else if (goal.progress >= 0.5) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    return Tooltip(
      message: goal.goalMet
          ? 'Daily goal complete! 🎉'
          : '${goal.formattedTime} / ${goal.goalMinutes}m today',
      child: InkWell(
        onTap: () => context.push('/progress'),
        borderRadius: BorderRadius.circular(size / 2),
        child: CircularPercentIndicator(
          radius: size / 2,
          lineWidth: 3.5,
          percent: goal.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          progressColor: progressColor,
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 800,
          center: goal.goalMet
              ? Icon(
                  Icons.check,
                  size: size * 0.45,
                  color: Colors.green,
                )
              : Text(
                  goal.studyMinutesToday.toString(),
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingRing(ColorScheme colorScheme) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

/// Larger daily goal ring for use in sidebars or dashboards
class DailyGoalRingLarge extends ConsumerWidget {
  final double size;

  const DailyGoalRingLarge({
    super.key,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(dailyGoalProgressProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return goalAsync.when(
      data: (goal) => _buildLargeRing(context, goal, colorScheme, textTheme),
      loading: () => _buildLoadingState(colorScheme),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildLargeRing(
    BuildContext context,
    DailyGoalProgress goal,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    Color progressColor;
    if (goal.goalMet) {
      progressColor = Colors.green;
    } else if (goal.progress >= 0.5) {
      progressColor = Colors.orange;
    } else {
      progressColor = colorScheme.primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularPercentIndicator(
          radius: size / 2,
          lineWidth: 8,
          percent: goal.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          progressColor: progressColor,
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animationDuration: 1000,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (goal.goalMet)
                Icon(
                  Icons.check_circle,
                  size: size * 0.3,
                  color: Colors.green,
                )
              else ...[
                Text(
                  goal.formattedTime,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '/ ${goal.goalMinutes}m',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space2),
        Text(
          goal.goalMet ? 'Goal Complete!' : 'Daily Goal',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: goal.goalMet ? Colors.green : colorScheme.onSurface,
          ),
        ),
        if (!goal.goalMet)
          Text(
            '${goal.remainingMinutes}m remaining',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CircularProgressIndicator(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
