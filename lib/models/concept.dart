import 'package:hive/hive.dart';

@HiveType(typeId: 2)
class Concept {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String lessonId;
  
  @HiveField(2)
  final String conceptText;
  
  @HiveField(3)
  final String? exampleText;
  
  @HiveField(4)
  final String createdBy;
  
  @HiveField(5)
  final DateTime createdAt;

  Concept({
    required this.id,
    required this.lessonId,
    required this.conceptText,
    this.exampleText,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Concept.fromJson(Map<String, dynamic> json) {
    return Concept(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      conceptText: json['concept_text'] as String,
      exampleText: json['example_text'] as String?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'concept_text': conceptText,
        'example_text': exampleText,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}