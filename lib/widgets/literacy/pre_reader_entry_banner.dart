import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';

/// Welcoming, high-contrast entry banner inviting non-literate learners
/// to start foundational literacy without needing to read instructions.
class PreReaderEntryBanner extends ConsumerWidget {
  const PreReaderEntryBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);

    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: InkWell(
        key: const Key('pre-reader-entry-card'),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        onTap: () {
          if (profile.enabled) {
            context.go('/literacy');
          } else {
            PreReaderTrackPickerDialog.show(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space4,
          ),
          child: Row(
            children: [
              // Pulsing audio icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hearing,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: DesignTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.enabled
                                ? 'Continue Reading & Writing'
                                : 'Start Here: Learn to Read & Write',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DesignTokens.space1),
                        Text(
                          profile.track == PreReaderTrack.youth ? '🎒' : '💼',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.enabled
                          ? 'Sound-to-letter matching, finger tracing & math'
                          : 'Tap to listen • No reading needed • Step-by-step',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up),
                tooltip: 'Listen to description',
                onPressed: () {
                  ref.read(preReaderProvider.notifier).speak(
                        'Welcome! Tap this card to learn how to read, write, and count from the very beginning.',
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
