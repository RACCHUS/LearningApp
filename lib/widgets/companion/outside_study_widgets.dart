import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

String _left(OutsideStudyPlan p) {
  if (p.remainingMinutes == 0) return '';
  return p.partsWithoutEstimate == 0
      ? 'About ${formatStudyMinutes(p.remainingMinutes)} of outside study left, by your own estimates.'
      : 'At least ${formatStudyMinutes(p.remainingMinutes)} of outside study left, by your own estimates.';
}

/// On Learn, under the main action (companion plan v1.0 §6, EX-4): the next
/// part of the learner's outside resource for the active goal. It is an
/// offer beside LearningApp's own next step, never instead of it, and it
/// takes no space when the learner has nothing outside to continue.
class OutsideStepCard extends ConsumerWidget {
  const OutsideStepCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activeOutsideStudyPlanProvider).valueOrNull;
    if (plan == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final minutes = plan.sectionMinutes;
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space4),
      child: Card(
        key: const Key('outside_step_card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Outside study', style: muted),
              const SizedBox(height: DesignTokens.space1),
              Text(
                'Next: ${plan.sectionTitle}',
                key: const Key('outside_step_title'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                '${plan.resourceTitle}${minutes == null ? '' : ' · about ${formatStudyMinutes(minutes)}'}. '
                'Then check yourself in LearningApp.',
                key: const Key('outside_step_detail'),
              ),
              const SizedBox(height: DesignTokens.space2),
              FilledButton.tonalIcon(
                key: const Key('outside_step_continue'),
                onPressed: () => context.push(
                  '/target/${plan.targetId}/companion/${plan.resourceId}',
                ),
                icon: const Icon(Icons.playlist_play),
                label: const Text('Continue outside study'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In the daily plan: the next outside part against today's study goal.
/// The daily budget itself is not changed. The learner sees whether the
/// part fits in it.
class OutsideStudyPlanLine extends ConsumerWidget {
  const OutsideStudyPlanLine({super.key, required this.dailyMinutes});

  final int dailyMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activeOutsideStudyPlanProvider).valueOrNull;
    if (plan == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final minutes = plan.sectionMinutes;
    final String fit;
    if (minutes == null || dailyMinutes <= 0) {
      fit = '';
    } else if (minutes <= dailyMinutes) {
      fit = ' It fits in your $dailyMinutes-minute goal today.';
    } else {
      final days = (minutes / dailyMinutes).ceil();
      fit =
          ' That is longer than your $dailyMinutes-minute goal, so allow about $days days for it.';
    }
    final left = _left(plan);
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space3),
      child: Text(
        'Outside study next: ${plan.sectionTitle}'
        '${minutes == null ? '' : ', about ${formatStudyMinutes(minutes)}'}.$fit'
        '${left.isEmpty ? '' : ' $left'}',
        key: const Key('daily_plan_outside_study'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// In the projected finish: how much the learner's own outside study adds
/// at their daily goal. It is stated on its own line and is not mixed into
/// LearningApp's estimate, because the two can cover the same objectives.
class OutsideStudyFinishLine extends ConsumerWidget {
  const OutsideStudyFinishLine({super.key, required this.dailyGoalMinutes});

  final int dailyGoalMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(activeOutsideStudyPlanProvider).valueOrNull;
    if (plan == null || plan.remainingMinutes == 0) {
      return const SizedBox.shrink();
    }
    final days = dailyGoalMinutes > 0
        ? (plan.remainingMinutes / dailyGoalMinutes).ceil()
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Text(
        '${_left(plan)}'
        '${days == null ? '' : ' At your daily goal that adds about $days ${days == 1 ? 'day' : 'days'}.'}'
        ' It is not included in the dates above.',
        key: const Key('projection_outside_study'),
      ),
    );
  }
}
