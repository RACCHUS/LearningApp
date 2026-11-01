import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:learning_pwa/models/lesson_content.dart';

part 'term_content.g.dart';

@HiveType(typeId: 8)
@JsonSerializable()
class TermContent extends LessonContent {
  @HiveField(6)
  final String term;

  @HiveField(7)
  final String definition;

  @HiveField(8)
  final String? example;

  TermContent({
    required super.id,
    required super.lessonId,
    required super.order,
    required this.term,
    required this.definition,
    this.example,
    required super.createdAt,
    required super.updatedAt,
  }) : super(
          type: 'term',
        );

  factory TermContent.fromJson(Map<String, dynamic> json) => 
    _$TermContentFromJson(json);

  @override
  Map<String, dynamic> toJson() {
    final json = _$TermContentToJson(this);
    json['type'] = type;
    return json;
  }
}
