// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'question_content.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestionContentAdapter extends TypeAdapter<QuestionContent> {
  @override
  final int typeId = 5;

  @override
  QuestionContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QuestionContent(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      order: fields[2] as int,
      questionText: fields[6] as String,
      options: (fields[7] as List).cast<String>(),
      correctAnswer: fields[8] as int,
      explanation: fields[9] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, QuestionContent obj) {
    writer
      ..writeByte(10)
      ..writeByte(6)
      ..write(obj.questionText)
      ..writeByte(7)
      ..write(obj.options)
      ..writeByte(8)
      ..write(obj.correctAnswer)
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
      other is QuestionContentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestionContent _$QuestionContentFromJson(Map<String, dynamic> json) =>
    QuestionContent(
      id: json['id'] as String,
      lessonId: json['lessonId'] as String,
      order: (json['order'] as num).toInt(),
      questionText: json['questionText'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctAnswer: (json['correctAnswer'] as num).toInt(),
      explanation: json['explanation'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$QuestionContentToJson(QuestionContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lessonId': instance.lessonId,
      'order': instance.order,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'questionText': instance.questionText,
      'options': instance.options,
      'correctAnswer': instance.correctAnswer,
      'explanation': instance.explanation,
    };
