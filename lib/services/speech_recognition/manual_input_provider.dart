import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/services/speech_recognition/speech_recognition_provider.dart';

/// Manual input provider that provides text input as a fallback
/// Used when speech recognition is not available or not working
class ManualInputProvider extends SpeechRecognitionProvider {
  String? _lastInput;
  bool _isListening = false;
  String? _errorMessage;
  Completer<String?>? _inputCompleter;

  @override
  String get providerName => 'Manual Text Input';

  @override
  Map<String, dynamic> get capabilities => {
    'continuous': false,
    'interimResults': false,
    'maxAlternatives': 1,
    'languages': ['any'],
    'maxDuration': 0, // No timeout for manual input
    'requiresInternet': false,
    'requiresHttps': false,
    'isManual': true,
  };

  @override
  Future<bool> isSupported() async {
    // Manual input is always available as a fallback
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    // No permissions needed for manual input
    return true;
  }

  @override
  Future<bool> hasPermissions() async {
    // Always has "permissions" for manual input
    return true;
  }

  @override
  Future<bool> startListening({
    Duration? timeout,
    String? language,
    bool continuous = false,
  }) async {
    if (_isListening) {
      await cancel();
    }

    _isListening = true;
    _lastInput = null;
    _errorMessage = null;
    _inputCompleter = Completer<String?>();

    if (kDebugMode) {
      print('🎙️ Manual input provider ready for input');
    }

    // Set up timeout if specified
    if (timeout != null) {
      Timer(timeout, () {
        if (_isListening && !_inputCompleter!.isCompleted) {
          _completeWithTimeout();
        }
      });
    }

    return true;
  }

  @override
  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      
      if (_inputCompleter != null && !_inputCompleter!.isCompleted) {
        _inputCompleter!.complete(_lastInput);
      }
      
      if (kDebugMode) {
        print('🎙️ Manual input provider stopped listening');
      }
    }
  }

  @override
  Future<void> cancel() async {
    if (_isListening) {
      _isListening = false;
      _lastInput = null;
      
      if (_inputCompleter != null && !_inputCompleter!.isCompleted) {
        _inputCompleter!.complete(null);
      }
      
      if (kDebugMode) {
        print('🎙️ Manual input provider cancelled');
      }
    }
  }

  /// Submit manual text input
  /// This method should be called by the UI when the user submits text
  void submitInput(String input) {
    if (!_isListening) {
      if (kDebugMode) {
        print('🎙️ Manual input provider not listening, ignoring input: "$input"');
      }
      return;
    }

    _lastInput = input.trim();
    
    if (kDebugMode) {
      print('🎙️ Manual input received: "$_lastInput"');
    }

    if (_inputCompleter != null && !_inputCompleter!.isCompleted) {
      _inputCompleter!.complete(_lastInput);
    }
    
    _isListening = false;
  }

  /// Wait for manual input to be submitted
  /// Returns the input text or null if cancelled/timeout
  Future<String?> waitForInput() async {
    if (!_isListening || _inputCompleter == null) {
      return null;
    }
    
    return await _inputCompleter!.future;
  }

  void _completeWithTimeout() {
    _errorMessage = 'Input timeout - no text was entered';
    _isListening = false;
    
    if (_inputCompleter != null && !_inputCompleter!.isCompleted) {
      _inputCompleter!.complete(null);
    }
    
    if (kDebugMode) {
      print('🎙️ Manual input provider timed out');
    }
  }

  @override
  String? get lastRecognizedText => _lastInput;

  @override
  double get confidence => _lastInput != null ? 1.0 : 0.0; // Perfect confidence for manual input

  @override
  bool get isListening => _isListening;

  @override
  String? get errorMessage => _errorMessage;

  @override
  void dispose() {
    if (_isListening) {
      cancel();
    }
    
    _lastInput = null;
    _errorMessage = null;
    _inputCompleter = null;
    
    if (kDebugMode) {
      print('🎙️ Manual input provider disposed');
    }
  }

  /// Get instructions for manual input mode
  static String getInstructions() {
    return 'Voice commands are not available in this browser. '
           'Please use the text input field to enter your responses or commands.';
  }

  /// Get manual command mappings for voice commands
  static Map<String, String> getCommandMappings() {
    return {
      'next': 'Type "next" to continue',
      'previous': 'Type "previous" to go back',
      'repeat': 'Type "repeat" to hear again',
      'pause': 'Type "pause" to pause',
      'play': 'Type "play" to resume',
      'A': 'Type "A" for option A',
      'B': 'Type "B" for option B',
      'C': 'Type "C" for option C',
      'D': 'Type "D" for option D',
      'true': 'Type "true" for true',
      'false': 'Type "false" for false',
    };
  }
}
