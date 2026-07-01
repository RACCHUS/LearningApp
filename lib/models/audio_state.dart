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

/// Structured voice info from the TTS engine (name + locale).
class VoiceInfo {
  final String name;
  final String locale;

  const VoiceInfo({required this.name, required this.locale});

  /// Friendly display label: strips engine prefixes, appends locale hint.
  String get displayName {
    // Strip common prefixes for cleaner display
    var label = name
        .replaceAll(RegExp(r'^Google\s+'), '')
        .replaceAll(RegExp(r'^Microsoft\s+'), '')
        .replaceAll(RegExp(r'^Apple\s+'), '');
    if (label == name) return '$name ($locale)';
    return '$label ($locale)';
  }

  /// True if this voice matches the given language prefix (e.g. "en" matches "en-US").
  bool matchesLanguage(String language) {
    final prefix = language.split('-').first.toLowerCase();
    return locale.toLowerCase().startsWith(prefix);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceInfo && name == other.name && locale == other.locale;

  @override
  int get hashCode => name.hashCode ^ locale.hashCode;
}

class AudioState {
  final AudioPlaybackState playbackState;
  final VoiceInputState voiceInputState;
  final String? currentText;
  final double progress;
  final String? errorMessage;
  final bool isAvailable;
  final bool hasPermissions; // Add permission state
  final List<String> availableVoices;
  final List<VoiceInfo> availableVoiceInfos;
  final String? recognizedText;
  final double confidence;

  const AudioState({
    this.playbackState = AudioPlaybackState.idle,
    this.voiceInputState = VoiceInputState.idle,
    this.currentText,
    this.progress = 0.0,
    this.errorMessage,
    this.isAvailable = true,
    this.hasPermissions = false, // Default to false
    this.availableVoices = const [],
    this.availableVoiceInfos = const [],
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
    bool? hasPermissions,
    List<String>? availableVoices,
    List<VoiceInfo>? availableVoiceInfos,
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
      hasPermissions: hasPermissions ?? this.hasPermissions,
      availableVoices: availableVoices ?? this.availableVoices,
      availableVoiceInfos: availableVoiceInfos ?? this.availableVoiceInfos,
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
          hasPermissions == other.hasPermissions &&
          availableVoices == other.availableVoices &&
          availableVoiceInfos == other.availableVoiceInfos &&
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
      hasPermissions.hashCode ^
      availableVoices.hashCode ^
      availableVoiceInfos.hashCode ^
      recognizedText.hashCode ^
      confidence.hashCode;
}
