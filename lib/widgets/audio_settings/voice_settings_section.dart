import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_settings.dart';

/// Widget that handles voice input and microphone testing
/// Shows different UI based on whether voice input is available
class VoiceSettingsSection extends ConsumerWidget {
  final bool canListen;
  final AudioSettings settings;
  final VoidCallback onTestMicrophone;
  final VoidCallback onTestVoiceCommands;
  final VoidCallback onShowPermissionHelp;
  final VoidCallback onShowVoiceCommandHelp;

  const VoiceSettingsSection({
    super.key,
    required this.canListen,
    required this.settings,
    required this.onTestMicrophone,
    required this.onTestVoiceCommands,
    required this.onShowPermissionHelp,
    required this.onShowVoiceCommandHelp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canListen) {
      return _buildMicrophoneRequiredCard(context);
    }

    return _buildVoiceReadyCard(context);
  }

  Widget _buildMicrophoneRequiredCard(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Microphone Access Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Voice commands require microphone access. Please enable microphone permissions in your browser settings.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onTestMicrophone,
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Microphone'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onShowPermissionHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceReadyCard(BuildContext context) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Voice Input Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Microphone permissions are granted. You can use voice commands.'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: onTestVoiceCommands,
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Voice Commands'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onShowVoiceCommandHelp,
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Commands'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
