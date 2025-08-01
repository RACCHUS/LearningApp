import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'lesson_content.dart';

part 'mcq.g.dart';

@HiveType(typeId: 4)
@JsonSerializable()
class Mcq extends LessonContent {
  @HiveField(6)
  final String question;

  @HiveField(7)
  final List<String> options;

  @HiveField(8)
  final int correctOption;

  @HiveField(9)
  final String? explanation;

  Mcq({
    required super.id,
    required super.lessonId,
    required super.order,
    required this.question,
    required this.options,
    required this.correctOption,
    this.explanation,
    required super.createdAt,
    required super.updatedAt,
  }) : super(type: 'mcq');

  factory Mcq.fromJson(Map<String, dynamic> json) => _$McqFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$McqToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is Mcq &&
          runtimeType == other.runtimeType &&
          question == other.question &&
          listEquals(options, other.options) &&
          correctOption == other.correctOption &&
          explanation == other.explanation;

  @override
  int get hashCode =>
      super.hashCode ^
      question.hashCode ^
      options.hashCode ^
      correctOption.hashCode ^
      explanation.hashCode;
}
