import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';

/// Widget that handles audio quality settings like speech rate, volume, pitch
/// Also includes voice selection and language settings
class AudioQualitySection extends ConsumerWidget {
  final AudioSettings settings;
  final AudioState audioState;
  final Function(double) onSpeechRateChanged;
  final Function(double) onVolumeChanged;
  final Function(double) onPitchChanged;
  final Function(String?) onPreferredVoiceChanged;
  final Function(String) onLanguageChanged;
  final VoidCallback onToggleAutoPlay;
  final VoidCallback onToggleAutoReadQuestions;
  final VoidCallback onToggleAutoReadAnswers;
  final VoidCallback onTestAudio;

  const AudioQualitySection({
    super.key,
    required this.settings,
    required this.audioState,
    required this.onSpeechRateChanged,
    required this.onVolumeChanged,
    required this.onPitchChanged,
    required this.onPreferredVoiceChanged,
    required this.onLanguageChanged,
    required this.onToggleAutoPlay,
    required this.onToggleAutoReadQuestions,
    required this.onToggleAutoReadAnswers,
    required this.onTestAudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Speech parameters
        _buildSpeechRateSlider(),
        _buildVolumeSlider(),
        _buildPitchSlider(),
        
        const Divider(),
        
        // Auto-play settings
        _buildAutoPlaySettings(),
        
        const Divider(),
        
        // Voice and language selection
        if (audioState.availableVoices.isNotEmpty) _buildVoiceSelection(),
        _buildLanguageSelection(),
        
        const Divider(),
        
        // Test button
        _buildTestButton(),
      ],
    );
  }

  Widget _buildSpeechRateSlider() {
    return ListTile(
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
          onChanged: settings.isEnabled ? onSpeechRateChanged : null,
        ),
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return ListTile(
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
          onChanged: settings.isEnabled ? onVolumeChanged : null,
        ),
      ),
    );
  }

  Widget _buildPitchSlider() {
    return ListTile(
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
          onChanged: settings.isEnabled ? onPitchChanged : null,
        ),
      ),
    );
  }

  Widget _buildAutoPlaySettings() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Auto-play Content'),
          subtitle: const Text('Automatically read content when displayed'),
          value: settings.autoPlay,
          onChanged: settings.isEnabled ? (_) => onToggleAutoPlay() : null,
        ),
        SwitchListTile(
          title: const Text('Auto-read Questions'),
          subtitle: const Text('Automatically read questions in quizzes'),
          value: settings.autoReadQuestions,
          onChanged: settings.isEnabled ? (_) => onToggleAutoReadQuestions() : null,
        ),
        SwitchListTile(
          title: const Text('Auto-read Answers'),
          subtitle: const Text('Automatically read answer options'),
          value: settings.autoReadAnswers,
          onChanged: settings.isEnabled ? (_) => onToggleAutoReadAnswers() : null,
        ),
      ],
    );
  }

  Widget _buildVoiceSelection() {
    return ListTile(
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
        onChanged: settings.isEnabled ? onPreferredVoiceChanged : null,
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return ListTile(
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
          ? (language) => language != null ? onLanguageChanged(language) : null
          : null,
      ),
    );
  }

  Widget _buildTestButton() {
    return ListTile(
      title: const Text('Test Audio'),
      subtitle: const Text('Test current audio settings'),
      trailing: ElevatedButton(
        onPressed: settings.isEnabled ? onTestAudio : null,
        child: const Text('Test'),
      ),
    );
  }
}
