import 'package:learning_pwa/models/global_voice_command.dart';

/// Provides context-sensitive voice command help messages.
/// 
/// Different screens have different available commands. This class
/// provides relevant help text based on the current route.
class ContextualHelpProvider {
  /// Get help text based on the current route.
  String getHelpForRoute(String? route) {
    switch (route) {
      case '/':
      case '/home':
        return _homeScreenHelp;
      case '/lessons':
        return _lessonLibraryHelp;
      case '/settings':
        return _settingsHelp;
      case '/profile':
        return _profileHelp;
      default:
        // Check if it's a lesson study route
        if (route?.startsWith('/lesson/') == true) {
          return _lessonStudyHelp;
        }
        return globalHelp;
    }
  }

  /// General help text for global commands available everywhere.
  String get globalHelp => GlobalVoiceCommand.getGlobalCommandsHelp();

  static const String _homeScreenHelp = '''
Home Screen Voice Commands:
• "My lessons" - View lesson library
• "Recent lessons" - View recent lessons  
• "Find lesson [name]" - Search for a lesson
• "Start lesson [name]" - Launch a lesson
• "Settings" - Open settings
• "Profile" - Open profile
''';

  static const String _lessonLibraryHelp = '''
Lesson Library Voice Commands:
• "Start lesson [name]" - Launch a lesson
• "Find lesson [name]" - Search for a lesson
• "Recent lessons" - View recent lessons
• "Create lesson" - Create a new lesson
• "Go home" - Return to home screen
''';

  static const String _settingsHelp = '''
Settings Voice Commands:
• "Voice help" - Show voice command help
• "Toggle hands free" - Enable/disable hands-free mode
• "Go home" - Return to home screen
• "Profile" - Open profile
''';

  static const String _profileHelp = '''
Profile Voice Commands:
• "Go home" - Return to home screen
• "Settings" - Open settings
• "My lessons" - View your lessons
''';

  static const String _lessonStudyHelp = '''
Lesson Study Voice Commands:
• "Next" - Go to next item
• "Previous" / "Back" - Go to previous item
• "Repeat" - Repeat current content
• "Pause" / "Resume" - Control audio
• "Go home" - Exit to home screen
• "Help" - Show available commands
''';

  /// Get a brief one-liner help suggestion for the current route.
  String getBriefHelpForRoute(String? route) {
    switch (route) {
      case '/':
      case '/home':
        return 'Say "Find lesson [name]" or "Settings"';
      case '/lessons':
        return 'Say "Start lesson [name]" or "Go home"';
      case '/settings':
        return 'Say "Go home" or "Profile"';
      default:
        if (route?.startsWith('/lesson/') == true) {
          return 'Say "Next", "Previous", or "Help"';
        }
        return 'Say "Help" for available commands';
    }
  }

  /// Get command examples for UI display.
  List<String> getExamplesForRoute(String? route) {
    switch (route) {
      case '/':
      case '/home':
        return [
          'Find lesson Python',
          'My lessons',
          'Recent lessons',
          'Settings',
        ];
      case '/lessons':
        return [
          'Start lesson JavaScript',
          'Find lesson databases',
          'Go home',
        ];
      case '/settings':
        return [
          'Go home',
          'Profile',
        ];
      default:
        if (route?.startsWith('/lesson/') == true) {
          return [
            'Next',
            'Previous',
            'Repeat',
            'Pause',
          ];
        }
        return [
          'Help',
          'Go home',
        ];
    }
  }
}
