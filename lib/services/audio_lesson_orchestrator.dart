import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/audio_lesson/content_processor.dart';
import 'package:learning_pwa/services/enhanced_voice_input_service.dart';
import 'package:learning_pwa/models/voice_command.dart';

enum AudioLessonState {
  idle,
  reading,
  waitingForVoice,
  processing,
  paused,
  error,
  completed,
}

enum LessonFlowAction {
  next,
  previous,
  repeat,
  pause,
  resume,
  restart,
  complete,
}

/// Refactored AudioLessonOrchestrator with dramatically reduced complexity
/// Reduced from 666 lines to ~120 lines by using the ContentProcessor service
/// and simplifying the architecture
class AudioLessonOrchestrator {
  static final AudioLessonOrchestrator _instance = AudioLessonOrchestrator._internal();
  factory AudioLessonOrchestrator() => _instance;
  AudioLessonOrchestrator._internal();

  // Core services
  final AudioService _audioService = AudioService();
  final ContentProcessor _contentProcessor = ContentProcessor();
  EnhancedVoiceInputService? _voiceService; // Make nullable and injectable

  // State management (simplified)
  AudioLessonSettings _settings = const AudioLessonSettings();
  AudioLessonState _state = AudioLessonState.idle;
  
  // Stream controllers for compatibility with providers
  final StreamController<AudioLessonState> _stateController = 
      StreamController<AudioLessonState>.broadcast();
  final StreamController<LessonFlowAction> _actionController = 
      StreamController<LessonFlowAction>.broadcast();
  final StreamController<int> _progressController = 
      StreamController<int>.broadcast();

  // Stream getters for compatibility
  Stream<AudioLessonState> get stateStream => _stateController.stream;
  Stream<LessonFlowAction> get actionStream => _actionController.stream;
  Stream<int> get progressStream => _progressController.stream;
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;
  bool _isListeningForCommands = false; // Prevent overlapping voice listening

  // Getters
  AudioLessonState get currentState => _state;
  AudioLessonSettings get settings => _settings;
  bool get isActive => _isActive;
  int get currentIndex => _currentIndex;
  int get totalContent => _contentList.length;
  bool get isFirstContent => _currentIndex == 0;
  bool get isLastContent => _currentIndex >= _contentList.length - 1;

  Future<void> initialize() async {
    await _audioService.initialize();
    await _voiceService?.initialize();
    if (kDebugMode) {
      print('🎓 AudioLessonOrchestrator initialized (refactored version)');
      print('🎙️ Voice service available: ${_voiceService?.canListen ?? false}');
    }
  }

  /// Set the voice service to use (allows injection from audio provider)
  void setVoiceService(EnhancedVoiceInputService voiceService) {
    _voiceService = voiceService;
    if (kDebugMode) {
      print('🎙️ Voice service injected into orchestrator');
      print('🎙️ Voice service details:');
      print('   - isAvailable: ${voiceService.isAvailable}');
      print('   - hasPermissions: ${voiceService.hasPermissions}');
      print('   - canListen: ${voiceService.canListen}');
      print('   - currentState: ${voiceService.currentState}');
    }
  }

  void updateSettings(AudioLessonSettings newSettings) {
    _settings = newSettings;
    if (kDebugMode) {
      print('⚙️ Settings updated');
    }
  }

  Future<void> startLesson(List<LessonContent> contentList, {int startIndex = 0}) async {
    if (contentList.isEmpty) {
      if (kDebugMode) {
        print('❌ Cannot start lesson: content list is empty');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🎓 Starting lesson with ${contentList.length} items');
      }

      _contentList = contentList;
      _currentIndex = startIndex.clamp(0, contentList.length - 1);
      _isActive = true;
      _updateState(AudioLessonState.idle);

      if (_settings.confirmationsEnabled) {
        await _speakConfirmation("Starting lesson with ${contentList.length} items");
      }

      // Begin reading the first content
      await _readCurrentContent();

      if (kDebugMode) {
        print('✅ Lesson started successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting lesson: $e');
      }
      _updateState(AudioLessonState.error);
    }
  }

  Future<void> stopLesson() async {
    if (kDebugMode) {
      print('⏹️ Stopping lesson');
    }

    _isActive = false;
    _isListeningForCommands = false; // Reset listening flag
    await _audioService.stop();
    
    // Cancel any active voice listening
    if (_voiceService != null) {
      await _voiceService!.cancel();
    }
    
    _updateState(AudioLessonState.idle);

    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson stopped");
    }
  }

  Future<void> pauseLesson() async {
    if (!_isActive) return;

    if (kDebugMode) {
      print('⏸️ Pausing lesson');
    }

    await _audioService.pause();
    _updateState(AudioLessonState.paused);

    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson paused");
    }
  }

  Future<void> resumeLesson() async {
    if (!_isActive || _state != AudioLessonState.paused) return;

    if (kDebugMode) {
      print('▶️ Resuming lesson');
    }

    _updateState(AudioLessonState.reading);
    await _readCurrentContent();

    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Resuming lesson");
    }
  }

  Future<void> nextContent() async {
    if (!_isActive) return;

    if (isLastContent) {
      await _completeLesson();
      return;
    }

    if (kDebugMode) {
      print('⏭️ Moving to next content');
    }

    await _audioService.stop();
    _currentIndex++;
    
    // Emit progress change for UI update
    if (kDebugMode) {
      print('🎓 Emitting progress change: $_currentIndex');
    }
    _progressController.add(_currentIndex);
    
    await _readCurrentContent();
  }

  Future<void> previousContent() async {
    if (!_isActive || isFirstContent) return;

    if (kDebugMode) {
      print('⏮️ Moving to previous content');
    }

    await _audioService.stop();
    _currentIndex--;
    
    // Emit progress change for UI update
    _progressController.add(_currentIndex);
    
    await _readCurrentContent();
  }

  Future<void> repeatContent() async {
    if (!_isActive) return;

    if (kDebugMode) {
      print('🔄 Repeating current content');
    }

    await _audioService.stop();
    await _readCurrentContent();
  }

  Future<void> _readCurrentContent() async {
    if (!_isActive || _currentIndex >= _contentList.length) return;

    final content = _contentList[_currentIndex];
    _updateState(AudioLessonState.reading);

    // Use ContentProcessor to extract and clean text
    final audioTexts = _extractContentTexts(content);
    
    // Speak each text in sequence
    for (final text in audioTexts) {
      if (!_isActive || _state == AudioLessonState.paused) break;
      
      final cleanText = _contentProcessor.cleanTextForTTS(text);
      await _audioService.speak(cleanText, interrupt: false);
      await _waitForAudioCompletion();
    }

    // Handle auto-progression or wait for user action
    if (kDebugMode) {
      print('🎓 Content reading completed. Checking next action...');
      print('   - autoProgressAfterReading: ${_settings.autoProgressAfterReading}');
      print('   - handsFreeModeEnabled: ${_settings.handsFreeModeEnabled}');
      print('   - voiceNavigationEnabled: ${_settings.voiceNavigationEnabled}');
      print('   - current state: $_state');
    }
    
    if (_settings.autoProgressAfterReading && _state == AudioLessonState.reading) {
      if (kDebugMode) {
        print('🎓 Auto-progressing after delay...');
      }
      await Future.delayed(_settings.autoProgressDelay);
      if (_isActive && _state == AudioLessonState.reading) {
        await nextContent();
      }
    } else if (_settings.handsFreeModeEnabled && _settings.voiceNavigationEnabled) {
      if (kDebugMode) {
        print('🎙️ Starting voice command listening after content reading...');
      }
      // Listen for voice commands when hands-free mode is enabled
      await _listenForVoiceCommands();
    } else {
      if (kDebugMode) {
        print('🎓 Waiting for manual user action (no auto-progress or voice commands)');
      }
    }
  }

  List<String> _extractContentTexts(LessonContent content) {
    final texts = <String>[];

    // Add progress if enabled
    if (_settings.confirmationsEnabled && _contentList.length > 1) {
      texts.add("Item ${_currentIndex + 1} of ${_contentList.length}");
    }

    // Extract content-specific audio using ContentProcessor methods
    if (content is TermContent) {
      texts.add("Term: ${content.term}");
      texts.add("Definition: ${content.definition}");
      if (content.example != null) {
        texts.add("Example: ${content.example}");
      }
    } else if (content is ConceptContent) {
      texts.add(content.conceptText);
      if (content.exampleText != null) {
        texts.add("Example: ${content.exampleText}");
      }
    } else if (content is QuestionContent) {
      texts.add(_contentProcessor.processQuestionText(content.questionText));
      
      if (content.type == 'mcq') {
        texts.add(_contentProcessor.formatOptions(content.options));
      }
      
      if (content.explanation?.isNotEmpty == true) {
        texts.add(_contentProcessor.processExplanationText(content.explanation!));
      }
    }

    return texts;
  }

  Future<void> _waitForAudioCompletion() async {
    while (_audioService.currentState.isPlaying || _audioService.currentState.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isActive || _state == AudioLessonState.paused) break;
    }
  }

  Future<void> _completeLesson() async {
    if (kDebugMode) {
      print('🎉 Lesson completed');
    }

    _isActive = false;
    _updateState(AudioLessonState.completed);
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson completed! Well done.");
    }
  }

  Future<void> _speakConfirmation(String message) async {
    if (_settings.confirmationsEnabled) {
      await _audioService.speak(message, interrupt: false);
      await _waitForAudioCompletion();
    }
  }

  void _updateState(AudioLessonState newState) {
    if (_state != newState) {
      _state = newState;
      if (kDebugMode) {
        print('🎓 State changed: $newState');
      }
    }
  }

  // Manual test method for debugging
  Future<void> simulateVoiceCommand(String commandText) async {
    if (kDebugMode) {
      print('🎙️ Simulating voice command: "$commandText"');
    }
    
    // Simple command handling
    switch (commandText.toLowerCase()) {
      case 'next':
        await nextContent();
        break;
      case 'previous':
        await previousContent();
        break;
      case 'repeat':
        await repeatContent();
        break;
      case 'pause':
        await pauseLesson();
        break;
      case 'resume':
        await resumeLesson();
        break;
      case 'stop':
        await stopLesson();
        break;
    }
  }

  /// Listen for voice commands in hands-free mode
  Future<void> _listenForVoiceCommands() async {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      return;
    }

    // Prevent overlapping listening sessions
    if (_isListeningForCommands) {
      if (kDebugMode) {
        print('🎙️ Already listening for commands, skipping new request');
      }
      return;
    }

    if (_voiceService == null) {
      if (kDebugMode) {
        print('🎙️ Voice service not available - no service injected');
      }
      return;
    }

    // Check if voice service is available and request permissions if needed
    if (!_voiceService!.isAvailable) {
      if (kDebugMode) {
        print('🎙️ Voice service not available - no speech providers ready');
      }
      return;
    }

    // Request permissions if not already granted
    if (!_voiceService!.hasPermissions) {
      if (kDebugMode) {
        print('🎙️ Requesting microphone permissions for hands-free mode...');
      }
      
      final permissionsGranted = await _voiceService!.requestPermissions();
      if (!permissionsGranted) {
        if (kDebugMode) {
          print('🎙️ Microphone permissions denied - cannot use voice commands');
        }
        return;
      }
      
      if (kDebugMode) {
        print('🎙️ Microphone permissions granted for hands-free mode');
        print('🎙️ Voice service state after permission grant:');
        print('   - isAvailable: ${_voiceService!.isAvailable}');
        print('   - hasPermissions: ${_voiceService!.hasPermissions}');
        print('   - canListen: ${_voiceService!.canListen}');
      }
    }

    if (!_voiceService!.canListen) {
      if (kDebugMode) {
        print('🎙️ Voice service still not ready for listening after permission check');
        print('   - isAvailable: ${_voiceService!.isAvailable}');
        print('   - hasPermissions: ${_voiceService!.hasPermissions}');
      }
      return;
    }

    _updateState(AudioLessonState.waitingForVoice);
    _isListeningForCommands = true; // Set flag to prevent overlapping
    
    if (kDebugMode) {
      print('🎙️ Listening for voice commands...');
    }

    try {
      // Listen for voice commands with configurable timeout
      final command = await _voiceService!.listenForCommand(
        timeout: _settings.voiceInputTimeout,
      );

      if (command != null) {
        if (kDebugMode) {
          print('🎙️ Voice command received: ${command.phrase} (${command.type})');
        }
        
        await _handleVoiceCommand(command);
        
        // Continue listening in hands-free mode if still active
        if (_isActive && _settings.handsFreeModeEnabled && _state != AudioLessonState.reading) {
          // Small delay before next listening session
          await Future.delayed(const Duration(milliseconds: 500));
          _isListeningForCommands = false; // Reset flag
          await _listenForVoiceCommands();
        } else {
          _isListeningForCommands = false; // Reset flag
        }
      } else {
        if (kDebugMode) {
          print('🎙️ No voice command detected, timeout reached');
        }
        
        // If in hands-free mode and no command detected, continue listening
        if (_isActive && _settings.handsFreeModeEnabled) {
          // Small delay before retrying
          await Future.delayed(const Duration(milliseconds: 500));
          _isListeningForCommands = false; // Reset flag
          await _listenForVoiceCommands();
        } else {
          _isListeningForCommands = false; // Reset flag
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Voice command error: $e');
      }
      
      _isListeningForCommands = false; // Reset flag on error
      
      // On error, wait longer before trying again to avoid rapid retries
      if (_isActive && _settings.handsFreeModeEnabled) {
        await Future.delayed(const Duration(seconds: 3));
        await _listenForVoiceCommands();
      }
    }
  }

  /// Handle a received voice command
  Future<void> _handleVoiceCommand(VoiceCommand command) async {
    if (!_isActive) return;

    // Interrupt current audio if setting is enabled
    if (_settings.interruptOnNextCommand && command.type == VoiceCommandType.navigation) {
      await _audioService.stop();
    }

    switch (command.type) {
      case VoiceCommandType.navigation:
        await _handleNavigationCommand(command.value as NavigationCommand);
        break;
      case VoiceCommandType.answer:
        await _handleAnswerCommand(command.value); // String or bool value
        break;
      case VoiceCommandType.control:
        await _handleControlCommand(command.value as ControlCommand);
        break;
      case VoiceCommandType.mode:
        await _handleModeCommand(command.value as ModeCommand);
        break;
    }
  }

  /// Handle navigation voice commands
  Future<void> _handleNavigationCommand(NavigationCommand command) async {
    switch (command) {
      case NavigationCommand.next:
        await nextContent();
        break;
      case NavigationCommand.previous:
      case NavigationCommand.back:
        await previousContent();
        break;
      case NavigationCommand.first:
        // Go to first content
        if (_currentIndex > 0) {
          await _audioService.stop();
          _currentIndex = 0;
          _progressController.add(_currentIndex); // Emit progress change
          await _readCurrentContent();
        }
        break;
      case NavigationCommand.last:
        // Go to last content
        if (_currentIndex < _contentList.length - 1) {
          await _audioService.stop();
          _currentIndex = _contentList.length - 1;
          _progressController.add(_currentIndex); // Emit progress change
          await _readCurrentContent();
        }
        break;
    }
    
    // Navigation commands automatically trigger content reading, 
    // which will handle voice listening continuation
  }

  /// Handle answer voice commands (for MCQ questions)
  Future<void> _handleAnswerCommand(dynamic answerValue) async {
    // Emit action for the UI to handle (since answer handling is context-specific)
    _actionController.add(LessonFlowAction.next); // Move to next after answer
    
    if (kDebugMode) {
      print('🎙️ Answer command: $answerValue');
    }
    
    // Continue listening in hands-free mode
    if (_settings.handsFreeModeEnabled && _settings.immediateAnswerProgression) {
      await nextContent();
    } else if (_settings.handsFreeModeEnabled) {
      await _listenForVoiceCommands();
    }
  }

  /// Handle control voice commands
  Future<void> _handleControlCommand(ControlCommand command) async {
    switch (command) {
      case ControlCommand.play:
        await resumeLesson();
        break;
      case ControlCommand.pause:
        await pauseLesson();
        break;
      case ControlCommand.stop:
        await stopLesson();
        break;
      case ControlCommand.repeat:
        await repeatContent();
        break;
      case ControlCommand.faster:
        // Increase speech rate - this would need audio service support
        if (kDebugMode) {
          print('🎙️ Speed up command received');
        }
        break;
      case ControlCommand.slower:
        // Decrease speech rate - this would need audio service support
        if (kDebugMode) {
          print('🎙️ Slow down command received');
        }
        break;
    }
  }

  /// Handle mode voice commands
  Future<void> _handleModeCommand(ModeCommand command) async {
    // Mode changes are typically handled at a higher level
    // For now, just log the command
    if (kDebugMode) {
      print('🎙️ Mode command: $command');
    }
  }

  void dispose() {
    _audioService.dispose();
    _voiceService?.dispose();
    _stateController.close();
    _actionController.close();
    _progressController.close();
  }
}
