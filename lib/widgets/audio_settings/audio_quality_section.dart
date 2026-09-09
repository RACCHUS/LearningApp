import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';

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
    // Filter voices by selected language
    final filteredVoices = audioState.availableVoiceInfos
        .where((v) => v.matchesLanguage(settings.language))
        .toList();

    if (filteredVoices.isEmpty && audioState.availableVoiceInfos.isEmpty) {
      return const SizedBox.shrink();
    }

    final voicesToShow =
        filteredVoices.isNotEmpty ? filteredVoices : audioState.availableVoiceInfos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Preferred Voice'),
          subtitle: Text(settings.preferredVoice ?? 'System Default'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String?>(
            value: voicesToShow.any((v) => v.name == settings.preferredVoice)
                ? settings.preferredVoice
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('System Default')),
              ...voicesToShow.map((voice) => DropdownMenuItem(
                    value: voice.name,
                    child: Text(
                      voice.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
            ],
            onChanged: settings.isEnabled ? onPreferredVoiceChanged : null,
          ),
        ),
        if (settings.preferredVoice != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: TextButton.icon(
              onPressed: settings.isEnabled
                  ? () {
                      final voice = audioState.availableVoiceInfos
                          .where((v) => v.name == settings.preferredVoice)
                          .firstOrNull;
                      if (voice != null) {
                        AudioService().previewVoice(voice);
                      }
                    }
                  : null,
              icon: const Icon(Icons.play_circle_outline, size: 20),
              label: const Text('Preview Voice'),
            ),
          ),
      ],
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
