import 'dart:async';
import 'dart:math' show min, pow;
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/audio_lesson/content_processor.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:synchronized/synchronized.dart';

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
  static final AudioLessonOrchestrator _instance =
      AudioLessonOrchestrator._internal();
  factory AudioLessonOrchestrator() => _instance;
  AudioLessonOrchestrator._internal();

  // Core services
  final AudioService _audioService = AudioService();
  final ContentProcessor _contentProcessor = ContentProcessor();
  VoiceInputService? _voiceService; // Make nullable and injectable

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
  final StreamController<int> _failedSegmentsController =
      StreamController<int>.broadcast();

  // Stream getters for compatibility
  Stream<AudioLessonState> get stateStream => _stateController.stream;
  Stream<LessonFlowAction> get actionStream => _actionController.stream;
  Stream<int> get progressStream => _progressController.stream;
  /// Emits the count of failed TTS segments after reading a content item.
  Stream<int> get failedSegmentsStream => _failedSegmentsController.stream;
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;
  bool _isListeningForCommands = false; // Prevent overlapping voice listening
  
  // Voice listening reliability improvements
  final Lock _listeningLock = Lock();
  int _consecutiveVoiceFailures = 0;
  static const int _maxConsecutiveVoiceFailures = 5;
  
  // Command debouncing
  VoiceCommand? _lastExecutedCommand;
  DateTime? _lastCommandTime;
  static const Duration _commandDebounceDuration = Duration(milliseconds: 800);

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
      print(
          '🎙️ Voice service available: ${_voiceService?.canListen ?? false}');
    }
  }

  /// Set the voice service to use (allows injection from audio provider)
  void setVoiceService(VoiceInputService voiceService) {
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

  Future<void> startLesson(List<LessonContent> contentList,
      {int startIndex = 0}) async {
    if (contentList.isEmpty) {
      if (kDebugMode) {
        print('❌ Cannot start lesson: content list is empty');
      }
      _isActive = false;
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
        await _speakConfirmation(
            "Starting lesson with ${contentList.length} items");
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

    // Reset content list and index
    _contentList = [];
    _currentIndex = 0;

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
      _actionController.add(LessonFlowAction.complete);
      await _completeLesson();
      return;
    }

    if (kDebugMode) {
      print('⏭️ Moving to next content');
    }
    _actionController.add(LessonFlowAction.next);

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

    int failedSegments = 0;

    try {
      // Use ContentProcessor to extract and clean text
      final audioTexts = _extractContentTexts(content);

      // Speak each text in sequence with error handling
      for (int i = 0; i < audioTexts.length; i++) {
        if (!_isActive || _state == AudioLessonState.paused) break;

        final text = audioTexts[i];
        try {
          final cleanText = _contentProcessor.cleanTextForTTS(text);
          final success =
              await _audioService.speak(cleanText, interrupt: false);

          if (!success) {
            failedSegments++;
            if (kDebugMode) {
              print('⚠️ TTS failed for text segment $i: "$text"');
            }
            continue;
          }

          // Wait for speech to finish via completion callback (no polling)
          await _audioService.speakCompletion;
        } on Exception catch (e, stackTrace) {
          failedSegments++;
          if (kDebugMode) {
            print('❌ Error speaking text segment $i: $e');
            print('Stack trace: $stackTrace');
          }
          continue;
        }
      }

      // Notify listeners if any segments failed
      if (failedSegments > 0) {
        _failedSegmentsController.add(failedSegments);
      }
    } on Exception catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Critical error in _readCurrentContent: $e');
        print('Stack trace: $stackTrace');
      }
      _updateState(AudioLessonState.error);
      return;
    }

    // Handle auto-progression or wait for user action
    if (kDebugMode) {
      print('🎓 Content reading completed. Checking next action...');
      print(
          '   - autoProgressAfterReading: ${_settings.autoProgressAfterReading}');
      print('   - handsFreeModeEnabled: ${_settings.handsFreeModeEnabled}');
      print('   - voiceNavigationEnabled: ${_settings.voiceNavigationEnabled}');
      print('   - current state: $_state');
    }

    if (_settings.autoProgressAfterReading &&
        _state == AudioLessonState.reading) {
      if (kDebugMode) {
        print('🎓 Auto-progressing after delay...');
      }
      await Future.delayed(_settings.autoProgressDelay);
      if (_isActive && _state == AudioLessonState.reading) {
        await nextContent();
      }
    } else if (_settings.handsFreeModeEnabled &&
        _settings.voiceNavigationEnabled) {
      if (kDebugMode) {
        print('🎙️ Starting voice command listening after content reading...');
      }
      // Listen for voice commands when hands-free mode is enabled
      await _listenForVoiceCommands();
    } else {
      if (kDebugMode) {
        print(
            '🎓 Waiting for manual user action (no auto-progress or voice commands)');
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
        texts.add(
            _contentProcessor.processExplanationText(content.explanation!));
      }
    }

    return texts;
  }

  Future<void> _waitForAudioCompletion() async {
    // Prefer the callback-based speakCompletion future when available.
    await _audioService.speakCompletion;
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
      _stateController.add(newState); // Emit state change to stream
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
  /// Uses lock to prevent race conditions and exponential backoff for reliability
  Future<void> _listenForVoiceCommands() async {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      return;
    }

    // Use lock to prevent race conditions with overlapping calls
    await _listeningLock.synchronized(() async {
      await _listenForVoiceCommandsInternal();
    });
  }

  /// Internal implementation of voice command listening
  Future<void> _listenForVoiceCommandsInternal() async {
    // Prevent overlapping listening sessions
    if (_isListeningForCommands) {
      if (kDebugMode) {
        print('🎙️ Already listening for commands, skipping new request');
      }
      return;
    }

    // Check for max consecutive failures
    if (_consecutiveVoiceFailures >= _maxConsecutiveVoiceFailures) {
      if (kDebugMode) {
        print('🎙️ Max consecutive voice failures reached ($_consecutiveVoiceFailures). Voice input disabled.');
        print('   - User should restart hands-free mode to try again');
      }
      _updateState(AudioLessonState.error);
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

    // Skip permission request if already granted (should be handled by UI)
    if (!_voiceService!.hasPermissions) {
      if (kDebugMode) {
        print('🎙️ Permissions not yet granted - waiting longer before retry');
        print(
            '   - Permissions should be requested when hands-free mode is enabled');
      }

      // Wait longer when permissions are missing to avoid rapid retries during permission dialog
      if (_isActive && _settings.handsFreeModeEnabled) {
        await Future.delayed(const Duration(seconds: 2));
        await _listenForVoiceCommands();
      }
      return;
    }

    if (!_voiceService!.canListen) {
      if (kDebugMode) {
        print(
            '🎙️ Voice service still not ready for listening after permission check');
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
      // Listen for voice commands with configurable timeout AND manual timeout wrapper
      final timeoutDuration = _settings.voiceInputTimeout;
      final maxTimeout = const Duration(seconds: 30); // Hard limit
      final actualTimeout = timeoutDuration.compareTo(maxTimeout) > 0
          ? maxTimeout
          : timeoutDuration;

      final command = await _voiceService!
          .listenForCommand(
        timeout: actualTimeout,
      )
          .timeout(
        actualTimeout,
        onTimeout: () {
          if (kDebugMode) {
            print(
                '🎙️ Voice listening timed out after ${actualTimeout.inSeconds} seconds');
          }
          return null;
        },
      );

      if (command != null) {
        // Reset failure counter on successful command
        _consecutiveVoiceFailures = 0;
        
        if (kDebugMode) {
          print(
              '🎙️ Voice command received: ${command.phrase} (${command.type})');
        }

        await _handleVoiceCommand(command);

        // Continue listening in hands-free mode if still active
        if (_isActive &&
            _settings.handsFreeModeEnabled &&
            _state != AudioLessonState.reading) {
          // Small delay before next listening session
          await Future.delayed(const Duration(milliseconds: 500));
          await _listenForVoiceCommands();
        }
      } else {
        if (kDebugMode) {
          print('🎙️ No voice command detected, timeout reached');
        }

        // If in hands-free mode and no command detected, continue listening
        if (_isActive && _settings.handsFreeModeEnabled) {
          // Small delay before retrying
          await Future.delayed(const Duration(milliseconds: 500));
          await _listenForVoiceCommands();
        }
      }
    } on Exception catch (e, stackTrace) {
      _consecutiveVoiceFailures++;
      
      if (kDebugMode) {
        print('❌ Voice command exception: $e');
        print('   - Consecutive failures: $_consecutiveVoiceFailures/$_maxConsecutiveVoiceFailures');
        print('Stack trace: $stackTrace');
      }

      // Exponential backoff on error to avoid rapid retries
      if (_isActive && _settings.handsFreeModeEnabled && 
          _consecutiveVoiceFailures < _maxConsecutiveVoiceFailures) {
        final backoffSeconds = min(30, pow(2, _consecutiveVoiceFailures).toInt());
        if (kDebugMode) {
          print('🎙️ Waiting ${backoffSeconds}s before retry (exponential backoff)');
        }
        await Future.delayed(Duration(seconds: backoffSeconds));
        await _listenForVoiceCommands();
      } else if (_consecutiveVoiceFailures >= _maxConsecutiveVoiceFailures) {
        _updateState(AudioLessonState.error);
        if (kDebugMode) {
          print('🎙️ Voice input disabled after $_consecutiveVoiceFailures consecutive failures');
        }
      }
    } catch (e, stackTrace) {
      _consecutiveVoiceFailures++;
      
      if (kDebugMode) {
        print('❌ Unexpected voice listening error: $e');
        print('   - Consecutive failures: $_consecutiveVoiceFailures/$_maxConsecutiveVoiceFailures');
        print('Stack trace: $stackTrace');
      }

      // Exponential backoff on error
      if (_isActive && _settings.handsFreeModeEnabled &&
          _consecutiveVoiceFailures < _maxConsecutiveVoiceFailures) {
        final backoffSeconds = min(30, pow(2, _consecutiveVoiceFailures).toInt());
        await Future.delayed(Duration(seconds: backoffSeconds));
        await _listenForVoiceCommands();
      } else if (_consecutiveVoiceFailures >= _maxConsecutiveVoiceFailures) {
        _updateState(AudioLessonState.error);
      }
    } finally {
      // CRITICAL: Always reset flag in finally block
      _isListeningForCommands = false;
    }
  }

  /// Reset voice failure counter (call when restarting hands-free mode)
  void resetVoiceFailures() {
    _consecutiveVoiceFailures = 0;
    if (kDebugMode) {
      print('🎙️ Voice failure counter reset');
    }
  }

  /// Handle a received voice command with debouncing
  Future<void> _handleVoiceCommand(VoiceCommand command) async {
    if (!_isActive) return;

    // Debounce duplicate commands
    final now = DateTime.now();
    if (_lastExecutedCommand?.phrase == command.phrase &&
        _lastCommandTime != null &&
        now.difference(_lastCommandTime!) < _commandDebounceDuration) {
      if (kDebugMode) {
        print('🎙️ Debounced duplicate command: ${command.phrase}');
      }
      return;
    }
    
    _lastExecutedCommand = command;
    _lastCommandTime = now;

    // Interrupt current audio if setting is enabled
    if (_settings.interruptOnNextCommand &&
        command.type == VoiceCommandType.navigation) {
      await _audioService.stop();
    }

    switch (command.type) {
      case VoiceCommandType.navigation:
        if (command.value == NavigationCommand.jumpToPage &&
            command.alternatives.isNotEmpty) {
          // Handle jump to page command with page number
          final pageNumber = int.tryParse(command.alternatives.first);
          if (pageNumber != null) {
            await _jumpToPage(pageNumber);
          }
        } else {
          await _handleNavigationCommand(command.value as NavigationCommand);
        }
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
      case NavigationCommand.jumpToPage:
        // This will be handled differently as it requires a page number
        // The page number is stored in the command's alternatives list
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
    if (_settings.handsFreeModeEnabled &&
        _settings.immediateAnswerProgression) {
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
        // Increase speech rate
        if (kDebugMode) {
          print('🎙️ Speed up command received');
        }
        await _adjustSpeechRate(increase: true);
        break;
      case ControlCommand.slower:
        // Decrease speech rate
        if (kDebugMode) {
          print('🎙️ Slow down command received');
        }
        await _adjustSpeechRate(increase: false);
        break;
      case ControlCommand.skip:
        // Skip current content (same as next)
        if (kDebugMode) {
          print('🎙️ Skip command received');
        }
        await nextContent();
        break;
      case ControlCommand.endLesson:
        // End the lesson completely
        if (kDebugMode) {
          print('🎙️ End lesson command received');
        }
        await stopLesson();
        _actionController.add(LessonFlowAction.complete);
        break;
      case ControlCommand.volumeUp:
        // Increase volume
        if (kDebugMode) {
          print('🎙️ Volume up command received');
        }
        await _adjustVolume(increase: true);
        break;
      case ControlCommand.volumeDown:
        // Decrease volume
        if (kDebugMode) {
          print('🎙️ Volume down command received');
        }
        await _adjustVolume(increase: false);
        break;
      case ControlCommand.showProgress:
        // Show progress information
        if (kDebugMode) {
          print('🎙️ Show progress command received');
        }
        await _announceProgress();
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

  /// Jump to a specific page/content index
  Future<void> _jumpToPage(int pageNumber) async {
    // Convert 1-based page number to 0-based index
    final targetIndex = pageNumber - 1;

    if (targetIndex >= 0 && targetIndex < _contentList.length) {
      await _audioService.stop();
      _currentIndex = targetIndex;
      _progressController.add(_currentIndex);
      await _readCurrentContent();

      if (kDebugMode) {
        print('🎙️ Jumped to page $pageNumber (index $targetIndex)');
      }
    } else {
      if (kDebugMode) {
        print(
            '🎙️ Invalid page number: $pageNumber (total pages: ${_contentList.length})');
      }
      // Could announce this error to the user
      await _audioService.speak(
          'Invalid page number. This lesson has ${_contentList.length} pages.');
    }
  }

  /// Announce current progress to the user
  Future<void> _announceProgress() async {
    final currentPage = _currentIndex + 1;
    final totalPages = _contentList.length;
    final progressPercent = ((currentPage / totalPages) * 100).round();

    final progressMessage = 'You are on page $currentPage of $totalPages. '
        'That is $progressPercent percent complete.';

    await _audioService.speak(progressMessage);

    if (kDebugMode) {
      print('🎙️ Progress announced: $progressMessage');
    }
  }

  /// Adjust speech rate by voice command
  Future<void> _adjustSpeechRate({required bool increase}) async {
    // Get current rate
    double currentRate = _audioService.currentSettings.speechRate;

    // Adjust by 0.1 increments, keep within reasonable bounds (0.3 - 2.0)
    double newRate = increase ? currentRate + 0.1 : currentRate - 0.1;
    newRate = newRate.clamp(0.3, 2.0);

    await _audioService.setRate(newRate);

    // Announce the change
    String message =
        increase ? 'Speech speed increased' : 'Speech speed decreased';
    await _audioService.speak(message, interrupt: false);

    if (kDebugMode) {
      print('🎙️ Speech rate adjusted to: $newRate');
    }
  }

  /// Adjust volume by voice command
  Future<void> _adjustVolume({required bool increase}) async {
    // Get current volume
    double currentVolume = _audioService.currentSettings.volume;

    // Adjust by 0.1 increments, keep within bounds (0.1 - 1.0)
    double newVolume = increase ? currentVolume + 0.1 : currentVolume - 0.1;
    newVolume = newVolume.clamp(0.1, 1.0);

    await _audioService.setVolume(newVolume);

    // Announce the change
    String message = increase ? 'Volume increased' : 'Volume decreased';
    await _audioService.speak(message, interrupt: false);

    if (kDebugMode) {
      print('🎙️ Volume adjusted to: $newVolume');
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
