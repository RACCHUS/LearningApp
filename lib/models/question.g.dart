// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lint:always_declare_return_types, lint:avoid_relative_lib_imports, lint:avoid_renaming_method_parameters, lint:lines_longer_than_80_chars, public_member_api_docs

part of 'question.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class QuestionAdapter extends TypeAdapter<Question> {
  @override
  final int typeId = 3;

  @override
  Question read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Question(
      id: fields[0] as String,
      questionText: fields[1] as String,
      options: (fields[2] as List).cast<String>(),
      correctAnswer: fields[3] as int,
      type: fields[4] as String,
      explanation: fields[5] as String?,
      createdBy: fields[6] as String,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Question obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.questionText)
      ..writeByte(2)
      ..write(obj.options)
      ..writeByte(3)
      ..write(obj.correctAnswer)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.explanation)
      ..writeByte(6)
      ..write(obj.createdBy)
      ..writeByte(7)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
