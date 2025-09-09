import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/global_voice_command.dart';
import 'package:learning_pwa/providers/enhanced_audio_provider.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/hands_free_settings_provider.dart';
import 'package:learning_pwa/widgets/global_voice_indicator.dart';
import 'package:learning_pwa/widgets/hands_free_onboarding.dart';

/// Demo screen for testing hands-free functionality
class HandsFreeTestScreen extends ConsumerStatefulWidget {
  const HandsFreeTestScreen({super.key});

  @override
  ConsumerState<HandsFreeTestScreen> createState() => _HandsFreeTestScreenState();
}

class _HandsFreeTestScreenState extends ConsumerState<HandsFreeTestScreen> {
  final List<String> _testCommands = [
    'next',
    'previous', 
    'pause',
    'skip',
    'go to page 3',
    'show progress',
    'end lesson',
    'volume up',
    'faster',
    'go home',
    'my lessons',
    'find lesson javascript',
    'settings',
  ];

  String _lastRecognizedCommand = 'None';
  String _lastParsedCommand = 'None';
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    final audioState = ref.watch(enhancedAudioProvider);
    final globalVoiceState = ref.watch(globalVoiceProvider);
    final handsFreeSettings = ref.watch(handsFreeSettingsProvider);

    return Scaffold(
      appBar: const AppBarWithGlobalVoice(
        title: 'Hands-Free Test',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Cards
            _buildStatusCard('Audio Service Status', [
              'Available: ${audioState.isAvailable}',
              'Has Permissions: ${audioState.hasPermissions}',
              'Is Listening: ${audioState.isListening}',
              'Last Recognized: ${audioState.recognizedText ?? "None"}',
              'Confidence: ${audioState.confidence.toStringAsFixed(2)}',
            ]),
            
            const SizedBox(height: 16),
            
            _buildStatusCard('Global Voice Status', [
              'Enabled: ${globalVoiceState.isEnabled}',
              'Listening: ${globalVoiceState.isListening}',
              'Available: ${globalVoiceState.isAvailable}',
              'Status: ${globalVoiceState.statusMessage}',
              'Last Command: ${globalVoiceState.lastCommand?.phrase ?? "None"}',
            ]),
            
            const SizedBox(height: 16),
            
            _buildStatusCard('Hands-Free Settings', [
              'Default Mode: ${handsFreeSettings.defaultHandsFreeMode}',
              'Global Commands: ${handsFreeSettings.globalVoiceCommands}',
              'Auto Lesson: ${handsFreeSettings.autoLessonHandsFree}',
              'Voice Timeout: ${handsFreeSettings.voiceTimeout.inSeconds}s',
              'Confidence Threshold: ${handsFreeSettings.confidenceThreshold}',
            ]),
            
            const SizedBox(height: 24),
            
            // Test Commands Section
            Text(
              'Test Voice Commands',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Voice Test Controls
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isListening ? null : _startListening,
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  label: Text(_isListening ? 'Listening...' : 'Test Voice'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showOnboarding,
                  icon: const Icon(Icons.school),
                  label: const Text('Show Onboarding'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildStatusCard('Test Results', [
              'Last Recognized: $_lastRecognizedCommand',
              'Last Parsed: $_lastParsedCommand',
            ]),
            
            const SizedBox(height: 16),
            
            // Command List
            Text(
              'Available Commands to Test:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _testCommands.map((command) => Chip(
                label: Text(command),
                onDeleted: () => _testCommand(command),
                deleteIcon: const Icon(Icons.play_arrow, size: 18),
              )).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Global Voice Indicator
            const GlobalVoiceIndicator(),
          ],
        ),
      ),
      floatingActionButton: const GlobalVoiceFAB(heroTag: "testVoiceFAB"),
    );
  }

  Widget _buildStatusCard(String title, List<String> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item'),
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
    });

    try {
      final audioNotifier = ref.read(enhancedAudioProvider.notifier);
      
      // Start listening
      await audioNotifier.startListening(timeout: const Duration(seconds: 5));
      
      // Wait a bit for recognition
      await Future.delayed(const Duration(seconds: 6));
      
      // Get the last recognized text
      final recognizedText = audioNotifier.lastRecognizedText;
      
      setState(() {
        _lastRecognizedCommand = recognizedText ?? 'No speech detected';
      });
      
      // Try to parse as lesson command
      if (recognizedText != null) {
        final lessonCommand = VoiceCommand.parseCommand(recognizedText);
        final globalCommand = GlobalVoiceCommand.parseCommand(recognizedText);
        
        if (lessonCommand != null) {
          setState(() {
            _lastParsedCommand = 'Lesson: ${lessonCommand.phrase} (${lessonCommand.type})';
          });
        } else if (globalCommand != null) {
          setState(() {
            _lastParsedCommand = 'Global: ${globalCommand.phrase} (${globalCommand.type})';
          });
        } else {
          setState(() {
            _lastParsedCommand = 'No command recognized';
          });
        }
      }
      
    } catch (e) {
      setState(() {
        _lastRecognizedCommand = 'Error: $e';
        _lastParsedCommand = 'Error during parsing';
      });
    } finally {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _testCommand(String command) {
    // Test parsing the command directly
    final lessonCommand = VoiceCommand.parseCommand(command);
    final globalCommand = GlobalVoiceCommand.parseCommand(command);
    
    setState(() {
      _lastRecognizedCommand = command;
      if (lessonCommand != null) {
        _lastParsedCommand = 'Lesson: ${lessonCommand.phrase} (${lessonCommand.type})';
      } else if (globalCommand != null) {
        _lastParsedCommand = 'Global: ${globalCommand.phrase} (${globalCommand.type})';
      } else {
        _lastParsedCommand = 'No command recognized';
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tested: $command'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showOnboarding() {
    showHandsFreeOnboarding(context);
  }
}
