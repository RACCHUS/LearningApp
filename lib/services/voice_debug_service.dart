import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/services/voice_command_parser.dart';

/// Debug service for voice command testing and logging
/// Provides manual testing capabilities and detailed logging
class VoiceDebugService {
  static final VoiceDebugService _instance = VoiceDebugService._internal();
  factory VoiceDebugService() => _instance;
  VoiceDebugService._internal();

  final VoiceCommandParser _parser = VoiceCommandParser();
  String? _lastRecognizedText;
  VoiceCommand? _lastParsedCommand;
  List<String> _debugLog = [];

  /// Current debug state
  String? get lastRecognizedText => _lastRecognizedText;
  VoiceCommand? get lastParsedCommand => _lastParsedCommand;
  List<String> get debugLog => List.unmodifiable(_debugLog);

  /// Set recognized text for testing (simulates speech recognition)
  void setRecognizedTextForTesting(String text) {
    if (kDebugMode) {
      print('🎙️ Setting recognized text for testing: "$text"');
      _addToLog('Testing: Set text to "$text"');
    }
    _lastRecognizedText = text;
  }

  /// Parse and log command for testing
  VoiceCommand? parseTestCommand(String text) {
    if (kDebugMode) {
      print('🎙️ Parsing test command: "$text"');
    }
    
    _lastRecognizedText = text;
    _lastParsedCommand = _parser.parseCommand(text);
    
    _addToLog('Parse test: "$text" → ${_lastParsedCommand?.phrase ?? "No command"}');
    
    return _lastParsedCommand;
  }

  /// Simulate various voice commands for testing
  Map<String, VoiceCommand?> runCommandTests() {
    final testCommands = [
      'next',
      'previous', 
      'repeat',
      'pause',
      'A',
      'option B',
      'true',
      'false',
      'invalid command',
      'hello world',
    ];

    final results = <String, VoiceCommand?>{};
    
    if (kDebugMode) {
      print('🎙️ Running voice command tests...');
    }
    
    for (final command in testCommands) {
      results[command] = parseTestCommand(command);
    }
    
    _addToLog('Completed command tests for ${testCommands.length} commands');
    return results;
  }

  /// Log voice recognition event
  void logVoiceEvent(String event, {String? details}) {
    final logEntry = details != null ? '$event: $details' : event;
    
    if (kDebugMode) {
      print('🎙️ $logEntry');
    }
    
    _addToLog(logEntry);
  }

  /// Log voice state change
  void logStateChange(String oldState, String newState) {
    final logEntry = 'State: $oldState → $newState';
    
    if (kDebugMode) {
      print('🎙️ $logEntry');
    }
    
    _addToLog(logEntry);
  }

  /// Log speech recognition result
  void logSpeechResult(String? text, double confidence, bool isFinal) {
    final logEntry = 'Speech: "${text ?? 'empty'}" (confidence: ${confidence.toStringAsFixed(2)}, final: $isFinal)';
    
    if (kDebugMode) {
      print('🎙️ $logEntry');
    }
    
    _addToLog(logEntry);
    
    if (isFinal) {
      _lastRecognizedText = text;
    }
  }

  /// Log command processing
  void logCommandProcessing(VoiceCommand? command) {
    final logEntry = command != null 
        ? 'Command: ${command.phrase} (${command.type})'
        : 'Command: None recognized';
    
    if (kDebugMode) {
      print('🎙️ $logEntry');
    }
    
    _addToLog(logEntry);
    _lastParsedCommand = command;
  }

  /// Get formatted debug report
  String getDebugReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Voice Debug Report ===');
    buffer.writeln('Last recognized text: "${_lastRecognizedText ?? 'none'}"');
    buffer.writeln('Last parsed command: ${_lastParsedCommand?.phrase ?? 'none'}');
    buffer.writeln('');
    buffer.writeln('Recent log entries:');
    
    final recentEntries = _debugLog.length > 10 
        ? _debugLog.sublist(_debugLog.length - 10)
        : _debugLog;
    
    for (int i = 0; i < recentEntries.length; i++) {
      buffer.writeln('${i + 1}. ${recentEntries[i]}');
    }
    
    return buffer.toString();
  }

  /// Get troubleshooting suggestions based on current state
  List<String> getTroubleshootingSuggestions() {
    final suggestions = <String>[];
    
    if (_lastRecognizedText == null || _lastRecognizedText!.isEmpty) {
      suggestions.add('Speech recognition is not capturing any text');
      suggestions.add('Check microphone permissions in browser settings');
      suggestions.add('Try speaking louder and more clearly');
      suggestions.add('Ensure microphone is not muted');
    } else if (_lastParsedCommand == null) {
      suggestions.add('Speech was recognized but no command was found');
      suggestions.add('Try using exact command words: "next", "previous", "repeat"');
      suggestions.add('For answers, say just the letter: "A", "B", "C", or "D"');
      suggestions.addAll(_parser.suggestAlternatives(_lastRecognizedText));
    } else {
      suggestions.add('Speech recognition and command parsing are working');
      suggestions.add('If commands aren\'t executing, check the orchestrator integration');
    }
    
    return suggestions;
  }

  /// Clear debug log
  void clearLog() {
    _debugLog.clear();
    _lastRecognizedText = null;
    _lastParsedCommand = null;
    
    if (kDebugMode) {
      print('🎙️ Debug log cleared');
    }
  }

  /// Add entry to debug log
  void _addToLog(String entry) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _debugLog.add('[$timestamp] $entry');
    
    // Keep log size manageable
    if (_debugLog.length > 100) {
      _debugLog.removeRange(0, 20);
    }
  }

  /// Export debug log as text
  String exportLog() {
    final buffer = StringBuffer();
    buffer.writeln('Voice Debug Log Export');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    
    for (final entry in _debugLog) {
      buffer.writeln(entry);
    }
    
    return buffer.toString();
  }
}
