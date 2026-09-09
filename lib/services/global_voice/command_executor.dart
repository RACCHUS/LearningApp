import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/global_voice_command.dart';

/// Executes global voice commands by navigating and performing actions.
/// 
/// Handles navigation, lesson management, and app-level commands.
class GlobalCommandExecutor {
  final GoRouter? _router;
  final void Function(String status)? _onStatusUpdate;

  GlobalCommandExecutor({
    GoRouter? router,
    void Function(String status)? onStatusUpdate,
  })  : _router = router,
        _onStatusUpdate = onStatusUpdate;

  /// Execute a recognized global voice command.
  Future<void> execute(GlobalVoiceCommand command) async {
    if (_router == null) {
      if (kDebugMode) {
        print('🌐 Router not available, cannot execute: ${command.phrase}');
      }
      return;
    }

    try {
      switch (command.type) {
        case GlobalVoiceCommandType.navigation:
          await _executeNavigation(command);
          break;
        case GlobalVoiceCommandType.lessonManagement:
          await _executeLessonManagement(command);
          break;
        case GlobalVoiceCommandType.app:
          await _executeAppCommand(command);
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error executing command "${command.phrase}": $e');
      }
    }
  }

  /// Execute navigation commands (home, settings, profile, etc.)
  Future<void> _executeNavigation(GlobalVoiceCommand command) async {
    final phrase = command.phrase.toLowerCase();
    
    switch (phrase) {
      case 'go home':
      case 'home':
      case 'home page':
        _router!.go('/');
        _log('Navigated to home');
        break;
        
      case 'settings':
      case 'go to settings':
      case 'open settings':
        _router!.go('/settings');
        _log('Navigated to settings');
        break;
        
      case 'profile':
      case 'my profile':
      case 'go to profile':
        _router!.go('/profile');
        _log('Navigated to profile');
        break;
        
      case 'lessons':
      case 'my lessons':
      case 'lesson list':
        _router!.go('/');
        _log('Navigated to lessons');
        break;
        
      case 'create lesson':
      case 'new lesson':
        _router!.go('/create-lesson');
        _log('Navigated to create lesson');
        break;
        
      default:
        _log('Unknown navigation: ${command.phrase}');
    }
  }

  /// Execute lesson management commands (find, start, recent, etc.)
  Future<void> _executeLessonManagement(GlobalVoiceCommand command) async {
    final lessonName = command.parameters['lessonName'] as String?;
    
    if (lessonName != null && lessonName.isNotEmpty) {
      // Navigate to home with search query
      _router?.go('/?search=${Uri.encodeComponent(lessonName)}');
      _log('Searching for lesson: "$lessonName"');
      _onStatusUpdate?.call('Searching for: $lessonName');
      return;
    }
    
    // General lesson management commands
    final phrase = command.phrase.toLowerCase();
    
    switch (phrase) {
      case 'my lessons':
      case 'lesson library':
      case 'all lessons':
        _router?.go('/');
        _log('Navigated to lesson library');
        break;
        
      case 'recent lessons':
      case 'recent':
        _router?.go('/?filter=recent');
        _log('Showing recent lessons');
        break;
        
      default:
        _router?.go('/');
        _log('Navigated to home for lesson management');
    }
  }

  /// Execute app-level commands (help, etc.)
  Future<void> _executeAppCommand(GlobalVoiceCommand command) async {
    final phrase = command.phrase.toLowerCase();
    
    switch (phrase) {
      case 'help':
      case 'voice help':
      case 'what can i say':
        _log('Help command executed');
        // Could emit an event for UI to show help dialog
        break;
        
      default:
        _log('Unknown app command: ${command.phrase}');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('🌐 $message');
    }
  }
}
