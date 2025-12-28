import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'audio_lesson_settings.g.dart';

@HiveType(typeId: 21)
@JsonSerializable()
class AudioLessonSettings {
  @HiveField(0)
  final bool handsFreeModeEnabled;

  @HiveField(1)
  final Duration autoProgressDelay;

  @HiveField(2)
  final Duration voiceInputTimeout;

  @HiveField(3)
  final bool autoReadAllContent;

  @HiveField(4)
  final bool voiceNavigationEnabled;

  @HiveField(5)
  final bool confirmationsEnabled;

  @HiveField(6)
  final double pauseBetweenItems;

  @HiveField(7)
  final bool autoProgressAfterReading;

  @HiveField(8)
  final bool immediateAnswerProgression;

  @HiveField(9)
  final int voiceRetryAttempts;

  @HiveField(10)
  final bool interruptOnNextCommand;

  /// Voice recognition locale (e.g., 'en_US', 'en_GB', 'es_ES', 'fr_FR')
  /// Used by speech recognition providers to determine language model
  @HiveField(11)
  final String voiceLocale;

  const AudioLessonSettings({
    this.handsFreeModeEnabled = false,
    this.autoProgressDelay = const Duration(seconds: 3),
    this.voiceInputTimeout = const Duration(seconds: 5),
    this.autoReadAllContent = true,
    this.voiceNavigationEnabled = true,
    this.confirmationsEnabled = true,
    this.pauseBetweenItems = 1.0, // seconds
    this.autoProgressAfterReading = false, // Wait for "next" by default
    this.immediateAnswerProgression = true,
    this.voiceRetryAttempts = 3,
    this.interruptOnNextCommand = true,
    this.voiceLocale = 'en_US',
  });

  factory AudioLessonSettings.fromJson(Map<String, dynamic> json) => 
    _$AudioLessonSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$AudioLessonSettingsToJson(this);

  AudioLessonSettings copyWith({
    bool? handsFreeModeEnabled,
    Duration? autoProgressDelay,
    Duration? voiceInputTimeout,
    bool? autoReadAllContent,
    bool? voiceNavigationEnabled,
    bool? confirmationsEnabled,
    double? pauseBetweenItems,
    bool? autoProgressAfterReading,
    bool? immediateAnswerProgression,
    int? voiceRetryAttempts,
    bool? interruptOnNextCommand,
    String? voiceLocale,
  }) {
    return AudioLessonSettings(
      handsFreeModeEnabled: handsFreeModeEnabled ?? this.handsFreeModeEnabled,
      autoProgressDelay: autoProgressDelay ?? this.autoProgressDelay,
      voiceInputTimeout: voiceInputTimeout ?? this.voiceInputTimeout,
      autoReadAllContent: autoReadAllContent ?? this.autoReadAllContent,
      voiceNavigationEnabled: voiceNavigationEnabled ?? this.voiceNavigationEnabled,
      confirmationsEnabled: confirmationsEnabled ?? this.confirmationsEnabled,
      pauseBetweenItems: pauseBetweenItems ?? this.pauseBetweenItems,
      autoProgressAfterReading: autoProgressAfterReading ?? this.autoProgressAfterReading,
      immediateAnswerProgression: immediateAnswerProgression ?? this.immediateAnswerProgression,
      voiceRetryAttempts: voiceRetryAttempts ?? this.voiceRetryAttempts,
      interruptOnNextCommand: interruptOnNextCommand ?? this.interruptOnNextCommand,
      voiceLocale: voiceLocale ?? this.voiceLocale,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioLessonSettings &&
          runtimeType == other.runtimeType &&
          handsFreeModeEnabled == other.handsFreeModeEnabled &&
          autoProgressDelay == other.autoProgressDelay &&
          voiceInputTimeout == other.voiceInputTimeout &&
          autoReadAllContent == other.autoReadAllContent &&
          voiceNavigationEnabled == other.voiceNavigationEnabled &&
          confirmationsEnabled == other.confirmationsEnabled &&
          pauseBetweenItems == other.pauseBetweenItems &&
          autoProgressAfterReading == other.autoProgressAfterReading &&
          immediateAnswerProgression == other.immediateAnswerProgression &&
          voiceRetryAttempts == other.voiceRetryAttempts &&
          interruptOnNextCommand == other.interruptOnNextCommand &&
          voiceLocale == other.voiceLocale;

  @override
  int get hashCode =>
      handsFreeModeEnabled.hashCode ^
      autoProgressDelay.hashCode ^
      voiceInputTimeout.hashCode ^
      autoReadAllContent.hashCode ^
      voiceNavigationEnabled.hashCode ^
      confirmationsEnabled.hashCode ^
      pauseBetweenItems.hashCode ^
      autoProgressAfterReading.hashCode ^
      immediateAnswerProgression.hashCode ^
      voiceRetryAttempts.hashCode ^
      interruptOnNextCommand.hashCode ^
      voiceLocale.hashCode;
}
