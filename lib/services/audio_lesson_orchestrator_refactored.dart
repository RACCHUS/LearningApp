import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/audio_lesson/content_processor.dart';

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

  // State management (simplified)
  AudioLessonSettings _settings = const AudioLessonSettings();
  AudioLessonState _state = AudioLessonState.idle;
  List<LessonContent> _contentList = [];
  int _currentIndex = 0;
  bool _isActive = false;

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
    if (kDebugMode) {
      print('🎓 AudioLessonOrchestrator initialized (refactored version)');
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
    await _audioService.stop();
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
    await _readCurrentContent();
  }

  Future<void> previousContent() async {
    if (!_isActive || isFirstContent) return;

    if (kDebugMode) {
      print('⏮️ Moving to previous content');
    }

    await _audioService.stop();
    _currentIndex--;
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
    if (_settings.autoProgressAfterReading && _state == AudioLessonState.reading) {
      await Future.delayed(_settings.autoProgressDelay);
      if (_isActive && _state == AudioLessonState.reading) {
        await nextContent();
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

  void dispose() {
    _audioService.dispose();
  }
}

// Keep backward compatibility enums
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
