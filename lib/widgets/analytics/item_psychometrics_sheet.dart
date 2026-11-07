import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Interactive modal sheet displaying 2PL Item Response Theory (IRT) psychometrics,
/// Elo rating state, and calibration lifecycle status (ER-09a, ER-09b, OPP-3).
class ItemPsychometricsSheet extends StatelessWidget {
  final String itemId;
  final String itemPrompt;
  final ItemPsychometricStatus status;
  final IrtParameters2Pl? irtParameters;
  final VoidCallback? onClose;

  const ItemPsychometricsSheet({
    super.key,
    required this.itemId,
    required this.itemPrompt,
    required this.status,
    this.irtParameters,
    this.onClose,
  });

  /// Displays the psychometrics sheet in a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String itemId,
    required String itemPrompt,
    required ItemPsychometricStatus status,
    IrtParameters2Pl? irtParameters,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemPsychometricsSheet(
        itemId: itemId,
        itemPrompt: itemPrompt,
        status: status,
        irtParameters: irtParameters,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item Psychometrics & Calibration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Item ID: $itemId',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('item_psychometrics_close_button'),
                    icon: const Icon(Icons.close),
                    onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Item Prompt Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  itemPrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Status Badge
              _buildStatusBadge(context),
              const SizedBox(height: 16),

              // Parameters Grid
              _buildMetricsGrid(context),
              const SizedBox(height: 20),

              // Item Characteristic Curve (ICC) Preview
              if (irtParameters != null || status.status == 'calibrated')
                _buildIccPreview(context),

              const SizedBox(height: 16),

              // ER-09 Evidence-Based Learning Science Footnote
              _buildFootnote(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeTitle;
    String badgeSubtitle;

    switch (status.status) {
      case 'calibrated':
        badgeColor = Colors.green;
        badgeIcon = Icons.verified;
        badgeTitle = 'Calibrated 2PL IRT Item';
        badgeSubtitle = 'Empirical standard error meets pool-validated bound (SE ≤ 0.30).';
        break;
      case 'preliminary_elo_ordering':
        badgeColor = Colors.blue;
        badgeIcon = Icons.auto_graph;
        badgeTitle = 'Preliminary Elo Ordering';
        badgeSubtitle = 'Low-stakes heuristic sequencing; pending IRT parameter convergence.';
        break;
      case 'observed_uncalibrated':
        badgeColor = Colors.orange;
        badgeIcon = Icons.visibility;
        badgeTitle = 'Observed (Uncalibrated)';
        badgeSubtitle = 'Observation exists (N = ${status.observationCount}), but difficulty is uncalibrated.';
        break;
      case 'unobserved':
      default:
        badgeColor = Colors.grey;
        badgeIcon = Icons.help_outline;
        badgeTitle = 'Unobserved Item';
        badgeSubtitle = 'Zero observed interactions (N = 0).';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(badgeIcon, color: badgeColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  badgeSubtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final diffText = status.difficultyEstimate != null
        ? status.difficultyEstimate!.toStringAsFixed(2)
        : (irtParameters != null ? irtParameters!.difficulty.toStringAsFixed(2) : '--');

    final discText = status.discriminationEstimate != null
        ? status.discriminationEstimate!.toStringAsFixed(2)
        : (irtParameters != null ? irtParameters!.discrimination.toStringAsFixed(2) : '--');

    final seText = status.standardError != null
        ? '±${status.standardError!.toStringAsFixed(3)}'
        : (irtParameters?.standardError != null
            ? '±${irtParameters!.standardError!.toStringAsFixed(3)}'
            : '--');

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Observations (N)',
            value: '${status.observationCount}',
            colorScheme: colorScheme,
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Difficulty (b)',
            value: diffText,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Discrim. (a)',
            value: discText,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Std. Error (SE)',
            value: seText,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildIccPreview(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final params = irtParameters ??
        IrtParameters2Pl(
          discrimination: status.discriminationEstimate ?? 1.0,
          difficulty: status.difficultyEstimate ?? 0.0,
        );

    final abilityPoints = [-2.0, -1.0, 0.0, 1.0, 2.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Characteristic Curve (2PL ICC)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: abilityPoints.map((theta) {
              final prob = params.probability(theta);
              final pct = (prob * 100.0).round();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 55,
                      child: Text(
                        'θ = ${theta.toStringAsFixed(1)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: prob,
                          minHeight: 8,
                          backgroundColor: colorScheme.onSurface.withOpacity(0.1),
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$pct%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFootnote(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Evidence-Based Governance (ER-09a, ER-09b): Single observations only mark item existence; Elo ratings provide low-stakes heuristic ordering subject to adaptive bias and non-convergence (Bolsinova et al., 2026). Calibrated IRT status requires pool-validated SE ≤ 0.30 (König et al., 2020).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blueGrey[800],
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

