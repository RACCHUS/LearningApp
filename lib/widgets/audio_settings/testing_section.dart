import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/services/audio_testing/audio_test_service.dart';
import 'package:learning_pwa/widgets/audio_settings/troubleshooting_section.dart';

/// Widget that handles all testing functionality for voice and microphone
/// Provides a clean interface for running audio tests
class TestingSection extends ConsumerStatefulWidget {
  final bool canListen;
  final bool canSpeak;

  const TestingSection({
    super.key,
    required this.canListen,
    required this.canSpeak,
  });

  @override
  ConsumerState<TestingSection> createState() => _TestingSectionState();
}

class _TestingSectionState extends ConsumerState<TestingSection> {
  late AudioTestService _testService;

  @override
  void initState() {
    super.initState();
    _testService = AudioTestService(ref);
  }

  @override
  Widget build(BuildContext context) {
    // Show basic testing interface regardless of current state
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Input Test',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Test your microphone and voice commands here.'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _testVoiceCommands,
                  icon: const Icon(Icons.mic),
                  label: const Text('Test Voice Commands'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => TroubleshootingSection.showVoiceCommandHelp(context),
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

    if (command == null) {
      // Either permission failed or no command heard
      // Show listening dialog first
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Voice Command Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Say "next" or "hello" clearly'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_up, color: Colors.green, size: 16),
                    SizedBox(width: 4),
                    Text('Listening...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      // Wait and try again
      await Future.delayed(const Duration(milliseconds: 500));
      final retryCommand = await _testService.testVoiceCommands();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close listening dialog

      _showCommandResult(retryCommand);
    } else {
      _showCommandResult(command);
    }
  }

  void _showCommandResult(VoiceCommand? command) {
    if (!mounted) return;

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
}
