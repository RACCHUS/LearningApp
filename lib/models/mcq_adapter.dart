import 'package:hive/hive.dart';
import 'mcq.dart';

class McqAdapter extends TypeAdapter<Mcq> {
  @override
  final int typeId = 3; // Must match the typeId in the model

  @override
  Mcq read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return Mcq(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      question: fields[2] as String,
      options: (fields[3] as List).cast<String>(),
      correctOptionIndex: fields[4] as int,
      explanation: fields[5] as String?,
      createdBy: fields[6] as String,
      createdAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Mcq obj) {
    writer
      ..writeByte(8) // Number of fields
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.lessonId)
      ..writeByte(2)..write(obj.question)
      ..writeByte(3)..write(obj.options)
      ..writeByte(4)..write(obj.correctOptionIndex)
      ..writeByte(5)..write(obj.explanation)
      ..writeByte(6)..write(obj.createdBy)
      ..writeByte(7)..write(obj.createdAt);
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
