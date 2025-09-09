import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/global_voice_command.dart';
import 'package:learning_pwa/services/enhanced_voice_input_service.dart';
import 'package:learning_pwa/services/voice_command_corrector.dart';
import 'package:learning_pwa/widgets/voice_command_confirmation.dart';

/// Global voice service that listens for voice commands throughout the app
/// Provides app-wide navigation and lesson management via voice
class GlobalVoiceService {
  static final GlobalVoiceService _instance = GlobalVoiceService._internal();
  factory GlobalVoiceService() => _instance;
  GlobalVoiceService._internal();

  EnhancedVoiceInputService? _voiceService;
  GoRouter? _router;
  bool _isListening = false;
  bool _isEnabled = false;
  String? _currentRoute;
  
  // Voice command correction
  final VoiceCommandCorrector _voiceCorrector = VoiceCommandCorrector();
  BuildContext? _context; // For showing confirmation dialogs
  
  // Phrase accumulation for multi-word commands
  String _accumulatedPhrase = '';
  Timer? _phraseAccumulationTimer;
  bool _isAccumulatingPhrase = false;
  static const Duration _phraseAccumulationDelay = Duration(milliseconds: 1200);
  
  // Stream controllers for state management
  final StreamController<bool> _isListeningController = StreamController<bool>.broadcast();
  final StreamController<GlobalVoiceCommand> _commandController = StreamController<GlobalVoiceCommand>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  
  // Streams for UI to listen to
  Stream<bool> get isListeningStream => _isListeningController.stream;
  Stream<GlobalVoiceCommand> get commandStream => _commandController.stream;
  Stream<String> get statusStream => _statusController.stream;
  
  // Getters
  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  bool get isAvailable => _voiceService?.isAvailable ?? false;
  bool get hasPermissions => _voiceService?.hasPermissions ?? false;

  /// Initialize the global voice service
  Future<void> initialize({
    required EnhancedVoiceInputService voiceService,
    GoRouter? router,
    BuildContext? context,
  }) async {
    _voiceService = voiceService;
    _router = router;
    _context = context;
    
    // Initialize voice corrector
    _voiceCorrector.initialize();
    
    if (kDebugMode) {
      print('🌐 GlobalVoiceService initialized with router: ${router != null}, context: ${context != null}');
    }
  }

  /// Update the build context for showing confirmation dialogs
  void updateContext(BuildContext? context) {
    _context = context;
  }

  /// Enable global voice listening
  Future<bool> enable() async {
    if (_voiceService == null) {
      if (kDebugMode) {
        print('🌐 Cannot enable - voice service not initialized');
      }
      return false;
    }

    if (!_voiceService!.isAvailable) {
      if (kDebugMode) {
        print('🌐 Cannot enable - voice service not available');
      }
      return false;
    }

    if (!_voiceService!.hasPermissions) {
      if (kDebugMode) {
        print('🌐 Requesting microphone permissions for global voice...');
      }
      
      // Note: Permission requests should be handled by the UI layer
      // This service assumes permissions are already granted
      return false;
    }

    _isEnabled = true;
    _updateStatus('Global voice enabled');
    
    if (kDebugMode) {
      print('🌐 Global voice service enabled');
    }

    // Start listening immediately
    await _startListening();
    return true;
  }

  /// Disable global voice listening
  Future<void> disable() async {
    _isEnabled = false;
    await _stopListening();
    
    // Clean up phrase accumulation
    _phraseAccumulationTimer?.cancel();
    _isAccumulatingPhrase = false;
    _accumulatedPhrase = '';
    
    _updateStatus('Global voice disabled');
    
    if (kDebugMode) {
      print('🌐 Global voice service disabled');
    }
  }

  /// Update current route for context-aware commands
  void updateRoute(String route) {
    _currentRoute = route;
    
    if (kDebugMode) {
      print('🌐 Route updated: $route');
    }
  }

  /// Start listening for global commands
  Future<void> _startListening() async {
    if (!_isEnabled || _isListening || _voiceService == null) {
      return;
    }

    _isListening = true;
    _isListeningController.add(true);
    
    try {
      if (kDebugMode) {
        print('🌐 Starting global voice listening...');
      }

      // Start voice recognition with longer timeout for multi-word commands
      final success = await _voiceService!.startListening(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 10), // Increased from 5 to 10
        pauseFor: const Duration(milliseconds: 800), // Wait for natural pauses
      );

      if (success) {
        _updateStatus('Listening for global commands...');
        // Wait for result and process it
        await _waitForCommandResult();
      } else {
        if (kDebugMode) {
          print('🌐 Failed to start listening');
        }
        _isListening = false;
        _isListeningController.add(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error starting global voice listening: $e');
      }
      _isListening = false;
      _isListeningController.add(false);
    }
  }

  /// Wait for voice recognition result and process command
  Future<void> _waitForCommandResult() async {
    // Listen to voice service state changes
    late StreamSubscription subscription;
    final completer = Completer<void>();

    subscription = _voiceService!.stateStream.listen((state) {
      if (state.voiceInputState.toString().contains('completed')) {
        // Process the recognized text
        final recognizedText = state.recognizedText;
        if (recognizedText != null && recognizedText.isNotEmpty) {
          _processVoiceInput(recognizedText, state.confidence);
        }
        subscription.cancel();
        completer.complete();
      } else if (state.voiceInputState.toString().contains('error') || 
                 state.voiceInputState.toString().contains('idle')) {
        subscription.cancel();
        completer.complete();
      }
    });

    // Timeout after 10 seconds
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete();
      }
    });

    await completer.future;
    
    _isListening = false;
    _isListeningController.add(false);

    // Restart listening if still enabled with minimal delay
    if (_isEnabled) {
      await Future.delayed(const Duration(milliseconds: 200)); // Reduced from 500ms to 200ms
      await _startListening();
    }
  }

  /// Process voice input and extract global commands
  Future<void> _processVoiceInput(String text, double confidence) async {
    if (kDebugMode) {
      print('🌐 Processing global voice input: "$text" (confidence: $confidence)');
    }

    // For high-confidence single-word navigation commands, process immediately
    final words = text.split(' ');
    final isSimpleCommand = words.length <= 2;
    final isHighConfidence = confidence >= 0.8;
    
    if (isSimpleCommand && isHighConfidence) {
      // Check if it's a known navigation command first
      final immediateCommand = GlobalVoiceCommand.parseCommand(text.toLowerCase().trim());
      if (immediateCommand != null && immediateCommand.type == GlobalVoiceCommandType.navigation) {
        if (kDebugMode) {
          print('🌐 Processing immediate navigation command: "${immediateCommand.phrase}"');
        }
        
        // Reset accumulation state since we're processing immediately
        _isAccumulatingPhrase = false;
        _phraseAccumulationTimer?.cancel();
        _accumulatedPhrase = '';
        
        _commandController.add(immediateCommand);
        _updateStatus('Command: ${immediateCommand.phrase}');
        await _executeCommand(immediateCommand);
        return;
      }
    }

    // Enhanced phrase accumulation for multi-word commands or lower confidence
    if (_isAccumulatingPhrase) {
      // Add to accumulated phrase if it's not a duplicate
      final accumulatedWords = _accumulatedPhrase.split(' ');
      
      // Check if this is a continuation or new text
      bool isNewText = true;
      if (accumulatedWords.isNotEmpty && words.isNotEmpty) {
        isNewText = !words.every((word) => accumulatedWords.contains(word.toLowerCase()));
      }
      
      if (isNewText && text.trim().isNotEmpty) {
        _accumulatedPhrase = '$_accumulatedPhrase $text'.trim();
        if (kDebugMode) {
          print('🌐 Accumulated phrase: "$_accumulatedPhrase"');
        }
      }
    } else {
      // Start new accumulation
      _accumulatedPhrase = text.trim();
      _isAccumulatingPhrase = true;
      
      if (kDebugMode) {
        print('🌐 Starting phrase accumulation with: "$_accumulatedPhrase"');
      }
    }

    // Cancel previous timer and start new one
    _phraseAccumulationTimer?.cancel();
    
    // Use shorter timeout for simple commands, longer for complex ones
    final timeoutDuration = words.length <= 2 ? 
        const Duration(milliseconds: 600) : // Faster for simple commands
        _phraseAccumulationDelay; // Full delay for complex commands
    
    _phraseAccumulationTimer = Timer(timeoutDuration, () {
      _processFinalPhrase(_accumulatedPhrase, confidence);
    });
  }

  /// Process the final accumulated phrase after waiting for completion
  Future<void> _processFinalPhrase(String finalPhrase, double confidence) async {
    // Reset accumulation state
    _isAccumulatingPhrase = false;
    _phraseAccumulationTimer?.cancel();
    
    if (kDebugMode) {
      print('🌐 Processing final phrase: "$finalPhrase" (confidence: $confidence)');
    }

    // Enhanced synonym mapping for better recognition
    String normalizedPhrase = _applyCommandSynonyms(finalPhrase.toLowerCase().trim());
    
    // Try voice correction if original command is not recognized
    GlobalVoiceCommand? command = GlobalVoiceCommand.parseCommand(normalizedPhrase);
    
    if (command == null) {
      // Initialize corrector if needed
      _voiceCorrector.initialize();
      
      // Try voice correction
      final correction = _voiceCorrector.analyzeCommand(finalPhrase, confidence);
      
      if (correction != null && correction.confidence > 0.7) {
        if (kDebugMode) {
          print('🌐 Voice correction suggested: "${correction.originalInput}" -> "${correction.suggestedCommand}" (${(correction.confidence * 100).toStringAsFixed(1)}%)');
        }
        
        // For high-confidence corrections, apply automatically
        if (correction.confidence > 0.9) {
          normalizedPhrase = correction.suggestedCommand;
          command = GlobalVoiceCommand.parseCommand(normalizedPhrase);
          
          if (kDebugMode) {
            print('🌐 Auto-applied high-confidence correction: "${correction.suggestedCommand}"');
          }
        } else if (_context != null) {
          // For medium-confidence corrections, ask for confirmation
          final confirmed = await showVoiceConfirmationDialog(_context!, correction);
          
          if (confirmed == true) {
            normalizedPhrase = correction.suggestedCommand;
            command = GlobalVoiceCommand.parseCommand(normalizedPhrase);
            
            if (kDebugMode) {
              print('🌐 User confirmed correction: "${correction.suggestedCommand}"');
            }
          } else if (confirmed == null) {
            // User chose "Try Again" - restart listening
            if (kDebugMode) {
              print('🌐 User requested to try again');
            }
            await _startListening();
            return;
          } else {
            // User rejected correction
            if (kDebugMode) {
              print('🌐 User rejected correction');
            }
            _updateStatus('Command not recognized: "$finalPhrase"');
            return;
          }
        }
      }
    }
    
    // Use dynamic confidence threshold based on command complexity
    final words = normalizedPhrase.split(' ');
    final confidenceThreshold = words.length > 2 ? 0.6 : 0.7; // Lower for multi-word commands
    
    if (command == null && confidence < confidenceThreshold) {
      if (kDebugMode) {
        print('🌐 Low confidence for global command (${(confidence * 100).toStringAsFixed(1)}% < ${(confidenceThreshold * 100).toStringAsFixed(1)}%), ignoring: "$normalizedPhrase"');
      }
      _updateStatus('Command unclear: "$finalPhrase"');
      return;
    }

    if (command != null) {
      if (kDebugMode) {
        print('🌐 Global command recognized: ${command.phrase}');
      }
      
      _commandController.add(command);
      _updateStatus('Command: ${command.phrase}');
      
      // Execute the command
      await _executeCommand(command);
    } else {
      if (kDebugMode) {
        print('🌐 No global command found in: "$normalizedPhrase"');
      }
      _updateStatus('Command not recognized: "$finalPhrase"');
    }
  }

  /// Apply command synonyms for better recognition
  String _applyCommandSynonyms(String input) {
    // Map common speech recognition variants to standard commands
    final synonymMap = {
      // Navigation synonyms
      'go home': ['home', 'main', 'dashboard', 'start'],
      'settings': ['setting', 'preferences', 'config', 'configuration'],
      'profile': ['my profile', 'user profile', 'account'],
      
      // Lesson management synonyms
      'find lesson': ['search lesson', 'look for lesson', 'show lesson', 'open lesson'],
      'start lesson': ['begin lesson', 'launch lesson', 'play lesson', 'run lesson'],
      'my lessons': ['lessons', 'lesson list', 'all lessons', 'lesson library'],
      'recent lessons': ['recent', 'last lessons', 'recently viewed'],
      
      // Action synonyms
      'find': ['search', 'look for', 'show', 'open', 'display'],
      'start': ['begin', 'launch', 'play', 'run', 'open'],
    };

    String normalized = input;
    
    // Apply full phrase synonyms first
    for (final entry in synonymMap.entries) {
      final standardForm = entry.key;
      final variants = entry.value;
      
      for (final variant in variants) {
        if (normalized.contains(variant)) {
          normalized = normalized.replaceAll(variant, standardForm);
          break;
        }
      }
    }
    
    // Special handling for lesson commands with parameters
    if (normalized.contains('lesson')) {
      // Handle patterns like "find laptops" -> "find lesson laptops"
      final findPattern = RegExp(r'\b(find|search|show|open)\s+(?!lesson)(\w+)');
      normalized = normalized.replaceAllMapped(findPattern, (match) {
        return '${match.group(1)} lesson ${match.group(2)}';
      });
      
      // Handle patterns like "start laptops" -> "start lesson laptops"
      final startPattern = RegExp(r'\b(start|begin|launch|play|run)\s+(?!lesson)(\w+)');
      normalized = normalized.replaceAllMapped(startPattern, (match) {
        return '${match.group(1)} lesson ${match.group(2)}';
      });
    }
    
    if (kDebugMode && normalized != input) {
      print('🌐 Applied synonyms: "$input" -> "$normalized"');
    }
    
    return normalized;
  }

  /// Stop listening for commands
  Future<void> _stopListening() async {
    if (!_isListening || _voiceService == null) {
      return;
    }

    try {
      await _voiceService!.stopListening();
      if (kDebugMode) {
        print('🌐 Stopped global voice listening');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error stopping global voice listening: $e');
      }
    }

    _isListening = false;
    _isListeningController.add(false);
  }

  /// Update status message
  void _updateStatus(String status) {
    _statusController.add(status);
    
    if (kDebugMode) {
      print('🌐 Status: $status');
    }
  }

  /// Get context-specific help based on current route
  String getContextualHelp() {
    switch (_currentRoute) {
      case '/':
      case '/home':
        return '''
Home Screen Voice Commands:
• "My lessons" - View lesson library
• "Recent lessons" - View recent lessons  
• "Find lesson [name]" - Search for a lesson
• "Start lesson [name]" - Launch a lesson
• "Settings" - Open settings
        ''';
      case '/lessons':
        return '''
Lesson Library Voice Commands:
• "Start lesson [name]" - Launch a lesson
• "Find lesson [name]" - Search for a lesson
• "Recent lessons" - View recent lessons
• "Go home" - Return to home screen
        ''';
      case '/settings':
        return '''
Settings Voice Commands:
• "Voice help" - Show voice command help
• "Toggle hands free" - Enable/disable hands-free mode
• "Go home" - Return to home screen
        ''';
      default:
        return GlobalVoiceCommand.getGlobalCommandsHelp();
    }
  }

  /// Execute a recognized global voice command
  Future<void> _executeCommand(GlobalVoiceCommand command) async {
    if (_router == null) {
      if (kDebugMode) {
        print('🌐 Router not available, cannot execute navigation command: ${command.phrase}');
      }
      return;
    }

    try {
      switch (command.type) {
        case GlobalVoiceCommandType.navigation:
          await _executeNavigationCommand(command);
          break;
        case GlobalVoiceCommandType.lessonManagement:
          await _executeLessonCommand(command);
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

  /// Execute navigation commands
  Future<void> _executeNavigationCommand(GlobalVoiceCommand command) async {
    if (_router == null) return;

    switch (command.phrase.toLowerCase()) {
      case 'go home':
      case 'home':
      case 'home page':
        _router!.go('/');
        if (kDebugMode) print('🌐 Navigated to home');
        break;
      case 'settings':
      case 'go to settings':
      case 'open settings':
        _router!.go('/settings');
        if (kDebugMode) print('🌐 Navigated to settings');
        break;
      case 'profile':
      case 'my profile':
      case 'go to profile':
        _router!.go('/profile');
        if (kDebugMode) print('🌐 Navigated to profile');
        break;
      case 'lessons':
      case 'my lessons':
      case 'lesson list':
        _router!.go('/');
        if (kDebugMode) print('🌐 Navigated to lessons (home)');
        break;
      case 'create lesson':
      case 'new lesson':
        _router!.go('/create-lesson');
        if (kDebugMode) print('🌐 Navigated to create lesson');
        break;
      default:
        if (kDebugMode) print('🌐 Unknown navigation command: ${command.phrase}');
    }
  }

  /// Execute lesson management commands
  Future<void> _executeLessonCommand(GlobalVoiceCommand command) async {
    if (kDebugMode) {
      print('🌐 Lesson command executed: ${command.phrase}');
    }
    
    // Extract lesson name from parameters if available
    final lessonName = command.parameters['lessonName'] as String?;
    
    if (lessonName != null && lessonName.isNotEmpty) {
      // Navigate to home with search query
      _router?.go('/?search=${Uri.encodeComponent(lessonName)}');
      
      if (kDebugMode) {
        print('🌐 Searching for lesson: "$lessonName"');
      }
      
      _updateStatus('Searching for: $lessonName');
    } else {
      // General lesson management commands
      switch (command.phrase.toLowerCase()) {
        case 'my lessons':
        case 'lesson library':
        case 'all lessons':
          _router?.go('/');
          if (kDebugMode) print('🌐 Navigated to lesson library');
          break;
        case 'recent lessons':
        case 'recent':
          _router?.go('/?filter=recent');
          if (kDebugMode) print('🌐 Showing recent lessons');
          break;
        default:
          // Default to home screen
          _router?.go('/');
          if (kDebugMode) print('🌐 Navigated to home for lesson management');
      }
    }
  }

  /// Execute app-level commands
  Future<void> _executeAppCommand(GlobalVoiceCommand command) async {
    switch (command.phrase.toLowerCase()) {
      case 'help':
      case 'voice help':
      case 'what can i say':
        // Could show a help dialog here
        if (kDebugMode) print('🌐 Help command executed');
        break;
      default:
        if (kDebugMode) print('🌐 Unknown app command: ${command.phrase}');
    }
  }

  /// Request microphone permissions (to be called by UI)
  Future<bool> requestPermissions() async {
    if (_voiceService == null) return false;
    
    // Note: This should be handled by the UI layer that uses this service
    // The service itself doesn't request permissions directly
    return _voiceService!.hasPermissions;
  }

  /// Dispose of the service
  void dispose() {
    _isEnabled = false;
    _stopListening();
    
    // Clean up phrase accumulation
    _phraseAccumulationTimer?.cancel();
    _isAccumulatingPhrase = false;
    _accumulatedPhrase = '';
    
    _isListeningController.close();
    _commandController.close();
    _statusController.close();
    
    if (kDebugMode) {
      print('🌐 GlobalVoiceService disposed');
    }
  }
}
