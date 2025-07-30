import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'concept.g.dart';

@HiveType(typeId: 2)
@JsonSerializable()
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

  factory Concept.fromJson(Map<String, dynamic> json) => _$ConceptFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConceptToJson(this);
}
