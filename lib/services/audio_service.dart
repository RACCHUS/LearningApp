import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterTts? _flutterTts;
  AudioSettings _settings = const AudioSettings();
  AudioState _state = const AudioState();
  
  final StreamController<AudioState> _stateController = StreamController<AudioState>.broadcast();
  Stream<AudioState> get stateStream => _stateController.stream;
  AudioState get currentState => _state;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      
      if (_flutterTts == null) {
        _updateState(_state.copyWith(
          isAvailable: false,
          errorMessage: 'Text-to-Speech not available on this platform',
        ));
        return;
      }

      // Set up event handlers
      _flutterTts!.setStartHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.playing,
          errorMessage: null,
        ));
      });

      _flutterTts!.setCompletionHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.idle,
          progress: 1.0,
          currentText: null,
        ));
      });

      _flutterTts!.setCancelHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.stopped,
          currentText: null,
        ));
      });

      _flutterTts!.setPauseHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.paused,
        ));
      });

      _flutterTts!.setContinueHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.playing,
        ));
      });

      _flutterTts!.setErrorHandler((msg) {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.error,
          errorMessage: msg,
        ));
      });

      // Get available voices
      final voices = await _getAvailableVoices();
      
      _updateState(_state.copyWith(
        isAvailable: true,
        availableVoices: voices,
      ));

      _isInitialized = true;
      
      // Apply default settings
      await updateSettings(_settings);
      
    } catch (e) {
      _updateState(_state.copyWith(
        isAvailable: false,
        errorMessage: 'Failed to initialize Text-to-Speech: $e',
      ));
      if (kDebugMode) {
        print('AudioService initialization error: $e');
      }
    }
  }

  Future<List<String>> _getAvailableVoices() async {
    try {
      if (_flutterTts == null) return [];
      
      final voices = await _flutterTts!.getVoices;
      if (voices is List) {
        return voices
            .where((voice) => voice is Map && voice['name'] != null)
            .map((voice) => voice['name'] as String)
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting voices: $e');
      }
      return [];
    }
  }

  Future<void> updateSettings(AudioSettings settings) async {
    _settings = settings;
    
    if (_flutterTts == null || !_settings.isEnabled) return;

    try {
      await _flutterTts!.setSpeechRate(_settings.speechRate);
      await _flutterTts!.setVolume(_settings.volume);
      await _flutterTts!.setPitch(_settings.pitch);
      await _flutterTts!.setLanguage(_settings.language);
      
      if (_settings.preferredVoice != null && _state.availableVoices.contains(_settings.preferredVoice)) {
        await _flutterTts!.setVoice({'name': _settings.preferredVoice!, 'locale': _settings.language});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating TTS settings: $e');
      }
    }
  }

  Future<bool> speak(String text, {bool interrupt = false}) async {
    if (!_isInitialized || _flutterTts == null || !_settings.isEnabled || text.trim().isEmpty) {
      return false;
    }

    try {
      if (interrupt && _state.isPlaying) {
        await stop();
      }

      _updateState(_state.copyWith(
        playbackState: AudioPlaybackState.loading,
        currentText: text,
        progress: 0.0,
        errorMessage: null,
      ));

      final result = await _flutterTts!.speak(text);
      return result == 1; // 1 indicates success
      
    } catch (e) {
      _updateState(_state.copyWith(
        playbackState: AudioPlaybackState.error,
        errorMessage: 'Speech failed: $e',
      ));
      if (kDebugMode) {
        print('TTS speak error: $e');
      }
      return false;
    }
  }

  Future<void> pause() async {
    if (_flutterTts == null || !_state.isPlaying) return;
    
    try {
      await _flutterTts!.stop();
      _updateState(_state.copyWith(
        playbackState: AudioPlaybackState.paused,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('TTS pause error: $e');
      }
    }
  }

  Future<void> resume() async {
    if (_flutterTts == null || !_state.isPaused) return;
    
    try {
      // For web TTS, we need to restart speaking from the beginning
      // since true pause/resume isn't available
      final result = await _flutterTts!.speak(_state.currentText ?? '');
      if (result == 1) {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.playing,
        ));
      }
    } catch (e) {
      if (kDebugMode) {
        print('TTS resume error: $e');
      }
    }
  }

  Future<void> stop() async {
    if (_flutterTts == null) return;
    
    try {
      await _flutterTts!.stop();
    } catch (e) {
      if (kDebugMode) {
        print('TTS stop error: $e');
      }
    }
  }

  Future<void> setRate(double rate) async {
    if (_flutterTts == null) return;
    
    _settings = _settings.copyWith(speechRate: rate);
    
    try {
      await _flutterTts!.setSpeechRate(rate);
    } catch (e) {
      if (kDebugMode) {
        print('TTS setRate error: $e');
      }
    }
  }

  Future<void> setVolume(double volume) async {
    if (_flutterTts == null) return;
    
    _settings = _settings.copyWith(volume: volume);
    
    try {
      await _flutterTts!.setVolume(volume);
    } catch (e) {
      if (kDebugMode) {
        print('TTS setVolume error: $e');
      }
    }
  }

  // Convenience methods for different content types
  Future<bool> speakQuestion(String questionText) async {
    if (_settings.autoReadQuestions) {
      return await speak('Question: $questionText');
    }
    return false;
  }

  Future<bool> speakAnswer(String answerText) async {
    if (_settings.autoReadAnswers) {
      return await speak('Answer: $answerText');
    }
    return false;
  }

  Future<bool> speakTerm(String term, String definition, {String? example}) async {
    String text = 'Term: $term. Definition: $definition';
    if (example != null && example.isNotEmpty) {
      text += '. Example: $example';
    }
    return await speak(text);
  }

  Future<bool> speakConcept(String conceptText, {String? example}) async {
    String text = conceptText;
    if (example != null && example.isNotEmpty) {
      text += '. Example: $example';
    }
    return await speak(text);
  }

  Future<bool> speakOptions(List<String> options) async {
    if (!_settings.autoReadQuestions) return false;
    
    String optionsText = 'Options: ';
    for (int i = 0; i < options.length; i++) {
      optionsText += '${String.fromCharCode(65 + i)}: ${options[i]}. ';
    }
    return await speak(optionsText);
  }

  void _updateState(AudioState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  void dispose() {
    _stateController.close();
    _flutterTts?.stop();
  }
}
