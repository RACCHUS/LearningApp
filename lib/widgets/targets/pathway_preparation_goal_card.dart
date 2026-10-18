import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/license_pathway_readiness.dart';
import '../../providers/pathway_readiness_provider.dart';
import '../../providers/verified_destinations_provider.dart';
import '../../theme/design_tokens.dart';
import '../taxonomy/pathway_preparation_sheet.dart';

/// Embedded card displayed on a private learning goal's detail screen when
/// the goal is linked to an official professional license destination with a
/// published regulatory pathway.
class PathwayPreparationGoalCard extends ConsumerWidget {
  final String targetId;
  final VerifiedDestination destination;

  const PathwayPreparationGoalCard({
    super.key,
    required this.targetId,
    required this.destination,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pathwayKey = '${destination.sourceNamespace}:${destination.sourceKey}';

    final pathwayAsync = ref.watch(reviewedLicensePathwayProvider((
      namespace: destination.sourceNamespace,
      key: destination.sourceKey,
    )));

    return pathwayAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reviewed) {
        if (reviewed == null) return const SizedBox.shrink();

        final readinessKey = (pathwayKey: pathwayKey, targetId: targetId);
        final readinessAsync = ref.watch(pathwayReadinessProvider(readinessKey));

        return readinessAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (readinessState) {
            final applicableSteps = PathwayTreeParser.extractApplicableSteps(
              reviewed.pathwayTree,
              selectedRouteLabel: readinessState.selectedRouteLabel,
            );

            final metrics = PathwayTreeParser.computeReadiness(
              applicableSteps: applicableSteps,
              completedLabels: readinessState.completedStepLabels,
            );

            final routes = PathwayTreeParser.extractRoutes(reviewed.pathwayTree);

            return Card(
              key: const Key('goal-pathway-preparation-card'),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: DesignTokens.space2),
                        Expanded(
                          child: Text(
                            'License Preparation Checklist',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                          ),
                          child: Text(
                            'Self-Reported',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.space1),
                    Text(
                      'Track sourced milestones for ${destination.title} (${destination.jurisdiction}). '
                      'Planning only; does not award a license or submit official paperwork.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space3),

                    // Route summary
                    if (routes.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              readinessState.selectedRouteLabel != null
                                  ? 'Route: ${readinessState.selectedRouteLabel}'
                                  : 'No specific qualification route selected yet',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            key: const Key('goal-pathway-change-route-button'),
                            onPressed: () => PathwayPreparationSheet.show(
                              context,
                              destination: destination,
                              targetId: targetId,
                            ),
                            child: Text(
                              readinessState.selectedRouteLabel != null
                                  ? 'Change'
                                  : 'Select route',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space2),
                    ],

                    // Progress bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Milestones Completed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${metrics.completedSteps} of ${metrics.totalSteps}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DesignTokens.space1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                      child: LinearProgressIndicator(
                        value: metrics.ratio,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space3),

                    // Quick Step List
                    for (int i = 0; i < applicableSteps.length; i++) ...[
                      CheckboxListTile(
                        key: Key('goal-pathway-step-checkbox-$i'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: readinessState.isStepCompleted(applicableSteps[i].label),
                        onChanged: (_) {
                          ref
                              .read(pathwayReadinessProvider(readinessKey).notifier)
                              .toggleStep(applicableSteps[i].label);
                        },
                        title: Text(
                          applicableSteps[i].label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: readinessState
                                    .isStepCompleted(applicableSteps[i].label)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          applicableSteps[i].stageDisplayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: DesignTokens.space2),

                    // View details button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('goal-pathway-full-details-button'),
                        onPressed: () => PathwayPreparationSheet.show(
                          context,
                          destination: destination,
                          targetId: targetId,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View full pathway & regulator links'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
