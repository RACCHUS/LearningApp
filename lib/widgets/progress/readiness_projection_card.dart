import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/target_readiness_provider.dart';
import '../../services/planning/readiness_projection.dart';
import '../../theme/design_tokens.dart';

/// Projected finish on the daily plan (ingestion plan v1.2 §8.7): study time
/// left on what LearningApp covers for the target, and roughly when the
/// learner would get through it at their daily goal. Shown only while
/// `learning.readiness_projection` is on; otherwise it takes no space.
class ReadinessProjectionCard extends ConsumerWidget {
  final String targetVersionId;

  const ReadinessProjectionCard({super.key, required this.targetVersionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref
        .watch(readinessProjectionProvider(targetVersionId))
        .valueOrNull;
    if (projection == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final date = DateFormat.yMMMd();

    final lines = <Widget>[];
    if (projection.nothingLeft) {
      lines.add(
        Text(
          "You've worked through everything LearningApp has for this target. Keep up your reviews "
          'so it stays strong.',
          key: const Key('projection_done'),
        ),
      );
    } else {
      final low = projection.remainingLow;
      final high = projection.remainingHigh;
      lines.add(
        Text(
          low == high || formatStudyTime(low) == formatStudyTime(high)
              ? 'Study time left: ${formatStudyTime(high)}.'
              : 'Study time left: ${formatStudyTime(low)} to ${formatStudyTime(high)}.',
          key: const Key('projection_remaining'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      if (projection.finishEarliest != null &&
          projection.finishLatest != null) {
        final a = date.format(projection.finishEarliest!);
        final b = date.format(projection.finishLatest!);
        lines.add(
          Text(
            'At your daily goal of ${projection.dailyGoalMinutes} minutes, you would get through '
            'it ${a == b ? 'around $a' : 'between $a and $b'}.',
            key: const Key('projection_dates'),
          ),
        );
      }
      if (projection.paceEarliest != null &&
          projection.paceLatest != null &&
          projection.recentMinutesPerWeek != null) {
        final a = date.format(projection.paceEarliest!);
        final b = date.format(projection.paceLatest!);
        lines.add(
          Text(
            'At your recent pace (about ${projection.recentMinutesPerWeek} minutes a week over the '
            'last 4 weeks), ${a == b ? 'around $a' : 'between $a and $b'}.',
            key: const Key('projection_recent_pace'),
          ),
        );
      }
      if (projection.examDate != null &&
          projection.minutesPerDayForExam != null) {
        final exam = date.format(projection.examDate!);
        lines.add(
          Text(
            projection.onTrackForExam
                ? "That's before your exam on $exam."
                : 'To get through it before your exam on $exam, plan on about '
                      '${projection.minutesPerDayForExam} minutes a day.',
            key: const Key('projection_exam'),
          ),
        );
      }
    }
    if (projection.unavailableShare > 0) {
      lines.add(
        Text(
          '${(projection.unavailableShare * 100).round()}% of this target isn\'t in LearningApp yet, '
          "so it isn't included.",
          key: const Key('projection_unavailable'),
          style: muted,
        ),
      );
    }
    lines.add(
      Text(
        'An estimate from lesson length and your progress: strong objectives count as done and '
        "ones you're building as half done. It isn't a promise of exam readiness, and pausing is "
        'fine: the dates just move.',
        key: const Key('projection_note'),
        style: muted,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Card(
        key: const Key('readiness_projection_card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: DesignTokens.space2),
                  Text(
                    'Projected finish',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              for (final l in lines) ...[
                const SizedBox(height: DesignTokens.space2),
                l,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
