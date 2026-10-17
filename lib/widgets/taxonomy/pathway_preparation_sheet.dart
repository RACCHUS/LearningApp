import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/license_pathway_readiness.dart';
import '../../providers/pathway_readiness_provider.dart';
import '../../providers/verified_destinations_provider.dart';
import '../../theme/design_tokens.dart';
import '../targets/create_target_dialog.dart';

/// Modal bottom sheet allowing learners to interactively explore licensing pathways,
/// select their qualification route, track required steps with a self-reported
/// readiness checklist, and optionally connect the pathway to a private learning goal.
///
/// Strictly disclaims official licensing determinations or examination awards.
class PathwayPreparationSheet extends ConsumerStatefulWidget {
  final VerifiedDestination destination;
  final String? targetId;

  const PathwayPreparationSheet({
    super.key,
    required this.destination,
    this.targetId,
  });

  static Future<void> show(
    BuildContext context, {
    required VerifiedDestination destination,
    String? targetId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.85,
          child: PathwayPreparationSheet(
            destination: destination,
            targetId: targetId,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<PathwayPreparationSheet> createState() =>
      _PathwayPreparationSheetState();
}

class _PathwayPreparationSheetState
    extends ConsumerState<PathwayPreparationSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pathwayKey =
        '${widget.destination.sourceNamespace}:${widget.destination.sourceKey}';

    final pathwayAsync = ref.watch(reviewedLicensePathwayProvider((
      namespace: widget.destination.sourceNamespace,
      key: widget.destination.sourceKey,
    )));

    final readinessKey = (pathwayKey: pathwayKey, targetId: widget.targetId);
    final readinessAsync = ref.watch(pathwayReadinessProvider(readinessKey));

    return pathwayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Text('Could not load regulator steps: $error'),
        ),
      ),
      data: (reviewed) {
        if (reviewed == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space5),
              child: Text(
                'No reviewed pathway available for this license yet. '
                'Consult its official regulator page.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final routes = PathwayTreeParser.extractRoutes(reviewed.pathwayTree);

        return readinessAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Readiness state unavailable: $error'),
          ),
          data: (readinessState) {
            final applicableSteps = PathwayTreeParser.extractApplicableSteps(
              reviewed.pathwayTree,
              selectedRouteLabel: readinessState.selectedRouteLabel,
            );

            final metrics = PathwayTreeParser.computeReadiness(
              applicableSteps: applicableSteps,
              completedLabels: readinessState.completedStepLabels,
            );

            return ListView(
              key: const Key('pathway-preparation-sheet-view'),
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space4,
                DesignTokens.space2,
                DesignTokens.space4,
                DesignTokens.space6,
              ),
              children: [
                // Title and Jurisdiction
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewed.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space1),
                          Text(
                            '${widget.destination.issuerName} · ${widget.destination.jurisdiction}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text('Rev ${reviewed.revision}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space2),

                // Source checked metadata
                Text(
                  'Regulator source verified ${reviewed.sourceCheckedAt.toIso8601String().substring(0, 10)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),

                // Legal Disclaimer Card
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: DesignTokens.space2),
                          Text(
                            'Informational Preparation Only',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.space1),
                      Text(
                        'Selected regulator-sourced steps only. This is not a legal eligibility '
                        'determination, license award, or an official application submission. '
                        'Self-reported checklist progress is for personal planning only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),

                // Overview text
                Text(
                  reviewed.overview,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: DesignTokens.space4),

                // Self-Reported Readiness Progress Meter
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Self-Reported Readiness',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${metrics.completedSteps} of ${metrics.totalSteps} steps',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.space2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                          child: LinearProgressIndicator(
                            value: metrics.ratio,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        if (metrics.isComplete) ...[
                          const SizedBox(height: DesignTokens.space2),
                          Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: Colors.green.shade700),
                              const SizedBox(width: DesignTokens.space1),
                              Text(
                                'All selected steps marked complete (self-reported)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.space4),

                // 1. Qualification Route Selector (if alternative routes exist)
                if (routes.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1. Choose Qualification Route',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (readinessState.selectedRouteLabel != null)
                        TextButton(
                          key: const Key('pathway-clear-route-button'),
                          onPressed: () {
                            ref
                                .read(pathwayReadinessProvider(readinessKey).notifier)
                                .selectRoute(-1, '');
                          },
                          child: const Text('Show all routes'),
                        ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space1),
                  Text(
                    'Select the statutory route that matches your education or background to tailor your checklist:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space2),

                  for (final route in routes) ...[
                    RadioListTile<String>(
                      key: Key('pathway-route-option-${route.index}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: route.label,
                      groupValue: readinessState.selectedRouteLabel,
                      onChanged: (val) {
                        if (val != null) {
                          ref
                              .read(pathwayReadinessProvider(readinessKey).notifier)
                              .selectRoute(route.index, val);
                        }
                      },
                      title: Text(
                        route.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: readinessState.selectedRouteLabel == route.label
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: route.condition != null
                          ? Text(
                              'Condition: ${route.condition}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : null,
                    ),
                  ],
                  const SizedBox(height: DesignTokens.space4),
                ],

                // 2. Interactive Milestone Checklist
                Text(
                  routes.isNotEmpty ? '2. Track Required Steps' : 'Required Steps',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  'Check off milestones as you complete them during your preparation:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space2),

                for (int i = 0; i < applicableSteps.length; i++) ...[
                  _buildStepCheckboxTile(
                    context,
                    step: applicableSteps[i],
                    index: i,
                    isCompleted: readinessState.isStepCompleted(applicableSteps[i].label),
                    onToggle: () {
                      ref
                          .read(pathwayReadinessProvider(readinessKey).notifier)
                          .toggleStep(applicableSteps[i].label);
                    },
                  ),
                ],
                const SizedBox(height: DesignTokens.space5),

                // Actions: Connect to Private Goal & Regulator Link
                if (widget.targetId == null) ...[
                  FilledButton.icon(
                    key: const Key('pathway-connect-goal-button'),
                    onPressed: () => _connectToPrivateGoal(
                      context,
                      readinessState.selectedRouteLabel,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Save to Private Learning Goal'),
                  ),
                  const SizedBox(height: DesignTokens.space2),
                ],

                OutlinedButton.icon(
                  key: const Key('pathway-open-regulator-source-button'),
                  onPressed: () => _openUrl(context, reviewed.sourceUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Current official regulator page'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepCheckboxTile(
    BuildContext context, {
    required PathwayStep step,
    required int index,
    required bool isCompleted,
    required VoidCallback onToggle,
  }) {
    final theme = Theme.of(context);

    return Card(
      key: Key('pathway-step-tile-$index'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: DesignTokens.space2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        side: BorderSide(
          color: isCompleted
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: CheckboxListTile(
        key: Key('pathway-step-checkbox-$index'),
        dense: true,
        value: isCompleted,
        onChanged: (_) => onToggle(),
        secondary: Icon(
          step.stageIcon,
          size: 20,
          color: isCompleted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          step.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  step.stageDisplayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (step.isRouteAlternative) ...[
                  const SizedBox(width: DesignTokens.space1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
                    ),
                    child: Text(
                      'Chosen Route',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (step.condition != null) ...[
              const SizedBox(height: 2),
              Text(
                'Note: ${step.condition}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            InkWell(
              onTap: () => _openUrl(context, step.sourceUrl),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Regulator citation link',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new, size: 12, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToPrivateGoal(
    BuildContext context,
    String? selectedRouteLabel,
  ) async {
    final pathwayKey =
        '${widget.destination.sourceNamespace}:${widget.destination.sourceKey}';

    final initialDesc = selectedRouteLabel != null && selectedRouteLabel.isNotEmpty
        ? 'Preparation pathway for ${widget.destination.title}.\nSelected qualification route: $selectedRouteLabel'
        : 'Preparation pathway for ${widget.destination.title}.';

    final createdTarget = await CreateTargetDialog.show(
      context,
      initialDestination: widget.destination,
      initialDescription: initialDesc,
    );

    if (createdTarget != null && context.mounted) {
      await ref
          .read(pathwayReadinessServiceProvider)
          .linkToGoal(targetId: createdTarget.id, pathwayKey: pathwayKey);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Checklist connected to private goal: "${createdTarget.title}"',
          ),
        ),
      );
    }
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Cannot launch URL');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: uri.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open external browser; link copied to clipboard.'),
          ),
        );
      }
    }
  }
}
