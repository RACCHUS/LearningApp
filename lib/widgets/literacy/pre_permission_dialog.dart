import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pre_reader_provider.dart';
import '../../theme/design_tokens.dart';

/// Spoken pre-permission dialog for audio/microphone requests.
///
/// Adheres to Section 5.2 of the Literacy Accessibility Plan:
/// Prior to invoking native OS or browser permission prompts (which are text-only),
/// this dialog explains the request in plain spoken language and guarantees a
/// 100% tap-only alternative so that microphone permissions are never a barrier.
class PrePermissionAudioDialog extends ConsumerStatefulWidget {
  final VoidCallback onAcceptMic;
  final VoidCallback onContinueTapOnly;

  const PrePermissionAudioDialog({
    super.key,
    required this.onAcceptMic,
    required this.onContinueTapOnly,
  });

  /// Helper to show the dialog
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onAcceptMic,
    required VoidCallback onContinueTapOnly,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PrePermissionAudioDialog(
        onAcceptMic: onAcceptMic,
        onContinueTapOnly: onContinueTapOnly,
      ),
    );
  }

  @override
  ConsumerState<PrePermissionAudioDialog> createState() =>
      _PrePermissionAudioDialogState();
}

class _PrePermissionAudioDialogState
    extends ConsumerState<PrePermissionAudioDialog> {
  static const String spokenPrompt =
      'To speak your answers out loud, tap the green button to turn on the microphone. '
      'Or, tap the button below to continue using tap only. You do not need a microphone to learn.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakInstructions();
    });
  }

  void _speakInstructions() {
    ref.read(preReaderAudioServiceProvider).speak(spokenPrompt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated Speaker Replay Button
              Center(
                child: InkWell(
                  onTap: _speakInstructions,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 38,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space3),

              Text(
                'Microphone Guidance',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space2),

              Text(
                'Would you like to speak your answers out loud?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space1),

              Container(
                padding: const EdgeInsets.all(DesignTokens.space2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Text(
                  '💡 Tap the big blue speaker above to hear instructions again.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),

              // Primary: Turn on Microphone
              FilledButton.icon(
                key: const Key('pre-permission-enable-mic'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.mic, size: 22),
                label: const Text(
                  'Turn On Microphone (Speak Answers)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAcceptMic();
                },
              ),
              const SizedBox(height: DesignTokens.space2),

              // Secondary: 100% Tap-Only Fallback Guarantee
              OutlinedButton.icon(
                key: const Key('pre-permission-tap-only'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.touch_app, size: 22),
                label: const Text(
                  'Continue with Tap Only (No Mic Needed)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onContinueTapOnly();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
