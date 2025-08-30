import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:learning_pwa/models/audio_lesson_settings.dart';
import 'package:learning_pwa/services/audio_service.dart';

/// Service responsible for managing audio playback queue and sequencing
/// Handles audio queue operations, playback coordination, and timing
class AudioQueueManager {
  final AudioService _audioService = AudioService();
  
  final List<String> _audioQueue = [];
  bool _isPlaying = false;
  AudioLessonSettings _settings = const AudioLessonSettings();

  // Callbacks for audio events
  VoidCallback? _onAudioComplete;
  VoidCallback? _onQueueEmpty;
  Function(String)? _onStartPlayback;

  /// Initialize the audio queue manager
  Future<void> initialize() async {
    await _audioService.initialize();
  }

  /// Update settings for audio playback
  void updateSettings(AudioLessonSettings settings) {
    _settings = settings;
  }

  /// Set callbacks for audio events
  void setCallbacks({
    VoidCallback? onAudioComplete,
    VoidCallback? onQueueEmpty,
    Function(String)? onStartPlayback,
  }) {
    _onAudioComplete = onAudioComplete;
    _onQueueEmpty = onQueueEmpty;
    _onStartPlayback = onStartPlayback;
  }

  /// Add text to the audio queue
  void enqueue(String text) {
    if (text.trim().isEmpty) return;

    _audioQueue.add(text);
    
    if (kDebugMode) {
      final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
      print('🔊 Added to audio queue: "$preview"');
      print('🔊 Queue size: ${_audioQueue.length}');
    }

    // Start playing if not already playing
    if (!_isPlaying) {
      _processQueue();
    }
  }

  /// Add multiple texts to the queue
  void enqueueMultiple(List<String> texts) {
    for (final text in texts) {
      enqueue(text);
    }
  }

  /// Clear all items from the queue
  void clearQueue() {
    if (kDebugMode) {
      print('🔊 Clearing audio queue (${_audioQueue.length} items)');
    }
    _audioQueue.clear();
  }

  /// Stop current playback and clear queue
  Future<void> stopAll() async {
    if (kDebugMode) {
      print('🔊 Stopping all audio playback');
    }
    
    await _audioService.stop();
    clearQueue();
    _isPlaying = false;
  }

  /// Pause current playback (keeps queue intact)
  Future<void> pause() async {
    if (kDebugMode) {
      print('🔊 Pausing audio playback');
    }
    await _audioService.pause();
    _isPlaying = false;
  }

  /// Resume playback from where it was paused
  Future<void> resume() async {
    if (kDebugMode) {
      print('🔊 Resuming audio playback');
    }
    await _audioService.resume();
    _isPlaying = true;
  }

  /// Process the audio queue sequentially
  Future<void> _processQueue() async {
    if (_audioQueue.isEmpty || _isPlaying) {
      if (_audioQueue.isEmpty) {
        _onQueueEmpty?.call();
      }
      return;
    }

    _isPlaying = true;
    
    while (_audioQueue.isNotEmpty) {
      final text = _audioQueue.removeAt(0);
      
      if (kDebugMode) {
        final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
        print('🔊 Processing audio: "$preview"');
      }

      _onStartPlayback?.call(text);

      try {
        await _audioService.speak(text);
        
        // Add pause between items if configured
        if (_settings.pauseBetweenItems > 0 && _audioQueue.isNotEmpty) {
          if (kDebugMode) {
            print('🔊 Pausing between items: ${_settings.pauseBetweenItems}s');
          }
          await Future.delayed(Duration(
            milliseconds: (_settings.pauseBetweenItems * 1000).round()
          ));
        }
        
        _onAudioComplete?.call();
        
      } catch (e) {
        if (kDebugMode) {
          print('🔊 Error playing audio: $e');
        }
        break;
      }
    }

    _isPlaying = false;
    
    if (_audioQueue.isEmpty) {
      if (kDebugMode) {
        print('🔊 Audio queue completed');
      }
      _onQueueEmpty?.call();
    }
  }

  /// Speak text immediately (bypasses queue)
  Future<void> speakImmediate(String text) async {
    if (text.trim().isEmpty) return;

    if (kDebugMode) {
      final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
      print('🔊 Speaking immediately: "$preview"');
    }

    _onStartPlayback?.call(text);
    
    try {
      await _audioService.speak(text);
      _onAudioComplete?.call();
    } catch (e) {
      if (kDebugMode) {
        print('🔊 Error in immediate speech: $e');
      }
    }
  }

  /// Wait for current audio to complete
  Future<void> waitForAudioCompletion() async {
    while (_isPlaying || _audioService.currentState.isPlaying) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Check if audio is currently playing
  bool get isPlaying => _isPlaying || _audioService.currentState.isPlaying;

  /// Check if queue has pending items
  bool get hasQueuedItems => _audioQueue.isNotEmpty;

  /// Get current queue size
  int get queueSize => _audioQueue.length;

  /// Get a copy of the current queue for debugging
  List<String> get currentQueue => List.unmodifiable(_audioQueue);

  /// Get the next item in queue without removing it
  String? peekNext() {
    return _audioQueue.isEmpty ? null : _audioQueue.first;
  }

  /// Skip current audio and move to next in queue
  Future<void> skipCurrent() async {
    if (kDebugMode) {
      print('🔊 Skipping current audio');
    }
    
    await _audioService.stop();
    
    // Continue with queue if there are more items
    if (_audioQueue.isNotEmpty && !_isPlaying) {
      _processQueue();
    }
  }

  /// Get audio queue status for debugging
  Map<String, dynamic> get queueStatus {
    return {
      'queueSize': _audioQueue.length,
      'isPlaying': _isPlaying,
      'serviceIsPlaying': _audioService.currentState.isPlaying,
      'hasQueuedItems': hasQueuedItems,
      'nextItem': peekNext()?.substring(0, 30) ?? 'none',
    };
  }

  /// Dispose of resources
  void dispose() {
    if (kDebugMode) {
      print('🗑️ Disposing audio queue manager');
    }
    
    stopAll();
    _onAudioComplete = null;
    _onQueueEmpty = null;
    _onStartPlayback = null;
  }
}
