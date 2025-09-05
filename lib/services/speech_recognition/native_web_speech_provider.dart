import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';

/// Native Web Speech API provider using the speech_to_text package
/// Provides the best support for Chrome and Edge browsers
class NativeWebSpeechProvider extends SpeechRecognitionProvider {
  SpeechToText? _speechToText;
  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasPermissions = false;
  String? _lastRecognizedText;
  double _confidence = 0.0;
  String? _errorMessage;

  @override
  String get providerName => 'Native Web Speech API';

  @override
  Map<String, dynamic> get capabilities => {
    'continuous': true,
    'interimResults': true,
    'maxAlternatives': 3,
    'languages': ['en-US', 'en-GB', 'es-ES', 'fr-FR', 'de-DE'],
    'maxDuration': 60, // seconds
    'requiresInternet': true,
    'requiresHttps': true,
  };

  @override
  Future<bool> isSupported() async {
    if (!kIsWeb) return false;
    
    try {
      _speechToText ??= SpeechToText();
      
      // Try to initialize to check support
      final isAvailable = await _speechToText!.initialize(
        onError: (error) {
          if (kDebugMode) {
            print('🎙️ Native provider initialization error: $error');
          }
        },
        onStatus: (status) {
          if (kDebugMode) {
            print('🎙️ Native provider status change: $status');
          }
          
          // Track status changes
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
        debugLogging: kDebugMode,
      );
      
      _isInitialized = isAvailable;
      
      if (kDebugMode) {
        print('🎙️ Native Web Speech provider supported: $isAvailable');
      }
      
      return isAvailable;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Native provider support check failed: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      final supported = await isSupported();
      if (!supported) return false;
    }

    try {
      if (kDebugMode) {
        print('🎙️ Native provider requesting microphone permissions...');
      }

      // For web, if the speech service is available and initialized, 
      // assume permissions are available. The real permission check 
      // happens when we actually start listening for voice commands.
      if (_speechToText!.isAvailable) {
        _hasPermissions = true;
        if (kDebugMode) {
          print('🎙️ Native provider: Speech service is available, assuming permissions granted');
          
          // Additional debug info about the speech service
          print('🎙️ Debug - Speech locales available: ${_speechToText!.locales}');
          print('🎙️ Debug - Speech is not listening: ${!_speechToText!.isListening}');
        }
        return true;
      }

      if (kDebugMode) {
        print('🎙️ Native provider: Speech service not available, permissions likely denied');
      }
      
      _hasPermissions = false;
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Native provider permission request failed: $e');
      }
      _errorMessage = 'Permission request failed: $e';
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    if (!_isInitialized) return false;
    
    try {
      // Return cached permission state if available
      return _hasPermissions;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> startListening({
    Duration? timeout,
    String? language,
    bool continuous = false,
  }) async {
    if (!_isInitialized) {
      final supported = await isSupported();
      if (!supported) {
        _errorMessage = 'Speech recognition not supported';
        return false;
      }
    }

    if (!_hasPermissions) {
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        _errorMessage = 'Microphone permissions not granted';
        return false;
      }
    }

    // Stop any existing listening session - check both our flag and the actual API state
    if (_isListening || (_speechToText != null && _speechToText!.isListening)) {
      if (kDebugMode) {
        print('🎙️ Stopping existing listening session before starting new one');
        print('   - _isListening: $_isListening');
        print('   - speechToText.isListening: ${_speechToText?.isListening}');
      }
      
      await stopListening();
      
      // Wait longer to ensure the previous session is fully stopped
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Double-check that it's actually stopped
      if (_speechToText != null && _speechToText!.isListening) {
        if (kDebugMode) {
          print('🎙️ Speech recognition still listening after stop attempt, forcing cancel');
        }
        await cancel();
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    try {
      _lastRecognizedText = null;
      _confidence = 0.0;
      _errorMessage = null;

      // Start listening - the listen method returns void, not bool
      if (kDebugMode) {
        print('🎙️ About to start listening with language: ${language ?? 'en_US'}');
        print('🎙️ Timeout: ${timeout ?? const Duration(seconds: 30)}');
        print('🎙️ Speech service available: ${_speechToText!.isAvailable}');
        print('🎙️ Speech service not listening: ${!_speechToText!.isListening}');
      }

      await _speechToText!.listen(
        onResult: _onSpeechResult,
        localeId: language ?? 'en_US',
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3), // Increased pause time
        onSoundLevelChange: (level) {
          // Always log sound levels for debugging
          if (kDebugMode) {
            print('🎙️ Sound level: $level');
          }
        },
        cancelOnError: false,
        partialResults: true,
      );

      // Check if we're actually listening after the call
      await Future.delayed(const Duration(milliseconds: 100));
      final isActuallyListening = _speechToText!.isListening;
      _isListening = isActuallyListening;

      if (kDebugMode) {
        print('🎙️ Native provider start listening completed, isListening: $isActuallyListening');
      }

      if (!isActuallyListening) {
        _errorMessage = 'Failed to start listening - not in listening state';
      }

      return isActuallyListening;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Native provider start listening error: $e');
      }
      _errorMessage = 'Error starting speech recognition: $e';
      _isListening = false;
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (_speechToText != null && _isListening) {
      try {
        await _speechToText!.stop();
        _isListening = false;
        
        if (kDebugMode) {
          print('🎙️ Native provider stopped listening');
        }
      } catch (e) {
        if (kDebugMode) {
          print('🎙️ Native provider stop error: $e');
        }
      }
    }
  }

  @override
  Future<void> cancel() async {
    if (_speechToText != null) {
      try {
        await _speechToText!.cancel();
        _isListening = false;
        _lastRecognizedText = null;
        _confidence = 0.0;
        
        if (kDebugMode) {
          print('🎙️ Native provider cancelled');
        }
      } catch (e) {
        if (kDebugMode) {
          print('🎙️ Native provider cancel error: $e');
        }
      }
    }
  }

  void _onSpeechResult(result) {
    try {
      if (kDebugMode) {
        print('🎙️ _onSpeechResult called with: $result');
        print('🎙️ Result type: ${result.runtimeType}');
      }
      
      _lastRecognizedText = result.recognizedWords;
      _confidence = result.confidence;
      
      if (kDebugMode) {
        print('🎙️ Speech result received: "${result.recognizedWords}"');
        print('🎙️ Confidence: ${result.confidence}');
        print('🎙️ Final result: ${result.finalResult}');
        print('🎙️ Has confidence: ${result.hasConfidenceRating}');
        if (result.alternates != null && result.alternates.isNotEmpty) {
          print('🎙️ Alternates: ${result.alternates.map((a) => a.recognizedWords).join(", ")}');
        }
      }
      
      if (result.finalResult) {
        _isListening = false;
        if (kDebugMode) {
          print('🎙️ Final result received - stopped listening');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Error processing speech result: $e');
        print('🎙️ Result object: $result');
      }
    }
  }

  @override
  String? get lastRecognizedText => _lastRecognizedText;

  @override
  double get confidence => _confidence;

  @override
  bool get isListening => _isListening;

  @override
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    if (_speechToText != null) {
      try {
        _speechToText!.cancel();
      } catch (e) {
        // Ignore disposal errors
      }
    }
    
    _speechToText = null;
    _isInitialized = false;
    _isListening = false;
    _hasPermissions = false;
    _lastRecognizedText = null;
    _confidence = 0.0;
    _errorMessage = null;
    
    if (kDebugMode) {
      print('🎙️ Native Web Speech provider disposed');
    }
  }
}
