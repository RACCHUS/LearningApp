import 'package:learning_pwa/models/lesson_content.dart';

class TextContent extends LessonContent {
  final String text;

  TextContent({
    required String id,
    required String lessonId,
    required int order,
    required this.text,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(
          id: id,
          lessonId: lessonId,
          order: order,
          type: 'text',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

  factory TextContent.fromJson(Map<String, dynamic> json) {
    return TextContent(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      order: json['order'] as int,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'order': order,
        'type': type,
        'text': text,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
