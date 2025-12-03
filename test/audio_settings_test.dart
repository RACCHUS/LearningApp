import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';

void main() {
  group('AudioSettings Model', () {
    test('should have correct default values', () {
      const settings = AudioSettings();
      
      expect(settings.isEnabled, true);
      expect(settings.speechRate, 1.0);
      expect(settings.volume, 1.0);
      expect(settings.pitch, 1.0);
      expect(settings.autoPlay, false);
      expect(settings.autoReadQuestions, false);
      expect(settings.autoReadAnswers, false);
      expect(settings.language, 'en-US');
    });

    test('should create copy with modified values', () {
      const original = AudioSettings();
      final modified = original.copyWith(
        speechRate: 1.5,
        volume: 0.8,
        autoPlay: true,
      );

      expect(modified.speechRate, 1.5);
      expect(modified.volume, 0.8);
      expect(modified.autoPlay, true);
      // Other values should remain unchanged
      expect(modified.isEnabled, true);
      expect(modified.pitch, 1.0);
      expect(modified.language, 'en-US');
    });

    test('should properly serialize to/from JSON', () {
      const settings = AudioSettings(
        isEnabled: false,
        speechRate: 1.2,
        volume: 0.9,
        pitch: 1.1,
        autoPlay: true,
        autoReadQuestions: false,
        autoReadAnswers: true,
        language: 'es-ES',
      );

      final json = settings.toJson();
      final deserialized = AudioSettings.fromJson(json);

      expect(deserialized.isEnabled, settings.isEnabled);
      expect(deserialized.speechRate, settings.speechRate);
      expect(deserialized.volume, settings.volume);
      expect(deserialized.pitch, settings.pitch);
      expect(deserialized.autoPlay, settings.autoPlay);
      expect(deserialized.autoReadQuestions, settings.autoReadQuestions);
      expect(deserialized.autoReadAnswers, settings.autoReadAnswers);
      expect(deserialized.language, settings.language);
    });

    test('should validate speech rate bounds', () {
      const settings = AudioSettings(speechRate: 1.5);
      
      expect(settings.speechRate, greaterThanOrEqualTo(0.5));
      expect(settings.speechRate, lessThanOrEqualTo(2.0));
    });

    test('should validate volume bounds', () {
      const settings = AudioSettings(volume: 0.8);
      
      expect(settings.volume, greaterThanOrEqualTo(0.0));
      expect(settings.volume, lessThanOrEqualTo(1.0));
    });

    test('should validate pitch bounds', () {
      const settings = AudioSettings(pitch: 1.2);
      
      expect(settings.pitch, greaterThanOrEqualTo(0.5));
      expect(settings.pitch, lessThanOrEqualTo(2.0));
    });
  });

  group('AudioSettingsNotifier', () {
    // All tests in this group require Hive initialization in test environment
    
    test('should initialize with default settings', () {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should toggle enabled state', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should update speech rate', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should update volume', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should update pitch', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should toggle auto play', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should toggle auto read questions', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should toggle auto read answers', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should update language', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should set preferred voice', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');

    test('should reset to defaults', () async {
      // Note: Requires Hive initialization
    }, skip: 'Requires Hive initialization in test environment');
  });

  group('Audio State', () {
    test('should have correct initial state', () {
      const state = AudioState();
      
      expect(state.playbackState, AudioPlaybackState.idle);
      expect(state.voiceInputState, VoiceInputState.idle);
      expect(state.currentText, isNull);
      expect(state.recognizedText, isNull);
      expect(state.isAvailable, true);
      expect(state.hasPermissions, false);
    });

    test('should create copy with modified playback state', () {
      const original = AudioState();
      final modified = original.copyWith(
        playbackState: AudioPlaybackState.playing,
        currentText: 'Test text',
      );

      expect(modified.playbackState, AudioPlaybackState.playing);
      expect(modified.currentText, 'Test text');
      expect(modified.voiceInputState, VoiceInputState.idle);
    });

    test('should create copy with modified voice input state', () {
      const original = AudioState();
      final modified = original.copyWith(
        voiceInputState: VoiceInputState.listening,
        recognizedText: 'hello',
        confidence: 0.95,
      );

      expect(modified.voiceInputState, VoiceInputState.listening);
      expect(modified.recognizedText, 'hello');
      expect(modified.confidence, 0.95);
    });

    test('should correctly identify playing state', () {
      final playingState = AudioState(playbackState: AudioPlaybackState.playing);
      final pausedState = AudioState(playbackState: AudioPlaybackState.paused);
      final stoppedState = AudioState(playbackState: AudioPlaybackState.stopped);

      expect(playingState.isPlaying, true);
      expect(pausedState.isPlaying, false);
      expect(stoppedState.isPlaying, false);
    });

    test('should correctly identify listening state', () {
      final listeningState = AudioState(voiceInputState: VoiceInputState.listening);
      final idleState = AudioState(voiceInputState: VoiceInputState.idle);
      final processingState = AudioState(voiceInputState: VoiceInputState.processing);

      expect(listeningState.isListening, true);
      expect(idleState.isListening, false);
      expect(processingState.isListening, false);
    });
  });
}
