// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'term_content.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TermContentAdapter extends TypeAdapter<TermContent> {
  @override
  final int typeId = 4;

  @override
  TermContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TermContent(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      order: fields[2] as int,
      term: fields[6] as String,
      definition: fields[7] as String,
      example: fields[8] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TermContent obj) {
    writer
      ..writeByte(9)
      ..writeByte(6)
      ..write(obj.term)
      ..writeByte(7)
      ..write(obj.definition)
      ..writeByte(8)
      ..write(obj.example)
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
      other is TermContentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TermContent _$TermContentFromJson(Map<String, dynamic> json) => TermContent(
      id: json['id'] as String,
      lessonId: json['lessonId'] as String,
      order: (json['order'] as num).toInt(),
      term: json['term'] as String,
      definition: json['definition'] as String,
      example: json['example'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$TermContentToJson(TermContent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lessonId': instance.lessonId,
      'order': instance.order,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'term': instance.term,
      'definition': instance.definition,
      'example': instance.example,
    };
