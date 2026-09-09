import 'package:hive/hive.dart';
import 'package:learning_pwa/core/errors/model_parse_exception.dart';

@HiveType(typeId: 7)
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

  @HiveField(6)
  final String? emoji;

  Concept({
    required this.id,
    required this.lessonId,
    required this.conceptText,
    this.exampleText,
    this.emoji,
    required this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Concept.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final lessonId = json['lesson_id']?.toString();
    final conceptText = json['concept_text']?.toString();
    final exampleText = json['example_text']?.toString();
    final emoji = json['emoji']?.toString();
    // Accept both 'created_by' and 'user_id' for compatibility
    final createdBy = (json['created_by'] ?? json['user_id'])?.toString();
    final createdAtRaw = json['created_at']?.toString();
    final missing = <String>[
      if (id == null) 'id',
      if (lessonId == null) 'lesson_id',
      if (conceptText == null) 'concept_text',
      if (createdBy == null) 'created_by',
      if (createdAtRaw == null) 'created_at',
    ];
    if (missing.isNotEmpty) {
      throw ModelParseException(
        'Concept',
        'Missing required field(s)',
        fields: missing,
      );
    }
    final createdAt = DateTime.tryParse(createdAtRaw!);
    if (createdAt == null) {
      throw const ModelParseException(
        'Concept',
        'Invalid date format',
        fields: ['created_at'],
      );
    }
    return Concept(
      id: id!,
      lessonId: lessonId!,
      conceptText: conceptText!,
      exampleText: exampleText,
      emoji: emoji,
      createdBy: createdBy!,
      createdAt: createdAt,
    );
  }
  
  Map<String, dynamic> toJson() => {
        'id': id,
        'lesson_id': lessonId,
        'concept_text': conceptText,
        'example_text': exampleText,
        if (emoji != null) 'emoji': emoji,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}
