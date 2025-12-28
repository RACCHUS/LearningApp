import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_lesson_provider.dart';
import 'package:learning_pwa/providers/audio_playback_provider.dart';
import 'package:learning_pwa/services/audio_lesson_orchestrator.dart';

class HandsFreeIndicator extends ConsumerWidget {
  const HandsFreeIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHandsFreeEnabled = ref.watch(handsFreeModeProvider);
    final isLessonActive = ref.watch(isAudioLessonActiveProvider);
    final lessonState = ref.watch(audioLessonStateProvider);
    final lessonInfo = ref.watch(audioLessonInfoProvider);

    if (!isHandsFreeEnabled || !isLessonActive) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(context, lessonState),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getBorderColor(context, lessonState),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(lessonState),
            size: 16,
            color: _getIconColor(context, lessonState),
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(lessonState, lessonInfo),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getTextColor(context, lessonState),
            ),
          ),
          if (lessonState == AudioLessonState.reading ||
              lessonState == AudioLessonState.processing) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getIconColor(context, lessonState),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor(BuildContext context, AudioLessonState state) {
    final theme = Theme.of(context);
    switch (state) {
      case AudioLessonState.reading:
        return theme.colorScheme.primaryContainer;
      case AudioLessonState.waitingForVoice:
        return theme.colorScheme.secondaryContainer;
      case AudioLessonState.processing:
        return theme.colorScheme.tertiaryContainer;
      case AudioLessonState.paused:
        return theme.colorScheme.surfaceContainerHighest;
      case AudioLessonState.error:
        return theme.colorScheme.errorContainer;
      case AudioLessonState.completed:
        return theme.colorScheme.surfaceContainerHighest;
      default:
        return theme.colorScheme.surface;
    }
  }

  Color _getBorderColor(BuildContext context, AudioLessonState state) {
    final theme = Theme.of(context);
    switch (state) {
      case AudioLessonState.reading:
        return theme.colorScheme.primary;
      case AudioLessonState.waitingForVoice:
        return theme.colorScheme.secondary;
      case AudioLessonState.processing:
        return theme.colorScheme.tertiary;
      case AudioLessonState.paused:
        return theme.colorScheme.outline;
      case AudioLessonState.error:
        return theme.colorScheme.error;
      case AudioLessonState.completed:
        return theme.colorScheme.outline;
      default:
        return theme.colorScheme.outline;
    }
  }

  Color _getIconColor(BuildContext context, AudioLessonState state) {
    final theme = Theme.of(context);
    switch (state) {
      case AudioLessonState.reading:
        return theme.colorScheme.onPrimaryContainer;
      case AudioLessonState.waitingForVoice:
        return theme.colorScheme.onSecondaryContainer;
      case AudioLessonState.processing:
        return theme.colorScheme.onTertiaryContainer;
      case AudioLessonState.paused:
        return theme.colorScheme.onSurfaceVariant;
      case AudioLessonState.error:
        return theme.colorScheme.onErrorContainer;
      case AudioLessonState.completed:
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.onSurface;
    }
  }

  Color _getTextColor(BuildContext context, AudioLessonState state) {
    return _getIconColor(context, state);
  }

  IconData _getIcon(AudioLessonState state) {
    switch (state) {
      case AudioLessonState.reading:
        return Icons.volume_up;
      case AudioLessonState.waitingForVoice:
        return Icons.mic;
      case AudioLessonState.processing:
        return Icons.mic;
      case AudioLessonState.paused:
        return Icons.pause;
      case AudioLessonState.error:
        return Icons.error;
      case AudioLessonState.completed:
        return Icons.check_circle;
      default:
        return Icons.mic;
    }
  }

  String _getStatusText(
      AudioLessonState state, Map<String, dynamic> lessonInfo) {
    final currentIndex = lessonInfo['currentIndex'] as int;
    final totalContent = lessonInfo['totalContent'] as int;
    final progressText =
        totalContent > 0 ? '${currentIndex + 1}/$totalContent' : '';

    switch (state) {
      case AudioLessonState.reading:
        return 'Reading $progressText';
      case AudioLessonState.waitingForVoice:
        return 'Listening $progressText';
      case AudioLessonState.processing:
        return 'Processing $progressText';
      case AudioLessonState.paused:
        return 'Paused $progressText';
      case AudioLessonState.error:
        return 'Error';
      case AudioLessonState.completed:
        return 'Completed';
      default:
        return 'Hands-Free $progressText';
    }
  }
}

class HandsFreeModeToggle extends ConsumerWidget {
  const HandsFreeModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(handsFreeModeProvider);
    final settingsNotifier = ref.read(audioLessonSettingsProvider.notifier);

    return ListTile(
      leading: Icon(
        isEnabled ? Icons.record_voice_over : Icons.touch_app,
        color: isEnabled ? Theme.of(context).colorScheme.primary : null,
      ),
      title: const Text('Hands-Free Mode'),
      subtitle: Text(
        isEnabled
            ? 'Voice navigation and auto-reading enabled'
            : 'Touch controls required',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (_) async {
          // If enabling hands-free mode, request permissions first
          if (!isEnabled) {
            final audioNotifier = ref.read(audioPlaybackProvider.notifier);

            if (kDebugMode) {
              print(
                  '🎙️ Requesting microphone permissions for hands-free mode...');
            }

            final permissionsGranted =
                await audioNotifier.requestMicrophonePermissions();

            if (!permissionsGranted) {
              if (kDebugMode) {
                print(
                    '❌ Microphone permissions denied - hands-free mode not enabled');
              }
              // Show user feedback about permission requirement
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Microphone permission required for hands-free mode'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              return;
            }

            if (kDebugMode) {
              print('✅ Microphone permissions granted for hands-free mode');
            }
          }

          // Toggle hands-free mode
          settingsNotifier.toggleHandsFreeMode();
        },
      ),
    );
  }
}

class AudioLessonProgressIndicator extends ConsumerWidget {
  const AudioLessonProgressIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonInfo = ref.watch(audioLessonInfoProvider);
    final isActive = lessonInfo['isActive'] as bool;

    if (!isActive) {
      return const SizedBox.shrink();
    }

    final currentIndex = lessonInfo['currentIndex'] as int;
    final totalContent = lessonInfo['totalContent'] as int;
    final progress = totalContent > 0 ? (currentIndex + 1) / totalContent : 0.0;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 4),
        Text(
          '${currentIndex + 1} of $totalContent',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class VoiceCommandHelpDialog extends StatelessWidget {
  final String? context;

  const VoiceCommandHelpDialog({super.key, this.context});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Voice Commands'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCommandSection('Navigation', [
              'Next - Move to next content',
              'Previous - Go back to previous content',
              'Repeat - Repeat current content',
              'First - Go to first content',
              'Last - Go to last content',
              'Go to page [number] - Jump to specific page',
            ]),
            const SizedBox(height: 16),
            _buildCommandSection('Lesson Control', [
              'Pause - Pause the lesson',
              'Play/Resume - Start or resume playback',
              'Stop - Stop the lesson',
              'Skip - Skip current content',
              'End lesson - Complete and exit lesson',
            ]),
            const SizedBox(height: 16),
            _buildCommandSection('Audio Control', [
              'Faster - Increase speech speed',
              'Slower - Decrease speech speed',
              'Volume up - Increase volume',
              'Volume down - Decrease volume',
            ]),
            const SizedBox(height: 16),
            _buildCommandSection('Information', [
              'Show progress - Hear current progress',
              'Where am I - Get current position',
            ]),
            const SizedBox(height: 16),
            _buildCommandSection('Answers', [
              'Multiple choice: Say "choose A", "choose B", etc.',
              'Also works: "first", "second", "option A"',
              'True/false: Say "true" or "false"',
              'Short answer: Speak your answer clearly',
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildCommandSection(String title, List<String> commands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...commands.map((command) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• $command'),
            )),
      ],
    );
  }
}
