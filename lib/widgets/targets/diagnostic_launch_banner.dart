import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/diagnostic_assessment_provider.dart';
import '../../theme/design_tokens.dart';

class DiagnosticLaunchBanner extends ConsumerWidget {
  final String targetId;
  final String targetTitle;
  final String targetVersionId;

  const DiagnosticLaunchBanner({
    super.key,
    required this.targetId,
    required this.targetTitle,
    required this.targetVersionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability =
        ref.watch(diagnosticAvailabilityProvider(targetVersionId));

    return availability.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (!result.isAvailable) return const SizedBox.shrink();

        final theme = Theme.of(context);
        return Card(
          key: const Key('diagnostic-launch-banner'),
          elevation: 0,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, color: theme.colorScheme.primary),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        'Optional diagnostic',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  'Use reviewed practice items to get a quick snapshot of '
                  'which concepts may need reinforcement before you begin.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: DesignTokens.space1),
                Text(
                  '${result.availableItemCount} eligible items across '
                  '${result.representedConceptCount} core concepts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
                FilledButton.tonalIcon(
                  key: const Key('start-diagnostic-pre-assessment-button'),
                  onPressed: () {
                    context.push(
                      '/target/$targetId/diagnostic/$targetVersionId',
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Take Diagnostic'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
