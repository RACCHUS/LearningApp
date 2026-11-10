import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/fast_plan_result.dart';
import '../../models/learning_context.dart';
import '../../models/learning_strategy.dart';
import '../../providers/learning_context_provider.dart';
import '../../providers/learning_strategy_provider.dart';
import '../../providers/next_action_provider.dart';
import '../../providers/site_feature_provider.dart';
import '../../services/next_action_engine.dart';
import '../../theme/design_tokens.dart';

/// Quiet Standard / Fast learning approach selector and transparent coverage
/// inspector rendered on `LearnScreen` for eligible target contexts (`TEL-04`).
class LearningApproachSelector extends ConsumerWidget {
  const LearningApproachSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(telFeatureFlagsProvider);
    final fastExperimental = isSiteFeatureExperimental(
      ref.watch(siteFeatureSnapshotProvider).valueOrNull,
      'tel.fast',
    );
    final activeContext = ref.watch(activeLearningContextProvider);
    if (activeContext == null ||
        activeContext.rootType != ContextRootType.target ||
        !flags.isFastEnabledForTarget(
          activeContext.rootId,
          isExamTarget: true,
        )) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final strategyState = ref.watch(learningStrategyProvider);
    final pref = strategyState.preferenceFor(activeContext.id);
    final conflict = strategyState.conflictFor(activeContext.id);
    final fastPlanAsync = ref.watch(activeFastPlanProvider);

    return Column(
      key: const Key('learning-approach-selector-container'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (conflict != null)
          Padding(
            padding: const EdgeInsets.only(bottom: DesignTokens.space3),
            child: Card(
              key: const Key('fast-preference-conflict-banner'),
              elevation: 0,
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space3),
                child: Row(
                  children: [
                    Icon(
                      Icons.sync_problem_outlined,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        'Your learning approach was updated on another device. '
                        'Showing the latest saved setting (${conflict.authoritativePreference.strategy.displayName}).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('fast-preference-conflict-dismiss'),
                      onPressed: () {
                        ref
                            .read(learningStrategyProvider.notifier)
                            .dismissConflict(activeContext.id);
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning approach',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pref.strategy == PersistedLearningStrategy.fast
                        ? 'Study the most relevant material first'
                        : 'Full curriculum in canonical order',
                    key: const Key('learning-approach-subtitle'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Select Standard or Fast learning approach',
              child: SegmentedButton<PersistedLearningStrategy>(
                key: const Key('learning-approach-segmented-button'),
                segments: const [
                  ButtonSegment<PersistedLearningStrategy>(
                    value: PersistedLearningStrategy.standard,
                    label: Text('Standard'),
                  ),
                  ButtonSegment<PersistedLearningStrategy>(
                    value: PersistedLearningStrategy.fast,
                    label: Text('Fast'),
                  ),
                ],
                selected: {pref.strategy},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) return;
                  final chosen = selection.first;
                  try {
                    ref.read(learningStrategyProvider.notifier).setStrategy(
                          contextId: activeContext.id,
                          strategy: chosen,
                        );
                    ref.invalidate(nextActionProvider);
                    ref.invalidate(activeFastPlanProvider);
                    ref.invalidate(resolvedActionPresentationProvider);
                  } on FastPreferenceConflictException {
                    // Conflict banner is automatically populated in state
                  }
                },
              ),
            ),
          ],
        ),
        // Verification maturity is independent from feature availability.
        // Fast remains usable while its wider effectiveness is being verified.
        if (fastExperimental)
          const Padding(
            padding: EdgeInsets.only(top: DesignTokens.space2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: 'Fast prioritization is available, but broad learning-outcome '
                  'verification is still underway.',
              child: Text(
                'Fast · Experimental',
                key: Key('fast-experimental-disclosure'),
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        if (pref.strategy == PersistedLearningStrategy.fast) ...[
          const SizedBox(height: DesignTokens.space2),
          Wrap(
            spacing: DesignTokens.space2,
            runSpacing: DesignTokens.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: const Key('open-fast-coverage-sheet-button'),
                onPressed: () {
                  final plan = fastPlanAsync.valueOrNull;
                  if (plan != null) {
                    _showFastPlanSheet(context, plan);
                  }
                },
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Topic coverage & priority order'),
              ),
              TextButton.icon(
                key: const Key('learn-quick-overview-link'),
                onPressed: () =>
                    context.push('/overview/${activeContext.rootId}'),
                icon: const Icon(Icons.explore_outlined, size: 16),
                label: const Text('Quick overview'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showFastPlanSheet(BuildContext context, FastPlanResult plan) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(DesignTokens.space4),
              children: [
                Text(
                  'Fast Prioritization & Blueprint Coverage',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  'Based on College Board’s published exam topic outline. '
                  'Fast orders lessons to cover all major exam areas first, then deepens high-weight and gap areas. '
                  'No topic is marked mastered without independent check evidence.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
                if (plan.hasUnknownDurations)
                  Card(
                    key: const Key('fast-plan-provisional-budget-disclosure'),
                    elevation: 0,
                    color: theme.colorScheme.tertiaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.space3),
                      child: Text(
                        'Time estimate note: ${plan.remainingUnknownTimeCount} '
                        'lesson(s) use default duration estimates (~15 min). '
                        'Known authored/measured subtotal: ${plan.knownDurationSubtotalMinutes} min.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                const SizedBox(height: DesignTokens.space3),
                Text(
                  'Official Blueprint Domains (${plan.domainCoverage.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),
                ...plan.domainCoverage.map(
                  (d) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${d.domainId} · ${d.title} (${d.publishedWeightRangeLabel})',
                    ),
                    subtitle: Text(
                      d.isCoverageMissing
                          ? 'Coverage gap: no mapped lesson in current scope'
                          : d.evidenceStatus.userFacingLabel,
                    ),
                    trailing: d.hasCompletedActivity
                        ? const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Secondary card shown beneath `ContinueCard` when `ResumeActivity` is primary
/// and Fast mode recommends a different top priority lesson (`RESUME-01`).
class SecondaryFastRecommendationCard extends StatelessWidget {
  final StartActivity secondaryAction;
  final String? rationale;

  const SecondaryFastRecommendationCard({
    super.key,
    required this.secondaryAction,
    this.rationale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = secondaryAction.activity;
    final route = switch (activity) {
      LessonActivity(:final lessonId) => '/lesson/$lessonId',
      StudySetActivity(:final studySetId) => '/study-set?setId=$studySetId',
      ReviewActivity() => '/review',
    };

    return Card(
      key: const Key('secondary-fast-recommendation-card'),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: DesignTokens.space1),
                Text(
                  'Fast priority alternative',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space1),
            Text(
              activity.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (rationale != null && rationale!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                rationale!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: DesignTokens.space2),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('secondary-fast-recommendation-start'),
                onPressed: () => context.push(route),
                child: const Text('Switch to priority topic'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
