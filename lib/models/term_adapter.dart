import 'package:hive/hive.dart';
import 'package:learning_pwa/models/term_content.dart';

class TermAdapter extends TypeAdapter<TermContent> {
  @override
  final int typeId = 4;

  @override
  TermContent read(BinaryReader reader) {
    final id = reader.readString();
    final lessonId = reader.readString();
    final order = reader.readInt();
    final term = reader.readString();
    final definition = reader.readString();
    final example = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return TermContent(
      id: id,
      lessonId: lessonId,
      order: order,
      term: term,
      definition: definition,
      example: example.isEmpty ? null : example,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, TermContent obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.lessonId);
    writer.writeInt(obj.order);
    writer.writeString(obj.term);
    writer.writeString(obj.definition);
    writer.writeString(obj.example ?? '');
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
