import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Web PWA user-gesture audio unlock banner.
///
/// Under browser autoplay security policies (W3C Web Audio API & SpeechSynthesis),
/// audio cannot play automatically upon initial page load without an explicit user gesture.
/// This banner provides an unmissable, friendly user gesture button that unlocks audio
/// and turns on automatic spoken navigation for non-readers.
class PwaAudioUnlockBanner extends ConsumerStatefulWidget {
  const PwaAudioUnlockBanner({super.key});

  @override
  ConsumerState<PwaAudioUnlockBanner> createState() =>
      _PwaAudioUnlockBannerState();
}

class _PwaAudioUnlockBannerState extends ConsumerState<PwaAudioUnlockBanner> {
  bool _hasUnlocked = false;

  void _unlockAudio() {
    setState(() {
      _hasUnlocked = true;
    });

    final audio = ref.read(preReaderAudioServiceProvider);
    audio.enablePreReaderDefaults();
    audio.speak(
        'Voice guidance is now active! Tap any card or button to listen.');
  }

  @override
  Widget build(BuildContext context) {
    // Only display when not yet unlocked and pre-reader mode is enabled
    final profile = ref.watch(preReaderProvider);
    if (!profile.enabled || _hasUnlocked) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space4,
        vertical: DesignTokens.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔊', style: TextStyle(fontSize: 28)),
          const SizedBox(width: DesignTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap to Turn On Voice Guidance',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Unlocks spoken sound in your web browser.',
                  style: TextStyle(
                    color: Colors.indigo.shade100,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.space2),
          ElevatedButton(
            key: const Key('pwa-audio-unlock-button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
            ),
            onPressed: _unlockAudio,
            child: const Text(
              'Listen ➔',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
