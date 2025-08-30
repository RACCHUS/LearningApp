import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/audio_provider.dart';

class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() => _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {
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
          
          // Microphone permissions section
          if (!canListen) ...[
            Card(
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
                          onPressed: () => _testMicrophone(),
                          icon: const Icon(Icons.mic),
                          label: const Text('Test Microphone'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showPermissionHelp(context),
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Help'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Voice input test for when it IS available
          if (canListen) ...[
            Card(
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
                          onPressed: () => _testVoiceCommands(),
                          icon: const Icon(Icons.mic),
                          label: const Text('Test Voice Commands'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showVoiceCommandHelp(context),
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Commands'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
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
                          onPressed: () => _testVoiceCommands(),
                          icon: const Icon(Icons.mic),
                          label: const Text('Test Voice Commands'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showVoiceCommandHelp(context),
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Commands'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
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
                  ? () => _testAudio()
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

  Future<void> _testMicrophone() async {
    final audioNotifier = ref.read(audioStateProvider.notifier);
    
    // Show dialog with microphone test
    if (mounted) {
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

    try {
      // First cancel any existing listening to ensure clean state
      await audioNotifier.cancelListening();
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (kDebugMode) {
        print('🎙️ Starting microphone test...');
      }
      
      // Try to start listening - just check if we can start, not if we get speech
      final success = await audioNotifier.startListening(
        timeout: const Duration(seconds: 2), // Short test
      );
      
      // Wait a moment to see if it actually starts listening
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Check the current state to see if we're actually listening
      final audioState = ref.read(audioStateProvider);
      final isActuallyListening = audioState.isListening;
      
      if (kDebugMode) {
        print('🎙️ Microphone test - startListening result: $success, isListening: $isActuallyListening');
      }
      
      // Stop listening
      await audioNotifier.cancelListening();
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Consider it successful if either startListening returned true OR we were actually listening
        final testSuccess = success || isActuallyListening;
        
        if (testSuccess) {
          // Since we successfully started listening, mark permissions as granted
          audioNotifier.setMicrophonePermissionGranted(true);
          
          if (kDebugMode) {
            print('🎙️ Microphone test succeeded - permissions granted');
          }
          
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
                    // Force a rebuild to update the UI state
                    setState(() {});
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          if (kDebugMode) {
            print('🎙️ Microphone test failed');
          }
          _showMicrophoneError(context);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Microphone test exception: $e');
      }
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showMicrophoneError(context);
      }
    }
  }

  void _showPermissionHelp(BuildContext context) {
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

  void _showMicrophoneError(BuildContext context) {
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
              _showPermissionHelp(context);
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

  Future<void> _testVoiceCommands() async {
    final audioNotifier = ref.read(audioStateProvider.notifier);
    
    // First ensure we can listen (this handles permissions)
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

    try {
      // First do a quick permission test
      await audioNotifier.cancelListening(); // Ensure clean state
      final canListen = await audioNotifier.startListening(timeout: const Duration(milliseconds: 500));
      await audioNotifier.cancelListening(); // Stop the test listen
      
      // Update permission state
      await audioNotifier.checkMicrophonePermissions();
      
      if (!canListen) {
        if (mounted) {
          Navigator.of(context).pop();
          _showMicrophoneError(context);
        }
        return;
      }
      
      // Now do the actual voice command test
      if (mounted) {
        Navigator.of(context).pop(); // Close permission dialog
        
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
                onPressed: () {
                  audioNotifier.cancelListening();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }

      // Wait a moment for dialog to show, then start listening
      await Future.delayed(const Duration(milliseconds: 500));
      
      final command = await audioNotifier.listenForCommand(
        timeout: const Duration(seconds: 5),
      );
      
      if (mounted) {
        Navigator.of(context).pop(); // Close listening dialog
        
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
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Voice Test Error'),
            content: Text('Error testing voice commands: $e\n\nTry:\n• Refreshing the page\n• Checking microphone permissions\n• Using a different browser'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showVoiceCommandHelp(BuildContext context) {
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

  void _testAudio() {
    final audioNotifier = ref.read(audioStateProvider.notifier);
    audioNotifier.speak(
      'This is a test of the text-to-speech functionality. '
      'Your audio settings are working correctly.',
    );
  }
}
