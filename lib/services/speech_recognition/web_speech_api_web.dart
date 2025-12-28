/// Web Speech API JavaScript interop bindings
/// Provides access to the native browser Speech Recognition API
///
/// This file uses dart:js_interop for modern Flutter web compatibility
/// Compatible with Dart 3.8.x and Flutter 3.32.x

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// External binding to SpeechRecognition constructor
@JS('SpeechRecognition')
external JSFunction? get _speechRecognitionConstructor;

/// External binding to webkitSpeechRecognition constructor (Safari)
@JS('webkitSpeechRecognition')
external JSFunction? get _webkitSpeechRecognitionConstructor;

/// Check if SpeechRecognition API is available in the browser
bool get isSpeechRecognitionSupported {
  if (!kIsWeb) return false;

  try {
    return _speechRecognitionConstructor != null ||
        _webkitSpeechRecognitionConstructor != null;
  } catch (e) {
    if (kDebugMode) {
      print('🎙️ Error checking speech recognition support: $e');
    }
    return false;
  }
}

/// Wrapper class for Web Speech API
/// Handles both standard SpeechRecognition and webkit-prefixed version
class WebSpeechRecognition {
  JSObject? _recognition;
  bool _isListening = false;
  String? _lastResult;
  double _confidence = 0.0;
  String? _errorMessage;

  final _resultController = StreamController<SpeechResult>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _endController = StreamController<void>.broadcast();

  Stream<SpeechResult> get onResult => _resultController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<void> get onEnd => _endController.stream;

  bool get isListening => _isListening;
  String? get lastResult => _lastResult;
  double get confidence => _confidence;
  String? get errorMessage => _errorMessage;

  /// Initialize the speech recognition instance
  bool initialize({String language = 'en-US', bool continuous = false}) {
    if (!kIsWeb) {
      _errorMessage = 'Speech recognition is only available on web platforms';
      return false;
    }

    try {
      // Try standard API first, then webkit prefix
      _recognition = _createRecognitionInstance();

      if (_recognition == null) {
        _errorMessage = 'Speech recognition not supported in this browser';
        return false;
      }

      // Configure recognition
      _recognition!.setProperty('lang'.toJS, language.toJS);
      _recognition!.setProperty('continuous'.toJS, continuous.toJS);
      _recognition!.setProperty('interimResults'.toJS, false.toJS);
      _recognition!.setProperty('maxAlternatives'.toJS, 1.toJS);

      // Set up event handlers
      _setupEventHandlers();

      if (kDebugMode) {
        print('🎙️ WebSpeechRecognition initialized with language: $language');
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize speech recognition: $e';
      if (kDebugMode) {
        print('🎙️ WebSpeechRecognition initialization error: $e');
      }
      return false;
    }
  }

  JSObject? _createRecognitionInstance() {
    try {
      // Try webkit prefix first (Safari)
      if (_webkitSpeechRecognitionConstructor != null) {
        final ctor = _webkitSpeechRecognitionConstructor!;
        return ctor.callAsConstructor<JSObject>();
      }

      // Try standard SpeechRecognition
      if (_speechRecognitionConstructor != null) {
        final ctor = _speechRecognitionConstructor!;
        return ctor.callAsConstructor<JSObject>();
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Error creating recognition instance: $e');
      }
      return null;
    }
  }

  void _setupEventHandlers() {
    if (_recognition == null) return;

    // onresult handler - capture results from speech recognition
    _recognition!.setProperty(
      'onresult'.toJS,
      ((JSObject event) {
        _handleResult(event);
      }).toJS,
    );

    // onerror handler
    _recognition!.setProperty(
      'onerror'.toJS,
      ((JSObject event) {
        _handleError(event);
      }).toJS,
    );

    // onend handler
    _recognition!.setProperty(
      'onend'.toJS,
      (() {
        _handleEnd();
      }).toJS,
    );

    // onstart handler
    _recognition!.setProperty(
      'onstart'.toJS,
      (() {
        _isListening = true;
        if (kDebugMode) {
          print('🎙️ Speech recognition started');
        }
      }).toJS,
    );
  }

  void _handleResult(JSObject event) {
    try {
      final results = event.getProperty<JSObject?>('results'.toJS);
      if (results == null) return;

      // Get the length of results
      final lengthValue = results.getProperty<JSNumber?>('length'.toJS);
      final length = lengthValue?.toDartInt ?? 0;
      if (length == 0) return;

      // Get the last result using bracket notation
      final lastIndex = length - 1;
      final result = results.getProperty<JSObject?>(lastIndex.toJS);
      if (result == null) return;

      // Get first alternative
      final firstAlternative = result.getProperty<JSObject?>(0.toJS);
      if (firstAlternative == null) return;

      // Extract transcript and confidence
      final transcriptJS =
          firstAlternative.getProperty<JSString?>('transcript'.toJS);
      _lastResult = transcriptJS?.toDart;

      final confidenceJS =
          firstAlternative.getProperty<JSNumber?>('confidence'.toJS);
      _confidence = confidenceJS?.toDartDouble ?? 0.0;

      if (kDebugMode) {
        print('🎙️ Speech result: "$_lastResult" (confidence: $_confidence)');
      }

      _resultController.add(SpeechResult(
        transcript: _lastResult ?? '',
        confidence: _confidence,
        isFinal: true,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Error handling speech result: $e');
      }
    }
  }

  void _handleError(JSObject event) {
    try {
      final errorJS = event.getProperty<JSString?>('error'.toJS);
      final errorType = errorJS?.toDart ?? 'unknown';
      _errorMessage = _getErrorMessage(errorType);
      _isListening = false;

      if (kDebugMode) {
        print('🎙️ Speech recognition error: $errorType - $_errorMessage');
      }

      _errorController.add(_errorMessage!);
    } catch (e) {
      _errorMessage = 'Speech recognition error: $e';
      _errorController.add(_errorMessage!);
    }
  }

  void _handleEnd() {
    _isListening = false;
    if (kDebugMode) {
      print('🎙️ Speech recognition ended');
    }
    _endController.add(null);
  }

  String _getErrorMessage(String errorType) {
    switch (errorType) {
      case 'not-allowed':
        return 'Microphone access denied. Please grant permission and try again.';
      case 'no-speech':
        return 'No speech detected. Please speak louder or check your microphone.';
      case 'audio-capture':
        return 'No microphone found. Please connect a microphone and try again.';
      case 'network':
        return 'Network error occurred. Please check your internet connection.';
      case 'aborted':
        return 'Speech recognition was cancelled.';
      case 'language-not-supported':
        return 'The selected language is not supported.';
      case 'service-not-allowed':
        return 'Speech recognition service is not available.';
      default:
        return 'Speech recognition error: $errorType';
    }
  }

  /// Start listening for speech
  Future<bool> start() async {
    if (_recognition == null) {
      _errorMessage = 'Speech recognition not initialized';
      return false;
    }

    if (_isListening) {
      await stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    try {
      _lastResult = null;
      _confidence = 0.0;
      _errorMessage = null;

      _recognition!.callMethod('start'.toJS);
      _isListening = true;

      return true;
    } catch (e) {
      _errorMessage = 'Failed to start speech recognition: $e';
      if (kDebugMode) {
        print('🎙️ Start error: $e');
      }
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stop() async {
    if (_recognition == null || !_isListening) return;

    try {
      _recognition!.callMethod('stop'.toJS);
      _isListening = false;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Stop error: $e');
      }
    }
  }

  /// Abort the current recognition session
  void abort() {
    if (_recognition == null) return;

    try {
      _recognition!.callMethod('abort'.toJS);
      _isListening = false;
      _lastResult = null;
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Abort error: $e');
      }
    }
  }

  /// Dispose of all resources
  void dispose() {
    abort();
    _resultController.close();
    _errorController.close();
    _endController.close();
    _recognition = null;
  }
}

/// Result from speech recognition
class SpeechResult {
  final String transcript;
  final double confidence;
  final bool isFinal;

  const SpeechResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
  });

  @override
  String toString() =>
      'SpeechResult(transcript: "$transcript", confidence: $confidence, isFinal: $isFinal)';
}
