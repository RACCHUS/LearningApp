import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_manager.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';
import 'package:learning_pwa/services/voice_command_parser.dart';

/// Enhanced voice input service using the multi-provider speech recognition system
/// Replaces the original VoiceInputService with better browser compatibility
class EnhancedVoiceInputService {
  static final EnhancedVoiceInputService _instance = EnhancedVoiceInputService._internal();
  factory EnhancedVoiceInputService() => _instance;
  EnhancedVoiceInputService._internal();

  final SpeechRecognitionManager _speechManager = SpeechRecognitionManager();
  final VoiceCommandParser _commandParser = VoiceCommandParser();
  
  bool _isInitialized = false;
  bool _hasPermissions = false;
  VoiceInputState _state = VoiceInputState.idle;
  String? _recognizedText;
  double _confidence = 0.0;
  String? _errorMessage;

  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _speechManager.currentProviderInfo != null;
  bool get hasPermissions => _hasPermissions;
  bool get canListen => isAvailable && hasPermissions;
  VoiceInputState get currentState => _state;
  String? get recognizedText => _recognizedText;
  double get confidence => _confidence;
  String? get errorMessage => _errorMessage;
  bool get isListening => _speechManager.isListening;

  /// Initialize the enhanced voice input service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('🎙️ Initializing Enhanced Voice Input Service...');
      }

      // Initialize the speech recognition manager
      final success = await _speechManager.initialize();
      
      if (success) {
        _isInitialized = true;
        _updateState(VoiceInputState.idle);
        
        // Listen for provider changes
        _speechManager.providerChanges.listen((providerInfo) {
          if (kDebugMode) {
            print('🎙️ Speech provider changed: ${providerInfo.name}');
          }
          _updateState(_state); // Refresh state with new provider info
        });

        if (kDebugMode) {
          print('🎙️ Enhanced Voice Input Service initialized successfully');
          print('🎙️ Current provider: ${_speechManager.currentProviderInfo?.name}');
        }
      } else {
        _errorMessage = 'No speech recognition providers available';
        _updateState(VoiceInputState.error);
        
        if (kDebugMode) {
          print('🎙️ Enhanced Voice Input Service initialization failed');
        }
      }
    } catch (e) {
      _isInitialized = false;
      _errorMessage = 'Voice service initialization failed: $e';
      _updateState(VoiceInputState.error);
      
      if (kDebugMode) {
        print('🎙️ Enhanced Voice Input Service initialization error: $e');
      }
    }
  }

  /// Check microphone permissions
  Future<bool> checkPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _hasPermissions = await _speechManager.hasPermissions();
      return _hasPermissions;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Permission check error: $e');
      }
      _hasPermissions = false;
      return false;
    }
  }

  /// Request microphone permissions
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final result = await _speechManager.requestPermissions();
      
      if (kDebugMode) {
        print('🎙️ Permission request result: $result');
        print('🎙️ _hasPermissions before update: $_hasPermissions');
      }

      // Update the local permissions flag
      _hasPermissions = result;
      
      if (kDebugMode) {
        print('🎙️ _hasPermissions after update: $_hasPermissions');
      }
      
      // Update state if permissions changed
      if (result) {
        _updateState(VoiceInputState.idle);
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Permission request error: $e');
      }
      _errorMessage = 'Permission request failed: $e';
      return false;
    }
  }

  /// Start listening for voice input
  Future<bool> startListening({
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return false;
    }

    // Check permissions first
    final hasPerms = await checkPermissions();
    if (!hasPerms) {
      _errorMessage = 'Microphone permissions not granted';
      _updateState(VoiceInputState.error);
      return false;
    }

    try {
      _recognizedText = null;
      _confidence = 0.0;
      _errorMessage = null;
      _updateState(VoiceInputState.listening);

      final success = await _speechManager.startListening(
        timeout: listenFor ?? const Duration(seconds: 5),
        language: localeId ?? 'en-US',
      );

      if (success) {
        if (kDebugMode) {
          print('🎙️ Started listening successfully');
        }
        
        // Start monitoring for results
        _monitorSpeechResults();
        return true;
      } else {
        _errorMessage = _speechManager.errorMessage ?? 'Failed to start listening';
        _updateState(VoiceInputState.error);
        
        if (kDebugMode) {
          print('🎙️ Failed to start listening: $_errorMessage');
        }
        
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error starting voice input: $e';
      _updateState(VoiceInputState.error);
      
      if (kDebugMode) {
        print('🎙️ Start listening error: $e');
      }
      
      return false;
    }
  }

  /// Monitor speech recognition results
  void _monitorSpeechResults() {
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_speechManager.isListening) {
        timer.cancel();
        
        // Get final results
        _recognizedText = _speechManager.lastRecognizedText;
        _confidence = _speechManager.confidence;
        
        if (_recognizedText != null && _recognizedText!.isNotEmpty) {
          _updateState(VoiceInputState.completed);
          
          if (kDebugMode) {
            print('🎙️ Speech recognition completed: "$_recognizedText" (confidence: $_confidence)');
          }
        } else {
          _errorMessage = _speechManager.errorMessage ?? 'No speech detected';
          _updateState(VoiceInputState.error);
          
          if (kDebugMode) {
            print('🎙️ Speech recognition completed with no results');
          }
        }
      } else {
        // Update with interim results if available
        final interimText = _speechManager.lastRecognizedText;
        if (interimText != null && interimText != _recognizedText) {
          _recognizedText = interimText;
          _confidence = _speechManager.confidence;
          _updateState(VoiceInputState.processing);
        }
      }
    });
  }

  /// Stop listening for voice input
  Future<void> stopListening() async {
    try {
      await _speechManager.stopListening();
      
      if (kDebugMode) {
        print('🎙️ Stopped listening');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Stop listening error: $e');
      }
    }
  }

  /// Cancel current listening session
  Future<void> cancel() async {
    try {
      await _speechManager.cancel();
      
      _recognizedText = null;
      _confidence = 0.0;
      _errorMessage = null;
      _updateState(VoiceInputState.idle);
      
      if (kDebugMode) {
        print('🎙️ Voice input cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Cancel error: $e');
      }
    }
  }

  /// Listen for a voice command with timeout
  Future<VoiceCommand?> listenForCommand({
    Duration? timeout,
    String? localeId,
  }) async {
    try {
      // Start listening
      final success = await startListening(
        localeId: localeId,
        listenFor: timeout ?? const Duration(seconds: 3),
      );

      if (!success) {
        if (kDebugMode) {
          print('🎙️ listenForCommand: Failed to start listening');
        }
        return null;
      }

      // Wait for completion
      final completer = Completer<VoiceCommand?>();
      late StreamSubscription subscription;

      subscription = stateStream.listen((audioState) {
        if (audioState.voiceInputState == VoiceInputState.completed) {
          subscription.cancel();
          final command = parseLastCommand();
          
          if (kDebugMode) {
            print('🎙️ listenForCommand: Completed with command: ${command?.phrase ?? "none"}');
          }
          
          completer.complete(command);
        } else if (audioState.voiceInputState == VoiceInputState.error) {
          subscription.cancel();
          
          if (kDebugMode) {
            print('🎙️ listenForCommand: Error - ${audioState.errorMessage}');
          }
          
          completer.complete(null);
        }
      });

      // Timeout fallback
      Timer(timeout ?? const Duration(seconds: 15), () { // Increased default from 5 to 15 seconds
        if (!completer.isCompleted) {
          subscription.cancel();
          stopListening();
          
          if (kDebugMode) {
            print('🎙️ listenForCommand: Timeout reached');
          }
          
          completer.complete(null);
        }
      });

      return completer.future;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ listenForCommand error: $e');
      }
      return null;
    }
  }

  /// Parse the last recognized text into a voice command
  VoiceCommand? parseLastCommand() {
    if (_recognizedText == null || _recognizedText!.isEmpty) {
      return null;
    }

    return _commandParser.parseCommand(_recognizedText!);
  }

  /// Submit manual input (for manual provider mode)
  void submitManualInput(String input) {
    _speechManager.submitManualInput(input);
  }

  /// Wait for manual input (for manual provider mode)
  Future<String?> waitForManualInput() async {
    return await _speechManager.waitForManualInput();
  }

  /// Get available locales
  List<String> getAvailableLocales() {
    // Return supported locales based on current provider capabilities
    final capabilities = _speechManager.capabilities;
    if (capabilities.containsKey('languages')) {
      final languages = capabilities['languages'];
      if (languages is List) {
        return List<String>.from(languages);
      }
    }
    
    return ['en-US', 'en-GB', 'es-ES', 'fr-FR', 'de-DE'];
  }

  /// Get current provider information
  ProviderInfo? get currentProviderInfo => _speechManager.currentProviderInfo;

  /// Get setup instructions for current provider
  List<String> getSetupInstructions() {
    return _speechManager.getSetupInstructions();
  }

  /// Get command mappings for manual input
  Map<String, String> getCommandMappings() {
    return _speechManager.getCommandMappings();
  }

  /// Get provider capabilities
  Map<String, dynamic> get capabilities => _speechManager.capabilities;

  /// Check if using manual input mode
  bool get isManualInputMode {
    final providerInfo = _speechManager.currentProviderInfo;
    if (providerInfo == null) return false;
    return providerInfo.capabilities['isManual'] == true;
  }

  /// Get status log for debugging
  List<String> get statusLog => _speechManager.statusLog;

  /// Fallback to next available provider
  Future<bool> fallbackToNextProvider() async {
    return await _speechManager.fallbackToNextProvider();
  }

  /// Update internal state and notify listeners
  void _updateState(VoiceInputState newState) {
    _state = newState;
    
    _stateController.add(AudioState(
      voiceInputState: _state,
      recognizedText: _recognizedText,
      confidence: _confidence,
      errorMessage: _errorMessage,
      isAvailable: isAvailable,
      hasPermissions: _hasPermissions,
    ));
  }

  /// Manually set permission state (for testing)
  void setPermissionGranted(bool granted) {
    if (kDebugMode) {
      print('🎙️ Enhanced service - permission state manually set to: $granted');
    }
    // The speech manager handles permission state internally
  }

  /// Set recognized text for testing
  void setRecognizedTextForTesting(String text) {
    _recognizedText = text;
    _confidence = 1.0;
    _updateState(VoiceInputState.completed);
    
    if (kDebugMode) {
      print('🎙️ Enhanced service - test text set: "$text"');
    }
  }

  /// Dispose of all resources
  void dispose() {
    _speechManager.dispose();
    _stateController.close();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('🎙️ Enhanced Voice Input Service disposed');
    }
  }
}
