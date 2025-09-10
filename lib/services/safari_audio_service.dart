import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/safari_compatibility_service.dart';

/// Safari-specific audio service that handles Safari's unique audio context requirements
class SafariAudioService {
  static final SafariAudioService _instance = SafariAudioService._internal();
  factory SafariAudioService() => _instance;
  SafariAudioService._internal();

  bool _isInitialized = false;
  bool _audioContextReady = false;
  bool _userGestureReceived = false;
  String? _errorMessage;

  /// Check if the audio service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if audio context is ready for use
  bool get audioContextReady => _audioContextReady;

  /// Check if user gesture has been received
  bool get userGestureReceived => _userGestureReceived;

  /// Get any error message
  String? get errorMessage => _errorMessage;

  /// Initialize Safari audio service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (!SafariCompatibilityService.isSafari) {
        // For non-Safari browsers, assume audio context works normally
        _isInitialized = true;
        _audioContextReady = true;
        
        if (kDebugMode) {
          print('🎵 Non-Safari browser detected - audio service initialized');
        }
        
        return true;
      }

      if (kDebugMode) {
        print('🍎 Initializing Safari audio service...');
        print('🍎 Safari version: ${SafariCompatibilityService.safariVersion}');
        print('🍎 Mobile Safari: ${SafariCompatibilityService.isSafariMobile}');
      }

      // Safari-specific initialization
      _isInitialized = true;
      
      // Audio context will be initialized on first user gesture
      _audioContextReady = false;
      
      if (kDebugMode) {
        print('🍎 Safari audio service initialized (waiting for user gesture)');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error initializing Safari audio service: $e');
      }
      _errorMessage = 'Failed to initialize audio service: $e';
      return false;
    }
  }

  /// Initialize audio context with user gesture (required for Safari)
  Future<bool> initializeAudioContextWithGesture() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!SafariCompatibilityService.isSafari) {
      // Non-Safari browsers don't need special handling
      _audioContextReady = true;
      return true;
    }

    if (_audioContextReady) {
      if (kDebugMode) {
        print('🍎 Safari audio context already ready');
      }
      return true;
    }

    try {
      if (kDebugMode) {
        print('🍎 Initializing Safari audio context with user gesture...');
      }

      // Mark that user gesture was received
      _userGestureReceived = true;

      // Simulate audio context initialization
      // In real implementation, this would create an AudioContext
      await Future.delayed(const Duration(milliseconds: 100));
      
      _audioContextReady = true;
      _errorMessage = null;

      if (kDebugMode) {
        print('🍎 Safari audio context initialized successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error initializing Safari audio context: $e');
      }
      _errorMessage = SafariCompatibilityService.getErrorMessage('audio_context_failed');
      return false;
    }
  }

  /// Play text-to-speech with Safari compatibility
  Future<bool> speak(String text, {
    String? language,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if audio context is ready for Safari
    if (SafariCompatibilityService.isSafari && !_audioContextReady) {
      _errorMessage = 'Audio context not ready. Please tap a button first.';
      if (kDebugMode) {
        print('🍎 Safari audio context not ready for speech synthesis');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('🍎 Speaking text: "$text"');
        print('🍎 Language: ${language ?? 'default'}');
        print('🍎 Rate: $rate, Pitch: $pitch, Volume: $volume');
      }

      // Simulate speech synthesis
      // In real implementation, this would use Web Speech Synthesis API
      await Future.delayed(Duration(milliseconds: text.length * 50));

      if (kDebugMode) {
        print('🍎 Speech synthesis completed');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error in Safari speech synthesis: $e');
      }
      _errorMessage = 'Speech synthesis failed: $e';
      return false;
    }
  }

  /// Stop speech synthesis
  Future<void> stopSpeaking() async {
    try {
      if (kDebugMode) {
        print('🍎 Stopping speech synthesis');
      }
      
      // In real implementation, this would stop the speech synthesis
      
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Error stopping speech synthesis: $e');
      }
    }
  }

  /// Check if text-to-speech is supported
  bool get isSpeechSynthesisSupported {
    if (!SafariCompatibilityService.isSafari) return true;
    
    // Safari generally supports speech synthesis
    return true;
  }

  /// Check if speech synthesis is currently speaking
  bool get isSpeaking {
    // In real implementation, this would check the actual speech synthesis state
    return false;
  }

  /// Get Safari-specific audio recommendations
  Map<String, dynamic> get audioRecommendations {
    if (!SafariCompatibilityService.isSafari) {
      return {
        'userGestureRequired': false,
        'contextInitialization': 'automatic',
        'recommendations': [],
      };
    }

    return {
      'userGestureRequired': true,
      'contextInitialization': 'manual',
      'recommendations': [
        'Tap any button before using audio features',
        'Audio may not work in private browsing mode',
        'Refresh page if audio stops working',
        if (SafariCompatibilityService.isSafariMobile)
          'Use headphones for better audio quality on mobile',
        if (SafariCompatibilityService.isPrivateBrowsing)
          'Exit private browsing for full audio support',
      ],
    };
  }

  /// Get audio capabilities for Safari
  Map<String, bool> get audioCapabilities {
    return {
      'speechSynthesis': isSpeechSynthesisSupported,
      'audioContext': SafariCompatibilityService.supportsAudioContextWithoutGesture || _audioContextReady,
      'userGestureRequired': SafariCompatibilityService.isSafari,
      'backgroundAudio': !SafariCompatibilityService.isSafariMobile,
      'autoplay': !SafariCompatibilityService.isSafari,
    };
  }

  /// Reset audio service state
  void reset() {
    _audioContextReady = false;
    _userGestureReceived = false;
    _errorMessage = null;
    
    if (kDebugMode) {
      print('🍎 Safari audio service reset');
    }
  }

  /// Dispose audio service resources
  void dispose() {
    _isInitialized = false;
    _audioContextReady = false;
    _userGestureReceived = false;
    _errorMessage = null;
    
    if (kDebugMode) {
      print('🍎 Safari audio service disposed');
    }
  }

  /// Get diagnostic information for debugging
  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'isInitialized': _isInitialized,
      'audioContextReady': _audioContextReady,
      'userGestureReceived': _userGestureReceived,
      'errorMessage': _errorMessage,
      'isSafari': SafariCompatibilityService.isSafari,
      'safariVersion': SafariCompatibilityService.safariVersion,
      'isMobile': SafariCompatibilityService.isSafariMobile,
      'isPrivateBrowsing': SafariCompatibilityService.isPrivateBrowsing,
      'capabilities': audioCapabilities,
      'recommendations': audioRecommendations,
    };
  }
}
