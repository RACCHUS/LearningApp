import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/content_types.dart';

class VoiceCommandRouter {
  static VoiceCommand? parseContextAwareCommand(
    String text, {
    String? context,
  }) {
    final normalizedText = text.toLowerCase().trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    // First try standard command parsing for navigation/control commands
    // But exclude ambiguous ordinals that could be MCQ answers when in MCQ context
    final standardCommand = VoiceCommand.parseCommand(text);
    if (standardCommand != null &&
        standardCommand.type == VoiceCommandType.navigation) {
      // If we're in MCQ/TF context and the command is an ambiguous ordinal (first/second/third/fourth)
      // let context-aware parsing handle it instead
      final isAmbiguousOrdinal =
          standardCommand.value == NavigationCommand.first ||
          standardCommand.value == NavigationCommand.last;
      final isAnswerContext =
          context == 'mcq' || context == 'true_false' || context == 'question';

      if (!isAmbiguousOrdinal || !isAnswerContext) {
        return standardCommand;
      }
    }

    // Then try context-aware parsing for answers
    if (context != null) {
      final contextCommand = _parseWithContext(
        normalizedText,
        text.trim(),
        context,
      );
      if (contextCommand != null) {
        return contextCommand;
      }
      final isAnswerContext =
          context == 'mcq' ||
          context == 'true_false' ||
          context == 'question' ||
          context == 'short_answer';
      if (isAnswerContext && standardCommand?.type == VoiceCommandType.answer) {
        return null;
      }
    }

    // Finally return any other standard commands (mode, settings, etc.)
    return standardCommand;
  }

  static VoiceCommand? _parseWithContext(
    String normalizedText,
    String originalText,
    String context,
  ) {
    switch (context) {
      case 'mcq':
        return _parseMcqContext(normalizedText);
      case 'true_false':
        return _parseTrueFalseContext(normalizedText);
      case 'question':
        return _parseMcqContext(normalizedText) ??
            _parseTrueFalseContext(normalizedText);
      case 'short_answer':
        return _parseShortAnswerContext(normalizedText, originalText);
      case 'lesson_navigation':
        return _parseNavigationContext(normalizedText);
      default:
        return null;
    }
  }

  static VoiceCommand? _parseMcqContext(String text) {
    if (text.isEmpty) return null;

    // Enhanced MCQ parsing with more natural speech patterns
    // Order matters - check longer/more specific patterns first

    // First, check for homophones that speech recognition commonly returns for letters
    // These need special handling because they're full words that map to single letters
    final homophoneAnswer = _checkLetterHomophones(text);
    if (homophoneAnswer != null) {
      return homophoneAnswer;
    }

    const mcqPhrasePatterns = [
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

      // Numeric with "number" prefix
      MapEntry('number one', 'A'),
      MapEntry('number two', 'B'),
      MapEntry('number three', 'C'),
      MapEntry('number four', 'D'),
      MapEntry('number 1', 'A'),
      MapEntry('number 2', 'B'),
      MapEntry('number 3', 'C'),
      MapEntry('number 4', 'D'),

      // Numeric with "option" / "choice" / "choose" / "select" / "answer" / "pick"
      MapEntry('option one', 'A'),
      MapEntry('option two', 'B'),
      MapEntry('option three', 'C'),
      MapEntry('option four', 'D'),
      MapEntry('option 1', 'A'),
      MapEntry('option 2', 'B'),
      MapEntry('option 3', 'C'),
      MapEntry('option 4', 'D'),
      MapEntry('choice one', 'A'),
      MapEntry('choice two', 'B'),
      MapEntry('choice three', 'C'),
      MapEntry('choice four', 'D'),
      MapEntry('choice 1', 'A'),
      MapEntry('choice 2', 'B'),
      MapEntry('choice 3', 'C'),
      MapEntry('choice 4', 'D'),
      MapEntry('choose one', 'A'),
      MapEntry('choose two', 'B'),
      MapEntry('choose three', 'C'),
      MapEntry('choose four', 'D'),
      MapEntry('choose 1', 'A'),
      MapEntry('choose 2', 'B'),
      MapEntry('choose 3', 'C'),
      MapEntry('choose 4', 'D'),
      MapEntry('select one', 'A'),
      MapEntry('select two', 'B'),
      MapEntry('select three', 'C'),
      MapEntry('select four', 'D'),
      MapEntry('select 1', 'A'),
      MapEntry('select 2', 'B'),
      MapEntry('select 3', 'C'),
      MapEntry('select 4', 'D'),
      MapEntry('answer one', 'A'),
      MapEntry('answer two', 'B'),
      MapEntry('answer three', 'C'),
      MapEntry('answer four', 'D'),
      MapEntry('answer 1', 'A'),
      MapEntry('answer 2', 'B'),
      MapEntry('answer 3', 'C'),
      MapEntry('answer 4', 'D'),
      MapEntry('pick one', 'A'),
      MapEntry('pick two', 'B'),
      MapEntry('pick three', 'C'),
      MapEntry('pick four', 'D'),
      MapEntry('pick 1', 'A'),
      MapEntry('pick 2', 'B'),
      MapEntry('pick 3', 'C'),
      MapEntry('pick 4', 'D'),

      // Letter with option
      MapEntry('option a', 'A'),
      MapEntry('option b', 'B'),
      MapEntry('option c', 'C'),
      MapEntry('option d', 'D'),

      // Choose patterns (common voice command prefix)
      MapEntry('choose a', 'A'),
      MapEntry('choose b', 'B'),
      MapEntry('choose c', 'C'),
      MapEntry('choose d', 'D'),

      // Choice indicators
      MapEntry('choice a', 'A'),
      MapEntry('choice b', 'B'),
      MapEntry('choice c', 'C'),
      MapEntry('choice d', 'D'),

      // Select patterns
      MapEntry('select a', 'A'),
      MapEntry('select b', 'B'),
      MapEntry('select c', 'C'),
      MapEntry('select d', 'D'),

      // Answer patterns
      MapEntry('answer a', 'A'),
      MapEntry('answer b', 'B'),
      MapEntry('answer c', 'C'),
      MapEntry('answer d', 'D'),

      // Pick patterns
      MapEntry('pick a', 'A'),
      MapEntry('pick b', 'B'),
      MapEntry('pick c', 'C'),
      MapEntry('pick d', 'D'),

      // Ordinal numbers
      MapEntry('first', 'A'),
      MapEntry('1st', 'A'),
      MapEntry('second', 'B'),
      MapEntry('2nd', 'B'),
      MapEntry('third', 'C'),
      MapEntry('3rd', 'C'),
      MapEntry('fourth', 'D'),
      MapEntry('4th', 'D'),
    ];

    for (final entry in mcqPhrasePatterns) {
      // Use exact match or prefix/suffix phrase match to avoid substring false positives
      if (text == entry.key ||
          text.startsWith('${entry.key} ') ||
          text.endsWith(' ${entry.key}')) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Standalone single-token answers (must match the entire utterance so words
    // like "a" or "one" inside a sentence do not falsely select an option).
    const standaloneMcqTokens = {
      'a': 'A',
      'b': 'B',
      'c': 'C',
      'd': 'D',
      '1': 'A',
      '2': 'B',
      '3': 'C',
      '4': 'D',
      'one': 'A',
      'two': 'B',
      'three': 'C',
      'four': 'D',
    };

    final standaloneValue = standaloneMcqTokens[text];
    if (standaloneValue != null) {
      return VoiceCommand(
        type: VoiceCommandType.answer,
        phrase: text,
        value: standaloneValue,
      );
    }

    return null;
  }

  /// Check for homophones that speech recognition commonly returns for letter sounds
  /// This handles cases where "A" is heard as "hey", "B" as "bee", "C" as "see", etc.
  static VoiceCommand? _checkLetterHomophones(String text) {
    // Homophones grouped by the letter they likely represent
    // These are checked when preceded by choice-indicator words
    const choiceIndicators = [
      'choose',
      'choice',
      'select',
      'pick',
      'option',
      'answer',
    ];

    // First check if text starts with a choice indicator
    String? indicatorUsed;
    String? remainingText;

    for (final indicator in choiceIndicators) {
      if (text.startsWith('$indicator ')) {
        indicatorUsed = indicator;
        remainingText = text.substring(indicator.length + 1).trim();
        break;
      }
    }

    if (indicatorUsed != null && remainingText != null) {
      // Check homophones after choice indicator
      final letter = _mapHomophoneToLetter(remainingText);
      if (letter != null) {
        return VoiceCommand(
          type: VoiceCommandType.answer,
          phrase: '$indicatorUsed $remainingText',
          value: letter,
        );
      }
    }

    // Also check standalone homophones that are unambiguous
    // Only exact matches for safety
    final standaloneHomophones = {
      // "A" homophones - only "ay" is unambiguous standalone
      'ay': 'A',

      // "B" homophones
      'bee': 'B',
      'be': 'B', // Only match exact "be" not "be careful"
      // "C" homophones
      'sea': 'C',
      // Note: "see" is ambiguous (could be "see the question")

      // "D" homophones
      'dee': 'D',
    };

    final exactMatch = standaloneHomophones[text];
    if (exactMatch != null) {
      return VoiceCommand(
        type: VoiceCommandType.answer,
        phrase: text,
        value: exactMatch,
      );
    }

    return null;
  }

  /// Map common homophones to their letter equivalents
  static String? _mapHomophoneToLetter(String text) {
    // A homophones
    const aHomophones = ['a', 'ay', 'aye', 'hey', 'eh'];
    if (aHomophones.contains(text)) return 'A';

    // B homophones
    const bHomophones = ['b', 'be', 'bee', 'bea'];
    if (bHomophones.contains(text)) return 'B';

    // C homophones
    const cHomophones = ['c', 'see', 'sea', 'si'];
    if (cHomophones.contains(text)) return 'C';

    // D homophones
    const dHomophones = ['d', 'dee', 'de', 'the'];
    if (dHomophones.contains(text)) return 'D';

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

  static VoiceCommand? _parseShortAnswerContext(
    String normalizedText,
    String originalText,
  ) {
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
        return [
          'choose A',
          'choose B',
          'choose C',
          'choose D',
          'A',
          'B',
          'C',
          'D',
          'first',
          'second',
          'third',
          'fourth',
        ];
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
        return 'Say "choose A", "choose B", etc. for best recognition. You can also say "first", "second", etc.';
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
