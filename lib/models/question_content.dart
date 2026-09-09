import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:learning_pwa/models/lesson_content.dart';

part 'question_content.g.dart';

@HiveType(typeId: 5)
@JsonSerializable()
class QuestionContent extends LessonContent {
  @HiveField(6)
  final String questionText;

  @HiveField(7)
  final List<String> options;

  @HiveField(8)
  final int correctAnswer;

  @HiveField(9)
  final String? explanation;

  QuestionContent({
    required String id,
    required String lessonId,
    required int order,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
          id: id,
          lessonId: lessonId,
          order: order,
          type: 'question',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  factory QuestionContent.fromJson(Map<String, dynamic> json) => 
    _$QuestionContentFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = _$QuestionContentToJson(this);
    json['type'] = type;
    return json;
  }
}
