import 'package:hive/hive.dart';
import 'package:learning_pwa/models/question_content.dart';

class QuestionContentAdapter extends TypeAdapter<QuestionContent> {
  @override
  final int typeId = 5;

  @override
  QuestionContent read(BinaryReader reader) {
    final id = reader.readString();
    final lessonId = reader.readString();
    final order = reader.readInt();
    final questionText = reader.readString();
    final options = reader.readStringList();
    final correctAnswer = reader.readInt();
    final explanation = reader.readString();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());

    return QuestionContent(
      id: id,
      lessonId: lessonId,
      order: order,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation.isEmpty ? null : explanation,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  void write(BinaryWriter writer, QuestionContent obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.lessonId);
    writer.writeInt(obj.order);
    writer.writeString(obj.questionText);
    writer.writeStringList(obj.options);
    writer.writeInt(obj.correctAnswer);
    writer.writeString(obj.explanation ?? '');
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}
