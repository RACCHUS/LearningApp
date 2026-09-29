import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Secondary review prompt.
///
/// Emphasis never scales with backlog size: 300 due items look exactly like 6,
/// only with a larger number. No red, no urgency, no debt framing.
class ReviewPrompt extends ConsumerWidget {
  final int dueCount;
  final String? contextId;

  const ReviewPrompt({
    super.key,
    required this.dueCount,
    this.contextId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dueCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final noun = dueCount == 1 ? 'concept' : 'concepts';
    final minutes = (dueCount * 0.7).ceil().clamp(1, 999);

    final activeId = ref.watch(learningContextsProvider).active?.id;
    final effectiveContextId = contextId ?? activeId;
    final route = effectiveContextId != null && effectiveContextId.isNotEmpty
        ? '/review?contextId=$effectiveContextId'
        : '/review';

    return Column(
      key: const Key('review-prompt'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$dueCount $noun ready for review · ~$minutes min',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: DesignTokens.space3),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('review-action'),
            onPressed: () => context.push(route),
            child: const Text('Review'),
          ),
        ),
      ],
    );
  }
}
