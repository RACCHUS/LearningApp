import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/voice_input_service.dart';

/// Service responsible for handling voice interactions during lessons
/// Manages voice command listening, processing, and retry logic
class VoiceInteractionHandler {
  final VoiceInputService _voiceService = VoiceInputService();
  
  AudioLessonSettings _settings = const AudioLessonSettings();
  int _currentRetryAttempt = 0;

  // Callbacks for voice events
  VoidCallback? _onVoiceTimeout;
  Function(String)? _onVoiceAnswer;

  /// Initialize the voice interaction handler
  Future<void> initialize() async {
    await _voiceService.initialize();
    _setupVoiceCommandListener();
  }

  /// Update settings for voice interaction
  void updateSettings(AudioLessonSettings settings) {
    _settings = settings;
    
    // Update voice command listening based on settings
    if (_settings.handsFreeModeEnabled && _settings.voiceNavigationEnabled) {
      _setupVoiceCommandListener();
    }
  }

  /// Set callbacks for voice events
  void setCallbacks({
    VoidCallback? onVoiceTimeout,
    Function(String)? onVoiceAnswer,
  }) {
    _onVoiceTimeout = onVoiceTimeout;
    _onVoiceAnswer = onVoiceAnswer;
  }

  /// Setup continuous voice command listening for hands-free mode
  void _setupVoiceCommandListener() {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      return;
    }

    if (kDebugMode) {
      print('🎙️ Setting up voice command listener for hands-free mode');
    }

    // Note: VoiceInputService doesn't have onVoiceCommand stream
    // This would need to be implemented differently, possibly through polling
    // or extending the VoiceInputService to support command streams
  }

  /// Start listening for voice input with timeout
  void startVoiceInputWithTimeout() {
    if (kDebugMode) {
      print('🎙️ Starting voice input with timeout: ${_settings.voiceInputTimeout}');
    }

    // Start listening for voice input using locale from settings
    _voiceService.startListening(
      localeId: _settings.voiceLocale,
      listenFor: _settings.voiceInputTimeout,
    );
  }

  /// Stop voice input
  Future<void> stopVoiceInput() async {
    if (kDebugMode) {
      print('🎙️ Stopping voice input');
    }
    await _voiceService.stopListening();
  }

  /// Handle voice timeout
  void handleVoiceTimeout() {
    _currentRetryAttempt++;
    
    if (kDebugMode) {
      print('🎙️ Voice timeout - attempt $_currentRetryAttempt/${_settings.voiceRetryAttempts}');
    }

    if (_currentRetryAttempt < _settings.voiceRetryAttempts) {
      // Trigger retry
      _onVoiceTimeout?.call();
    } else {
      // Max retries reached
      if (kDebugMode) {
        print('🎙️ Maximum voice retry attempts reached');
      }
      _resetRetryAttempts();
      _onVoiceTimeout?.call();
    }
  }

  /// Process voice command for navigation
  bool processNavigationCommand(VoiceCommand command) {
    if (command.type != VoiceCommandType.navigation && 
        command.type != VoiceCommandType.control) {
      return false;
    }

    if (kDebugMode) {
      print('🎙️ Processing navigation command: ${command.phrase}');
    }

    // Allow interruption if enabled
    if (_settings.interruptOnNextCommand && 
        (command.value == NavigationCommand.next || 
         command.value == ControlCommand.play)) {
      return true;
    }

    return true;
  }

  /// Process voice answer for questions
  String? processAnswerCommand(VoiceCommand command, QuestionContent questionContent) {
    if (command.type != VoiceCommandType.answer) {
      return null;
    }

    if (kDebugMode) {
      print('🎙️ Processing answer command: ${command.phrase} for question type: ${questionContent.type}');
    }

    final answer = command.value?.toString();
    
    // Reset retry attempts on successful answer
    _resetRetryAttempts();
    
    _onVoiceAnswer?.call(answer ?? '');
    return answer;
  }

  /// Get retry prompt based on attempt number
  String getRetryPrompt(int attemptNumber) {
    switch (attemptNumber) {
      case 1:
        return "I didn't catch that. Please try again and speak clearly.";
      case 2:
        return "Still having trouble hearing you. Please speak louder and more slowly.";
      case 3:
        return "Let's try one more time. Make sure you're close to the microphone.";
      default:
        return "Please try speaking your answer again.";
    }
  }

  /// Generate voice prompt for question type
  String generateQuestionPrompt(QuestionContent content) {
    switch (content.type) {
      case 'mcq':
        return "Please say A, B, C, or D for your answer";
      case 'true_false':
        return "Please say true or false";
      case 'short_answer':
        return "Please speak your answer";
      default:
        return "Please provide your answer";
    }
  }

  /// Reset retry attempts counter
  void _resetRetryAttempts() {
    _currentRetryAttempt = 0;
  }

  /// Get current retry attempt
  int get currentRetryAttempt => _currentRetryAttempt;

  /// Check if voice input is available
  bool get isVoiceInputAvailable {
    return _voiceService.isAvailable;
  }

  /// Check if currently listening for voice
  bool get isListening {
    return _voiceService.currentState == VoiceInputState.listening;
  }

  /// Get voice service status for debugging
  Map<String, dynamic> get voiceStatus {
    return {
      'isAvailable': isVoiceInputAvailable,
      'isListening': isListening,
      'currentRetryAttempt': _currentRetryAttempt,
      'maxRetryAttempts': _settings.voiceRetryAttempts,
      'handsFreeModeEnabled': _settings.handsFreeModeEnabled,
      'voiceNavigationEnabled': _settings.voiceNavigationEnabled,
    };
  }

  /// Dispose of resources
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing voice interaction handler');
    }
    _voiceService.dispose();
    _onVoiceTimeout = null;
    _onVoiceAnswer = null;
  }
}
