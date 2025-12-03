import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_settings.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/enhanced_voice_input_service.dart';
import 'package:learning_pwa/models/voice_command.dart';
import 'package:learning_pwa/providers/base_settings_notifier.dart';

// Audio Settings Provider
final audioSettingsProvider = StateNotifierProvider<AudioSettingsNotifier, AudioSettings>((ref) {
  return AudioSettingsNotifier();
});

class AudioSettingsNotifier extends BaseSettingsNotifier<AudioSettings> {
  AudioSettingsNotifier() : super(
    const AudioSettings(),
    storageKey: 'audioSettings',
    storage: SettingsStorage.hive,
  ) {
    _initializeAudioService();
  }

  final AudioService _audioService = AudioService();

  Future<void> _initializeAudioService() async {
    await _audioService.initialize();
    await _audioService.updateSettings(state);
  }

  @override
  AudioSettings getDefaultSettings() => const AudioSettings();

  @override
  Future<void> updateSettings(AudioSettings newSettings) async {
    await super.updateSettings(newSettings);
    await _audioService.updateSettings(newSettings);
  }

  Future<void> toggleEnabled() async {
    await updateSettings(state.copyWith(isEnabled: !state.isEnabled));
  }

  Future<void> setSpeechRate(double rate) async {
    await updateSettings(state.copyWith(speechRate: rate));
  }

  Future<void> setVolume(double volume) async {
    await updateSettings(state.copyWith(volume: volume));
  }

  Future<void> setPitch(double pitch) async {
    await updateSettings(state.copyWith(pitch: pitch));
  }

  Future<void> setPreferredVoice(String? voice) async {
    await updateSettings(state.copyWith(preferredVoice: voice));
  }

  Future<void> toggleAutoPlay() async {
    await updateSettings(state.copyWith(autoPlay: !state.autoPlay));
  }

  Future<void> toggleAutoReadQuestions() async {
    await updateSettings(state.copyWith(autoReadQuestions: !state.autoReadQuestions));
  }

  Future<void> toggleAutoReadAnswers() async {
    await updateSettings(state.copyWith(autoReadAnswers: !state.autoReadAnswers));
  }

  Future<void> setLanguage(String language) async {
    await updateSettings(state.copyWith(language: language));
  }
}

// Audio State Provider
final audioStateProvider = StateNotifierProvider<AudioStateNotifier, AudioState>((ref) {
  return AudioStateNotifier(ref.watch(audioSettingsProvider.notifier));
});

class AudioStateNotifier extends StateNotifier<AudioState> {
  AudioStateNotifier(this._settingsNotifier) : super(const AudioState()) {
    _initialize();
  }

  final AudioSettingsNotifier _settingsNotifier;
  final AudioService _audioService = AudioService();
  final EnhancedVoiceInputService _voiceService = EnhancedVoiceInputService();

  Future<void> _initialize() async {
    await _audioService.initialize();
    await _voiceService.initialize();

    // Listen to audio service state changes
    _audioService.stateStream.listen((audioState) {
      state = state.copyWith(
        playbackState: audioState.playbackState,
        currentText: audioState.currentText,
        progress: audioState.progress,
        errorMessage: audioState.errorMessage,
        isAvailable: audioState.isAvailable,
        availableVoices: audioState.availableVoices,
      );
    });

    // Listen to voice service state changes
    _voiceService.stateStream.listen((voiceState) {
      state = state.copyWith(
        voiceInputState: voiceState.voiceInputState,
        recognizedText: voiceState.recognizedText,
        confidence: voiceState.confidence,
        hasPermissions: voiceState.hasPermissions,
      );
    });
  }

  // Text-to-Speech methods
  Future<bool> speak(String text, {bool interrupt = false}) async {
    return await _audioService.speak(text, interrupt: interrupt);
  }

  Future<bool> speakQuestion(String questionText) async {
    return await _audioService.speakQuestion(questionText);
  }

  Future<bool> speakAnswer(String answerText) async {
    return await _audioService.speakAnswer(answerText);
  }

  Future<bool> speakTerm(String term, String definition, {String? example}) async {
    return await _audioService.speakTerm(term, definition, example: example);
  }

  Future<bool> speakConcept(String conceptText, {String? example}) async {
    return await _audioService.speakConcept(conceptText, example: example);
  }

  Future<bool> speakOptions(List<String> options) async {
    return await _audioService.speakOptions(options);
  }

  Future<void> pause() async {
    await _audioService.pause();
  }

  Future<void> resume() async {
    await _audioService.resume();
  }

  Future<void> stop() async {
    await _audioService.stop();
  }

  Future<void> setRate(double rate) async {
    await _audioService.setRate(rate);
    await _settingsNotifier.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
    await _settingsNotifier.setVolume(volume);
  }

  // Voice Input methods
  Future<bool> startListening({String? localeId, Duration? timeout}) async {
    return await _voiceService.startListening(
      localeId: localeId,
      listenFor: timeout,
    );
  }

  Future<void> stopListening() async {
    await _voiceService.stopListening();
  }

  Future<void> cancelListening() async {
    await _voiceService.cancel();
  }

  Future<VoiceCommand?> listenForCommand({Duration? timeout, String? localeId}) async {
    return await _voiceService.listenForCommand(
      timeout: timeout,
      localeId: localeId,
    );
  }

  VoiceCommand? parseLastCommand() {
    return _voiceService.parseLastCommand();
  }

  // Permission checking method
  Future<bool> checkMicrophonePermissions() async {
    return await _voiceService.checkPermissions();
  }

  // Request microphone permissions from the browser
  Future<bool> requestMicrophonePermissions() async {
    return await _voiceService.requestPermissions();
  }

  // Method to manually mark permissions as granted (when we know they are)
  void setMicrophonePermissionGranted(bool granted) {
    _voiceService.setPermissionGranted(granted);
  }

  // Utility methods
  bool get canSpeak => state.isAvailable && _settingsNotifier.state.isEnabled;
  bool get canListen => _voiceService.canListen; // Use the service's combined check
  
  // Expose voice service for orchestrator injection
  EnhancedVoiceInputService get voiceService => _voiceService;
  
  List<String> get availableVoices => state.availableVoices;
  List<String> get availableLocales => _voiceService.getAvailableLocales();
}

// Convenience providers for specific audio features
final canSpeakProvider = Provider<bool>((ref) {
  final settings = ref.watch(audioSettingsProvider);
  final state = ref.watch(audioStateProvider);
  return settings.isEnabled && state.isAvailable;
});

final canListenProvider = Provider<bool>((ref) {
  final state = ref.watch(audioStateProvider); // Watch the state, not just read notifier
  return state.isAvailable && state.hasPermissions;
});

final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.isPlaying;
});

final isListeningProvider = Provider<bool>((ref) {
  final state = ref.watch(audioStateProvider);
  return state.isListening;
});
