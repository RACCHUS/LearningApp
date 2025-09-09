/// Settings for hands-free voice navigation functionality
class HandsFreeSettings {
  final bool defaultHandsFreeMode;        // Auto-enable on app start
  final bool globalVoiceCommands;         // Listen for commands anywhere
  final bool autoLessonHandsFree;         // Auto hands-free for lessons
  final Duration voiceTimeout;            // Command timeout
  final double confidenceThreshold;       // Minimum confidence level
  final bool autoRequestPermissions;      // Auto-request mic permissions
  final bool showVoiceIndicator;          // Show voice status indicator
  final bool announceCommands;            // Audio feedback for commands
  final bool enableWakeWord;              // Wake word activation
  final String wakeWord;                  // Custom wake word
  final bool persistAcrossSessions;       // Remember hands-free state

  const HandsFreeSettings({
    this.defaultHandsFreeMode = false,
    this.globalVoiceCommands = true,
    this.autoLessonHandsFree = true,
    this.voiceTimeout = const Duration(seconds: 5),
    this.confidenceThreshold = 0.7,
    this.autoRequestPermissions = true,
    this.showVoiceIndicator = true,
    this.announceCommands = false,
    this.enableWakeWord = false,
    this.wakeWord = 'hey learning',
    this.persistAcrossSessions = true,
  });

  HandsFreeSettings copyWith({
    bool? defaultHandsFreeMode,
    bool? globalVoiceCommands,
    bool? autoLessonHandsFree,
    Duration? voiceTimeout,
    double? confidenceThreshold,
    bool? autoRequestPermissions,
    bool? showVoiceIndicator,
    bool? announceCommands,
    bool? enableWakeWord,
    String? wakeWord,
    bool? persistAcrossSessions,
  }) {
    return HandsFreeSettings(
      defaultHandsFreeMode: defaultHandsFreeMode ?? this.defaultHandsFreeMode,
      globalVoiceCommands: globalVoiceCommands ?? this.globalVoiceCommands,
      autoLessonHandsFree: autoLessonHandsFree ?? this.autoLessonHandsFree,
      voiceTimeout: voiceTimeout ?? this.voiceTimeout,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      autoRequestPermissions: autoRequestPermissions ?? this.autoRequestPermissions,
      showVoiceIndicator: showVoiceIndicator ?? this.showVoiceIndicator,
      announceCommands: announceCommands ?? this.announceCommands,
      enableWakeWord: enableWakeWord ?? this.enableWakeWord,
      wakeWord: wakeWord ?? this.wakeWord,
      persistAcrossSessions: persistAcrossSessions ?? this.persistAcrossSessions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultHandsFreeMode': defaultHandsFreeMode,
      'globalVoiceCommands': globalVoiceCommands,
      'autoLessonHandsFree': autoLessonHandsFree,
      'voiceTimeoutMs': voiceTimeout.inMilliseconds,
      'confidenceThreshold': confidenceThreshold,
      'autoRequestPermissions': autoRequestPermissions,
      'showVoiceIndicator': showVoiceIndicator,
      'announceCommands': announceCommands,
      'enableWakeWord': enableWakeWord,
      'wakeWord': wakeWord,
      'persistAcrossSessions': persistAcrossSessions,
    };
  }

  factory HandsFreeSettings.fromJson(Map<String, dynamic> json) {
    return HandsFreeSettings(
      defaultHandsFreeMode: json['defaultHandsFreeMode'] ?? false,
      globalVoiceCommands: json['globalVoiceCommands'] ?? true,
      autoLessonHandsFree: json['autoLessonHandsFree'] ?? true,
      voiceTimeout: Duration(milliseconds: json['voiceTimeoutMs'] ?? 5000),
      confidenceThreshold: (json['confidenceThreshold'] ?? 0.7).toDouble(),
      autoRequestPermissions: json['autoRequestPermissions'] ?? true,
      showVoiceIndicator: json['showVoiceIndicator'] ?? true,
      announceCommands: json['announceCommands'] ?? false,
      enableWakeWord: json['enableWakeWord'] ?? false,
      wakeWord: json['wakeWord'] ?? 'hey learning',
      persistAcrossSessions: json['persistAcrossSessions'] ?? true,
    );
  }

  @override
  String toString() {
    return 'HandsFreeSettings('
           'defaultHandsFreeMode: $defaultHandsFreeMode, '
           'globalVoiceCommands: $globalVoiceCommands, '
           'autoLessonHandsFree: $autoLessonHandsFree, '
           'voiceTimeout: $voiceTimeout, '
           'confidenceThreshold: $confidenceThreshold)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandsFreeSettings &&
          runtimeType == other.runtimeType &&
          defaultHandsFreeMode == other.defaultHandsFreeMode &&
          globalVoiceCommands == other.globalVoiceCommands &&
          autoLessonHandsFree == other.autoLessonHandsFree &&
          voiceTimeout == other.voiceTimeout &&
          confidenceThreshold == other.confidenceThreshold &&
          autoRequestPermissions == other.autoRequestPermissions &&
          showVoiceIndicator == other.showVoiceIndicator &&
          announceCommands == other.announceCommands &&
          enableWakeWord == other.enableWakeWord &&
          wakeWord == other.wakeWord &&
          persistAcrossSessions == other.persistAcrossSessions;

  @override
  int get hashCode =>
      defaultHandsFreeMode.hashCode ^
      globalVoiceCommands.hashCode ^
      autoLessonHandsFree.hashCode ^
      voiceTimeout.hashCode ^
      confidenceThreshold.hashCode ^
      autoRequestPermissions.hashCode ^
      showVoiceIndicator.hashCode ^
      announceCommands.hashCode ^
      enableWakeWord.hashCode ^
      wakeWord.hashCode ^
      persistAcrossSessions.hashCode;
}
