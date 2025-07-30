import 'package:json_annotation/json_annotation.dart';

part 'lesson_import_model.g.dart';

@JsonSerializable()
class LessonImportModel {
  final String title;
  final String? description;
  final List<String> tags;
  final List<LessonTerm>? terms;
  final List<LessonQuestion>? questions;
  final List<LessonConcept>? concepts;

  LessonImportModel({
    required this.title,
    this.description,
    this.tags = const [],
    this.terms,
    this.questions,
    this.concepts,
  });

  factory LessonImportModel.fromJson(Map<String, dynamic> json) =>
      _$LessonImportModelFromJson(json);
  Map<String, dynamic> toJson() => _$LessonImportModelToJson(this);
}

@JsonSerializable()
class LessonTerm {
  final String term;
  final String definition;
  final String? example;

  LessonTerm({
    required this.term,
    required this.definition,
    this.example,
  });

  factory LessonTerm.fromJson(Map<String, dynamic> json) =>
      _$LessonTermFromJson(json);
  Map<String, dynamic> toJson() => _$LessonTermToJson(this);
}

@JsonSerializable()
class LessonQuestion {
  final String question;
  final List<String> options;
  @JsonKey(name: 'correct_answer')
  final int correctAnswer;
  final String? explanation;
  final String? type;

  LessonQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.type = 'multiple_choice',
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) =>
      _$LessonQuestionFromJson(json);
  Map<String, dynamic> toJson() => _$LessonQuestionToJson(this);
}

@JsonSerializable()
class LessonConcept {
  final String text;
  final String? example;
  @JsonKey(name: 'key_points')
  final List<String>? keyPoints;

  LessonConcept({
    required this.text,
    this.example,
    this.keyPoints,
  });

  factory LessonConcept.fromJson(Map<String, dynamic> json) =>
      _$LessonConceptFromJson(json);
  Map<String, dynamic> toJson() => _$LessonConceptToJson(this);
}
