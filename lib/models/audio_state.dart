enum AudioPlaybackState {
  idle,
  loading,
  playing,
  paused,
  stopped,
  error,
}

enum VoiceInputState {
  idle,
  listening,
  processing,
  completed,
  error,
}

class AudioState {
  final AudioPlaybackState playbackState;
  final VoiceInputState voiceInputState;
  final String? currentText;
  final double progress;
  final String? errorMessage;
  final bool isAvailable;
  final List<String> availableVoices;
  final String? recognizedText;
  final double confidence;

  const AudioState({
    this.playbackState = AudioPlaybackState.idle,
    this.voiceInputState = VoiceInputState.idle,
    this.currentText,
    this.progress = 0.0,
    this.errorMessage,
    this.isAvailable = true,
    this.availableVoices = const [],
    this.recognizedText,
    this.confidence = 0.0,
  });

  AudioState copyWith({
    AudioPlaybackState? playbackState,
    VoiceInputState? voiceInputState,
    String? currentText,
    double? progress,
    String? errorMessage,
    bool? isAvailable,
    List<String>? availableVoices,
    String? recognizedText,
    double? confidence,
  }) {
    return AudioState(
      playbackState: playbackState ?? this.playbackState,
      voiceInputState: voiceInputState ?? this.voiceInputState,
      currentText: currentText ?? this.currentText,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      isAvailable: isAvailable ?? this.isAvailable,
      availableVoices: availableVoices ?? this.availableVoices,
      recognizedText: recognizedText ?? this.recognizedText,
      confidence: confidence ?? this.confidence,
    );
  }

  bool get isPlaying => playbackState == AudioPlaybackState.playing;
  bool get isPaused => playbackState == AudioPlaybackState.paused;
  bool get isLoading => playbackState == AudioPlaybackState.loading;
  bool get hasError => playbackState == AudioPlaybackState.error || voiceInputState == VoiceInputState.error;
  bool get isListening => voiceInputState == VoiceInputState.listening;
  bool get isProcessingVoice => voiceInputState == VoiceInputState.processing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioState &&
          runtimeType == other.runtimeType &&
          playbackState == other.playbackState &&
          voiceInputState == other.voiceInputState &&
          currentText == other.currentText &&
          progress == other.progress &&
          errorMessage == other.errorMessage &&
          isAvailable == other.isAvailable &&
          availableVoices == other.availableVoices &&
          recognizedText == other.recognizedText &&
          confidence == other.confidence;

  @override
  int get hashCode =>
      playbackState.hashCode ^
      voiceInputState.hashCode ^
      currentText.hashCode ^
      progress.hashCode ^
      errorMessage.hashCode ^
      isAvailable.hashCode ^
      availableVoices.hashCode ^
      recognizedText.hashCode ^
      confidence.hashCode;
}
