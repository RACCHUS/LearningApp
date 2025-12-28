import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/services/audio_testing/audio_test_service.dart';
import 'package:learning_pwa/widgets/audio_settings/audio_status_card.dart';
import 'package:learning_pwa/widgets/audio_settings/testing_section.dart';
import 'package:learning_pwa/widgets/audio_settings/audio_quality_section.dart';
import 'package:learning_pwa/widgets/audio_settings/troubleshooting_section.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() =>
      _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {
  late AudioTestService _testService;

  @override
  void initState() {
    super.initState();
    _testService = AudioTestService(ref);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(audioSettingsProvider);
    final settingsNotifier = ref.read(audioSettingsProvider.notifier);
    final audioState = ref.watch(audioStateProvider);
    final canSpeak = ref.watch(canSpeakProvider);
    final canListen = ref.watch(canListenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio availability status
          AudioStatusCard(
            canSpeak: canSpeak,
            canListen: canListen,
          ),

          const SizedBox(height: 16),

          // Voice recognition testing section - disables global voice during tests
          TestingSection(
            canListen: canListen,
            canSpeak: canSpeak,
          ),

          const SizedBox(height: 16),

          // Voice Commands Section (consolidated hands-free settings)
          _buildVoiceCommandsSection(ref),

          const SizedBox(height: 16),

          // Text-to-Speech Section
          _buildTextToSpeechSection(
              settings, settingsNotifier, canSpeak, audioState),

          // Show troubleshooting if no audio features are available
          if (!canSpeak && !canListen) ...[
            const SizedBox(height: 16),
            const TroubleshootingSection(),
          ],
        ],
      ),
    );
  }

  /// Build consolidated voice commands section
  Widget _buildVoiceCommandsSection(WidgetRef ref) {
    final globalVoiceState = ref.watch(globalVoiceProvider);
    final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);
    final handsFreeSettings = ref.watch(handsFreeSettingsProvider);
    final handsFreeNotifier = ref.read(handsFreeSettingsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.voice_chat,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Voice Commands',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Control the app with your voice',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // Main voice toggle - most important
            SwitchListTile(
              title: const Text('Enable Voice Commands'),
              subtitle: Text(globalVoiceState.isEnabled
                  ? 'Active - Say "go home", "settings", "help"'
                  : 'Off - Tap to enable voice control'),
              value: globalVoiceState.isEnabled,
              onChanged: globalVoiceState.isAvailable
                  ? (value) async {
                      if (value) {
                        await globalVoiceNotifier.enable();
                      } else {
                        await globalVoiceNotifier.disable();
                      }
                    }
                  : null,
              secondary: Icon(
                globalVoiceState.isEnabled ? Icons.mic : Icons.mic_off,
                color: globalVoiceState.isEnabled ? Colors.green : Colors.grey,
              ),
            ),

            // Status indicator when enabled
            if (globalVoiceState.isEnabled) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      globalVoiceState.isListening
                          ? Icons.hearing
                          : Icons.mic_none,
                      size: 20,
                      color: globalVoiceState.isListening
                          ? Colors.red
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        globalVoiceState.statusMessage,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: () => _showVoiceCommandHelp(ref),
                      tooltip: 'Voice command help',
                    ),
                  ],
                ),
              ),
            ],

            const Divider(),

            // Auto-start settings - grouped under "Startup Behavior"
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                'Startup Behavior',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),

            SwitchListTile(
              title: const Text('Auto-start with app'),
              subtitle: const Text(
                  'Enable voice commands automatically when opening the app'),
              value: handsFreeSettings.defaultHandsFreeMode,
              onChanged: (value) async {
                await handsFreeNotifier.toggleDefaultHandsFreeMode();
              },
              dense: true,
            ),

            SwitchListTile(
              title: const Text('Auto-start for lessons'),
              subtitle: const Text(
                  'Enable voice commands when you start studying a lesson'),
              value: handsFreeSettings.autoLessonHandsFree,
              onChanged: (value) async {
                await handsFreeNotifier.toggleAutoLessonHandsFree();
              },
              dense: true,
            ),

            // Setup button if not available
            if (!globalVoiceState.isAvailable) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Voice commands not available'),
                subtitle: const Text('Check microphone permissions'),
                trailing: ElevatedButton(
                  onPressed: () => globalVoiceNotifier.enable(),
                  child: const Text('Setup'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build text-to-speech settings section
  Widget _buildTextToSpeechSection(
    AudioSettings settings,
    AudioSettingsNotifier settingsNotifier,
    bool canSpeak,
    AudioState audioState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.volume_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Text-to-Speech',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Master toggle
                Switch(
                  value: settings.isEnabled,
                  onChanged: canSpeak
                      ? (value) => settingsNotifier.toggleEnabled()
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              settings.isEnabled
                  ? 'Audio playback is enabled'
                  : 'Audio playback is disabled',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (settings.isEnabled && canSpeak) ...[
              const SizedBox(height: 16),

              // Audio quality controls
              AudioQualitySection(
                settings: settings,
                audioState: audioState,
                onSpeechRateChanged: settingsNotifier.setSpeechRate,
                onVolumeChanged: settingsNotifier.setVolume,
                onPitchChanged: settingsNotifier.setPitch,
                onPreferredVoiceChanged: settingsNotifier.setPreferredVoice,
                onLanguageChanged: settingsNotifier.setLanguage,
                onToggleAutoPlay: settingsNotifier.toggleAutoPlay,
                onToggleAutoReadQuestions:
                    settingsNotifier.toggleAutoReadQuestions,
                onToggleAutoReadAnswers: settingsNotifier.toggleAutoReadAnswers,
                onTestAudio: _testService.testAudio,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show voice command help dialog
  void _showVoiceCommandHelp(WidgetRef ref) {
    final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);
    final helpText = globalVoiceNotifier.getContextualHelp();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Commands'),
        content: SingleChildScrollView(
          child: Text(helpText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
