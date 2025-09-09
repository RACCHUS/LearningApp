/// Global voice commands that work throughout the app
enum GlobalVoiceCommandType {
  navigation,
  lessonManagement,
  app,
}

enum GlobalNavigationCommand {
  goHome,
  settings,
  help,
  profile,
  back,
}

enum LessonManagementCommand {
  findLesson,
  startLesson,
  myLessons,
  recentLessons,
  continueLesson,
}

enum AppCommand {
  voiceHelp,
  toggleHandsFree,
  whatCanISay,
}

class GlobalVoiceCommand {
  final GlobalVoiceCommandType type;
  final String phrase;
  final List<String> alternatives;
  final dynamic value;
  final double confidence;
  final Map<String, dynamic> parameters;

  const GlobalVoiceCommand({
    required this.type,
    required this.phrase,
    this.alternatives = const [],
    this.value,
    this.confidence = 0.0,
    this.parameters = const {},
  });

  static const Map<String, GlobalNavigationCommand> navigationCommands = {
    'go home': GlobalNavigationCommand.goHome,
    'home': GlobalNavigationCommand.goHome,
    'main screen': GlobalNavigationCommand.goHome,
    'dashboard': GlobalNavigationCommand.goHome,
    'settings': GlobalNavigationCommand.settings,
    'open settings': GlobalNavigationCommand.settings,
    'preferences': GlobalNavigationCommand.settings,
    'help': GlobalNavigationCommand.help,
    'show help': GlobalNavigationCommand.help,
    'voice help': GlobalNavigationCommand.help,
    'profile': GlobalNavigationCommand.profile,
    'my profile': GlobalNavigationCommand.profile,
    'user profile': GlobalNavigationCommand.profile,
    'go back': GlobalNavigationCommand.back,
    'back': GlobalNavigationCommand.back,
    'previous screen': GlobalNavigationCommand.back,
  };

  static const Map<String, LessonManagementCommand> lessonCommands = {
    'find lesson': LessonManagementCommand.findLesson,
    'search lesson': LessonManagementCommand.findLesson,
    'look for lesson': LessonManagementCommand.findLesson,
    'start lesson': LessonManagementCommand.startLesson,
    'begin lesson': LessonManagementCommand.startLesson,
    'launch lesson': LessonManagementCommand.startLesson,
    'my lessons': LessonManagementCommand.myLessons,
    'lesson library': LessonManagementCommand.myLessons,
    'all lessons': LessonManagementCommand.myLessons,
    'recent lessons': LessonManagementCommand.recentLessons,
    'recent': LessonManagementCommand.recentLessons,
    'last lessons': LessonManagementCommand.recentLessons,
    'continue lesson': LessonManagementCommand.continueLesson,
    'resume lesson': LessonManagementCommand.continueLesson,
    'continue where I left off': LessonManagementCommand.continueLesson,
  };

  static const Map<String, AppCommand> appCommands = {
    'what can I say': AppCommand.whatCanISay,
    'voice commands': AppCommand.whatCanISay,
    'available commands': AppCommand.whatCanISay,
    'voice help': AppCommand.voiceHelp,
    'help with voice': AppCommand.voiceHelp,
    'toggle hands free': AppCommand.toggleHandsFree,
    'enable hands free': AppCommand.toggleHandsFree,
    'disable hands free': AppCommand.toggleHandsFree,
    'hands free mode': AppCommand.toggleHandsFree,
  };

  /// Parse a global voice command from text
  static GlobalVoiceCommand? parseCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    
    // Enhanced lesson name patterns with more flexible matching
    final lessonPatterns = [
      // Put longer patterns first to match "look for" before "look"
      RegExp(r'(look for|find|search|show|open) lesson (.+)', caseSensitive: false),
      RegExp(r'(start|begin|launch|play|run) lesson (.+)', caseSensitive: false),
      // Handle cases where "lesson" might be missing but context suggests it
      RegExp(r'(look for|find|search|show|open) (?!lesson)([a-zA-Z]+(?:\s+[a-zA-Z]+)*)', caseSensitive: false),
      RegExp(r'(start|begin|launch|play|run) (?!lesson)([a-zA-Z]+(?:\s+[a-zA-Z]+)*)', caseSensitive: false),
    ];
    
    for (final pattern in lessonPatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        final action = match.group(1)!.toLowerCase();
        final lessonName = match.group(2)!.trim();
        
        // Skip if lesson name is too generic or a known navigation command
        if (isGenericTerm(lessonName)) continue;
        
        if (['find', 'search', 'show', 'open', 'look for'].contains(action)) {
          return GlobalVoiceCommand(
            type: GlobalVoiceCommandType.lessonManagement,
            phrase: 'find lesson $lessonName',
            value: LessonManagementCommand.findLesson,
            parameters: {'lessonName': lessonName},
          );
        } else {
          return GlobalVoiceCommand(
            type: GlobalVoiceCommandType.lessonManagement,
            phrase: 'start lesson $lessonName',
            value: LessonManagementCommand.startLesson,
            parameters: {'lessonName': lessonName},
          );
        }
      }
    }

    // Check navigation commands
    for (final entry in navigationCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return GlobalVoiceCommand(
          type: GlobalVoiceCommandType.navigation,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check lesson management commands
    for (final entry in lessonCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return GlobalVoiceCommand(
          type: GlobalVoiceCommandType.lessonManagement,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    // Check app commands
    for (final entry in appCommands.entries) {
      if (normalizedText.contains(entry.key)) {
        return GlobalVoiceCommand(
          type: GlobalVoiceCommandType.app,
          phrase: entry.key,
          value: entry.value,
        );
      }
    }

    return null;
  }

  /// Check if a term is too generic to be a lesson name
  static bool isGenericTerm(String term) {
    final genericTerms = {
      'home', 'settings', 'profile', 'help', 'back', 'menu', 'page',
      'screen', 'app', 'application', 'system', 'user', 'account',
      'lesson', 'lessons', 'course', 'courses', 'for', 'in', 'on',
      'the', 'a', 'an', 'and', 'or', 'but', 'to', 'from',
    };
    
    return genericTerms.contains(term.toLowerCase()) || term.length < 2;
  }

  /// Get help text for global commands
  static String getGlobalCommandsHelp() {
    return '''
Global Voice Commands (available anywhere in the app):

Navigation:
• "Go home" - Return to main screen
• "Settings" - Open settings
• "Help" - Show help
• "Profile" - View profile
• "Go back" - Go to previous screen

Lesson Management:
• "Find lesson [name]" - Search for a lesson
• "Start lesson [name]" - Launch a specific lesson
• "My lessons" - View lesson library
• "Recent lessons" - View recently accessed lessons
• "Continue lesson" - Resume last lesson

App Commands:
• "What can I say" - Show available commands
• "Voice help" - Show voice command help
• "Toggle hands free" - Enable/disable hands-free mode
    ''';
  }

  @override
  String toString() {
    return 'GlobalVoiceCommand(type: $type, phrase: $phrase, value: $value, parameters: $parameters)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GlobalVoiceCommand &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          phrase == other.phrase &&
          value == other.value;

  @override
  int get hashCode => type.hashCode ^ phrase.hashCode ^ value.hashCode;
}
