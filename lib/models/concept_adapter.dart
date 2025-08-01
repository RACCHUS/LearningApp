import 'package:hive/hive.dart';
import 'package:learning_pwa/models/concept.dart';

class ConceptAdapter extends TypeAdapter<Concept> {
  @override
  final int typeId = 3;

  @override
  Concept read(BinaryReader reader) {
    final id = reader.readString();
    final lessonId = reader.readString();
    final conceptText = reader.readString();
    final exampleText = reader.readString();
    final createdBy = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return Concept(
      id: id,
      lessonId: lessonId,
      conceptText: conceptText,
      exampleText: exampleText,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }

  @override
  void write(BinaryWriter writer, Concept obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.lessonId);
    writer.writeString(obj.conceptText);
    writer.writeString(obj.exampleText ?? '');
    writer.writeString(obj.createdBy);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
