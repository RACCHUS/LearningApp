import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:learning_pwa/models/lesson_content.dart';

part 'concept_content.g.dart';

@HiveType(typeId: 6)
@JsonSerializable()
class ConceptContent extends LessonContent {
  @HiveField(6)
  final String conceptText;

  @HiveField(7)
  final String? exampleText;

  @HiveField(8)
  final List<String>? keyPoints;

  ConceptContent({
    required super.id,
    required super.lessonId,
    required super.order,
    required this.conceptText,
    this.exampleText,
    this.keyPoints,
    required super.createdAt,
    required super.updatedAt,
  }) : super(
          type: 'concept',
        );

  factory ConceptContent.fromJson(Map<String, dynamic> json) => 
    _$ConceptContentFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = _$ConceptContentToJson(this);
    json['type'] = type;
    return json;
  }
}
