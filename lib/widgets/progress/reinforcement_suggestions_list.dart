import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/providers/reinforcement_suggestions_provider.dart';
import 'package:learning_pwa/services/progress/reinforcement_suggestion_service.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// The Retention section's "needs reinforcement" list (UI spec §5.5): each
/// concept starts a targeted review of its due items. Optional by design
/// (§8): hiding one is silent, and nothing here nags or counts down.
///
/// Renders nothing while `learning.reinforcement_suggestions` is OFF, while
/// loading, on error, or when there is nothing to suggest.
class ReinforcementSuggestionsList extends ConsumerWidget {
  const ReinforcementSuggestionsList({super.key});

  static String reviewRoute(Iterable<String> contentIds) =>
      '/review?concepts=${contentIds.map(Uri.encodeQueryComponent).join(',')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(reinforcementSuggestionsFeatureEnabledProvider)) {
      return const SizedBox.shrink();
    }
    final all = ref.watch(reinforcementSuggestionsProvider).valueOrNull ?? const [];
    ref.watch(reinforcementDismissalsProvider);
    final dismissals = ref.read(reinforcementDismissalsProvider.notifier);
    final visible = all.where((s) => !dismissals.isHidden(s)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final withDue = visible.where((s) => s.hasDueItems).toList();

    Future<void> open(Iterable<String> ids) async {
      await context.push(reviewRoute(ids));
      ref.invalidate(reinforcementSuggestionsProvider);
    }

    return Column(
      key: const Key('reinforcement-suggestions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: DesignTokens.space6),
        Text('Needs reinforcement', style: theme.textTheme.titleSmall),
        const SizedBox(height: DesignTokens.space1),
        Text(
          'Optional. Concepts whose retrieval history is weakest.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        for (final s in visible)
          ListTile(
            key: Key('reinforce-${s.conceptId}'),
            contentPadding: EdgeInsets.zero,
            title: Text(s.name),
            subtitle: Text(_subtitle(s)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.hasDueItems)
                  TextButton(
                    key: Key('reinforce-review-${s.conceptId}'),
                    onPressed: () => open(s.dueContentIds),
                    child: const Text('Review'),
                  ),
                IconButton(
                  key: Key('reinforce-hide-${s.conceptId}'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Hide ${s.name}',
                  onPressed: () => dismissals.hide(s),
                ),
              ],
            ),
          ),
        if (withDue.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('reinforce-review-all'),
              icon: const Icon(Icons.replay, size: 18),
              label: Text('Review all ${withDue.length}'),
              onPressed: () => open({
                for (final s in withDue) ...s.dueContentIds,
              }.take(ReinforcementSuggestionService.maxItemsPerConcept * 2)),
            ),
          ),
      ],
    );
  }

  static String _subtitle(ReinforcementSuggestion s) {
    final confidence = switch (s.confidence) {
      ConceptConfidence.low => 'low confidence',
      ConceptConfidence.medium => 'medium confidence',
      ConceptConfidence.high => 'high confidence',
    };
    final n = s.dueContentIds.length;
    final due = n == 0 ? 'nothing due yet' : (n == 1 ? '1 item due' : '$n items due');
    return 'Needs reinforcement · $confidence · $due';
  }
}
