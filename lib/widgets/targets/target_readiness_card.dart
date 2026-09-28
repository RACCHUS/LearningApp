import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_concept_state.dart';
import '../../providers/target_readiness_provider.dart';
import '../../theme/design_tokens.dart';

/// Card displaying qualitative Target Readiness per Learning Architecture v2 §9.
///
/// Adheres strictly to Invariant 5:
/// Structural completion and Knowledge Readiness remain separate metrics
/// and are never merged into a single blended percentage.
class TargetReadinessCard extends ConsumerWidget {
  final String targetVersionId;

  const TargetReadinessCard({
    super.key,
    required this.targetVersionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readinessAsync = ref.watch(targetReadinessProvider(targetVersionId));
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space4),
        child: readinessAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.space3),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              'Readiness unavailable: $e',
              style: theme.textTheme.bodySmall,
            ),
          ),
          data: (readiness) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Knowledge Readiness',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _ReadinessBadge(band: readiness.band),
                  ],
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  readiness.totalCoreConcepts > 0
                      ? '${readiness.assessedConceptsCount} of ${readiness.totalCoreConcepts} core concepts assessed'
                      : 'No core concepts mapped to this curriculum version yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (readiness.totalCoreConcepts > 0) ...[
                  const SizedBox(height: DesignTokens.space3),
                  _DistributionBar(
                    distribution: readiness.bandDistribution,
                    total: readiness.totalCoreConcepts,
                  ),
                  const SizedBox(height: DesignTokens.space3),
                  Wrap(
                    spacing: DesignTokens.space2,
                    runSpacing: DesignTokens.space1,
                    children: [
                      _BandCountChip(
                        label: 'Well Established',
                        count: readiness.bandDistribution[RetrievalBand.wellEstablished] ?? 0,
                        color: Colors.green,
                      ),
                      _BandCountChip(
                        label: 'Well Retained',
                        count: readiness.bandDistribution[RetrievalBand.wellRetained] ?? 0,
                        color: Colors.teal,
                      ),
                      _BandCountChip(
                        label: 'Developing',
                        count: readiness.bandDistribution[RetrievalBand.developing] ?? 0,
                        color: Colors.blue,
                      ),
                      _BandCountChip(
                        label: 'Needs Reinforcement',
                        count: readiness.bandDistribution[RetrievalBand.needsReinforcement] ?? 0,
                        color: Colors.orange,
                      ),
                      _BandCountChip(
                        label: 'Not Assessed',
                        count: readiness.bandDistribution[RetrievalBand.unassessed] ?? 0,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: DesignTokens.space2),
                const Divider(),
                Text(
                  'Knowledge state is independent of structural course completion (Invariant 5).',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReadinessBadge extends StatelessWidget {
  final TargetReadinessBand band;

  const _ReadinessBadge({required this.band});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color bg, Color fg, IconData icon) = switch (band) {
      TargetReadinessBand.strongCoverage => (
          Colors.green.withValues(alpha: 0.2),
          Colors.green.shade800,
          Icons.verified,
        ),
      TargetReadinessBand.developing => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
          Icons.trending_up,
        ),
      TargetReadinessBand.needsReinforcement => (
          Colors.orange.withValues(alpha: 0.2),
          Colors.orange.shade900,
          Icons.build_circle_outlined,
        ),
      TargetReadinessBand.notYetAssessed => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant,
          Icons.schedule,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space2,
        vertical: DesignTokens.space1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            band.displayName,
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

class _DistributionBar extends StatelessWidget {
  final Map<RetrievalBand, int> distribution;
  final int total;

  const _DistributionBar({
    required this.distribution,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            _barSegment(distribution[RetrievalBand.wellEstablished] ?? 0, Colors.green),
            _barSegment(distribution[RetrievalBand.wellRetained] ?? 0, Colors.teal),
            _barSegment(distribution[RetrievalBand.developing] ?? 0, Colors.blue),
            _barSegment(distribution[RetrievalBand.needsReinforcement] ?? 0, Colors.orange),
            _barSegment(distribution[RetrievalBand.unassessed] ?? 0, Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _barSegment(int count, Color color) {
    if (count <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: count,
      child: Container(color: color),
    );
  }
}

class _BandCountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _BandCountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXs),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
