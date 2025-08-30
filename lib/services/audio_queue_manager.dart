import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';

/// Service responsible for managing audio queues and playback sequencing
/// Extracted from AudioLessonOrchestrator for better separation of concerns
class AudioQueueManager {
  static final AudioQueueManager _instance = AudioQueueManager._internal();
  factory AudioQueueManager() => _instance;
  AudioQueueManager._internal();

  final AudioService _audioService = AudioService();
  final List<String> _audioQueue = [];
  bool _isPlaying = false;

  /// Current audio queue state
  List<String> get currentQueue => List.unmodifiable(_audioQueue);
  bool get isPlaying => _isPlaying;
  bool get hasQueuedAudio => _audioQueue.isNotEmpty;

  /// Initialize the audio service
  Future<void> initialize() async {
    await _audioService.initialize();
  }

  /// Build audio sequence for lesson content
  List<String> buildAudioSequence(
    LessonContent content, 
    AudioLessonSettings settings,
    {int? currentIndex, int? totalItems}
  ) {
    final audioItems = <String>[];
    
    // Add progress announcement if enabled
    if (settings.confirmationsEnabled && 
        currentIndex != null && totalItems != null && totalItems > 1) {
      audioItems.add("Item ${currentIndex + 1} of $totalItems");
    }
    
    // Add content-specific audio
    if (content is TermContent) {
      audioItems.add("Term: ${content.term}");
      audioItems.add("Definition: ${content.definition}");
      if (content.example != null) {
        audioItems.add("Example: ${content.example}");
      }
    } else if (content is ConceptContent) {
      audioItems.add(content.conceptText);
      if (content.exampleText != null) {
        audioItems.add("Example: ${content.exampleText}");
      }
    } else if (content is QuestionContent) {
      audioItems.add("Question: ${content.questionText}");
      
      // Add options for MCQ
      if (content.type == 'mcq') {
        String optionsText = "Options: ";
        for (int i = 0; i < content.options.length; i++) {
          optionsText += "${String.fromCharCode(65 + i)}: ${content.options[i]}. ";
        }
        audioItems.add(optionsText);
      }
    }
    
    return audioItems;
  }

  /// Queue audio sequence for playback
  void queueAudioSequence(List<String> audioItems) {
    _audioQueue.clear();
    _audioQueue.addAll(audioItems);
    
    if (kDebugMode) {
      print('🎵 Queued ${audioItems.length} audio items');
    }
  }

  /// Play the queued audio sequence
  Future<void> playQueuedAudio(AudioLessonSettings settings) async {
    if (_audioQueue.isEmpty) {
      if (kDebugMode) {
        print('🎵 No audio items in queue');
      }
      return;
    }

    _isPlaying = true;
    
    try {
      for (int i = 0; i < _audioQueue.length; i++) {
        if (!_isPlaying) break; // Stop if cancelled
        
        final audioText = _audioQueue[i];
        
        if (kDebugMode) {
          print('🎵 Playing audio ${i + 1}/${_audioQueue.length}: "${audioText.substring(0, 50)}..."');
        }
        
        await _audioService.speak(audioText, interrupt: false);
        
        // Wait for audio to complete
        await _waitForAudioCompletion();
        
        if (settings.pauseBetweenItems > 0) {
          await Future.delayed(Duration(milliseconds: (settings.pauseBetweenItems * 1000).round()));
        }
      }
    } finally {
      _isPlaying = false;
      _audioQueue.clear();
      
      if (kDebugMode) {
        print('🎵 Audio sequence completed');
      }
    }
  }

  /// Stop current audio playback
  Future<void> stopAudio() async {
    _isPlaying = false;
    await _audioService.stop();
    _audioQueue.clear();
    
    if (kDebugMode) {
      print('🎵 Audio playback stopped');
    }
  }

  /// Pause current audio playback
  Future<void> pauseAudio() async {
    _isPlaying = false;
    await _audioService.pause();
    
    if (kDebugMode) {
      print('🎵 Audio playback paused');
    }
  }

  /// Resume audio playback
  Future<void> resumeAudio() async {
    _isPlaying = true;
    await _audioService.resume();
    
    if (kDebugMode) {
      print('🎵 Audio playback resumed');
    }
  }

  /// Speak a single confirmation message
  Future<void> speakConfirmation(String message, AudioLessonSettings settings) async {
    if (!settings.confirmationsEnabled) return;
    
    if (kDebugMode) {
      print('🎵 Speaking confirmation: "$message"');
    }
    
    await _audioService.speak(message, interrupt: false);
    await _waitForAudioCompletion();
  }

  /// Speak answer feedback
  Future<void> speakAnswerFeedback(
    bool isCorrect, 
    String? explanation,
    AudioLessonSettings settings
  ) async {
    if (!settings.confirmationsEnabled) return;
    
    final feedback = isCorrect ? "Correct!" : "Incorrect.";
    await speakConfirmation(feedback, settings);
    
    // Add explanation if available
    if (explanation != null && explanation.isNotEmpty) {
      await speakConfirmation("Explanation: $explanation", settings);
    }
  }

  /// Wait for current audio to complete
  Future<void> _waitForAudioCompletion() async {
    while (_audioService.currentState.isPlaying || _audioService.currentState.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isPlaying) break; // Stop waiting if cancelled
    }
  }

  /// Get audio service state
  dynamic get audioState => _audioService.currentState;

  /// Check if audio service is currently playing
  bool get isAudioPlaying => _audioService.currentState.isPlaying;

  /// Clear the audio queue
  void clearQueue() {
    _audioQueue.clear();
    
    if (kDebugMode) {
      print('🎵 Audio queue cleared');
    }
  }

  /// Get queue status for debugging
  String getQueueStatus() {
    return 'Queue: ${_audioQueue.length} items, Playing: $_isPlaying';
  }

  /// Dispose and clean up resources
  void dispose() {
    _audioQueue.clear();
    _isPlaying = false;
    // Note: Don't dispose audio service as it might be used elsewhere
  }
}
