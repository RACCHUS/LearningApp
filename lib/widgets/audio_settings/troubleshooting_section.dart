import 'package:flutter/material.dart';

/// Widget that displays troubleshooting information and help dialogs
/// Handles permission help, voice command help, and error messages
class TroubleshootingSection extends StatelessWidget {
  const TroubleshootingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }

  /// Show microphone permission help dialog
  static void showPermissionHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('To use voice commands, please:'),
              SizedBox(height: 12),
              Text('🔵 Chrome/Edge:'),
              Text('• Click the 🔒 lock icon in the address bar'),
              Text('• Change microphone to "Allow"'),
              Text('• Refresh the page and try again'),
              SizedBox(height: 12),
              Text('🔥 Firefox:'),
              Text('• Click the 🛡️ shield icon'),
              Text('• Allow microphone permissions'),
              Text('• Refresh the page and try again'),
              SizedBox(height: 12),
              Text('💡 When testing:'),
              Text('• Click "Allow" when prompted'),
              Text('• Speak clearly when indicator shows'),
              Text('• Make sure microphone is not muted'),
              SizedBox(height: 12),
              Text('📱 Mobile:'),
              Text('• Check browser settings'),
              Text('• Enable microphone for this site'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show voice command help dialog
  static void showVoiceCommandHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Commands'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Navigation Commands:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• "Next" - Move forward'),
              Text('• "Previous" - Move back'),
              Text('• "Repeat" - Repeat current'),
              Text('• "Pause" - Pause lesson'),
              SizedBox(height: 12),
              Text('Answer Commands:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• "A", "B", "C", "D" - Multiple choice'),
              Text('• "True" or "False" - True/false questions'),
              Text('• Speak naturally - Short answers'),
              SizedBox(height: 12),
              Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Speak clearly and loudly'),
              Text('• Wait for the "listening" indicator'),
              Text('• Try different phrasings if not recognized'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show microphone error dialog
  static void showMicrophoneError(BuildContext context, VoidCallback onTryAgain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Test Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_off, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Could not access microphone.'),
            const SizedBox(height: 8),
            const Text('This might be due to:'),
            const SizedBox(height: 8),
            const Text('• Permission denied'),
            const Text('• Microphone in use by another app'),
            const Text('• Browser not supported'),
            const Text('• Hardware issues'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text('🔧 Debugging tip:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Press F12 → Console tab to see detailed error messages'),
                  Text('Look for 🎙️ prefixed logs'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onTryAgain();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show microphone test success dialog
  static void showMicrophoneSuccess(BuildContext context, VoidCallback onOk) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Working!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green),
            SizedBox(height: 16),
            Text('Microphone access granted and working correctly.'),
            SizedBox(height: 8),
            Text('You can now use voice commands in lessons.'),
            SizedBox(height: 8),
            Text('The page will update to show voice features.', 
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show loading dialog for microphone test
  static void showMicrophoneTestDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Test'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('Testing microphone access...'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                children: [
                  Text('📋 This test will:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('1. Request microphone permission'),
                  Text('2. Try to start voice recognition'),
                  Text('3. Stop after 2 seconds (no speech needed)'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
