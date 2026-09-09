// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'concept_content.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConceptContentAdapter extends TypeAdapter<ConceptContent> {
  @override
  final int typeId = 6;

  @override
  ConceptContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConceptContent(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      order: fields[2] as int,
      conceptText: fields[6] as String,
      exampleText: fields[7] as String?,
      keyPoints: (fields[8] as List?)?.cast<String>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ConceptContent obj) {
    writer
      ..writeByte(9)
      ..writeByte(6)
      ..write(obj.conceptText)
      ..writeByte(7)
      ..write(obj.exampleText)
      ..writeByte(8)
      ..write(obj.keyPoints)
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
      other is ConceptContentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConceptContent _$ConceptContentFromJson(Map<String, dynamic> json) =>
    ConceptContent(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      order: (json['order'] as num).toInt(),
      conceptText: json['conceptText'] as String,
      exampleText: json['exampleText'] as String?,
      keyPoints: (json['keyPoints'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ConceptContentToJson(ConceptContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lesson_id': instance.lessonId,
      'order': instance.order,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'conceptText': instance.conceptText,
      'exampleText': instance.exampleText,
      'keyPoints': instance.keyPoints,
    };
