import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/voice_command.dart';

/// Service responsible for parsing recognized text into voice commands
/// Extracted from VoiceInputService to improve separation of concerns
class VoiceCommandParser {
  static final VoiceCommandParser _instance = VoiceCommandParser._internal();
  factory VoiceCommandParser() => _instance;
  VoiceCommandParser._internal();

  /// Parse recognized text into a voice command
  /// Returns null if no valid command is found
  VoiceCommand? parseCommand(String? recognizedText) {
    if (recognizedText == null || recognizedText.isEmpty) {
      if (kDebugMode) {
        print('🎙️ Parse command: No text recognized');
      }
      return null;
    }
    
    if (kDebugMode) {
      print('🎙️ Parse command: Analyzing text: "$recognizedText"');
    }
    
    final command = VoiceCommand.parseCommand(recognizedText);
    
    if (kDebugMode) {
      if (command != null) {
        print('🎙️ Parse command: Found command: ${command.phrase} (${command.type})');
      } else {
        print('🎙️ Parse command: No command found in text: "$recognizedText"');
      }
    }
    
    return command;
  }

  /// Parse command with additional confidence scoring
  /// Useful for determining if a command was clearly spoken
  VoiceCommand? parseCommandWithConfidence(String? recognizedText, double confidence) {
    final command = parseCommand(recognizedText);
    
    if (command != null && confidence < 0.5) {
      if (kDebugMode) {
        print('🎙️ Parse command: Low confidence ($confidence) for command: ${command.phrase}');
      }
      // You might want to ask for confirmation for low-confidence commands
    }
    
    return command;
  }

  /// Get help text for available voice commands
  String getAvailableCommands() {
    return '''
Available Voice Commands:

Navigation:
• "next" or "forward" - Go to next content
• "previous" or "back" - Go to previous content  
• "repeat" or "again" - Repeat current content
• "pause" - Pause the lesson
• "resume" or "play" - Resume the lesson

MCQ Answers:
• "A", "B", "C", "D" - Select answer option
• "option A", "first", "second", etc.

True/False:
• "true", "yes", "correct"
• "false", "no", "incorrect"

Control:
• "help" - Show available commands
• "stop" - End the lesson
    ''';
  }

  /// Check if text contains any recognizable command patterns
  /// Useful for determining if speech recognition should continue listening
  bool containsCommandPattern(String? text) {
    if (text == null || text.isEmpty) return false;
    
    final lowercaseText = text.toLowerCase();
    
    // Check for common command patterns
    final patterns = [
      'next', 'previous', 'repeat', 'pause', 'play', 'resume', 'stop',
      'option', 'first', 'second', 'third', 'fourth',
      'true', 'false', 'yes', 'no', 'correct', 'incorrect',
      RegExp(r'\b[a-d]\b'), // Single letter A-D
    ];
    
    for (final pattern in patterns) {
      if (pattern is String && lowercaseText.contains(pattern)) {
        return true;
      } else if (pattern is RegExp && pattern.hasMatch(lowercaseText)) {
        return true;
      }
    }
    
    return false;
  }

  /// Suggest alternative commands if parsing fails
  List<String> suggestAlternatives(String? failedText) {
    if (failedText == null || failedText.isEmpty) {
      return ['Try saying "next", "previous", or "repeat"'];
    }
    
    final lowercaseText = failedText.toLowerCase();
    final suggestions = <String>[];
    
    // Suggest based on partial matches
    if (lowercaseText.contains('nex') || lowercaseText.contains('for')) {
      suggestions.add('Try saying "next" clearly');
    }
    
    if (lowercaseText.contains('prev') || lowercaseText.contains('bac')) {
      suggestions.add('Try saying "previous"');
    }
    
    if (lowercaseText.contains('rep') || lowercaseText.contains('aga')) {
      suggestions.add('Try saying "repeat"');
    }
    
    if (RegExp(r'[a-d]').hasMatch(lowercaseText)) {
      suggestions.add('For answers, try saying just the letter: "A", "B", "C", or "D"');
    }
    
    if (suggestions.isEmpty) {
      suggestions.add('Try speaking more clearly or use the touch screen');
    }
    
    return suggestions;
  }
}
