import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/content_types.dart';

class VoiceCommandRouter {
  static VoiceCommand? parseContextAwareCommand(String text, {String? context}) {
    final normalizedText = text.toLowerCase().trim();
    
    // First try standard command parsing for navigation/control commands
    // But exclude ambiguous ordinals that could be MCQ answers when in MCQ context
    final standardCommand = VoiceCommand.parseCommand(text);
    if (standardCommand != null && standardCommand.type == VoiceCommandType.navigation) {
      // If we're in MCQ/TF context and the command is an ambiguous ordinal (first/second/third/fourth)
      // let context-aware parsing handle it instead
      final isAmbiguousOrdinal = standardCommand.value == NavigationCommand.first ||
          standardCommand.value == NavigationCommand.last;
      final isAnswerContext = context == 'mcq' || context == 'true_false';
      
      if (!isAmbiguousOrdinal || !isAnswerContext) {
        return standardCommand;
      }
    }
    
    // Then try context-aware parsing for answers
    if (context != null) {
      final contextCommand = _parseWithContext(normalizedText, text.trim(), context);
      if (contextCommand != null) {
        return contextCommand;
      }
    }
    
    // Finally return any other standard commands (mode, settings, etc.)
    return standardCommand;
  }
  
  static VoiceCommand? _parseWithContext(String normalizedText, String originalText, String context) {
    switch (context) {
      case 'mcq':
        return _parseMcqContext(normalizedText);
      case 'true_false':
        return _parseTrueFalseContext(normalizedText);
      case 'short_answer':
        return _parseShortAnswerContext(normalizedText, originalText);
      case 'lesson_navigation':
        return _parseNavigationContext(normalizedText);
      default:
        return null;
    }
  }
  
  static VoiceCommand? _parseMcqContext(String text) {
    // Enhanced MCQ parsing with more natural speech patterns
    // Order matters - check longer/more specific patterns first
    const mcqPatterns = [
      // Natural speech patterns (longest first)
      MapEntry('the first one', 'A'),
      MapEntry('the second one', 'B'),
      MapEntry('the third one', 'C'),
      MapEntry('the fourth one', 'D'),
      
      // Ordinal with option
      MapEntry('first option', 'A'),
      MapEntry('second option', 'B'),
      MapEntry('third option', 'C'),
      MapEntry('fourth option', 'D'),
      
      // Letter with option
      MapEntry('option a', 'A'),
      MapEntry('option b', 'B'),
      MapEntry('option c', 'C'),
      MapEntry('option d', 'D'),
      
      // Choice indicators
      MapEntry('choice a', 'A'),
      MapEntry('choice b', 'B'),
      MapEntry('choice c', 'C'),
      MapEntry('choice d', 'D'),
      
      // Answer patterns
      MapEntry('answer a', 'A'),
      MapEntry('answer b', 'B'),
      MapEntry('answer c', 'C'),
      MapEntry('answer d', 'D'),
      
      // Ordinal numbers
      MapEntry('first', 'A'),
      MapEntry('second', 'B'),
      MapEntry('third', 'C'),
      MapEntry('fourth', 'D'),
      
      // Direct letter answers (shortest, last)
      MapEntry('a', 'A'),
      MapEntry('b', 'B'), 
      MapEntry('c', 'C'),
      MapEntry('d', 'D'),
    ];
    
    for (final entry in mcqPatterns) {
      // Use exact match or word boundary match to avoid substring false positives
      if (text == entry.key || text.startsWith('${entry.key} ') || text.endsWith(' ${entry.key}')) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }
    
    return null;
  }
  
  static VoiceCommand? _parseTrueFalseContext(String text) {
    // Enhanced True/False parsing
    // Order matters - check longer/more specific patterns first
    const trueFalsePatterns = [
      // Longer patterns first to avoid substring matches
      MapEntry('definitely true', true),
      MapEntry('definitely false', false),
      MapEntry('absolutely true', true),
      MapEntry('absolutely false', false),
      MapEntry('that is true', true),
      MapEntry('that is false', false),
      MapEntry('that\'s true', true),
      MapEntry('that\'s false', false),
      
      // Correct/Incorrect variants (check "incorrect" before "correct")
      MapEntry('incorrect', false),
      MapEntry('correct', true),
      
      // Direct answers
      MapEntry('true', true),
      MapEntry('false', false),
      
      // Yes/No variants
      MapEntry('yes', true),
      MapEntry('no', false),
      
      // Right/Wrong
      MapEntry('right', true),
      MapEntry('wrong', false),
    ];
    
    for (final entry in trueFalsePatterns) {
      if (text == entry.key || text.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }
    
    return null;
  }
  
  static VoiceCommand? _parseShortAnswerContext(String normalizedText, String originalText) {
    // For short answers, we typically want to capture the entire text
    // but filter out command words
    final commandWords = ['next', 'previous', 'repeat', 'pause', 'stop'];
    
    // Check if this is actually a command, not an answer
    for (final command in commandWords) {
      if (normalizedText.contains(command)) {
        return VoiceCommand.parseCommand(originalText);
      }
    }
    
    // If it's not a command, treat it as an answer (preserve original case)
    if (originalText.isNotEmpty) {
      return VoiceCommand(
        type: VoiceCommandType.answer,
        phrase: normalizedText,
        value: originalText,
      );
    }
    
    return null;
  }
  
  static VoiceCommand? _parseNavigationContext(String text) {
    // Enhanced navigation command parsing
    const navigationPatterns = {
      // Standard navigation
      'next': NavigationCommand.next,
      'forward': NavigationCommand.next,
      'continue': NavigationCommand.next,
      'move on': NavigationCommand.next,
      'go next': NavigationCommand.next,
      
      'previous': NavigationCommand.previous,
      'back': NavigationCommand.previous,
      'go back': NavigationCommand.previous,
      'move back': NavigationCommand.previous,
      
      // Jump commands
      'first': NavigationCommand.first,
      'beginning': NavigationCommand.first,
      'start': NavigationCommand.first,
      'go to start': NavigationCommand.first,
      
      'last': NavigationCommand.last,
      'end': NavigationCommand.last,
      'finish': NavigationCommand.last,
      'go to end': NavigationCommand.last,
    };
    
    for (final entry in navigationPatterns.entries) {
      if (text == entry.key || text.contains(entry.key)) {
        return VoiceCommand(
          type: VoiceCommandType.navigation,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }
    
    return null;
  }
  
  static String? getContextFromContent(LessonContent content) {
    if (content is QuestionContent) {
      return content.type;
    }
    return null;
  }
  
  static List<String> getExpectedCommandsForContext(String context) {
    switch (context) {
      case 'mcq':
        return ['A', 'B', 'C', 'D', 'option A', 'option B', 'option C', 'option D', 'first', 'second', 'third', 'fourth'];
      case 'true_false':
        return ['true', 'false', 'yes', 'no', 'correct', 'incorrect'];
      case 'short_answer':
        return ['speak your answer', 'any text response'];
      case 'lesson_navigation':
        return ['next', 'previous', 'repeat', 'pause', 'first', 'last'];
      default:
        return ['next', 'previous', 'repeat', 'pause'];
    }
  }
  
  static String getHelpTextForContext(String context) {
    switch (context) {
      case 'mcq':
        return 'Say A, B, C, or D, or say "first", "second", etc.';
      case 'true_false':
        return 'Say "true" or "false", or "yes" or "no".';
      case 'short_answer':
        return 'Speak your answer clearly.';
      case 'lesson_navigation':
        return 'Say "next", "previous", "repeat", or "pause".';
      default:
        return 'Say "next" to continue, or "help" for more options.';
    }
  }
}
