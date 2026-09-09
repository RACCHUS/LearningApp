import 'dart:async';
import 'package:flutter/foundation.dart';

/// Enum representing the current state of an audio lesson
enum AudioLessonState {
  idle,
  reading,
  waitingForVoice,
  processing,
  paused,
  error,
  completed,
}

/// Enum representing actions that can be performed in a lesson
enum LessonFlowAction {
  next,
  previous,
  repeat,
  pause,
  resume,
  restart,
  complete,
}

/// Service responsible for managing lesson state transitions and validation
/// Provides centralized state management with proper validation and notifications
class LessonStateManager {
  AudioLessonState _currentState = AudioLessonState.idle;
  
  // Stream controllers for state notifications
  final StreamController<AudioLessonState> _stateController = 
      StreamController<AudioLessonState>.broadcast();
  final StreamController<LessonFlowAction> _actionController = 
      StreamController<LessonFlowAction>.broadcast();

  // Getters
  AudioLessonState get currentState => _currentState;
  Stream<AudioLessonState> get stateStream => _stateController.stream;
  Stream<LessonFlowAction> get actionStream => _actionController.stream;

  /// Update the lesson state with validation
  void updateState(AudioLessonState newState) {
    if (_currentState == newState) return;

    final previousState = _currentState;
    
    // Validate state transition
    if (!_isValidTransition(previousState, newState)) {
      if (kDebugMode) {
        print('⚠️ Invalid state transition: $previousState → $newState');
      }
      return;
    }

    _currentState = newState;
    
    if (kDebugMode) {
      print('🔄 State transition: $previousState → $newState');
    }

    // Notify listeners
    _stateController.add(newState);
  }

  /// Notify about a lesson flow action
  void notifyAction(LessonFlowAction action) {
    if (kDebugMode) {
      print('🎬 Lesson action: $action');
    }
    _actionController.add(action);
  }

  /// Validate if a state transition is allowed
  bool _isValidTransition(AudioLessonState from, AudioLessonState to) {
    // Define valid state transitions
    switch (from) {
      case AudioLessonState.idle:
        return [
          AudioLessonState.reading,
          AudioLessonState.error,
          AudioLessonState.completed,
        ].contains(to);

      case AudioLessonState.reading:
        return [
          AudioLessonState.idle,
          AudioLessonState.waitingForVoice,
          AudioLessonState.processing,
          AudioLessonState.paused,
          AudioLessonState.error,
          AudioLessonState.completed,
        ].contains(to);

      case AudioLessonState.waitingForVoice:
        return [
          AudioLessonState.processing,
          AudioLessonState.reading,
          AudioLessonState.paused,
          AudioLessonState.error,
          AudioLessonState.idle,
        ].contains(to);

      case AudioLessonState.processing:
        return [
          AudioLessonState.reading,
          AudioLessonState.waitingForVoice,
          AudioLessonState.idle,
          AudioLessonState.error,
        ].contains(to);

      case AudioLessonState.paused:
        return [
          AudioLessonState.reading,
          AudioLessonState.idle,
          AudioLessonState.error,
          AudioLessonState.completed,
        ].contains(to);

      case AudioLessonState.error:
        return [
          AudioLessonState.idle,
          AudioLessonState.reading,
          AudioLessonState.completed,
        ].contains(to);

      case AudioLessonState.completed:
        return [
          AudioLessonState.idle,
        ].contains(to);
    }
  }

  /// Check if the current state allows reading audio
  bool get canRead {
    return [
      AudioLessonState.idle,
      AudioLessonState.reading,
    ].contains(_currentState);
  }

  /// Check if the current state allows voice input
  bool get canListen {
    return [
      AudioLessonState.waitingForVoice,
      AudioLessonState.processing,
    ].contains(_currentState);
  }

  /// Check if the lesson is currently active
  bool get isActive {
    return _currentState != AudioLessonState.idle &&
           _currentState != AudioLessonState.completed &&
           _currentState != AudioLessonState.error;
  }

  /// Check if the lesson is paused
  bool get isPaused {
    return _currentState == AudioLessonState.paused;
  }

  /// Check if the lesson has completed
  bool get isCompleted {
    return _currentState == AudioLessonState.completed;
  }

  /// Check if there's an error state
  bool get hasError {
    return _currentState == AudioLessonState.error;
  }

  /// Force state to idle (for emergency stops)
  void forceIdle() {
    if (kDebugMode) {
      print('🛑 Force setting state to idle');
    }
    _currentState = AudioLessonState.idle;
    _stateController.add(AudioLessonState.idle);
  }

  /// Get human-readable description of current state
  String get stateDescription {
    switch (_currentState) {
      case AudioLessonState.idle:
        return 'Ready to start';
      case AudioLessonState.reading:
        return 'Reading content';
      case AudioLessonState.waitingForVoice:
        return 'Waiting for voice input';
      case AudioLessonState.processing:
        return 'Processing response';
      case AudioLessonState.paused:
        return 'Lesson paused';
      case AudioLessonState.error:
        return 'Error occurred';
      case AudioLessonState.completed:
        return 'Lesson completed';
    }
  }

  /// Dispose of resources
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing lesson state manager');
    }
    _stateController.close();
    _actionController.close();
  }
}
