import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

/// Secondary review prompt.
///
/// Emphasis never scales with backlog size: 300 due items look exactly like 6,
/// only with a larger number. No red, no urgency, no debt framing.
class ReviewPrompt extends StatelessWidget {
  final int dueCount;

  const ReviewPrompt({super.key, required this.dueCount});

  @override
  Widget build(BuildContext context) {
    if (dueCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final noun = dueCount == 1 ? 'concept' : 'concepts';
    final minutes = (dueCount * 0.7).ceil().clamp(1, 999);

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
            onPressed: () => context.push('/review'),
            child: const Text('Review'),
          ),
        ),
      ],
    );
  }
}
