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
    print('DEBUG: Concept.fromJson input: ' + json.toString());
    final id = json['id']?.toString();
    final lessonId = json['lesson_id']?.toString();
    final conceptText = json['concept_text']?.toString();
    final exampleText = json['example_text']?.toString();
    // Accept both 'created_by' and 'user_id' for compatibility
    final createdBy = (json['created_by'] ?? json['user_id'])?.toString();
    final createdAtRaw = json['created_at']?.toString();
    if (id == null || lessonId == null || conceptText == null || createdBy == null || createdAtRaw == null) {
      print('ERROR: Null value in Concept.fromJson fields. id: $id, lessonId: $lessonId, conceptText: $conceptText, createdBy: $createdBy, createdAt: $createdAtRaw');
      throw Exception('Null value in required Concept field');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      print('ERROR: Invalid date format in Concept.fromJson: $createdAtRaw');
      throw Exception('Invalid date format in Concept.fromJson');
    }
    return Concept(
      id: id,
      lessonId: lessonId,
      conceptText: conceptText,
      exampleText: exampleText,
      createdBy: createdBy,
      createdAt: createdAt,
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