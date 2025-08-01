import 'package:hive/hive.dart';
import 'package:learning_pwa/models/mcq.dart';

class McqAdapter extends TypeAdapter<Mcq> {
  @override
  final int typeId = 4;

  @override
  Mcq read(BinaryReader reader) {
    final id = reader.readString();
    final lessonId = reader.readString();
    final order = reader.readInt();
    final question = reader.readString();
    final options = reader.readStringList();
    final correctOption = reader.readInt();
    final explanation = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return Mcq(
      id: id,
      lessonId: lessonId,
      order: order,
      question: question,
      options: options,
      correctOption: correctOption,
      explanation: explanation,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, Mcq obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.lessonId);
    writer.writeInt(obj.order);
    writer.writeString(obj.question);
    writer.writeStringList(obj.options);
    writer.writeInt(obj.correctOption);
    writer.writeString(obj.explanation ?? '');
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
