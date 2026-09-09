import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';

class VoiceInputHandler {
  /// Handles voice input for MCQ questions
  /// Returns the selected answer index (0-3) or null if no valid answer found
  static int? handleMcqVoiceInput(String voiceInput, QuestionContent content) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);
    
    if (command?.type == VoiceCommandType.answer) {
      // Convert voice command answer (A, B, C, D) to index
      final answerLetter = command!.value as String;
      int? answerIndex;
      
      switch (answerLetter) {
        case 'A':
          answerIndex = 0;
          break;
        case 'B':
          answerIndex = 1;
          break;
        case 'C':
          answerIndex = 2;
          break;
        case 'D':
          answerIndex = 3;
          break;
      }
      
      if (answerIndex != null && answerIndex < content.options.length) {
        return answerIndex;
      }
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();
      int? answerIndex;
      
      if (input.contains('a') || input.contains('first')) {
        answerIndex = 0;
      } else if (input.contains('b') || input.contains('second')) {
        answerIndex = 1;
      } else if (input.contains('c') || input.contains('third')) {
        answerIndex = 2;
      } else if (input.contains('d') || input.contains('fourth')) {
        answerIndex = 3;
      }
      
      if (answerIndex != null && answerIndex < content.options.length) {
        return answerIndex;
      }
    }
    
    return null;
  }

  /// Handles voice input for True/False questions
  /// Returns true, false, or null if no valid answer found
  static bool? handleTrueFalseVoiceInput(String voiceInput) {
    // Use the sophisticated VoiceCommand parsing system
    final command = VoiceCommand.parseCommand(voiceInput);
    
    if (command?.type == VoiceCommandType.answer && command!.value is bool) {
      return command.value as bool;
    } else {
      // Fallback to simple parsing for backwards compatibility
      final input = voiceInput.toLowerCase().trim();
      
      if (input.contains('true') || input.contains('yes') || input.contains('correct')) {
        return true;
      } else if (input.contains('false') || input.contains('no') || input.contains('incorrect')) {
        return false;
      }
    }
    
    return null;
  }

  /// Handles voice input for short answer questions
  /// Returns the voice input as text
  static String handleShortAnswerVoiceInput(String voiceInput) {
    return voiceInput.trim();
  }
}
