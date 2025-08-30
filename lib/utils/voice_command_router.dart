import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/content_types.dart';

class VoiceCommandRouter {
  static VoiceCommand? parseContextAwareCommand(String text, {String? context}) {
    final normalizedText = text.toLowerCase().trim();
    
    // First try standard command parsing
    final standardCommand = VoiceCommand.parseCommand(text);
    if (standardCommand != null) {
      return standardCommand;
    }
    
    // Context-aware parsing for specific scenarios
    if (context != null) {
      return _parseWithContext(normalizedText, context);
    }
    
    return null;
  }
  
  static VoiceCommand? _parseWithContext(String text, String context) {
    switch (context) {
      case 'mcq':
        return _parseMcqContext(text);
      case 'true_false':
        return _parseTrueFalseContext(text);
      case 'short_answer':
        return _parseShortAnswerContext(text);
      case 'lesson_navigation':
        return _parseNavigationContext(text);
      default:
        return null;
    }
  }
  
  static VoiceCommand? _parseMcqContext(String text) {
    // Enhanced MCQ parsing with more natural speech patterns
    const mcqPatterns = {
      // Direct letter answers
      'a': 'A',
      'b': 'B', 
      'c': 'C',
      'd': 'D',
      
      // Letter with option
      'option a': 'A',
      'option b': 'B',
      'option c': 'C',
      'option d': 'D',
      
      // Ordinal numbers
      'first': 'A',
      'second': 'B',
      'third': 'C',
      'fourth': 'D',
      
      // Ordinal with option
      'first option': 'A',
      'second option': 'B',
      'third option': 'C',
      'fourth option': 'D',
      
      // Choice indicators
      'choice a': 'A',
      'choice b': 'B',
      'choice c': 'C',
      'choice d': 'D',
      
      // Natural speech patterns
      'the first one': 'A',
      'the second one': 'B',
      'the third one': 'C',
      'the fourth one': 'D',
      
      // Answer patterns
      'answer a': 'A',
      'answer b': 'B',
      'answer c': 'C',
      'answer d': 'D',
    };
    
    for (final entry in mcqPatterns.entries) {
      if (text == entry.key || text.endsWith(entry.key) || text.contains(entry.key)) {
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
    const trueFalsePatterns = {
      // Direct answers
      'true': true,
      'false': false,
      
      // Yes/No variants
      'yes': true,
      'no': false,
      
      // Correct/Incorrect variants
      'correct': true,
      'incorrect': false,
      'right': true,
      'wrong': false,
      
      // Natural speech
      'that is true': true,
      'that is false': false,
      'that\'s true': true,
      'that\'s false': false,
      
      // Affirmative patterns
      'definitely true': true,
      'definitely false': false,
      'absolutely true': true,
      'absolutely false': false,
    };
    
    for (final entry in trueFalsePatterns.entries) {
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
  
  static VoiceCommand? _parseShortAnswerContext(String text) {
    // For short answers, we typically want to capture the entire text
    // but filter out command words
    final commandWords = ['next', 'previous', 'repeat', 'pause', 'stop'];
    
    // Check if this is actually a command, not an answer
    for (final command in commandWords) {
      if (text.toLowerCase().contains(command)) {
        return VoiceCommand.parseCommand(text);
      }
    }
    
    // If it's not a command, treat it as an answer
    if (text.isNotEmpty) {
      return VoiceCommand(
        type: VoiceCommandType.answer,
        phrase: text,
        value: text,
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
  
  static String getContextFromContent(LessonContent content) {
    if (content is QuestionContent) {
      return content.type;
    } else if (content is TermContent || content is ConceptContent) {
      return 'lesson_navigation';
    }
    return 'lesson_navigation';
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
