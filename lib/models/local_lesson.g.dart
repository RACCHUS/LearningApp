// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'local_lesson.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalLessonAdapter extends TypeAdapter<LocalLesson> {
  @override
  final int typeId = 1;

  @override
  LocalLesson read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalLesson(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      tags: (fields[3] as List).cast<String>(),
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
      userId: fields[7] as String,
      isLocal: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LocalLesson obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.tags)
      ..writeByte(4)
      ..write(obj.isLocal)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalLessonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
