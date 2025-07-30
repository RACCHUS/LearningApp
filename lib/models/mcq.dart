import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mcq.g.dart';

@HiveType(typeId: 3)
@JsonSerializable()
class Mcq {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String lessonId;
  
  @HiveField(2)
  final String question;
  
  @HiveField(3)
  final List<String> options;
  
  @HiveField(4)
  final int correctOptionIndex;
  
  @HiveField(5)
  final String? explanation;
  
  @HiveField(6)
  final String createdBy;
  
  @HiveField(7)
  final DateTime createdAt;

  Mcq({
    required this.id,
    required this.lessonId,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
    required this.createdBy,
    DateTime? createdAt,
  })  : assert(correctOptionIndex >= 0 && correctOptionIndex < options.length,
            'correctOptionIndex must be a valid index in options'),
        createdAt = createdAt ?? DateTime.now();

  factory Mcq.fromJson(Map<String, dynamic> json) => _$McqFromJson(json);
  
  Map<String, dynamic> toJson() => _$McqToJson(this);
  
  bool isCorrect(int selectedIndex) => selectedIndex == correctOptionIndex;
}
