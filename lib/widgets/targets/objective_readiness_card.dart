import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/objective_readiness.dart';
import '../../providers/target_readiness_provider.dart';
import '../../theme/design_tokens.dart';

/// Readiness by objective (ingestion plan v1.2 §8.7): each blueprint domain
/// with its weight, and each objective marked strong, building, not started
/// or not yet available. Shown only while `learning.objective_readiness_view`
/// is on; while loading, switched off or unreadable it takes no space.
class ObjectiveReadinessCard extends ConsumerWidget {
  final String targetVersionId;

  const ObjectiveReadinessCard({super.key, required this.targetVersionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref
        .watch(objectiveReadinessProvider(targetVersionId))
        .valueOrNull;
    if (view == null || view.domains.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final anyMissing = view.domains.any(
      (d) =>
          d.status == ObjectiveReadinessStatus.notAvailable ||
          d.objectives.any(
            (o) => o.status == ObjectiveReadinessStatus.notAvailable,
          ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space3),
      child: Card(
        key: const Key('objective_readiness_card'),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Readiness by objective',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.space1),
              Text(
                view.weightsEditorial
                    ? 'Each area counts equally here (no official weights).'
                    : 'Bigger areas count for more of the target.',
                style: muted,
              ),
              for (final d in view.domains) ...[
                const SizedBox(height: DesignTokens.space3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        view.weightsEditorial
                            ? d.title
                            : '${d.title} · ${d.weightPercent}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusChip(status: d.status),
                  ],
                ),
                for (final o in d.objectives)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: DesignTokens.space3,
                      top: DesignTokens.space1,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            o.code.isEmpty ? o.title : '${o.code} ${o.title}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space2),
                        _StatusChip(
                          status: o.status,
                          key: Key('objective_status_${o.code}'),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: DesignTokens.space3),
              if (view.hasUncheckedObjectives)
                Text(
                  'An objective shows Strong only when it also has ${view.minHeldOutItems} or more '
                  'independent checks. Until then, strong practice shows as Building.',
                  key: const Key('objective_readiness_unchecked_note'),
                  style: muted,
                ),
              if (anyMissing)
                Text(
                  'Not yet available: LearningApp has no lessons for it yet. It is never counted '
                  'as done or as zero.',
                  key: const Key('objective_readiness_missing_note'),
                  style: muted,
                ),
              if (!view.signedIn)
                Text(
                  'Sign in to see your own progress by objective.',
                  key: const Key('objective_readiness_guest_note'),
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ObjectiveReadinessStatus status;

  const _StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg, IconData icon) = switch (status) {
      ObjectiveReadinessStatus.strong => (
        Colors.green.withValues(alpha: 0.2),
        Colors.green.shade800,
        Icons.verified,
      ),
      ObjectiveReadinessStatus.building => (
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
        Icons.trending_up,
      ),
      ObjectiveReadinessStatus.notStarted => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        Icons.radio_button_unchecked,
      ),
      ObjectiveReadinessStatus.notAvailable => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        Icons.hourglass_empty,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
