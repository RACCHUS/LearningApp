import 'package:hive/hive.dart';
import 'concept.dart';

class ConceptAdapter extends TypeAdapter<Concept> {
  @override
  final int typeId = 2; // Must match the typeId in the model

  @override
  Concept read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    return Concept(
      id: fields[0] as String,
      lessonId: fields[1] as String,
      conceptText: fields[2] as String,
      exampleText: fields[3] as String?,
      createdBy: fields[4] as String,
      createdAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Concept obj) {
    writer
      ..writeByte(6) // Number of fields
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.lessonId)
      ..writeByte(2)..write(obj.conceptText)
      ..writeByte(3)..write(obj.exampleText)
      ..writeByte(4)..write(obj.createdBy)
      ..writeByte(5)..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConceptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
