import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/pre_reader_profile.dart';
import 'package:learning_pwa/services/pre_reader_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preReaderAudioServiceProvider = Provider<PreReaderAudioService>((ref) {
  return PreReaderAudioService();
});

class PreReaderNotifier extends StateNotifier<PreReaderProfile> {
  final PreReaderAudioService _audioService;
  static const String _keyEnabled = 'pre_reader_enabled';
  static const String _keyTrack = 'pre_reader_track';
  static const String _keyAutoSpeak = 'pre_reader_auto_speak';

  PreReaderNotifier({
    PreReaderAudioService? audioService,
    PreReaderProfile initialProfile = const PreReaderProfile(),
  })  : _audioService = audioService ?? PreReaderAudioService(),
        super(initialProfile) {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyEnabled) ?? state.enabled;
      final trackStr = prefs.getString(_keyTrack);
      final track = trackStr == null
          ? state.track
          : (trackStr == 'youth' ? PreReaderTrack.youth : PreReaderTrack.adult);
      final autoSpeak = prefs.getBool(_keyAutoSpeak) ?? state.autoSpeakScreens;

      state = state.copyWith(
        enabled: enabled,
        track: track,
        autoSpeakScreens: autoSpeak,
      );
    } catch (_) {
      // Graceful fallback to default in test / headless environments
    }
  }

  Future<void> enable(PreReaderTrack track) async {
    state = state.copyWith(
      enabled: true,
      track: track,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await prefs.setString(_keyTrack, track.name);

    // Synchronize global audio defaults for pre-reader accessibility
    await _audioService.enablePreReaderDefaults(track: track);

    // Give spoken welcome feedback
    if (track == PreReaderTrack.youth) {
      await _audioService.speak(
        'Welcome! You are ready to learn sounds, letters, and fun words!',
        track: track,
      );
    } else {
      await _audioService.speak(
        'Welcome! We will start step-by-step with letter sounds and writing.',
        track: track,
      );
    }
  }

  Future<void> disable() async {
    state = state.copyWith(enabled: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    await _audioService.stop();
  }

  Future<void> setTrack(PreReaderTrack track) async {
    state = state.copyWith(track: track);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTrack, track.name);
  }

  Future<void> toggleAutoSpeak() async {
    final next = !state.autoSpeakScreens;
    state = state.copyWith(autoSpeakScreens: next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSpeak, next);
    if (next) {
      await _audioService.speak('Read aloud is on.', track: state.track);
    } else {
      await _audioService.speak('Read aloud on tap only.', track: state.track);
    }
  }

  Future<void> speak(String text, {double? customRate}) async {
    await _audioService.speak(
      text,
      track: state.track,
      customRate: customRate ?? state.speechRate,
    );
  }

  Future<void> speakPhoneme(
    String letter,
    String phonemeSound,
    String anchorWord,
  ) async {
    await _audioService.speakPhoneme(
      letter,
      phonemeSound,
      anchorWord,
      track: state.track,
    );
  }

  Future<void> stop() async {
    await _audioService.stop();
  }
}

final preReaderProvider =
    StateNotifierProvider<PreReaderNotifier, PreReaderProfile>((ref) {
  final audioService = ref.watch(preReaderAudioServiceProvider);
  return PreReaderNotifier(audioService: audioService);
});
