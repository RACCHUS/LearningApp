import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/global_voice_command.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:learning_pwa/services/voice_command_corrector.dart';
import 'package:learning_pwa/services/global_voice/global_voice.dart';
import 'package:learning_pwa/widgets/voice_command_confirmation.dart';

/// Global voice service that listens for voice commands throughout the app
/// Provides app-wide navigation and lesson management via voice
class GlobalVoiceService {
  static final GlobalVoiceService _instance = GlobalVoiceService._internal();
  factory GlobalVoiceService() => _instance;
  GlobalVoiceService._internal();

  VoiceInputService? _voiceService;
  bool _isListening = false;
  bool _isEnabled = false;
  String? _currentRoute;
  
  /// Voice recognition locale (e.g., 'en_US', 'en-US')
  /// Set this to match the user's preferred language from settings
  String _voiceLocale = 'en_US';
  
  // Voice command correction
  final VoiceCommandCorrector _voiceCorrector = VoiceCommandCorrector();
  BuildContext? _context; // For showing confirmation dialogs
  
  // Extracted modules for better maintainability
  final PhraseAccumulator _phraseAccumulator = PhraseAccumulator();
  final CommandSynonymMapper _synonymMapper = CommandSynonymMapper();
  final ContextualHelpProvider _helpProvider = ContextualHelpProvider();
  GlobalCommandExecutor? _commandExecutor;
  
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
  String get voiceLocale => _voiceLocale;
  
  /// Update the voice recognition locale
  /// Call this when user changes language preference in settings
  set voiceLocale(String locale) => _voiceLocale = locale;

  /// Initialize the global voice service
  Future<void> initialize({
    required VoiceInputService voiceService,
    GoRouter? router,
    BuildContext? context,
  }) async {
    _voiceService = voiceService;
    _context = context;
    
    // Initialize command executor with router
    _commandExecutor = GlobalCommandExecutor(
      router: router,
      onStatusUpdate: _updateStatus,
    );
    
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
    try {
      await _startListening();
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error starting listening after enable: $e');
      }
      // Don't fail enable if starting listening fails
      // The service will retry on next cycle
    }
    return true;
  }

  /// Disable global voice listening
  Future<void> disable() async {
    _isEnabled = false;
    await _stopListening();
    
    // Clean up phrase accumulation
    _phraseAccumulator.reset();
    
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
        print('🌐 Starting global voice listening with locale: $_voiceLocale');
      }

      // Start voice recognition with longer timeout for multi-word commands
      final success = await _voiceService!.startListening(
        localeId: _voiceLocale,
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
        _phraseAccumulator.reset();
        
        _commandController.add(immediateCommand);
        _updateStatus('Command: ${immediateCommand.phrase}');
        await _executeCommand(immediateCommand);
        return;
      }
    }

    // Use phrase accumulator for multi-word commands or lower confidence
    _phraseAccumulator.addText(text);
    
    // Start timer with callback to process final phrase
    _phraseAccumulator.startTimer(
      onComplete: (finalPhrase) => _processFinalPhrase(finalPhrase, confidence),
      wordCount: words.length,
    );
  }

  /// Process the final accumulated phrase after waiting for completion
  Future<void> _processFinalPhrase(String finalPhrase, double confidence) async {
    // Reset accumulation state
    _phraseAccumulator.reset();
    
    if (kDebugMode) {
      print('🌐 Processing final phrase: "$finalPhrase" (confidence: $confidence)');
    }

    // Apply synonym mapping for better recognition
    String normalizedPhrase = _synonymMapper.normalize(finalPhrase);
    
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
    return _helpProvider.getHelpForRoute(_currentRoute);
  }
  
  /// Get brief help suggestion for current route
  String getBriefHelp() {
    return _helpProvider.getBriefHelpForRoute(_currentRoute);
  }
  
  /// Get example commands for current route
  List<String> getExampleCommands() {
    return _helpProvider.getExamplesForRoute(_currentRoute);
  }

  /// Execute a recognized global voice command
  Future<void> _executeCommand(GlobalVoiceCommand command) async {
    if (_commandExecutor == null) {
      if (kDebugMode) {
        print('🌐 Command executor not available, cannot execute: ${command.phrase}');
      }
      return;
    }

    try {
      await _commandExecutor!.execute(command);
    } catch (e) {
      if (kDebugMode) {
        print('🌐 Error executing command "${command.phrase}": $e');
      }
      _updateStatus('Error executing command');
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
    _phraseAccumulator.dispose();
    
    _isListeningController.close();
    _commandController.close();
    _statusController.close();
    
    if (kDebugMode) {
      print('🌐 GlobalVoiceService disposed');
    }
  }
}
