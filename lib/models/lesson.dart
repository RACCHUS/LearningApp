import 'package:hive/hive.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:learning_pwa/models/term.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/models/concept.dart';

part 'lesson.g.dart';

@HiveType(typeId: 0)
class Lesson extends BaseLesson {
  @HiveField(0)
  final List<Term> terms;
  @HiveField(1)
  final List<Question> questions;
  @HiveField(2)
  final List<Concept> concepts;

  // BaseLesson fields need to be redeclared for Hive
  @HiveField(3)
  final String id;
  @HiveField(4)
  final String title;
  @HiveField(5)
  final String? description;
  @HiveField(6)
  final List<String> tags;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final DateTime updatedAt;
  @HiveField(9)
  final String userId;

  const Lesson({
    required this.id,
    required this.title,
    this.description,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.terms,
    required this.questions,
    required this.concepts,
  }) : super(
    id: id,
    title: title,
    description: description,
    tags: tags,
    createdAt: createdAt,
    updatedAt: updatedAt,
    userId: userId,
  );

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      tags: List<String>.from(json['tags'] as List),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userId: json['user_id'] as String,
      terms: (json['terms'] as List).map((t) => Term.fromJson(t)).toList(),
      questions: (json['questions'] as List).map((q) => Question.fromJson(q)).toList(),
      concepts: (json['concepts'] as List).map((c) => Concept.fromJson(c)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'tags': tags,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'user_id': userId,
    'terms': terms.map((t) => t.toJson()).toList(),
    'questions': questions.map((q) => q.toJson()).toList(),
    'concepts': concepts.map((c) => c.toJson()).toList(),
  };

  @override
  Lesson copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    List<Term>? terms,
    List<Question>? questions,
    List<Concept>? concepts,
  }) {
    return Lesson(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      terms: terms ?? this.terms,
      questions: questions ?? this.questions,
      concepts: concepts ?? this.concepts,
    );
  }
}
