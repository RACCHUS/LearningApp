// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'mcq.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class McqAdapter extends TypeAdapter<Mcq> {
  @override
  final int typeId = 4;

  @override
  Mcq read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Mcq(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      order: fields[2] as int,
      question: fields[6] as String,
      options: (fields[7] as List).cast<String>(),
      correctOption: fields[8] as int,
      explanation: fields[9] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Mcq obj) {
    writer
      ..writeByte(10)
      ..writeByte(6)
      ..write(obj.question)
      ..writeByte(7)
      ..write(obj.options)
      ..writeByte(8)
      ..write(obj.correctOption)
      ..writeByte(9)
      ..write(obj.explanation)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lessonId)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McqAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Mcq _$McqFromJson(Map<String, dynamic> json) => Mcq(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      order: (json['order'] as num).toInt(),
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctOption: (json['correct_option_index'] as num).toInt(),
      explanation: json['explanation'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$McqToJson(Mcq instance) => <String, dynamic>{
      'id': instance.id,
      'lesson_id': instance.lessonId,
      'order': instance.order,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'question': instance.question,
      'options': instance.options,
      'correct_option_index': instance.correctOption,
      'explanation': instance.explanation,
    };
