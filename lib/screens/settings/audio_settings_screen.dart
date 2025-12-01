import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/services/audio_testing/audio_test_service.dart';
import 'package:learning_pwa/widgets/audio_settings/audio_status_card.dart';
import 'package:learning_pwa/widgets/audio_settings/voice_settings_section.dart';
import 'package:learning_pwa/widgets/audio_settings/audio_quality_section.dart';
import 'package:learning_pwa/widgets/audio_settings/troubleshooting_section.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
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
          
          // Voice input section - shows different UI based on microphone access
          VoiceSettingsSection(
            canListen: canListen,
            settings: settings,
            onTestMicrophone: _testMicrophone,
            onTestVoiceCommands: _testVoiceCommands,
            onShowPermissionHelp: () => TroubleshootingSection.showPermissionHelp(context),
            onShowVoiceCommandHelp: () => TroubleshootingSection.showVoiceCommandHelp(context),
          ),
          
          const SizedBox(height: 16),
          
          // Hands-Free Settings Section
          _buildHandsFreeSection(ref),
          
          const SizedBox(height: 16),
          
          // Audio enabled toggle
          SwitchListTile(
            title: const Text('Enable Audio Features'),
            subtitle: const Text('Turn on/off all audio functionality'),
            value: settings.isEnabled,
            onChanged: canSpeak ? (value) => settingsNotifier.toggleEnabled() : null,
          ),
          
          const Divider(),
          
          // Audio quality and settings - only show if speech is available
          if (canSpeak) 
            AudioQualitySection(
              settings: settings,
              audioState: audioState,
              onSpeechRateChanged: settingsNotifier.setSpeechRate,
              onVolumeChanged: settingsNotifier.setVolume,
              onPitchChanged: settingsNotifier.setPitch,
              onPreferredVoiceChanged: settingsNotifier.setPreferredVoice,
              onLanguageChanged: settingsNotifier.setLanguage,
              onToggleAutoPlay: settingsNotifier.toggleAutoPlay,
              onToggleAutoReadQuestions: settingsNotifier.toggleAutoReadQuestions,
              onToggleAutoReadAnswers: settingsNotifier.toggleAutoReadAnswers,
              onTestAudio: _testService.testAudio,
            ),
          
          // Show troubleshooting if no audio features are available
          if (!canSpeak && !canListen) ...[
            const SizedBox(height: 16),
            const TroubleshootingSection(),
          ],
        ],
      ),
    );
  }

  Future<void> _testMicrophone() async {
    if (!mounted) return;

    TroubleshootingSection.showMicrophoneTestDialog(context);

    final success = await _testService.testMicrophone();

    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (success) {
      TroubleshootingSection.showMicrophoneSuccess(context, () {
        // Force a rebuild to update the UI state
        setState(() {});
      });
    } else {
      TroubleshootingSection.showMicrophoneError(context, () {
        TroubleshootingSection.showPermissionHelp(context);
      });
    }
  }

  Future<void> _testVoiceCommands() async {
    if (!mounted) return;

    // First show permission dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Voice Command Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Preparing voice recognition...'),
            const SizedBox(height: 8),
            const Text('Try saying one of these commands:', 
              style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('"next", "A", "B", "C", "D", "true", "false"', 
              style: TextStyle(fontSize: 14, color: Colors.green)),
            const SizedBox(height: 8),
            const Text('If prompted, click "Allow" for microphone access.', 
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );

    final command = await _testService.testVoiceCommands();

    if (!mounted) return;
    Navigator.of(context).pop(); // Close permission dialog

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(command != null ? '✅ Command Recognized!' : '❌ No Command Heard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              command != null ? Icons.check_circle : Icons.error,
              size: 48,
              color: command != null ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              command != null 
                ? 'Successfully heard: "${command.phrase}"\nRecognized as: ${command.type} command'
                : 'No speech was detected. This could be due to:\n\n• Speaking too quietly\n• Background noise\n• Microphone issues\n• Browser compatibility'
            ),
          ],
        ),
        actions: [
          if (command == null) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _testVoiceCommands(); // Retry
              },
              child: const Text('Try Again'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Build hands-free settings section
  Widget _buildHandsFreeSection(WidgetRef ref) {
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
                  'Hands-Free Mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Global voice toggle
            SwitchListTile(
              title: const Text('Enable Global Voice Commands'),
              subtitle: Text(
                globalVoiceState.isEnabled 
                  ? 'Voice commands work anywhere in the app'
                  : 'Tap to enable "go home", "settings", etc.'
              ),
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
            ),
            
            const Divider(),
            
            // Auto-enable setting
            SwitchListTile(
              title: const Text('Enable hands-free by default'),
              subtitle: const Text(
                'Automatically enable voice commands when the app starts'
              ),
              value: handsFreeSettings.defaultHandsFreeMode,
              onChanged: (value) async {
                await handsFreeNotifier.toggleDefaultHandsFreeMode();
              },
            ),
            
            // Auto lesson hands-free setting
            SwitchListTile(
              title: const Text('Auto hands-free for lessons'),
              subtitle: const Text(
                'Automatically enable voice commands when starting lessons'
              ),
              value: handsFreeSettings.autoLessonHandsFree,
              onChanged: (value) async {
                await handsFreeNotifier.toggleAutoLessonHandsFree();
              },
            ),
            
            // Status info
            if (globalVoiceState.isEnabled) ...[
              const Divider(),
              ListTile(
                leading: Icon(
                  globalVoiceState.isListening ? Icons.mic : Icons.mic_off,
                  color: globalVoiceState.isListening ? Colors.red : Colors.grey,
                ),
                title: Text(globalVoiceState.statusMessage),
                subtitle: const Text('Say "go home", "settings", "help"'),
                trailing: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showVoiceCommandHelp(ref),
                ),
              ),
            ],
            
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
