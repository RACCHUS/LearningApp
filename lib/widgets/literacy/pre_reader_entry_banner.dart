import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/providers/pre_reader_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/literacy/pre_reader_track_picker_dialog.dart';

/// A visual, voice-first choice on Learn. Only the explicit Start button
/// navigates; tapping surrounding homepage content must never open this path.
class PreReaderEntryBanner extends ConsumerWidget {
  const PreReaderEntryBanner({super.key});

  static const String entryInstructions =
      'Want to learn with pictures and spoken instructions? '
      'First tap the big A B C and picture button in this box. '
      'Next choose Adult or Kids. Then press the Start button. '
      'You can use the speaker to hear these steps again.';

  static const String continueInstructions =
      'You have already chosen your learning path. '
      'Tap the big picture button to continue learning. '
      'Tap the speaker to hear these instructions again.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = ref.watch(preReaderProvider);

    void openTrack() {
      if (profile.enabled) {
        context.go('/literacy');
      } else {
        PreReaderTrackPickerDialog.show(context);
      }
    }

    return Container(
      key: const Key('pre-reader-entry-card'),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
        border: Border.all(color: colors.primary, width: 2.5),
      ),
      padding: const EdgeInsets.all(DesignTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Distinctive, large visual anchors rather than a small ear icon.
          Row(
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('🔤', style: TextStyle(fontSize: 45)),
              ),
              const SizedBox(width: DesignTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.enabled
                          ? 'Continue Reading & Writing'
                          : 'Start Here: Learn to Read & Write',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '👂 Listen  •  👆 Tap  •  🖼️ Pictures',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space3),
          Text(
            profile.enabled
                ? 'Use pictures and sound to keep learning.'
                : 'No reading needed. Hear the steps, then choose Adult or Kids.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DesignTokens.space3),
          // Separate hit targets. Neither listening nor the background opens
          // the track; only this visible picture-and-action button does.
          FilledButton.icon(
            key: const Key('pre-reader-open-button'),
            onPressed: openTrack,
            icon: const Text('🔤 👆', style: TextStyle(fontSize: 26)),
            label: Text(
              profile.enabled ? 'Continue with Pictures' : 'Start with Pictures',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space2),
          OutlinedButton.icon(
            key: const Key('pre-reader-listen-button'),
            onPressed: () =>
                ref.read(preReaderProvider.notifier).speak(
                  profile.enabled ? continueInstructions : entryInstructions,
                ),
            icon: const Icon(Icons.volume_up_rounded, size: 34),
            label: const Text('🔊  HEAR HOW TO START'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(60),
              foregroundColor: colors.onSurface,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.primary, width: 2),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
