/// Models for Pre-Reader and Foundational Literacy support.
enum PreReaderTrack {
  /// Tailored for adult learners: dignified, practical life anchors
  /// (work tools, grocery, currency, medicine, workplace safety signs, bus routes).
  adult,

  /// Tailored for youth and children: playful cartoon anchors
  /// (animals, space, nature, cheerful celebratory feedback).
  youth,
}

class PreReaderProfile {
  final bool enabled;
  final PreReaderTrack track;
  final bool autoSpeakScreens;
  final double speechRate;

  const PreReaderProfile({
    this.enabled = false,
    this.track = PreReaderTrack.adult,
    this.autoSpeakScreens = true,
    this.speechRate = 0.85,
  });

  PreReaderProfile copyWith({
    bool? enabled,
    PreReaderTrack? track,
    bool? autoSpeakScreens,
    double? speechRate,
  }) {
    return PreReaderProfile(
      enabled: enabled ?? this.enabled,
      track: track ?? this.track,
      autoSpeakScreens: autoSpeakScreens ?? this.autoSpeakScreens,
      speechRate: speechRate ?? this.speechRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'track': track.name,
    'autoSpeakScreens': autoSpeakScreens,
    'speechRate': speechRate,
  };

  factory PreReaderProfile.fromJson(Map<String, dynamic> json) {
    return PreReaderProfile(
      enabled: json['enabled'] as bool? ?? false,
      track: (json['track'] as String?) == 'youth'
          ? PreReaderTrack.youth
          : PreReaderTrack.adult,
      autoSpeakScreens: json['autoSpeakScreens'] as bool? ?? true,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.85,
    );
  }
}
