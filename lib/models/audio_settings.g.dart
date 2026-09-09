// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'audio_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioSettingsAdapter extends TypeAdapter<AudioSettings> {
  @override
  final int typeId = 20;

  @override
  AudioSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioSettings(
      isEnabled: fields[0] as bool,
      speechRate: fields[1] as double,
      volume: fields[2] as double,
      pitch: fields[3] as double,
      preferredVoice: fields[4] as String?,
      autoPlay: fields[5] as bool,
      autoReadQuestions: fields[6] as bool,
      autoReadAnswers: fields[7] as bool,
      language: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AudioSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.isEnabled)
      ..writeByte(1)
      ..write(obj.speechRate)
      ..writeByte(2)
      ..write(obj.volume)
      ..writeByte(3)
      ..write(obj.pitch)
      ..writeByte(4)
      ..write(obj.preferredVoice)
      ..writeByte(5)
      ..write(obj.autoPlay)
      ..writeByte(6)
      ..write(obj.autoReadQuestions)
      ..writeByte(7)
      ..write(obj.autoReadAnswers)
      ..writeByte(8)
      ..write(obj.language);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioSettings _$AudioSettingsFromJson(Map<String, dynamic> json) =>
    AudioSettings(
      isEnabled: json['isEnabled'] as bool? ?? true,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 1.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      preferredVoice: json['preferredVoice'] as String?,
      autoPlay: json['autoPlay'] as bool? ?? false,
      autoReadQuestions: json['autoReadQuestions'] as bool? ?? false,
      autoReadAnswers: json['autoReadAnswers'] as bool? ?? false,
      language: json['language'] as String? ?? 'en-US',
    );

Map<String, dynamic> _$AudioSettingsToJson(AudioSettings instance) =>
    <String, dynamic>{
      'isEnabled': instance.isEnabled,
      'speechRate': instance.speechRate,
      'volume': instance.volume,
      'pitch': instance.pitch,
      'preferredVoice': instance.preferredVoice,
      'autoPlay': instance.autoPlay,
      'autoReadQuestions': instance.autoReadQuestions,
      'autoReadAnswers': instance.autoReadAnswers,
      'language': instance.language,
    };
