import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/voice_input_service.dart';

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

class AudioLessonOrchestrator {
  static final AudioLessonOrchestrator _instance = AudioLessonOrchestrator._internal();
  factory AudioLessonOrchestrator() => _instance;
  AudioLessonOrchestrator._internal();

  final AudioService _audioService = AudioService();
  final VoiceInputService _voiceService = VoiceInputService();
  
  AudioLessonSettings _settings = const AudioLessonSettings();
  AudioLessonState _state = AudioLessonState.idle;
  
  // Lesson flow state
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;
  
  // Audio queue management
  final List<String> _audioQueue = [];
  Timer? _autoProgressTimer;
  Timer? _voiceInputTimer;
  
  // Voice retry logic
  int _currentRetryAttempt = 0;
  
  // Stream controllers
  final StreamController<AudioLessonState> _stateController = 
      StreamController<AudioLessonState>.broadcast();
  final StreamController<LessonFlowAction> _actionController = 
      StreamController<LessonFlowAction>.broadcast();
  final StreamController<int> _progressController = 
      StreamController<int>.broadcast();

  // Getters
  Stream<AudioLessonState> get stateStream => _stateController.stream;
  Stream<LessonFlowAction> get actionStream => _actionController.stream;
  Stream<int> get progressStream => _progressController.stream;
  
  AudioLessonState get currentState => _state;
  AudioLessonSettings get settings => _settings;
  bool get isActive => _isActive;
  int get currentIndex => _currentIndex;
  int get totalContent => _contentList.length;
  bool get isFirstContent => _currentIndex == 0;
  bool get isLastContent => _currentIndex == _contentList.length - 1;

  Future<void> initialize() async {
    await _audioService.initialize();
    await _voiceService.initialize();
    
    // Listen to voice commands when hands-free mode is enabled
    _setupVoiceCommandListener();
  }

  void updateSettings(AudioLessonSettings newSettings) {
    _settings = newSettings;
    
    // Update voice command listening based on settings
    if (_settings.handsFreeModeEnabled && _settings.voiceNavigationEnabled) {
      _setupVoiceCommandListener();
    }
  }

  Future<void> startLesson(List<LessonContent> contentList, {int startIndex = 0}) async {
    if (contentList.isEmpty) return;
    
    _contentList = contentList;
    _currentIndex = max(0, min(startIndex, contentList.length - 1));
    _isActive = true;
    _currentRetryAttempt = 0;
    
    _updateState(AudioLessonState.idle);
    _notifyProgress();
    
    if (_settings.handsFreeModeEnabled && _settings.confirmationsEnabled) {
      await _speakConfirmation("Starting lesson with ${contentList.length} items");
    }
    
    // Begin reading the first content
    await _readCurrentContent();
  }

  Future<void> stopLesson() async {
    _isActive = false;
    _clearTimers();
    await _audioService.stop();
    await _voiceService.cancel();
    _audioQueue.clear();
    _updateState(AudioLessonState.idle);
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson stopped");
    }
  }

  Future<void> pauseLesson() async {
    if (!_isActive) return;
    
    _clearTimers();
    await _audioService.pause();
    await _voiceService.cancel();
    _updateState(AudioLessonState.paused);
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson paused");
    }
  }

  Future<void> resumeLesson() async {
    if (!_isActive || _state != AudioLessonState.paused) return;
    
    _updateState(AudioLessonState.idle);
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Resuming lesson");
    }
    
    await _readCurrentContent();
  }

  Future<void> nextContent() async {
    if (!_isActive || isLastContent) {
      await _completeLesson();
      return;
    }
    
    _clearTimers();
    await _audioService.stop();
    await _voiceService.cancel();
    
    _currentIndex++;
    _currentRetryAttempt = 0;
    _notifyProgress();
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Moving to next item");
    }
    
    await _readCurrentContent();
  }

  Future<void> previousContent() async {
    if (!_isActive || isFirstContent) return;
    
    _clearTimers();
    await _audioService.stop();
    await _voiceService.cancel();
    
    _currentIndex--;
    _currentRetryAttempt = 0;
    _notifyProgress();
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Moving to previous item");
    }
    
    await _readCurrentContent();
  }

  Future<void> repeatContent() async {
    if (!_isActive) return;
    
    _clearTimers();
    await _audioService.stop();
    await _voiceService.cancel();
    
    _currentRetryAttempt = 0;
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Repeating content");
    }
    
    await _readCurrentContent();
  }

  Future<void> _readCurrentContent() async {
    if (!_isActive || _currentIndex >= _contentList.length) return;
    
    final content = _contentList[_currentIndex];
    _updateState(AudioLessonState.reading);
    
    // Build audio sequence based on content type
    await _buildAndExecuteAudioSequence(content);
  }

  Future<void> _buildAndExecuteAudioSequence(LessonContent content) async {
    _audioQueue.clear();
    
    // Add progress announcement if enabled
    if (_settings.confirmationsEnabled && _contentList.length > 1) {
      _audioQueue.add("Item ${_currentIndex + 1} of ${_contentList.length}");
    }
    
    // Add content-specific audio
    if (content is TermContent) {
      _audioQueue.add("Term: ${content.term}");
      _audioQueue.add("Definition: ${content.definition}");
      if (content.example != null) {
        _audioQueue.add("Example: ${content.example}");
      }
    } else if (content is ConceptContent) {
      _audioQueue.add(content.conceptText);
      if (content.exampleText != null) {
        _audioQueue.add("Example: ${content.exampleText}");
      }
    } else if (content is QuestionContent) {
      _audioQueue.add("Question: ${content.questionText}");
      
      // Add options for MCQ
      if (content.type == 'mcq') {
        String optionsText = "Options: ";
        for (int i = 0; i < content.options.length; i++) {
          optionsText += "${String.fromCharCode(65 + i)}: ${content.options[i]}. ";
        }
        _audioQueue.add(optionsText);
      }
    }
    
    // Execute the audio sequence
    await _executeAudioQueue(content);
  }

  Future<void> _executeAudioQueue(LessonContent content) async {
    if (_audioQueue.isEmpty) return;
    
    for (int i = 0; i < _audioQueue.length; i++) {
      if (!_isActive || _state == AudioLessonState.paused) break;
      
      final audioText = _audioQueue[i];
      await _audioService.speak(audioText, interrupt: false);
      
      // Wait for audio to complete + pause between items
      await _waitForAudioCompletion();
      
      if (_settings.pauseBetweenItems > 0) {
        await Future.delayed(Duration(milliseconds: (_settings.pauseBetweenItems * 1000).round()));
      }
    }
    
    // Handle post-audio logic based on content type
    await _handlePostAudioLogic(content);
  }

  Future<void> _waitForAudioCompletion() async {
    while (_audioService.currentState.isPlaying || _audioService.currentState.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isActive || _state == AudioLessonState.paused) break;
    }
  }

  Future<void> _handlePostAudioLogic(LessonContent content) async {
    if (!_isActive) return;
    
    if (content is QuestionContent) {
      // For questions, wait for voice input
      await _waitForVoiceAnswer(content);
    } else {
      // For terms and concepts, handle auto-progression
      await _handleAutoProgression();
    }
  }

  Future<void> _waitForVoiceAnswer(QuestionContent content) async {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      if (kDebugMode) {
        print('🎙️ Voice answer disabled: hands-free=${_settings.handsFreeModeEnabled}, voice-nav=${_settings.voiceNavigationEnabled}');
      }
      return; // Fall back to manual interaction
    }
    
    if (kDebugMode) {
      print('🎙️ Waiting for voice answer for question: ${content.questionText.substring(0, min(50, content.questionText.length))}...');
    }
    
    _updateState(AudioLessonState.waitingForVoice);
    _currentRetryAttempt = 0;
    
    await _promptForVoiceAnswer(content);
  }

  Future<void> _promptForVoiceAnswer(QuestionContent content) async {
    String prompt;
    
    switch (content.type) {
      case 'mcq':
        prompt = "Please say A, B, C, or D for your answer";
        break;
      case 'true_false':
        prompt = "Please say true or false";
        break;
      case 'short_answer':
        prompt = "Please speak your answer";
        break;
      default:
        prompt = "Please provide your answer";
    }
    
    if (_currentRetryAttempt > 0) {
      prompt = _getRetryPrompt(_currentRetryAttempt);
    }
    
    await _audioService.speak(prompt);
    await _waitForAudioCompletion();
    
    // Start voice input with timeout
    _startVoiceInputWithTimeout();
  }

  void _startVoiceInputWithTimeout() {
    _updateState(AudioLessonState.processing);
    
    if (kDebugMode) {
      print('🎙️ Starting voice input with timeout: ${_settings.voiceInputTimeout}');
    }
    
    // Start listening for voice input
    _voiceService.startListening(
      localeId: 'en_US',
      listenFor: _settings.voiceInputTimeout,
    );
    
    // Set timeout timer
    _voiceInputTimer = Timer(_settings.voiceInputTimeout, () {
      if (kDebugMode) {
        print('🎙️ Voice input timeout reached');
      }
      _handleVoiceInputTimeout();
    });
  }

  Future<void> _handleVoiceInputTimeout() async {
    if (kDebugMode) {
      print('🎙️ Voice input timeout - attempt ${_currentRetryAttempt + 1}/${_settings.voiceRetryAttempts}');
    }
    
    await _voiceService.cancel();
    _currentRetryAttempt++;
    
    if (_currentRetryAttempt <= _settings.voiceRetryAttempts) {
      // Retry with escalating helpful prompts
      final content = _contentList[_currentIndex] as QuestionContent;
      await _promptForVoiceAnswer(content);
    } else {
      // Give up and switch to manual mode
      if (kDebugMode) {
        print('🎙️ Voice input failed after ${_settings.voiceRetryAttempts} attempts, switching to manual mode');
      }
      if (_settings.confirmationsEnabled) {
        await _speakConfirmation("Switching to manual mode. You can use the touch screen instead.");
      }
      _updateState(AudioLessonState.idle);
    }
  }

  String _getRetryPrompt(int attemptNumber) {
    switch (attemptNumber) {
      case 1:
        return "I didn't catch that. Please repeat your answer.";
      case 2:
        return "Could you speak a bit clearer? Try again.";
      case 3:
        return "Having trouble? You can use the touch screen instead.";
      default:
        return "Switching to manual mode.";
    }
  }

  Future<void> _handleAutoProgression() async {
    if (!_settings.autoProgressAfterReading) {
      // Wait for voice "next" command
      if (kDebugMode) {
        print('🎙️ Waiting for voice "next" command (auto-progress disabled)');
      }
      _updateState(AudioLessonState.waitingForVoice);
      
      // Actually start listening for voice commands
      if (_settings.handsFreeModeEnabled && _settings.voiceNavigationEnabled) {
        await _startListeningForCommand();
      }
      return;
    }
    
    // Auto-progress after delay
    if (kDebugMode) {
      print('🎙️ Auto-progressing after ${_settings.autoProgressDelay.inSeconds} seconds');
    }
    
    _autoProgressTimer = Timer(_settings.autoProgressDelay, () {
      if (_isActive && _state != AudioLessonState.paused) {
        nextContent();
      }
    });
  }

  void _setupVoiceCommandListener() {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      if (kDebugMode) {
        print('🎙️ Voice command listener not setup: hands-free=${_settings.handsFreeModeEnabled}, voice-nav=${_settings.voiceNavigationEnabled}');
      }
      return;
    }
    
    if (kDebugMode) {
      print('🎙️ Setting up voice command listener...');
    }
    
    _voiceService.stateStream.listen((audioState) {
      if (kDebugMode) {
        print('🎙️ Voice state changed: ${audioState.voiceInputState}');
      }
      
      if (audioState.voiceInputState == VoiceInputState.completed) {
        _handleVoiceCommand();
      }
    });
  }

  Future<void> _startListeningForCommand() async {
    if (!_settings.handsFreeModeEnabled || !_settings.voiceNavigationEnabled) {
      if (kDebugMode) {
        print('🎙️ Cannot start listening - hands-free or voice navigation disabled');
      }
      return;
    }
    
    // Check if voice service is already busy
    if (_voiceService.currentState == VoiceInputState.listening ||
        _voiceService.currentState == VoiceInputState.processing) {
      if (kDebugMode) {
        print('🎙️ Voice service already active - skipping start listening');
      }
      return;
    }
    
    if (kDebugMode) {
      print('🎙️ Starting to listen for voice commands...');
    }
    
    try {
      // Cancel any existing session first
      await _voiceService.cancel();
      
      // Give a brief pause to ensure cancellation is complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Start listening with a generous timeout for navigation commands
      final started = await _voiceService.startListening(
        localeId: 'en_US',
        listenFor: const Duration(seconds: 30), // Long timeout for navigation
      );
      
      if (!started) {
        if (kDebugMode) {
          print('🎙️ Failed to start listening for commands');
        }
        return;
      }
      
      if (kDebugMode) {
        print('🎙️ Now listening for navigation commands like "next", "previous", "repeat"');
      }
      
      // Set up timeout timer that restarts listening
      _voiceInputTimer = Timer(const Duration(seconds: 25), () {
        if (_isActive && _state == AudioLessonState.waitingForVoice) {
          if (kDebugMode) {
            print('🎙️ Restarting voice listening (timeout)');
          }
          _startListeningForCommand(); // Restart listening
        }
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('🎙️ Error starting voice command listening: $e');
      }
    }
  }

  Future<void> _handleVoiceCommand() async {
    final command = _voiceService.parseLastCommand();
    
    if (kDebugMode) {
      print('🎙️ Handling voice command: ${command?.phrase} (type: ${command?.type})');
    }
    
    if (command == null) {
      if (kDebugMode) {
        print('🎙️ No command parsed from voice input - use the test button to simulate "next"');
      }
      
      // Don't restart automatically to avoid the race condition
      // User can click the test button or try speaking again manually
      return;
    }
    
    _clearTimers();
    
    switch (command.type) {
      case VoiceCommandType.navigation:
        if (kDebugMode) {
          print('🎙️ Processing navigation command: ${command.value}');
        }
        await _handleNavigationCommand(command.value as NavigationCommand);
        break;
      case VoiceCommandType.control:
        if (kDebugMode) {
          print('🎙️ Processing control command: ${command.value}');
        }
        await _handleControlCommand(command.value as ControlCommand);
        break;
      case VoiceCommandType.answer:
        if (kDebugMode) {
          print('🎙️ Processing answer command: ${command.value}');
        }
        await _handleAnswerCommand(command);
        break;
      case VoiceCommandType.mode:
        if (kDebugMode) {
          print('🎙️ Processing mode command: ${command.value}');
        }
        // Handle mode switching if needed
        break;
    }
  }

  Future<void> _handleNavigationCommand(NavigationCommand command) async {
    switch (command) {
      case NavigationCommand.next:
        if (_settings.interruptOnNextCommand && _audioService.currentState.isPlaying) {
          await _audioService.stop();
        }
        await nextContent();
        break;
      case NavigationCommand.previous:
        await previousContent();
        break;
      case NavigationCommand.first:
        _currentIndex = 0;
        _notifyProgress();
        await _readCurrentContent();
        break;
      case NavigationCommand.last:
        _currentIndex = _contentList.length - 1;
        _notifyProgress();
        await _readCurrentContent();
        break;
      case NavigationCommand.back:
        await previousContent();
        break;
    }
  }

  Future<void> _handleControlCommand(ControlCommand command) async {
    switch (command) {
      case ControlCommand.play:
        if (_state == AudioLessonState.paused) {
          await resumeLesson();
        } else {
          await _readCurrentContent();
        }
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
        // Handle speed changes if needed
        break;
      case ControlCommand.slower:
        // Handle speed changes if needed
        break;
    }
  }

  Future<void> _handleAnswerCommand(VoiceCommand command) async {
    if (_currentIndex >= _contentList.length) return;
    
    final content = _contentList[_currentIndex];
    if (content is! QuestionContent) return;
    
    // Process the answer and provide feedback
    bool isCorrect = false;
    String feedback = "";
    
    if (content.type == 'mcq' && command.value is String) {
      final answerIndex = command.value.codeUnitAt(0) - 65; // A=0, B=1, etc.
      isCorrect = answerIndex == content.correctAnswer;
      feedback = isCorrect ? "Correct!" : "Incorrect. The answer is ${String.fromCharCode(65 + content.correctAnswer)}.";
    } else if (content.type == 'true_false' && command.value is bool) {
      isCorrect = command.value == (content.correctAnswer == 0); // Assuming 0=true, 1=false
      feedback = isCorrect ? "Correct!" : "Incorrect.";
    }
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation(feedback);
    }
    
    // Add explanation if available
    if (content.explanation != null && content.explanation!.isNotEmpty) {
      await _audioService.speak("Explanation: ${content.explanation}");
      await _waitForAudioCompletion();
    }
    
    // Auto-progress or wait for next command
    if (_settings.immediateAnswerProgression) {
      await Future.delayed(const Duration(milliseconds: 500));
      await nextContent();
    } else {
      _updateState(AudioLessonState.waitingForVoice);
    }
  }

  Future<void> _completeLesson() async {
    _isActive = false;
    _clearTimers();
    _updateState(AudioLessonState.completed);
    
    if (_settings.confirmationsEnabled) {
      await _speakConfirmation("Lesson completed! Well done.");
    }
    
    _actionController.add(LessonFlowAction.complete);
  }

  Future<void> _speakConfirmation(String message) async {
    if (_settings.confirmationsEnabled) {
      await _audioService.speak(message, interrupt: false);
      await _waitForAudioCompletion();
    }
  }

  void _clearTimers() {
    _autoProgressTimer?.cancel();
    _autoProgressTimer = null;
    _voiceInputTimer?.cancel();
    _voiceInputTimer = null;
  }

  void _updateState(AudioLessonState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(_state);
    }
  }

  void _notifyProgress() {
    _progressController.add(_currentIndex);
  }

  void dispose() {
    _clearTimers();
    _stateController.close();
    _actionController.close();
    _progressController.close();
  }

  // Manual test method for debugging voice commands
  Future<void> simulateVoiceCommand(String commandText) async {
    if (kDebugMode) {
      print('🎙️ Simulating voice command: "$commandText"');
    }
    
    // Temporarily set the recognized text in voice service
    _voiceService.setRecognizedTextForTesting(commandText);
    
    // Process the command
    await _handleVoiceCommand();
  }
}
