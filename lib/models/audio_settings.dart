import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'audio_settings.g.dart';

@HiveType(typeId: 20)
@JsonSerializable()
class AudioSettings {
  @HiveField(0)
  final bool isEnabled;

  @HiveField(1)
  final double speechRate;

  @HiveField(2)
  final double volume;

  @HiveField(3)
  final double pitch;

  @HiveField(4)
  final String? preferredVoice;

  @HiveField(5)
  final bool autoPlay;

  @HiveField(6)
  final bool autoReadQuestions;

  @HiveField(7)
  final bool autoReadAnswers;

  @HiveField(8)
  final String language;

  const AudioSettings({
    this.isEnabled = true,
    this.speechRate = 1.0,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.preferredVoice,
    this.autoPlay = false, // Changed to false by default
    this.autoReadQuestions = false, // Changed to false by default
    this.autoReadAnswers = false, // Changed to false by default
    this.language = 'en-US',
  });

  factory AudioSettings.fromJson(Map<String, dynamic> json) => 
    _$AudioSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AudioSettingsToJson(this);

  AudioSettings copyWith({
    bool? isEnabled,
    double? speechRate,
    double? volume,
    double? pitch,
    String? preferredVoice,
    bool? autoPlay,
    bool? autoReadQuestions,
    bool? autoReadAnswers,
    String? language,
  }) {
    return AudioSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      preferredVoice: preferredVoice ?? this.preferredVoice,
      autoPlay: autoPlay ?? this.autoPlay,
      autoReadQuestions: autoReadQuestions ?? this.autoReadQuestions,
      autoReadAnswers: autoReadAnswers ?? this.autoReadAnswers,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSettings &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          speechRate == other.speechRate &&
          volume == other.volume &&
          pitch == other.pitch &&
          preferredVoice == other.preferredVoice &&
          autoPlay == other.autoPlay &&
          autoReadQuestions == other.autoReadQuestions &&
          autoReadAnswers == other.autoReadAnswers &&
          language == other.language;

  @override
  int get hashCode =>
      isEnabled.hashCode ^
      speechRate.hashCode ^
      volume.hashCode ^
      pitch.hashCode ^
      preferredVoice.hashCode ^
      autoPlay.hashCode ^
      autoReadQuestions.hashCode ^
      autoReadAnswers.hashCode ^
      language.hashCode;
}
