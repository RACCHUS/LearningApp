import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/audio_state.dart';
import 'package:learning_pwa/services/audio_service.dart';
import 'package:learning_pwa/services/voice_input_service.dart';
import 'package:learning_pwa/models/voice_command.dart';

// Audio Playback Provider - manages TTS playback and voice recognition state
final audioPlaybackProvider = StateNotifierProvider<AudioPlaybackNotifier, AudioState>((ref) {
  return AudioPlaybackNotifier();
});

class AudioPlaybackNotifier extends StateNotifier<AudioState> {
  AudioPlaybackNotifier() : super(const AudioState()) {
    _initialize();
  }

  final AudioService _audioService = AudioService();
  final VoiceInputService _voiceService = VoiceInputService();

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

    // Update initial state with voice service capabilities
    state = state.copyWith(
      isAvailable: _voiceService.isAvailable,
      hasPermissions: _voiceService.hasPermissions,
    );
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
  }

  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
  }

  // Enhanced Voice Recognition methods
  Future<bool> checkMicrophonePermissions() async {
    final hasPerms = await _voiceService.checkPermissions();
    state = state.copyWith(hasPermissions: hasPerms);
    return hasPerms;
  }

  Future<bool> requestMicrophonePermissions() async {
    final granted = await _voiceService.requestPermissions();
    state = state.copyWith(hasPermissions: granted);
    return granted;
  }

  Future<bool> startListening({Duration? timeout}) async {
    return await _voiceService.startListening(
      listenFor: timeout ?? const Duration(seconds: 5),
    );
  }

  Future<void> stopListening() async {
    await _voiceService.stopListening();
  }

  Future<void> cancelListening() async {
    await _voiceService.cancel();
  }

  Future<VoiceCommand?> listenForCommand({Duration? timeout}) async {
    return await _voiceService.listenForCommand(timeout: timeout);
  }

  VoiceCommand? parseLastCommand() {
    return _voiceService.parseLastCommand();
  }

  // Manual input support for fallback mode
  void submitManualInput(String input) {
    _voiceService.submitManualInput(input);
  }

  Future<String?> waitForManualInput() async {
    return await _voiceService.waitForManualInput();
  }

  // Provider information and capabilities
  bool get isManualInputMode => _voiceService.isManualInputMode;
  
  Map<String, dynamic> get voiceCapabilities => _voiceService.capabilities;
  
  List<String> getSetupInstructions() => _voiceService.getSetupInstructions();
  
  Map<String, String> getCommandMappings() => _voiceService.getCommandMappings();
  
  List<String> get voiceStatusLog => _voiceService.statusLog;

  // State getters for UI
  bool get isListening => state.isListening;
  bool get canSpeak => state.isAvailable;
  bool get canListen => _voiceService.canListen;
  String? get lastRecognizedText => state.recognizedText;
  double get recognitionConfidence => state.confidence;
  
  // Service access for global voice service
  VoiceInputService get voiceService => _voiceService;

  // Manual state setters for testing
  void setMicrophonePermissionGranted(bool granted) {
    _voiceService.setPermissionGranted(granted);
    state = state.copyWith(hasPermissions: granted);
  }

  void setRecognizedTextForTesting(String text) {
    _voiceService.setRecognizedTextForTesting(text);
  }

  // Fallback management
  Future<bool> fallbackToNextProvider() async {
    final success = await _voiceService.fallbackToNextProvider();
    if (success) {
      // Update state with new provider info
      state = state.copyWith(
        isAvailable: _voiceService.isAvailable,
        hasPermissions: _voiceService.hasPermissions,
      );
    }
    return success;
  }

  // Dispose resources
  @override
  void dispose() {
    _voiceService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
