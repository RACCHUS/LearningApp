import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/screens/settings/audio_settings_screen.dart';
import 'package:learning_pwa/services/audio_testing/audio_test_service.dart';
import 'package:learning_pwa/widgets/audio_settings/audio_quality_section.dart';

/// App-bar action that opens read-aloud preferences without leaving a lesson.
class AudioPreferencesAction extends StatelessWidget {
  const AudioPreferencesAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('audio-preferences-action'),
      icon: const Icon(Icons.tune),
      tooltip: 'Read-aloud settings',
      onPressed: () => AudioPreferencesSheet.show(context),
    );
  }
}

class AudioPreferencesSheet extends ConsumerStatefulWidget {
  const AudioPreferencesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const AudioPreferencesSheet(),
    );
  }

  @override
  ConsumerState<AudioPreferencesSheet> createState() =>
      _AudioPreferencesSheetState();
}

class _AudioPreferencesSheetState extends ConsumerState<AudioPreferencesSheet> {
  late final AudioTestService _testService = AudioTestService(ref);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(audioSettingsProvider);
    final notifier = ref.read(audioSettingsProvider.notifier);
    final audioState = ref.watch(audioStateProvider);
    final available = audioState.isAvailable;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Read aloud', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('audio-preferences-read-aloud'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.volume_up),
              title: const Text('Read aloud'),
              subtitle: Text(available
                  ? 'Speaker buttons read questions, answers, and text.'
                  : "This browser doesn't offer read aloud."),
              value: settings.isEnabled && available,
              onChanged: available ? (_) => notifier.toggleEnabled() : null,
            ),
            if (settings.isEnabled && available)
              AudioQualitySection(
                settings: settings,
                audioState: audioState,
                onSpeechRateChanged: notifier.setSpeechRate,
                onVolumeChanged: notifier.setVolume,
                onPitchChanged: notifier.setPitch,
                onPreferredVoiceChanged: notifier.setPreferredVoice,
                onLanguageChanged: notifier.setLanguage,
                onToggleAutoPlay: notifier.toggleAutoPlay,
                onToggleAutoReadQuestions: notifier.toggleAutoReadQuestions,
                onToggleAutoReadAnswers: notifier.toggleAutoReadAnswers,
                onTestAudio: _testService.testAudio,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AudioSettingsScreen(),
                  ));
                },
                icon: const Icon(Icons.settings_voice_outlined),
                label: const Text('Microphone and all audio settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
