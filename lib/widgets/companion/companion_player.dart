import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/companion/learner_resource.dart';
import 'package:learning_pwa/models/companion/video_embed.dart';
import 'package:learning_pwa/providers/learner_resource_provider.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/theme/design_tokens.dart';
import 'package:learning_pwa/widgets/companion/embed_frame_stub.dart'
    if (dart.library.js_interop) 'package:learning_pwa/widgets/companion/embed_frame_web.dart';

/// What the in-app player is showing for one resource. Null: closed, and
/// nothing has been loaded from the provider.
class CompanionPlayback {
  const CompanionPlayback({this.startSeconds});
  final int? startSeconds;
}

final companionPlayerProvider = StateProvider.autoDispose
    .family<CompanionPlayback?, String>((ref, resourceId) => null);

/// The video id of [resource] when the in-app player may be offered for it:
/// the switch is on and its link is a single YouTube video.
String? embeddableVideoId(WidgetRef ref, LearnerResource resource) =>
    ref.watch(companionEmbedsEnabledProvider)
    ? VideoEmbed.youTubeId(resource.url)
    : null;

/// The offer to play here, shown in the companion's list while the player is
/// closed (companion plan v1.0 §7.3). Nothing is requested from the provider
/// until the learner taps play.
class CompanionPlayerOffer extends ConsumerWidget {
  const CompanionPlayerOffer({super.key, required this.resource});

  final LearnerResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (embeddableVideoId(ref, resource) == null ||
        ref.watch(companionPlayerProvider(resource.id)) != null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Future<void> open(String url) async {
      try {
        await ref.read(externalLinkLauncherProvider)(Uri.parse(url));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Column(
        key: const Key('companion_player_offer'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            key: const Key('companion_play_here'),
            onPressed: () =>
                ref.read(companionPlayerProvider(resource.id).notifier).state =
                    const CompanionPlayback(),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Play here (loads YouTube)'),
          ),
          const SizedBox(height: DesignTokens.space1),
          Text(
            'Playing here loads the video from YouTube, which will see that this device played it. '
            'LearningApp does not record what you watch, and playing a video never counts as studied. '
            "By playing, you agree to YouTube's Terms of Service.",
            key: const Key('companion_player_notice'),
            style: muted,
          ),
          Wrap(
            spacing: DesignTokens.space2,
            children: [
              TextButton(
                key: const Key('companion_player_terms'),
                onPressed: () => open(VideoEmbed.youTubeTermsUrl),
                child: const Text(
                  'YouTube Terms of Service (leaves LearningApp)',
                ),
              ),
              TextButton(
                key: const Key('companion_player_privacy'),
                onPressed: () => open(VideoEmbed.googlePrivacyUrl),
                child: const Text('Google Privacy Policy (leaves LearningApp)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The open player, pinned above the companion's parts so the video stays in
/// view while the learner reads what to look for and takes the checks below.
/// The provider's player is shown as it is: at least 200 by 200, with
/// nothing over it.
class CompanionPlayer extends ConsumerWidget {
  const CompanionPlayer({super.key, required this.resource});

  final LearnerResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = embeddableVideoId(ref, resource);
    final playback = ref.watch(companionPlayerProvider(resource.id));
    if (id == null || playback == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final screen = MediaQuery.sizeOf(context).height;
        final height = math.max(200.0, math.min(width * 9 / 16, screen * 0.45));
        return Column(
          key: const Key('companion_player'),
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: math.max(200.0, width),
              height: height,
              child: buildEmbedFrame(
                VideoEmbed.youTubeEmbedUri(
                  id,
                  startSeconds: playback.startSeconds,
                ),
                title: 'YouTube video player: ${resource.title}',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Playing from YouTube. LearningApp does not record what you watch.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('companion_player_close'),
                    onPressed: () =>
                        ref
                                .read(
                                  companionPlayerProvider(resource.id).notifier,
                                )
                                .state =
                            null,
                    child: const Text('Close player'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }
}
