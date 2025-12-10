import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/models/voice_command.dart';

class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  SpeechToText? _speechToText;
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _hasPermissions = false; // Track permission state
  
  VoiceInputState _state = VoiceInputState.idle;
  String? _recognizedText;
  double _confidence = 0.0;
  String? _errorMessage;

  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get hasPermissions => _hasPermissions;
  bool get canListen => _isAvailable && _hasPermissions; // New combined check
  VoiceInputState get currentState => _state;
  String? get recognizedText => _recognizedText;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _speechToText = SpeechToText();
      
      if (kDebugMode) {
        print('Initializing SpeechToText...');
      }
      
      final initResult = await _speechToText!.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: kDebugMode,
      );

      _isAvailable = initResult == true;
      _isInitialized = true;
      _updateState(VoiceInputState.idle);
      
      if (kDebugMode) {
        print('VoiceInputService initialized. Available: $_isAvailable');
      }
      
    } catch (e) {
      _isAvailable = false;
      _isInitialized = true; // Mark as initialized even if failed
      _errorMessage = 'Failed to initialize speech recognition: $e';
      _updateState(VoiceInputState.error);
      
      if (kDebugMode) {
        print('VoiceInputService initialization error: $e');
      }
    }
  }

  Future<bool> checkPermissions() async {
    try {
      // On web, the best way to check microphone permission is to try to use it
      // The permission_handler package doesn't work reliably on web
      if (kIsWeb) {
        if (!_isInitialized || !_isAvailable || _speechToText == null) {
          return false;
        }
        
        // Try a very brief listen test to check permissions
        try {
          final testResult = await _speechToText!.listen(
            onResult: (_) {}, // Empty result handler for test
            listenFor: const Duration(milliseconds: 100), // Very short test
            pauseFor: const Duration(milliseconds: 50),
          );
          
          // Stop immediately after test
          await _speechToText!.stop();
          
          return testResult == true;
        } catch (e) {
          if (kDebugMode) {
            print('Permission test failed: $e');
          }
          return false;
        }
      }
      
      // For non-web platforms, use permission_handler
      final status = await Permission.microphone.status;
      
      if (status == PermissionStatus.denied || status == PermissionStatus.permanentlyDenied) {
        final result = await Permission.microphone.request();
        return result == PermissionStatus.granted;
      }
      
      return status == PermissionStatus.granted;
    } catch (e) {
      if (kDebugMode) {
        print('Permission check error: $e');
      }
      return false;
    }
  }

  Future<bool> startListening({
    String? localeId,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    if (!_isInitialized || !_isAvailable || _speechToText == null) {
      if (kDebugMode) {
        print('Voice service not ready: initialized=$_isInitialized, available=$_isAvailable');
      }
      return false;
    }

    // Check if already listening to avoid duplicate calls
    if (_speechToText != null) {
      try {
        final isListening = _speechToText!.isListening;
        if (isListening == true) {
          if (kDebugMode) {
            print('Already listening, stopping first');
          }
          await _speechToText!.stop();
          // Wait a moment for the stop to complete
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error checking listening state: $e');
        }
      }
    }

    try {
      _recognizedText = null;
      _confidence = 0.0;
      _errorMessage = null;
      
      if (kDebugMode) {
        print('Attempting to start listening...');
      }

      // Set state to listening before actually starting
      _updateState(VoiceInputState.listening);

      final success = await _speechToText!.listen(
        onResult: _onSpeechResult,
        localeId: localeId ?? 'en_US',
        listenFor: listenFor ?? const Duration(seconds: 5),
        pauseFor: pauseFor ?? const Duration(seconds: 2),
        // Important: Web requires explicit user gesture, so set this
        onSoundLevelChange: (level) {
          if (kDebugMode && level > 0) {
            print('Sound detected: $level');
          }
        },
      );

      if (kDebugMode) {
        print('Listen result: $success');
      }

      if (success != true) {
        _errorMessage = 'Failed to start listening - check microphone permissions';
        _updateState(VoiceInputState.error);
        return false;
      }

      return true;
      
    } catch (e) {
      _errorMessage = 'Error starting voice input: $e';
      _updateState(VoiceInputState.error);
      
      if (kDebugMode) {
        print('StartListening error: $e');
      }
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_speechToText != null) {
      try {
        final isListening = _speechToText!.isListening;
        if (isListening == true) {
          await _speechToText!.stop();
          _updateState(VoiceInputState.completed);
        }
      } catch (e) {
        if (kDebugMode) {
          print('StopListening error: $e');
        }
      }
    }
  }

  Future<void> cancel() async {
    if (_speechToText != null) {
      try {
        await _speechToText!.cancel();
        // Wait a moment for cancellation to complete
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        if (kDebugMode) {
          print('Cancel error: $e');
        }
      }
    }
    
    // Reset all state variables
    _recognizedText = null;
    _confidence = 0.0;
    _errorMessage = null;
    _updateState(VoiceInputState.idle);
    
    if (kDebugMode) {
      print('Voice service cancelled and reset to idle state');
    }
  }

  void _onSpeechResult(result) {
    try {
      _recognizedText = result.recognizedWords;
      _confidence = result.confidence;
      
      if (result.finalResult) {
        _updateState(VoiceInputState.completed);
      } else {
        _updateState(VoiceInputState.processing);
      }
      
      if (kDebugMode) {
        print('Speech result: $_recognizedText (confidence: $_confidence)');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Speech result error: $e');
      }
    }
  }

  void _onSpeechError(error) {
    _errorMessage = error.errorMsg;
    _updateState(VoiceInputState.error);
    
    if (kDebugMode) {
      print('Speech error: $_errorMessage');
    }
  }

  void _onSpeechStatus(String status) {
    if (kDebugMode) {
      print('Speech status: $status');
    }
    
    switch (status) {
      case 'listening':
        _updateState(VoiceInputState.listening);
        break;
      case 'notListening':
        // Only go to idle if we haven't completed or errored
        if (_state == VoiceInputState.listening || _state == VoiceInputState.processing) {
          // If we were listening but now not listening without a result, 
          // it might be a timeout or permission issue
          if (_recognizedText == null || _recognizedText!.isEmpty) {
            _errorMessage = 'No speech detected - try speaking louder or check microphone';
            _updateState(VoiceInputState.error);
          } else {
            _updateState(VoiceInputState.idle);
          }
        }
        break;
      case 'done':
        // Speech recognition session completed
        if (_recognizedText != null && _recognizedText!.isNotEmpty) {
          _updateState(VoiceInputState.completed);
        } else {
          // No results captured
          _errorMessage = 'No speech detected - ensure microphone access is granted';
          _updateState(VoiceInputState.error);
        }
        break;
    }
  }

  VoiceCommand? parseLastCommand() {
    if (_recognizedText == null || _recognizedText!.isEmpty) {
      return null;
    }
    
    return VoiceCommand.parseCommand(_recognizedText!);
  }

  // Convenience method for quick command recognition
  Future<VoiceCommand?> listenForCommand({
    Duration? timeout,
    String? localeId,
  }) async {
    // Ensure clean state before starting
    if (_speechToText != null) {
      try {
        if (_speechToText!.isListening) {
          await _speechToText!.stop();
          await Future.delayed(const Duration(milliseconds: 100)); // Wait for stop to complete
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error stopping previous listen: $e');
        }
      }
    }
    
    // Reset state variables
    _recognizedText = null;
    _confidence = 0.0;
    _errorMessage = null;
    _updateState(VoiceInputState.idle);
    
    final success = await startListening(
      localeId: localeId,
      listenFor: timeout ?? const Duration(seconds: 3),
    );
    
    if (!success) {
      if (kDebugMode) {
        print('listenForCommand: Failed to start listening');
      }
      return null;
    }

    // Wait for completion or timeout
    final completer = Completer<VoiceCommand?>();
    late StreamSubscription subscription;
    
    subscription = stateStream.listen((audioState) {
      if (kDebugMode) {
        print('listenForCommand: State changed to ${audioState.voiceInputState}');
      }
      
      if (audioState.voiceInputState == VoiceInputState.completed) {
        subscription.cancel();
        final command = parseLastCommand();
        if (kDebugMode) {
          print('listenForCommand: Completed with command: $command');
        }
        completer.complete(command);
      } else if (audioState.voiceInputState == VoiceInputState.error) {
        subscription.cancel();
        if (kDebugMode) {
          print('listenForCommand: Error state - ${audioState.errorMessage}');
        }
        completer.complete(null);
      }
    });

    // Timeout fallback
    Timer(timeout ?? const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        if (kDebugMode) {
          print('listenForCommand: Timeout reached');
        }
        subscription.cancel();
        stopListening();
        completer.complete(null);
      }
    });

    return completer.future;
  }

  List<String> getAvailableLocales() {
    if (_speechToText == null || !_isAvailable) return [];
    
    try {
      // Return commonly supported locales as fallback
      return ['en_US', 'en_GB', 'es_ES', 'fr_FR', 'de_DE'];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting locales: $e');
      }
      return ['en_US'];
    }
  }

  void _updateState(VoiceInputState newState) {
    _state = newState;
    _stateController.add(AudioState(
      voiceInputState: _state,
      recognizedText: _recognizedText,
      confidence: _confidence,
      errorMessage: _errorMessage,
      isAvailable: _isAvailable,
    ));
  }

  // Testing method to manually set recognized text for debugging
  void setRecognizedTextForTesting(String text) {
    _recognizedText = text;
    _updateState(VoiceInputState.processing);
  }

  // Method to manually set permission state when we know permissions are granted
  void setPermissionGranted(bool granted) {
    _hasPermissions = granted;
    if (kDebugMode) {
      print('🎙️ Permission state manually set to: $granted');
    }
  }

  void dispose() {
    _stateController.close();
    _speechToText?.cancel();
  }
}
