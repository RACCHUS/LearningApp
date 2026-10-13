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
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.5),
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
              // High-visibility audio emblem
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                    // Distinguishing category badge to prevent learner confusion
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.record_voice_over_outlined,
                              size: 12,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                profile.enabled
                                    ? (profile.track == PreReaderTrack.youth
                                        ? 'ACTIVE: YOUTH TRACK 🎒'
                                        : 'ACTIVE: ADULT TRACK 💼')
                                    : 'NON-READER & SPOKEN TRACK',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
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
                    const SizedBox(height: 2),
                    Text(
                      profile.enabled
                          ? 'Letter sounds, finger tracing & everyday numbers'
                          : 'No reading required • 100% voice & picture guided',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesignTokens.space2),
              // Prominent dedicated Listen button
              FilledButton.tonalIcon(
                key: const Key('pre-reader-listen-button'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                  ),
                ),
                icon: const Icon(Icons.volume_up, size: 18),
                label: const Text('Listen'),
                onPressed: () {
                  ref.read(preReaderProvider.notifier).speak(
                        'Welcome! This is the spoken learning track. Tap anywhere on this card to learn how to read, write, and count using pictures and voice, with no reading required.',
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
