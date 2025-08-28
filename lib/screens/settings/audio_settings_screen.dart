import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';

class AudioSettingsScreen extends ConsumerWidget {
  const AudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Features Status',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        canSpeak ? Icons.check_circle : Icons.error,
                        color: canSpeak ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Text-to-Speech: ${canSpeak ? 'Available' : 'Not Available'}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        canListen ? Icons.check_circle : Icons.error,
                        color: canListen ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text('Voice Input: ${canListen ? 'Available' : 'Not Available'}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Audio enabled toggle
          SwitchListTile(
            title: const Text('Enable Audio Features'),
            subtitle: const Text('Turn on/off all audio functionality'),
            value: settings.isEnabled,
            onChanged: canSpeak ? (value) => settingsNotifier.toggleEnabled() : null,
          ),
          
          const Divider(),
          
          // Speech settings
          if (canSpeak) ...[
            ListTile(
              title: const Text('Speech Rate'),
              subtitle: Text('${settings.speechRate}x speed'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.speechRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${settings.speechRate}x',
                  onChanged: settings.isEnabled 
                    ? (value) => settingsNotifier.setSpeechRate(value)
                    : null,
                ),
              ),
            ),
            
            ListTile(
              title: const Text('Volume'),
              subtitle: Text('${(settings.volume * 100).round()}%'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(settings.volume * 100).round()}%',
                  onChanged: settings.isEnabled 
                    ? (value) => settingsNotifier.setVolume(value)
                    : null,
                ),
              ),
            ),
            
            ListTile(
              title: const Text('Pitch'),
              subtitle: Text('${settings.pitch}x'),
              trailing: SizedBox(
                width: 200,
                child: Slider(
                  value: settings.pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${settings.pitch}x',
                  onChanged: settings.isEnabled 
                    ? (value) => settingsNotifier.setPitch(value)
                    : null,
                ),
              ),
            ),
            
            const Divider(),
            
            // Auto-play settings
            SwitchListTile(
              title: const Text('Auto-play Content'),
              subtitle: const Text('Automatically read content when displayed'),
              value: settings.autoPlay,
              onChanged: settings.isEnabled 
                ? (value) => settingsNotifier.toggleAutoPlay()
                : null,
            ),
            
            SwitchListTile(
              title: const Text('Auto-read Questions'),
              subtitle: const Text('Automatically read questions in quizzes'),
              value: settings.autoReadQuestions,
              onChanged: settings.isEnabled 
                ? (value) => settingsNotifier.toggleAutoReadQuestions()
                : null,
            ),
            
            SwitchListTile(
              title: const Text('Auto-read Answers'),
              subtitle: const Text('Automatically read answer options'),
              value: settings.autoReadAnswers,
              onChanged: settings.isEnabled 
                ? (value) => settingsNotifier.toggleAutoReadAnswers()
                : null,
            ),
            
            const Divider(),
            
            // Voice selection
            if (audioState.availableVoices.isNotEmpty) ...[
              ListTile(
                title: const Text('Preferred Voice'),
                subtitle: Text(settings.preferredVoice ?? 'Default'),
                trailing: DropdownButton<String?>(
                  value: settings.preferredVoice,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Default')),
                    ...audioState.availableVoices.map((voice) => 
                      DropdownMenuItem(value: voice, child: Text(voice))
                    ),
                  ],
                  onChanged: settings.isEnabled 
                    ? (voice) => settingsNotifier.setPreferredVoice(voice)
                    : null,
                ),
              ),
            ],
            
            ListTile(
              title: const Text('Language'),
              subtitle: Text(settings.language),
              trailing: DropdownButton<String>(
                value: settings.language,
                items: const [
                  DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                  DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                  DropdownMenuItem(value: 'es-ES', child: Text('Spanish')),
                  DropdownMenuItem(value: 'fr-FR', child: Text('French')),
                  DropdownMenuItem(value: 'de-DE', child: Text('German')),
                ],
                onChanged: settings.isEnabled 
                  ? (language) => language != null ? settingsNotifier.setLanguage(language) : null
                  : null,
              ),
            ),
            
            const Divider(),
            
            // Test buttons
            ListTile(
              title: const Text('Test Audio'),
              subtitle: const Text('Test current audio settings'),
              trailing: ElevatedButton(
                onPressed: settings.isEnabled 
                  ? () => _testAudio(ref)
                  : null,
                child: const Text('Test'),
              ),
            ),
          ],
          
          if (!canSpeak && !canListen) ...[
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Audio Not Available',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Audio features are not supported on this device or browser. '
                      'Try using a supported browser like Chrome, Firefox, or Edge.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _testAudio(WidgetRef ref) {
    final audioNotifier = ref.read(audioStateProvider.notifier);
    audioNotifier.speak(
      'This is a test of the text-to-speech functionality. '
      'Your audio settings are working correctly.',
    );
  }
}
