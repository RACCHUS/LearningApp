import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Card presenting non-coercive, evidence-based recommendations adhering to the Coach Principle (ECO-11).
class CoachRecommendationsCard extends StatefulWidget {
  final List<CoachRecommendation> recommendations;
  final void Function(CoachRecommendation recommendation)? onAction;
  final void Function(CoachRecommendation recommendation)? onDismiss;

  const CoachRecommendationsCard({
    super.key,
    required this.recommendations,
    this.onAction,
    this.onDismiss,
  });

  @override
  State<CoachRecommendationsCard> createState() => _CoachRecommendationsCardState();
}

class _CoachRecommendationsCardState extends State<CoachRecommendationsCard> {
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.recommendations
        .where((r) => !_dismissedIds.contains(r.id))
        .toList();

    if (active.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('coach_recommendations_card'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coach Recommendations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Evidence-based suggestions (Coach Principle: always optional)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Recommendation items
            ...active.map((rec) => _buildRecommendationTile(context, rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationTile(BuildContext context, CoachRecommendation rec) {
    final theme = Theme.of(context);

    Color badgeBg;
    Color badgeFg;
    IconData icon;

    switch (rec.urgency) {
      case RecommendationUrgency.immediateReview:
        badgeBg = Colors.amber.shade100;
        badgeFg = Colors.amber.shade900;
        icon = Icons.restore;
        break;
      case RecommendationUrgency.misconceptionRemediation:
        badgeBg = Colors.orange.shade100;
        badgeFg = Colors.orange.shade900;
        icon = Icons.psychology;
        break;
      case RecommendationUrgency.enrichment:
        badgeBg = Colors.green.shade100;
        badgeFg = Colors.green.shade900;
        icon = Icons.trending_up;
        break;
    }

    return Container(
      key: Key('rec_tile_${rec.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeFg.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 12, color: badgeFg),
                    const SizedBox(width: 4),
                    Text(
                      rec.urgency.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('rec_dismiss_button_${rec.id}'),
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Dismiss recommendation',
                onPressed: () {
                  setState(() {
                    _dismissedIds.add(rec.id);
                  });
                  widget.onDismiss?.call(rec);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rec.headline,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rec.rationale,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: Key('rec_action_button_${rec.id}'),
                onPressed: () => widget.onAction?.call(rec),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_getActionLabel(rec.recommendedAction)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'review_flashcards':
        return 'Review Memory Flashcards';
      case 'practice_items':
        return 'Practice Target Concept';
      case 'watch_video':
        return 'Watch Interactive Video';
      default:
        return 'Explore Resource';
    }
  }
}
