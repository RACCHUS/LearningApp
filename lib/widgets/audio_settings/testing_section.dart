import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/global_voice_command.dart';
import 'package:learning_pwa/providers/global_voice_provider.dart';
import 'package:learning_pwa/providers/audio_provider.dart';
import 'package:learning_pwa/widgets/audio_settings/troubleshooting_section.dart';

/// Widget that handles all testing functionality for voice and microphone
/// Provides a clean interface for running audio tests with detailed feedback
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
  bool _isTesting = false;
  bool _wasGlobalVoiceEnabled = false;
  
  // Test history for analysis
  final List<_VoiceTestResult> _testHistory = [];
  static const int _maxHistoryItems = 10;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Voice Recognition Test',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (_isTesting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                        const SizedBox(width: 4),
                        Text('Testing', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Test your microphone and see exactly what commands are recognized.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            
            // Test controls
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _startVoiceTest,
                  icon: Icon(_isTesting ? Icons.mic : Icons.mic_none),
                  label: Text(_isTesting ? 'Listening...' : 'Start Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTesting ? Colors.grey : Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isTesting)
                  TextButton.icon(
                    onPressed: _stopTest,
                    icon: const Icon(Icons.stop, color: Colors.red),
                    label: const Text('Stop', style: TextStyle(color: Colors.red)),
                  )
                else
                  TextButton.icon(
                    onPressed: _testHistory.isNotEmpty ? _clearHistory : null,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => TroubleshootingSection.showVoiceCommandHelp(context),
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('Commands'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Test history / results
            if (_testHistory.isNotEmpty) ...[
              Text(
                'Recognition Results',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: _testHistory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _testHistory[_testHistory.length - 1 - index]; // Newest first
                    return _buildResultTile(result);
                  },
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.mic_none, size: 32, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'Press "Start Test" and speak',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Global voice commands are disabled during testing',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(_VoiceTestResult result) {
    final hasCommand = result.lessonCommand != null || result.globalCommand != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp and raw text
          Row(
            children: [
              Icon(
                hasCommand ? Icons.check_circle : Icons.warning_amber,
                size: 16,
                color: hasCommand ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '"${result.rawText}"',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _formatTime(result.timestamp),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          
          // Confidence
          Row(
            children: [
              const SizedBox(width: 24),
              Text(
                'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.grey.shade300,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: result.confidence.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: result.confidence > 0.7 
                          ? Colors.green 
                          : result.confidence > 0.4 
                              ? Colors.orange 
                              : Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Parsed commands
          if (result.lessonCommand != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Lesson: ${result.lessonCommand!.type.name}',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                  ),
                ),
              ],
            ),
          ],
          if (result.globalCommand != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Global: ${result.globalCommand!.type.name}',
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade800),
                  ),
                ),
                if (result.globalCommand!.parameters.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '→ ${result.globalCommand!.parameters}',
                    style: TextStyle(fontSize: 11, color: Colors.purple.shade600),
                  ),
                ],
              ],
            ),
          ],
          if (!hasCommand && result.rawText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 24),
                Text(
                  'Not recognized as a command',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Future<void> _startVoiceTest() async {
    if (_isTesting) return;

    // Disable global voice commands during test
    final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);
    final globalVoiceState = ref.read(globalVoiceProvider);
    _wasGlobalVoiceEnabled = globalVoiceState.isEnabled;
    
    if (_wasGlobalVoiceEnabled) {
      await globalVoiceNotifier.disable();
    }

    setState(() {
      _isTesting = true;
    });

    try {
      final audioNotifier = ref.read(audioStateProvider.notifier);
      
      // Request permissions first
      final hasPermissions = await audioNotifier.requestMicrophonePermissions();
      if (!hasPermissions) {
        _showError('Microphone permission denied');
        return;
      }

      // Start continuous test loop
      while (_isTesting && mounted) {
        await audioNotifier.cancelListening();
        await Future.delayed(const Duration(milliseconds: 200));
        
        await audioNotifier.listenForCommand(
          timeout: const Duration(seconds: 10),
        );
        
        if (!mounted || !_isTesting) break;

        // Get the raw recognized text from state
        final audioState = ref.read(audioStateProvider);
        final rawText = audioState.recognizedText ?? '';
        final confidence = audioState.confidence;
        
        if (rawText.isNotEmpty) {
          // Parse both command types
          final lessonCmd = VoiceCommand.parseCommand(rawText);
          final globalCmd = GlobalVoiceCommand.parseCommand(rawText);
          
          setState(() {
            _testHistory.add(_VoiceTestResult(
              rawText: rawText,
              confidence: confidence,
              lessonCommand: lessonCmd,
              globalCommand: globalCmd,
              timestamp: DateTime.now(),
            ));
            
            // Keep history limited
            while (_testHistory.length > _maxHistoryItems) {
              _testHistory.removeAt(0);
            }
          });
        }
        
        // Small delay before next listen
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      if (mounted) {
        _showError('Test error: $e');
      }
    } finally {
      await _stopTest();
    }
  }

  Future<void> _stopTest() async {
    if (!_isTesting) return;
    
    setState(() {
      _isTesting = false;
    });

    // Cancel any ongoing listening
    final audioNotifier = ref.read(audioStateProvider.notifier);
    await audioNotifier.cancelListening();

    // Re-enable global voice if it was enabled before
    if (_wasGlobalVoiceEnabled) {
      final globalVoiceNotifier = ref.read(globalVoiceProvider.notifier);
      await globalVoiceNotifier.enable();
    }
  }

  void _clearHistory() {
    setState(() {
      _testHistory.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    // Ensure we clean up if widget is disposed while testing
    if (_isTesting) {
      _stopTest();
    }
    super.dispose();
  }
}

/// Represents a single voice test result
class _VoiceTestResult {
  final String rawText;
  final double confidence;
  final VoiceCommand? lessonCommand;
  final GlobalVoiceCommand? globalCommand;
  final DateTime timestamp;

  _VoiceTestResult({
    required this.rawText,
    required this.confidence,
    this.lessonCommand,
    this.globalCommand,
    required this.timestamp,
  });
}
