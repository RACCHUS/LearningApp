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
  
  VoiceInputState _state = VoiceInputState.idle;
  String? _recognizedText;
  double _confidence = 0.0;
  String? _errorMessage;

  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;

  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
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
      _errorMessage = 'Failed to initialize speech recognition: $e';
      _updateState(VoiceInputState.error);
      
      if (kDebugMode) {
        print('VoiceInputService initialization error: $e');
      }
    }
  }

  Future<bool> checkPermissions() async {
    try {
      final status = await Permission.microphone.status;
      
      // More explicit null checking to avoid null boolean expressions
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
      return false;
    }

    // Check microphone permissions first
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      _errorMessage = 'Microphone permission denied';
      _updateState(VoiceInputState.error);
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
      _updateState(VoiceInputState.listening);

      if (kDebugMode) {
        print('Attempting to start listening...');
      }

      final success = await _speechToText!.listen(
        onResult: _onSpeechResult,
        localeId: localeId ?? 'en_US',
        listenFor: listenFor ?? const Duration(seconds: 5),
        pauseFor: pauseFor ?? const Duration(seconds: 2),
      );

      if (kDebugMode) {
        print('Listen result: $success');
      }

      if (success != true) {
        _errorMessage = 'Failed to start listening';
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
        _recognizedText = null;
        _confidence = 0.0;
        _updateState(VoiceInputState.idle);
      } catch (e) {
        if (kDebugMode) {
          print('Cancel error: $e');
        }
      }
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
        if (_state != VoiceInputState.completed && _state != VoiceInputState.error) {
          _updateState(VoiceInputState.idle);
        }
        break;
      case 'done':
        _updateState(VoiceInputState.completed);
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
    final success = await startListening(
      localeId: localeId,
      listenFor: timeout ?? const Duration(seconds: 3),
    );
    
    if (!success) return null;

    // Wait for completion or timeout
    final completer = Completer<VoiceCommand?>();
    late StreamSubscription subscription;
    
    subscription = stateStream.listen((audioState) {
      if (audioState.voiceInputState == VoiceInputState.completed) {
        subscription.cancel();
        completer.complete(parseLastCommand());
      } else if (audioState.voiceInputState == VoiceInputState.error) {
        subscription.cancel();
        completer.complete(null);
      }
    });

    // Timeout fallback
    Timer(timeout ?? const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
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

  void dispose() {
    _stateController.close();
    _speechToText?.cancel();
  }
}
