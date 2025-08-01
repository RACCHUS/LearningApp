import 'package:hive/hive.dart';
import 'package:learning_pwa/models/concept_content.dart';

class ConceptContentAdapter extends TypeAdapter<ConceptContent> {
  @override
  final int typeId = 6;

  @override
  ConceptContent read(BinaryReader reader) {
    final id = reader.readString();
    final lessonId = reader.readString();
    final order = reader.readInt();
    final conceptText = reader.readString();
    final exampleText = reader.readString();
    final keyPointsLength = reader.readInt();
    final keyPoints = keyPointsLength > 0 
        ? List.generate(keyPointsLength, (_) => reader.readString())
        : null;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return ConceptContent(
      id: id,
      lessonId: lessonId,
      order: order,
      conceptText: conceptText,
      exampleText: exampleText.isEmpty ? null : exampleText,
      keyPoints: keyPoints,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, ConceptContent obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.lessonId);
    writer.writeInt(obj.order);
    writer.writeString(obj.conceptText);
    writer.writeString(obj.exampleText ?? '');
    writer.writeInt(obj.keyPoints?.length ?? 0);
    if (obj.keyPoints != null) {
      for (final point in obj.keyPoints!) {
        writer.writeString(point);
      }
    }
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
