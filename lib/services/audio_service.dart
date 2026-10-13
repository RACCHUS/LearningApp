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
  AudioSettings get currentSettings => _settings;

  bool _isInitialized = false;

  /// Completer that resolves when the current speak() call finishes.
  Completer<void>? _speakCompleter;

  /// Future that completes when the current speech utterance ends
  /// (via completion, cancellation, or error). Returns immediately if idle.
  Future<void> get speakCompletion =>
      _speakCompleter?.future ?? Future.value();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();
      
      if (_flutterTts == null) {
        _updateState(_state.copyWith(
          isAvailable: false,
          errorMessage: 'Text-to-Speech not available on this platform',
        ));
        
        // Log TTS unavailability for diagnostics
        if (kDebugMode) {
          print('❌ CRITICAL: TTS not available on this platform');
          print('Platform: ${defaultTargetPlatform.toString()}');
        }
        
        // Mark as "initialized" even though TTS unavailable (graceful degradation)
        _isInitialized = true;
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
        _completeSpeaking();
      });

      _flutterTts!.setCancelHandler(() {
        _updateState(_state.copyWith(
          playbackState: AudioPlaybackState.stopped,
          currentText: null,
        ));
        _completeSpeaking();
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
        _completeSpeaking();
        if (kDebugMode) {
          print('❌ TTS error: $msg');
        }
      });

      // Get available voices (Chromium Web loads SpeechSynthesis voices asynchronously, so retry briefly if empty)
      var voiceInfos = await _getAvailableVoiceInfos();
      if (kIsWeb && voiceInfos.isEmpty) {
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          voiceInfos = await _getAvailableVoiceInfos();
          if (voiceInfos.isNotEmpty) break;
        }
      }
      final voiceNames = voiceInfos.map((v) => v.name).toList();
      
      _updateState(_state.copyWith(
        isAvailable: true,
        availableVoices: voiceNames,
        availableVoiceInfos: voiceInfos,
      ));

      _isInitialized = true;

      // Select a natural, gentle educational voice if none explicitly chosen
      if (_settings.preferredVoice == null && voiceInfos.isNotEmpty) {
        final bestVoice = findBestNaturalVoice(voiceInfos, _settings.language);
        if (bestVoice != null) {
          _settings = _settings.copyWith(preferredVoice: bestVoice);
        }
      }
      
      // Apply default settings
      await updateSettings(_settings);
      
      if (kDebugMode) {
        print('✅ AudioService initialized successfully');
        print('Available voices: ${voiceInfos.length}, Selected: ${_settings.preferredVoice}');
      }
      
    } catch (e) {
      _updateState(_state.copyWith(
        isAvailable: false,
        errorMessage: 'Failed to initialize Text-to-Speech: $e',
      ));
      if (kDebugMode) {
        print('❌ AudioService initialization error: $e');
      }
      
      // Still mark as initialized (graceful degradation)
      _isInitialized = true;
    }
  }

  /// Heuristically identifies the most natural, human-sounding voice available
  /// from the platform (preferring Google Natural, Microsoft Online/Neural,
  /// or Apple enhanced voices over robotic legacy synthesizers).
  static String? findBestNaturalVoice(List<VoiceInfo> voices, String languageCode) {
    if (voices.isEmpty) return null;

    final langPrefix = languageCode.split('-').first.toLowerCase();
    final matching = voices.where((v) {
      final loc = v.locale.toLowerCase();
      return loc.startsWith(langPrefix) || loc.isEmpty;
    }).toList();

    final candidatePool = matching.isNotEmpty ? matching : voices;

    // 1. Google Chrome High-Quality Web Voices (soft, natural educator tone)
    final googleVoice = candidatePool.firstWhere(
      (v) =>
          v.name.contains('Google') &&
          (v.name.contains('US English') ||
              v.name.contains('UK English Female') ||
              v.name.contains('English')),
      orElse: () => const VoiceInfo(name: '', locale: ''),
    );
    if (googleVoice.name.isNotEmpty) return googleVoice.name;

    // 2. Microsoft / Edge Neural & Natural Online Voices
    final neuralVoice = candidatePool.firstWhere(
      (v) =>
          v.name.toLowerCase().contains('natural') ||
          v.name.toLowerCase().contains('neural') ||
          v.name.toLowerCase().contains('online'),
      orElse: () => const VoiceInfo(name: '', locale: ''),
    );
    if (neuralVoice.name.isNotEmpty) return neuralVoice.name;

    // 3. Known warm & gentle voices (Zira, Jenny, Aria, Samantha, Ava, Karen, Victoria, Serena, Hazel)
    final warmVoice = candidatePool.firstWhere(
      (v) {
        final n = v.name.toLowerCase();
        return n.contains('zira') ||
            n.contains('jenny') ||
            n.contains('aria') ||
            n.contains('samantha') ||
            n.contains('ava') ||
            n.contains('karen') ||
            n.contains('victoria') ||
            n.contains('serena') ||
            n.contains('hazel') ||
            n.contains('susan') ||
            n.contains('catherine');
      },
      orElse: () => const VoiceInfo(name: '', locale: ''),
    );
    if (warmVoice.name.isNotEmpty) return warmVoice.name;

    // 4. Any English voice that is NOT the robotic Microsoft David Desktop / Mark
    final nonRobotic = candidatePool.firstWhere(
      (v) => !v.name.contains('David') && !v.name.contains('Mark'),
      orElse: () => candidatePool.first,
    );
    return nonRobotic.name;
  }

  /// Ensures available voices are discovered and cached.
  /// Chromium Web loads voices asynchronously after page startup; this
  /// retries discovery if the cache is initially empty.
  Future<void> _ensureVoicesLoaded() async {
    if (_state.availableVoices.isNotEmpty) return;
    try {
      var voiceInfos = await _getAvailableVoiceInfos();
      if (kIsWeb && voiceInfos.isEmpty) {
        for (int i = 0; i < 8; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          voiceInfos = await _getAvailableVoiceInfos();
          if (voiceInfos.isNotEmpty) break;
        }
      }
      if (voiceInfos.isNotEmpty) {
        final voiceNames = voiceInfos.map((v) => v.name).toList();
        _updateState(_state.copyWith(
          availableVoices: voiceNames,
          availableVoiceInfos: voiceInfos,
        ));
        if (_settings.preferredVoice == null) {
          final bestVoice = findBestNaturalVoice(voiceInfos, _settings.language);
          if (bestVoice != null) {
            _settings = _settings.copyWith(preferredVoice: bestVoice);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in _ensureVoicesLoaded: $e');
      }
    }
  }

  Future<List<VoiceInfo>> _getAvailableVoiceInfos() async {
    try {
      if (_flutterTts == null) return [];
      
      final voices = await _flutterTts!.getVoices;
      if (voices is List) {
        return voices
            .where((voice) => voice is Map && voice['name'] != null)
            .map((voice) => VoiceInfo(
                  name: voice['name'] as String,
                  locale: (voice['locale'] as String?) ?? '',
                ))
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

  /// Applies a specific voice to the TTS engine.
  /// On Web, flutter_tts_web matches exact {name: e.name, locale: e.lang}.
  /// Passing the exact VoiceInfo.locale guarantees targetList in flutter_tts_web
  /// finds the speech voice instead of silently failing.
  Future<void> _applyVoice(String voiceName) async {
    if (_flutterTts == null) return;
    try {
      final match = _state.availableVoiceInfos.firstWhere(
        (v) => v.name == voiceName,
        orElse: () => VoiceInfo(name: voiceName, locale: _settings.language),
      );
      final voiceMap = {
        'name': match.name,
        'locale': match.locale.isNotEmpty ? match.locale : _settings.language,
      };
      await _flutterTts!.setVoice(voiceMap);
      if (kDebugMode) {
        print('🔊 TTS voice applied: ${match.name} (${voiceMap['locale']})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error applying voice $voiceName: $e');
      }
    }
  }

  Future<void> updateSettings(AudioSettings settings) async {
    _settings = settings;
    
    if (_flutterTts == null || !_settings.isEnabled) return;

    try {
      if (_state.availableVoices.isEmpty) {
        await _ensureVoicesLoaded();
      }

      await _flutterTts!.setSpeechRate(_settings.speechRate);
      await _flutterTts!.setVolume(_settings.volume);
      await _flutterTts!.setPitch(_settings.pitch);
      // Set language first. Note: on web flutter_tts_web setLanguage resets utterance.voice,
      // so setVoice MUST be executed immediately after setLanguage.
      await _flutterTts!.setLanguage(_settings.language);
      
      final voiceToUse = _settings.preferredVoice ??
          findBestNaturalVoice(_state.availableVoiceInfos, _settings.language);

      if (voiceToUse != null) {
        if (_settings.preferredVoice == null) {
          _settings = _settings.copyWith(preferredVoice: voiceToUse);
        }
        await _applyVoice(voiceToUse);
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
      if (_state.availableVoices.isEmpty) {
        await _ensureVoicesLoaded();
      }

      // Re-apply preferred or best natural voice before speaking to guarantee
      // that flutter_tts_web utterance.voice is explicitly bound to our chosen voice
      final voiceToUse = _settings.preferredVoice ??
          findBestNaturalVoice(_state.availableVoiceInfos, _settings.language);
      if (voiceToUse != null) {
        if (_settings.preferredVoice == null) {
          _settings = _settings.copyWith(preferredVoice: voiceToUse);
        }
        await _applyVoice(voiceToUse);
      }

      if (interrupt && _state.isPlaying) {
        await stop();
      }

      // Create a new completer for this utterance
      _completeSpeaking(); // resolve any dangling completer
      _speakCompleter = Completer<void>();

      _updateState(_state.copyWith(
        playbackState: AudioPlaybackState.loading,
        currentText: text,
        progress: 0.0,
        errorMessage: null,
      ));

      // On Web, SpeechSynthesisUtterance.onboundary can report charIndex past string length
      // at sentence boundaries, causing flutter_tts_web to throw RangeError on substring().
      // Appending safe trailing whitespace prevents charIndex out-of-bounds while preserving audio.
      final safeText = kIsWeb ? text.padRight(text.length + 16) : text;
      final result = await _flutterTts!.speak(safeText);
      return result == 1; // 1 indicates success
      
    } catch (e) {
      _updateState(_state.copyWith(
        playbackState: AudioPlaybackState.error,
        errorMessage: 'Speech failed: $e',
      ));
      _completeSpeaking();
      if (kDebugMode) {
        print('TTS speak error: $e');
      }
      return false;
    }
  }

  /// Safely resolve the current speak completer if pending.
  void _completeSpeaking() {
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    _speakCompleter = null;
  }

  /// Preview a specific voice with a sample sentence, then restore the original voice.
  Future<void> previewVoice(VoiceInfo voice) async {
    if (_flutterTts == null) return;
    try {
      await stop();
      await _flutterTts!.setVoice({'name': voice.name, 'locale': voice.locale});
      _speakCompleter = Completer<void>();
      const previewText = 'Hello! This is how I sound when reading your lessons.';
      final safePreview = kIsWeb ? previewText.padRight(previewText.length + 16) : previewText;
      await _flutterTts!.speak(safePreview);
      await speakCompletion;
      // Restore the user's preferred voice
      await updateSettings(_settings);
    } catch (e) {
      if (kDebugMode) {
        print('Voice preview error: $e');
      }
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
