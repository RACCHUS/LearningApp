import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';

/// Service responsible for managing lesson timers and auto-progression
/// Handles timeouts, delays, and automatic progression between content
class LessonTimerService {
  Timer? _autoProgressTimer;
  Timer? _voiceInputTimer;
  Timer? _delayTimer;

  AudioLessonSettings _settings = const AudioLessonSettings();

  // Callbacks for timer events
  VoidCallback? _onAutoProgress;
  VoidCallback? _onVoiceInputTimeout;
  VoidCallback? _onDelayComplete;

  /// Update settings used for timer durations
  void updateSettings(AudioLessonSettings settings) {
    _settings = settings;
  }

  /// Set callbacks for timer events
  void setCallbacks({
    VoidCallback? onAutoProgress,
    VoidCallback? onVoiceInputTimeout,
    VoidCallback? onDelayComplete,
  }) {
    _onAutoProgress = onAutoProgress;
    _onVoiceInputTimeout = onVoiceInputTimeout;
    _onDelayComplete = onDelayComplete;
  }

  /// Start auto-progression timer if enabled in settings
  void startAutoProgressTimer() {
    if (!_settings.autoProgressAfterReading) return;

    _cancelAutoProgressTimer();

    if (kDebugMode) {
      print('🕐 Starting auto-progress timer: ${_settings.autoProgressDelay}');
    }

    _autoProgressTimer = Timer(_settings.autoProgressDelay, () {
      if (kDebugMode) {
        print('🕐 Auto-progress timer fired');
      }
      _onAutoProgress?.call();
    });
  }

  /// Start voice input timeout timer
  void startVoiceInputTimer() {
    _cancelVoiceInputTimer();

    if (kDebugMode) {
      print('🕐 Starting voice input timer: ${_settings.voiceInputTimeout}');
    }

    _voiceInputTimer = Timer(_settings.voiceInputTimeout, () {
      if (kDebugMode) {
        print('🕐 Voice input timer fired - timeout reached');
      }
      _onVoiceInputTimeout?.call();
    });
  }

  /// Start a general delay timer
  void startDelayTimer(Duration delay) {
    _cancelDelayTimer();

    if (kDebugMode) {
      print('🕐 Starting delay timer: $delay');
    }

    _delayTimer = Timer(delay, () {
      if (kDebugMode) {
        print('🕐 Delay timer completed');
      }
      _onDelayComplete?.call();
    });
  }

  /// Cancel auto-progression timer
  void _cancelAutoProgressTimer() {
    if (_autoProgressTimer?.isActive == true) {
      if (kDebugMode) {
        print('🕐 Cancelling auto-progress timer');
      }
      _autoProgressTimer?.cancel();
    }
    _autoProgressTimer = null;
  }

  /// Cancel voice input timer
  void _cancelVoiceInputTimer() {
    if (_voiceInputTimer?.isActive == true) {
      if (kDebugMode) {
        print('🕐 Cancelling voice input timer');
      }
      _voiceInputTimer?.cancel();
    }
    _voiceInputTimer = null;
  }

  /// Cancel delay timer
  void _cancelDelayTimer() {
    if (_delayTimer?.isActive == true) {
      if (kDebugMode) {
        print('🕐 Cancelling delay timer');
      }
      _delayTimer?.cancel();
    }
    _delayTimer = null;
  }

  /// Cancel all active timers
  void cancelAllTimers() {
    if (kDebugMode) {
      print('🕐 Cancelling all timers');
    }
    _cancelAutoProgressTimer();
    _cancelVoiceInputTimer();
    _cancelDelayTimer();
  }

  /// Check if any timers are currently active
  bool get hasActiveTimers {
    return (_autoProgressTimer?.isActive == true) ||
           (_voiceInputTimer?.isActive == true) ||
           (_delayTimer?.isActive == true);
  }

  /// Get status of all timers for debugging
  Map<String, bool> get timerStatus {
    return {
      'autoProgress': _autoProgressTimer?.isActive == true,
      'voiceInput': _voiceInputTimer?.isActive == true,
      'delay': _delayTimer?.isActive == true,
    };
  }

  /// Dispose of all timers and resources
  void dispose() {
    if (kDebugMode) {
      print('🕐 Disposing timer service');
    }
    cancelAllTimers();
    _onAutoProgress = null;
    _onVoiceInputTimeout = null;
    _onDelayComplete = null;
  }
}
