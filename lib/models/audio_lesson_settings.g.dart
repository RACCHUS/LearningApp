// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'audio_lesson_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioLessonSettingsAdapter extends TypeAdapter<AudioLessonSettings> {
  @override
  final int typeId = 21;

  @override
  AudioLessonSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioLessonSettings(
      handsFreeModeEnabled: fields[0] as bool,
      autoProgressDelay: fields[1] as Duration,
      voiceInputTimeout: fields[2] as Duration,
      autoReadAllContent: fields[3] as bool,
      voiceNavigationEnabled: fields[4] as bool,
      confirmationsEnabled: fields[5] as bool,
      pauseBetweenItems: fields[6] as double,
      autoProgressAfterReading: fields[7] as bool,
      immediateAnswerProgression: fields[8] as bool,
      voiceRetryAttempts: fields[9] as int,
      interruptOnNextCommand: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AudioLessonSettings obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.handsFreeModeEnabled)
      ..writeByte(1)
      ..write(obj.autoProgressDelay)
      ..writeByte(2)
      ..write(obj.voiceInputTimeout)
      ..writeByte(3)
      ..write(obj.autoReadAllContent)
      ..writeByte(4)
      ..write(obj.voiceNavigationEnabled)
      ..writeByte(5)
      ..write(obj.confirmationsEnabled)
      ..writeByte(6)
      ..write(obj.pauseBetweenItems)
      ..writeByte(7)
      ..write(obj.autoProgressAfterReading)
      ..writeByte(8)
      ..write(obj.immediateAnswerProgression)
      ..writeByte(9)
      ..write(obj.voiceRetryAttempts)
      ..writeByte(10)
      ..write(obj.interruptOnNextCommand);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioLessonSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioLessonSettings _$AudioLessonSettingsFromJson(Map<String, dynamic> json) =>
    AudioLessonSettings(
      handsFreeModeEnabled: json['handsFreeModeEnabled'] as bool? ?? false,
      autoProgressDelay: json['autoProgressDelay'] == null
          ? const Duration(seconds: 3)
          : Duration(microseconds: (json['autoProgressDelay'] as num).toInt()),
      voiceInputTimeout: json['voiceInputTimeout'] == null
          ? const Duration(seconds: 5)
          : Duration(microseconds: (json['voiceInputTimeout'] as num).toInt()),
      autoReadAllContent: json['autoReadAllContent'] as bool? ?? true,
      voiceNavigationEnabled: json['voiceNavigationEnabled'] as bool? ?? true,
      confirmationsEnabled: json['confirmationsEnabled'] as bool? ?? true,
      pauseBetweenItems: (json['pauseBetweenItems'] as num?)?.toDouble() ?? 1.0,
      autoProgressAfterReading:
          json['autoProgressAfterReading'] as bool? ?? false,
      immediateAnswerProgression:
          json['immediateAnswerProgression'] as bool? ?? true,
      voiceRetryAttempts: (json['voiceRetryAttempts'] as num?)?.toInt() ?? 3,
      interruptOnNextCommand: json['interruptOnNextCommand'] as bool? ?? true,
    );

Map<String, dynamic> _$AudioLessonSettingsToJson(
        AudioLessonSettings instance) =>
    <String, dynamic>{
      'handsFreeModeEnabled': instance.handsFreeModeEnabled,
      'autoProgressDelay': instance.autoProgressDelay.inMicroseconds,
      'voiceInputTimeout': instance.voiceInputTimeout.inMicroseconds,
      'autoReadAllContent': instance.autoReadAllContent,
      'voiceNavigationEnabled': instance.voiceNavigationEnabled,
      'confirmationsEnabled': instance.confirmationsEnabled,
      'pauseBetweenItems': instance.pauseBetweenItems,
      'autoProgressAfterReading': instance.autoProgressAfterReading,
      'immediateAnswerProgression': instance.immediateAnswerProgression,
      'voiceRetryAttempts': instance.voiceRetryAttempts,
      'interruptOnNextCommand': instance.interruptOnNextCommand,
    };
