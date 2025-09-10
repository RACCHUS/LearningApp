import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';
import 'package:learning_pwa/services/safari_compatibility_service.dart';

/// Safari-specific speech recognition provider
/// Handles Safari's unique requirements and limitations for Web Speech API
class SafariSpeechProvider extends SpeechRecognitionProvider {
  bool _isInitialized = false;
  bool _isListening = false;
  bool _hasPermissions = false;
  String? _lastRecognizedText;
  double _confidence = 0.0;
  String? _errorMessage;
  Timer? _timeoutTimer;
  Completer<bool>? _permissionCompleter;
  bool _userGestureReceived = false;

  @override
  String get providerName => 'Safari Web Speech API';

  @override
  Map<String, dynamic> get capabilities => {
    'continuous': false, // Safari doesn't handle continuous well
    'interimResults': false, // Safari has issues with interim results
    'maxAlternatives': 1, // Keep it simple for Safari
    'languages': ['en-US', 'en-GB'],
    'maxDuration': 10, // Shorter timeout for Safari
    'requiresInternet': true,
    'requiresHttps': true,
    'requiresUserGesture': true,
    'isSafariOptimized': true,
  };

  @override
  Future<bool> isSupported() async {
    try {
      // Check if we're in Safari and if it supports speech recognition
      if (!SafariCompatibilityService.isSafari) {
        if (kDebugMode) {
          print('🍎 Safari provider: Not running in Safari browser');
        }
        return false;
      }

      if (!SafariCompatibilityService.supportsSpeechRecognition) {
        if (kDebugMode) {
          print('🍎 Safari provider: Safari version ${SafariCompatibilityService.safariVersion} does not support speech recognition');
        }
        return false;
      }

      // Test speech capabilities
      final testResults = await SafariCompatibilityService.testSpeechCapabilities();
      _isInitialized = testResults['available'] == true;

      if (kDebugMode) {
        print('🍎 Safari provider supported: $_isInitialized');
        print('🍎 Test results: $testResults');
      }

      return _isInitialized;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Safari provider support check failed: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      final supported = await isSupported();
      if (!supported) {
        _errorMessage = SafariCompatibilityService.getErrorMessage('speech_not_supported');
        return false;
      }
    }

    try {
      if (kDebugMode) {
        print('🍎 Safari provider: Requesting microphone permissions...');
        print('🍎 User gesture received: $_userGestureReceived');
      }

      // Safari requires explicit user gesture for microphone access
      if (!_userGestureReceived) {
        _errorMessage = 'Safari requires a user tap/click to access the microphone. Please tap the microphone button.';
        if (kDebugMode) {
          print('🍎 Safari provider: No user gesture detected, cannot request permissions');
        }
        return false;
      }

      // Show Safari-specific permission request dialog
      final granted = await _showSafariPermissionDialog();
      _hasPermissions = granted;

      if (granted) {
        if (kDebugMode) {
          print('🍎 Safari provider: Microphone permissions granted');
        }
      } else {
        _errorMessage = SafariCompatibilityService.getErrorMessage('permission_denied');
        if (kDebugMode) {
          print('🍎 Safari provider: Microphone permissions denied');
        }
      }

      return granted;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Safari provider permission request failed: $e');
      }
      _errorMessage = SafariCompatibilityService.getErrorMessage('permission_denied');
      return false;
    }
  }

  @override
  Future<bool> hasPermissions() async {
    return _hasPermissions;
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
        _errorMessage = SafariCompatibilityService.getErrorMessage('speech_not_supported');
        return false;
      }
    }

    if (!_hasPermissions) {
      final hasPerms = await requestPermissions();
      if (!hasPerms) {
        return false;
      }
    }

    if (_isListening) {
      await cancel();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    try {
      _lastRecognizedText = null;
      _confidence = 0.0;
      _errorMessage = null;

      // Safari-specific configuration
      final safariConfig = SafariCompatibilityService.safariSpeechConfig;
      final safariTimeout = Duration(seconds: safariConfig['timeoutDuration'] ?? 10);

      if (kDebugMode) {
        print('🍎 Safari provider: Starting speech recognition...');
        print('🍎 Language: ${language ?? 'en-US'}');
        print('🍎 Timeout: ${timeout ?? safariTimeout}');
        print('🍎 Safari config: $safariConfig');
      }

      // Set up timeout timer
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(timeout ?? safariTimeout, () {
        if (_isListening) {
          _handleTimeout();
        }
      });

      // Simulate Safari speech recognition behavior
      // In a real implementation, this would use the Web Speech API
      _isListening = true;
      
      // Simulate a delay and then stop listening
      Timer(const Duration(seconds: 2), () {
        if (_isListening) {
          _simulateSpeechResult('safari test result');
        }
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🍎 Safari provider start listening error: $e');
      }
      _errorMessage = 'Error starting Safari speech recognition: $e';
      _isListening = false;
      return false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (_isListening) {
      _timeoutTimer?.cancel();
      _isListening = false;
      
      if (kDebugMode) {
        print('🍎 Safari provider: Stopped listening');
      }
    }
  }

  @override
  Future<void> cancel() async {
    _timeoutTimer?.cancel();
    _isListening = false;
    _lastRecognizedText = null;
    _confidence = 0.0;
    
    if (kDebugMode) {
      print('🍎 Safari provider: Cancelled');
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

  /// Check if user gesture has been received
  bool get userGestureReceived => _userGestureReceived;

  /// Indicate that a user gesture was received (for Safari permission requirements)
  void setUserGestureReceived() {
    _userGestureReceived = true;
    if (kDebugMode) {
      print('🍎 Safari provider: User gesture received');
    }
  }

  /// Show Safari-specific permission request dialog
  Future<bool> _showSafariPermissionDialog() async {
    if (_permissionCompleter != null && !_permissionCompleter!.isCompleted) {
      return await _permissionCompleter!.future;
    }

    _permissionCompleter = Completer<bool>();

    if (kDebugMode) {
      print('🍎 Safari provider: Showing permission dialog');
    }

    // In a real implementation, this would trigger the browser's permission dialog
    // For now, simulate the process
    Timer(const Duration(seconds: 1), () {
      if (!_permissionCompleter!.isCompleted) {
        // Simulate permission granted (in real app, this depends on user choice)
        _permissionCompleter!.complete(true);
      }
    });

    return await _permissionCompleter!.future;
  }

  /// Handle speech recognition timeout
  void _handleTimeout() {
    if (kDebugMode) {
      print('🍎 Safari provider: Speech recognition timeout');
    }
    
    _isListening = false;
    _errorMessage = SafariCompatibilityService.getErrorMessage('timeout');
    _timeoutTimer?.cancel();
  }

  /// Simulate speech recognition result (for testing)
  void _simulateSpeechResult(String text) {
    _lastRecognizedText = text;
    _confidence = 0.8; // Simulate moderate confidence
    _isListening = false;
    _timeoutTimer?.cancel();

    if (kDebugMode) {
      print('🍎 Safari provider: Speech result: "$text" (confidence: $_confidence)');
    }
  }

  /// Get Safari-specific setup instructions
  List<String> getSetupInstructions() {
    return SafariCompatibilityService.permissionInstructions;
  }

  /// Get Safari compatibility warnings
  List<String> getCompatibilityWarnings() {
    return SafariCompatibilityService.compatibilityWarnings;
  }

  /// Get recommended fallback options
  Map<String, String> getFallbackOptions() {
    return SafariCompatibilityService.fallbackOptions;
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _permissionCompleter = null;
    _isInitialized = false;
    _isListening = false;
    _hasPermissions = false;
    _lastRecognizedText = null;
    _confidence = 0.0;
    _errorMessage = null;
    _userGestureReceived = false;
    
    if (kDebugMode) {
      print('🍎 Safari speech provider disposed');
    }
  }
}
